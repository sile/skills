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
- On the library crate root (`src/lib.rs`):

  ```rust
  #![warn(missing_docs)]
  #![forbid(unsafe_code)]
  ```

  - Write these inner attributes in every library crate in a
    workspace. Do not fold them into Cargo.toml `[lints]`.
  - Do not remove `forbid(unsafe_code)` or propose `unsafe` code unless
    the user explicitly agrees to lift it.

## Error Handlings

- Do not use `unwrap` or `unwrap_err`. Use `expect` or `expect_err` instead.
  - In documentation examples, prefer `?` wherever possible.

## Imports

- `use` is only for `std` (including `core` and `alloc`) and items in
  the current crate (`crate`, `super`, `self`, and local `mod`s). Refer
  to other crates with fully qualified paths (e.g. `other_crate::Widget`).
  - Traits are an exception: `use some_crate::SomeTrait;` is allowed so
    trait methods can be called as methods.
  - Rationale: a code fragment should show where each item comes from
    without opening the file header. `std` is shared vocabulary, so an
    unfamiliar name is then something defined in this crate.
  - This applies everywhere: library and binary code (`src/`), tests
    (`tests/`), examples (`examples/`), and documentation examples.

## Rustdoc intra-doc links

Rendered rustdoc displays the link *label*, not only the destination.
On public items, keep that label free of `crate::` and `Self::`.

- When the item is not in the current module, put `crate::` in the
  explicit target, not in the label:

  ```markdown
  [`Widget`](crate::Widget)
  [`Builder::finish`](crate::Builder::finish)
  [`docs::guide`](crate::docs::guide)
  ```

  Do not write `` [`crate::Widget`] ``.
- On public items, name the type instead of `Self`: write
  `` [`Builder::MAX`] ``, not `` [`Self::MAX`] ``. Callers write the
  type name; `Self::` reads as an impl-block leftover.
- `Self::` and `crate::` in the label are fine on `pub(crate)` and
  private items, which rustdoc does not publish by default.
- An external crate path in the label (`std::…`, a dependency) is
  fine when the origin is useful.
- Code samples in documentation still follow the import rule above;
  that rule is about source fragments, not link labels.
