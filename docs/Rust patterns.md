# Patterns in Rust code

## Newtypes

The newtype idiom gives compile time guarantees that the right type of value is supplied to a program. We use structs
with tuple syntax, as in:

```rust
struct Years(i64);

struct Days(i64);

impl Days {
    pub fn to_years(&self) -> Years {
        Years(self.0 / 365)
    }
}
```

Note that you will likely need a `new` static method to be able to instantiate new instances of your newtype.

If you are wrapping a `String`, implement the `Deref` trait for your newtype as that will allow the compiler to
automatically turn your `&type` to a `&str` using the inner value. Same with `FromStr` and parsing. Just beware that
this exposes the wrapped data!
See:

```rust
pub struct PhoneNumber(String);

use std::str::FromStr;

impl FromStr for PhoneNumber {
    type Err = Box<dyn std::error::Error>;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(PhoneNumber(s.to_string()))
    }
}

use std::ops::Deref;

impl Deref for PhoneNumber {
    type Target = str;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let num = PhoneNumber::from_str("555-1234")?;

    // Deref can be called when we take a reference. The function
    // takes a &str and our type can Deref from &PhoneNumber to &str.
    print_strings(&num);
    Ok(())
}

fn print_strings(s: &str) {
    println!("I've been asked to print {}", s);
}
```

If you don't wrap a `String`, use `From` and `Into` traits instead. Note that you only need tom implement `From`.

For integration with `Serde`, implement `TryFrom<T>` so that Serde doesn't bypass any validations you added.

## Associated types

It's a way to avoid having to define generic parameters on all the call points involving a trait. We can define a trait
with 2 generic parameters like:

```rust
trait Contains<A, B> {
    fn contains(&self, _: &A, _: &B) -> bool;
    // Explicitly requires `A` and `B`.
    fn first(&self) -> i32;
    // Doesn't explicitly require `A` or `B`.
    fn last(&self) -> i32;  // Doesn't explicitly require `A` or `B`.
}

impl Contains<i32, i32> for Container {
    //....
}
```

But any function using this trait will need to define `<A, B, C: Contains<A,B>>` for it to compile.

Using associated types, we move the generics inside the trait:

```rust
trait Contains {
    type A;
    type B;

    // Updated syntax to refer to these new types generically.
    fn contains(&self, &Self::A, &Self::B) -> bool;
}

impl Contains for Container {
    // Specify what types `A` and `B` are. If the `input` type
    // is `Container(i32, i32)`, the `output` types are determined
    // as `i32` and `i32`.
    type A = i32;
    type B = i32;

    // ...
}
```

This means a function can reference `<C: Contains>` without having to specify `A` nor `B`, reducing boilerplate

## Phantom types

A phantom type parameter is one that doesn't show up at runtime, but is checked statically (and only) at compile time.
They are marked using `use std::marker::PhantomData;`

```rust
use std::marker::PhantomData;

struct PhantomTuple<A, B>(A, PhantomData<B>);

fn main() {
    let _tuple1: PhantomTuple<char, f32> = PhantomTuple('Q', PhantomData);
}
```

An example of a use case for PhantomTypes can be to avoid operating with incompatible units, like meters and inches

```rust
use std::marker::PhantomData;

/// Create void enumerations to define unit types.
enum Inch {}

enum Mm {}

// Unit is the name of the generic type
struct Length<Unit>(f64, PhantomData<Unit>);

impl<Unit> Add for Length<Unit> {
    type Output = Length<Unit>;

    fn add(self, rhs: Length<Unit>) -> Length<Unit> {
        Length(self.0 + rhs.0, PhantomData)
    }
}

fn main() {
    let one_foot: Length<Inch> = Length(12.0, PhantomData);
    let one_meter: Length<Mm> = Length(1000.0, PhantomData);

    //below fails at compile time due to phantom type
    let _one_feter = one_foot + one_meter;
}
```

## Named closures

Because closure types don't have names, you can't write out an explicit return type if your function returns closures,
like iterators with closures. But you can use `impl Trait` to work around it:

```rust
fn double_positives<'a>(numbers: &'a Vec<i32>) -> impl Iterator<Item=i32> + 'a {
    //this is returning closures, but we mark the return type as the trait and all is fine
    numbers
        .iter()
        .filter(|x| x > &&0)
        .map(|x| x * 2)
}
```

## Avoid cloning

It is common to try to avoid the borrow checker by using `clone()` but that is an anti-pattern. Cloning is acceptable in
some cases, like `Rc` and `Arc` which handle the references intelligently. But, in general, it should be avoided as it
it a hack around a legit issue.

Clippy may alert about some unnecessary clones when run.