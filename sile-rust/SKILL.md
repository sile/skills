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
  - Default to `forbid(unsafe_code)`: it cannot be overridden, so an
    accidental `unsafe` cannot slip through. Do not propose `unsafe`
    code unless the user explicitly agrees to lift it.
  - Some crates genuinely cannot avoid `unsafe` (for example, calling
    `libc` directly). For such a crate only, relax the attribute to
    `#![deny(unsafe_code)]` and document per crate why the relaxation
    is needed. A `deny` crate marks the surviving `unsafe` with
    `#[expect(unsafe_code, reason = "...")]` (see the Lints section),
    so every exception is visible in review. Keep the relaxation to
    the crate that needs it; do not widen it.
  - The relaxation is per crate, so a project can legitimately have a
    `forbid(unsafe_code)` library next to a `deny(unsafe_code)` binary
    that wraps `libc`. Relax only the crate that needs the `unsafe`;
    the library keeps `forbid`, which is why the two attributes can
    differ within one project. Do not raise the library to `deny` to
    "match" the binary.
  - Prefer the narrowest scope that still says something useful. When
    one module holds all the FFI (say, a `sys` module that wraps
    `libc`), a single file-level `#[expect]` on that module is the
    right granularity: the reason is the same at every site, and
    repeating it per function adds noise without adding review signal.
    Narrow it to one function only when that lets you say something
    the module-level reason cannot.

- Skip `#![warn(missing_docs)]` on a **binary** crate (a crate root
  with only a `main`). It is a convenience hint for a reusable public
  API; for an application nobody links, documenting every internal
  item is busywork with no caller to benefit.
  - The `unsafe_code` attribute still applies there, at the same
    strictness as a library: `forbid` by default, `deny` only for the
    rare binary that cannot avoid `unsafe`.
  - This is per crate. In a workspace with both a library and a
    binary, the library root gets `warn(missing_docs)` and the binary
    root omits it; both get the `unsafe_code` attribute.

## Cargo config

For repositories worked on by an agent, add a repository-level
`.cargo/config.toml` to quiet cargo's success noise:

```toml
[term]
quiet = true
```

This strips only per-test boilerplate (`running N tests`,
`test foo::bar ... ok`) from `cargo test` and similar commands. It keeps
everything useful: failures (`test result: FAILED`, `panicked at ...`),
warnings, and `cargo fmt --check` diffs are still shown in full. The config
is a default, so a single command can opt back in with `cargo test -v` or
`CARGO_TERM_QUIET=false cargo test`.

## Module layout

Start with a **flat** `src/` layout. Do not introduce directory
modules (`src/foo/`) or nested `mod` trees unless the user asks for
them, or unless keeping everything flat would make the code harder to
follow than a hierarchy (for example, many large sibling files that
share a clear boundary).

- Prefer sibling files with a common prefix:
  `terminal.rs`, `terminal_emu.rs`, `terminal_buffer.rs`.
- Do not use `mod.rs`. Use `<module>.rs`; if a directory module is
  unavoidable, use `<module>.rs` plus `<module>/<submodule>.rs`
  (`tests/` is an exception; see the Tests section).
- Do not create `src/<module>/` subdirectories on your own initiative.

### `src/lib.rs`

- Declare modules at the crate root (`mod pty;`, `mod terminal;`, …).
- **Re-export** the public API from `lib.rs` so callers use
  `my_crate::TerminalState`, not `my_crate::terminal::TerminalState`.
- Keep implementation modules private; only types and functions meant
  for callers appear in `pub use`.

### When to depart from flat layout

Hierarchy is allowed when:

1. The user explicitly asks to reorganize into directories or nested
   modules, or
2. Flat files would be worse than a hierarchy (size, cohesion, or
   navigation cost)—and the reason is obvious from the code.

## Tests

- Prefer `tests/` over `#[cfg(test)] mod tests` in `src/`, so a test
  exercises the API the way a caller sees it.
- Keep a test in `src/` only when it needs a private item (a private
  function, a private field, or a private module).
- Name a test file after what it covers (`tests/terminal.rs`,
  `tests/style.rs`), not after the test style (so there is no
  `tests/pbt.rs`).
- Put a helper shared by several test files in a subdirectory of
  `tests/` and use `mod.rs` there (`tests/<name>/mod.rs`): Cargo
  compiles every file directly under `tests/` as its own test target,
  so the helper cannot be `tests/<name>.rs`.
- Keep helper modules flat, one per subject, and name each after that
  subject (`tests/helpers_foo/mod.rs`, `tests/helpers_bar/mod.rs`).
  Grouping them under a single parent
  (`mod helpers { mod foo; mod bar; }`) looks tidier, but a test file
  can only declare the whole parent module: `mod helpers;` pulls in
  every submodule, so a test file that needs one helper would also
  build the others. A sibling module per subject lets each test file
  declare exactly the helpers it uses.
- Share a helper between test files only when more than one file
  actually needs it. A helper used by a single file belongs in that
  file, and a small amount of repetition across test files is fine:
  prefer redefining something locally over forcing it into an existing
  helper module whose name no longer fits. Factor it out into
  `tests/<name>/mod.rs` once the same need shows up often enough that
  the duplication starts to cost more than the indirection.
- Prefer a property-based test to an example-based one whenever the
  requirement can be stated as a property ("for any input ..., ..."),
  and keep an example-based test for what a property cannot express (a
  crash reproduced from a reported seed, an exact message, a worked
  example).
- Write properties with `noprop`; see the `noprop` skill.

## API design

A library is composed by its callers. Do not let it impose an implicit
policy or constraint on them.

- Expose mechanism and state; leave policy to the caller. Publish a way
  to observe the condition the caller must decide on, and a way to carry
  out that decision in one step. The shape is the layer's own business;
  the rule is that the caller decides, not the library.
- Never hide a decision with a user-visible trade-off (a timeout, a retry,
  a buffer cap, an automatic recovery). Provide a default only if it is
  explicit, documented, and overridable.
- This matters most for a low-level, foundational layer: the more code
  sits on top of it, the more freedom and choice it must keep. A utility
  convenience layer may offer integrated defaults; a foundation must not.
- Extra caller-side code is acceptable when the alternative is a policy
  the caller cannot see or override.
- Do not mark an enum with `#[non_exhaustive]`. A caller that
  enumerates every variant should get a compile error when a new variant
  is added, so the new case is handled rather than silently falling
  through a `_ => ...` arm.

See [api-design.md](api-design.md) for worked examples.

## Lints

- Suppress a lint with `#[expect(...)]`, not `#[allow(...)]`.
  - `expect` states that the lint *does* fire here. When the code changes
    so it no longer fires, `unfulfilled_lint_expectations` reports the now
    stale `expect`; `allow` would stay silent forever, so a suppression
    outlives its reason.
  - Give a `reason = "..."` so the suppression explains itself.

  ```rust
  #[expect(
      clippy::should_implement_trait,
      reason = "the type is a stateful parser, not an iterator"
  )]
  ```

- The same form covers a crate relaxed to `deny(unsafe_code)` (see the
  Project defaults section). A direct `libc` call is the ordinary
  case. Mark the smallest item that owns the reason:

  ```rust
  #[expect(
      unsafe_code,
      reason = "libc::kill needs an unsafe call to probe a pid"
  )]
  fn probe_pid(pid: i32) -> bool {
      unsafe { libc::kill(pid, 0) == 0 }
  }
  ```

  When the `unsafe` is spread across one module, put the `expect` in
  that module's file header as an inner attribute instead:

  ```rust
  // src/sys.rs

  #![expect(
      unsafe_code,
      reason = "terminal mode control and SIGWINCH handling go through libc"
  )]
  ```

  `deny(unsafe_code)` still makes the compiler list every site, so one
  file-level `expect` does not hide where the `unsafe` is. Leave the
  `unsafe` blocks themselves as small as possible (wrap the `libc` call,
  not the surrounding logic), so each one is easy to audit.

  Use the per-function form when only one function needs it. Keep the
  `expect` out of `lib.rs` when the `unsafe` belongs to one
  implementation module.

## Error Handlings

- Do not use `unwrap` or `unwrap_err`. Use `expect` or `expect_err` instead.
  - In documentation examples, prefer `?` wherever possible.

## Imports

- `use` is only for `std` (including `core` and `alloc`) and items in
  the current crate (`crate`, `super`, `self`, and local `mod`s). Refer
  to other crates with fully qualified paths (e.g. `other_crate::Widget`).
  - "Current crate" means the compiling crate root, not the project
    directory. In a project with both `src/lib.rs` and `src/main.rs`,
    the binary is a separate crate from the library, so it names the
    library in full (`my_crate::Widget`), exactly like a dependency.
    The same holds for `tests/`, `examples/`, and `benches/`, which
    Cargo compiles as their own crates. A project's own library is not
    special: `use my_crate::Widget;` in a binary or a test is the same
    mistake as `use other_crate::Widget;`. Only `use crate::…` and
    `use super::…` reach items in the crate being compiled.
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
  [`Builder::finish()`](crate::Builder::finish)
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
- For a method or function, always write the `()` so the reader can
  tell it is a callable item and not a type or constant: `` [`value()`](Self::value) ``,
  not `` [`value`](Self::value) ``.

## Doc comments

Describe the *current* design. A first-time reader has no knowledge of the
commit history, branch naming, or previous versions, so the doc must not rely
on any of those.

- Say what the item does now. Avoid describing it by contrast with an earlier
  state (e.g. 'no longer …', 'used to be …', 'previously …', 'this used to').
  Such wording only makes sense to someone who knows the old API, so it
  communicates nothing to a new reader. State the behavior directly instead.
- Do not restate a fact the same doc already established one line above.
