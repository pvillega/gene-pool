#!/usr/bin/env bash
dir="$(cd "$(dirname "$0")" && pwd)"
cd "${dir}"/.. || exit

echo "Run fmt to format code"
cargo fmt
