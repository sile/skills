#! /bin/sh

set -eux

daberu -x clean-files

pushd ../../rust/nojson

echo 'create skill files for this Rust crate' | \
  daberu -k skill-creator \
    -r README.md \
    -r Cargo.toml \
    -r src/lib.rs \
    -r src/display_json.rs \
    -r src/raw.rs \
    -r src/format.rs \
    -r src/kind.rs \
    -r src/parse.rs \
    -r src/parse_error.rs \
    -r src/try_from_impls.rs \
    -r tests/test_format.rs \
    -r tests/test_jsonc.rs \
    -r tests/test_parse.rs

popd
