---
name: sile-rust
description: >-
  sile's personal Rust coding conventions. Use when creating, writing,
  or reviewing Rust code in personal projects.
---

# sile-rust

Personal Rust coding conventions.

## Project defaults

Personal crates use these project-level defaults. Apply them when
creating a crate and when reviewing an existing one.

- Set `edition = "2024"` in Cargo.toml (workspace root or each crate).
- Use the stable toolchain only. Do not use nightly, `#![feature(...)]`,
  or nightly-only Cargo features.
- At the top of each crate root (`lib.rs` and/or `main.rs`):

  ```rust
  #![warn(missing_docs)]
  #![forbid(unsafe_code)]
  ```

  - Write these inner attributes in every crate in a workspace. Do not
    fold them into Cargo.toml `[lints]`.
  - Do not remove `forbid(unsafe_code)` or propose `unsafe` code unless
    the user explicitly agrees to lift it.

## Conventions

- Do not use `unwrap` or `unwrap_err`. Use `expect` or `expect_err` instead.
  - In documentation examples, prefer `?` wherever possible.

## Imports (tests, examples, and docs)

- In integration tests (`tests/`), example code (`examples/`), and
  documentation examples, do not `use` items from external crates. Refer
  to them with fully qualified paths (e.g. `my_crate::Widget`,
  `dev_tools::Runner`).
  - Traits are an exception: `use some_crate::SomeTrait;` is allowed so
    trait methods can be called as methods.
  - `std` is also an exception: `use std::...` is allowed because it is
    shared vocabulary.
  - Rationale: a code fragment should show where each item comes from
    without opening the file header.
  - `use super::*`, `mod` helpers, and same-crate paths (e.g.
    `helpers::...` from a sibling test module) are fine; the rule targets
    the crate under test, third-party crates, and sibling-workspace crates,
    not local test modules.
  - Implementation code under `src/` is out of scope; normal `use` there
    is fine. Documentation examples in `src/` still follow this rule.
