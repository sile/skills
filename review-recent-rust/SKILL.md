---
name: review-recent-rust
description: >-
  Audits a Rust crate for stable language and std features relative to
  its MSRV. Reports what can be adopted now versus what a higher MSRV
  would unlock. Use when the user asks to check unused stable Rust
  features, whether to bump rust-version, or invokes
  /review-recent-rust. Do not use when writing new code or doing a
  general bug review.
---

# review-recent-rust

Report whether this crate is missing stable language/`std` features
relative to its MSRV, and whether raising MSRV would unlock enough
that applies to *this* code. Do not edit files, run `cargo fix`,
change `rust-version`, or migrate edition.

Read [catalog.md](catalog.md) after resolving MSRV.

## Out of scope

- Nightly, `#![feature(...)]`, or unsafe replacements
- Re-checking sile-rust rules (`expect`, imports, Project defaults,
  `missing_docs`, folding lints into Cargo.toml)
- General quality review, fashionable crate swaps, or listing new
  APIs that do not improve this codebase
- Edition upgrades (`cargo fix --edition`)

## Resolve MSRV

State this budget to the user before scanning.

1. If `Cargo.toml` has `rust-version` (package or
   `[workspace.package]`), that is MSRV.
2. Otherwise MSRV is the compiler floor for the crate's `edition`:
   - 2024 → 1.85
   - 2021 → 1.56
   - 2018 → 1.31
   - 2015 → 1.0
3. If `rust-version` is lower than the edition floor, report the
   inconsistency and use the edition floor as the effective MSRV.

Workspace: resolve per crate when `edition` / `rust-version` differ.

CI toolchain (`.github/workflows`, `rust-toolchain.toml`) is **not**
MSRV. If CI is newer than MSRV, mention that raising `rust-version`
toward CI may be cheap. Do not treat CI as the contract.

## Workflow

1. Resolve MSRV and note `edition`.
2. Run `cargo clippy` (default lints) as a signal. Do not pass
   `--fix` or enable pedantic/nursery. If clippy cannot run, say so
   and continue from the catalog.
3. Read [catalog.md](catalog.md). For each entry, search this
   codebase. Skip anything that is not present or would not help.
   Classify:
   - **Usable now** if `since <= MSRV` (and `edition` matches, if
     the entry requires one)
   - **Needs MSRV *since*** if `since > MSRV`
   - Drop edition-gated entries when `edition` is too old (do not
     propose an edition bump)
4. Check stable releases newer than catalog `Last reviewed` on
   [releases.rs](https://releases.rs) or the [Rust blog](https://blog.rust-lang.org/).
   Only mention a newer stable API if it would change this code.
   Ignore nightly and unstable features.
5. Print the report and stop. Do not apply changes.

Do not compile throwaway snippets in the crate tree. `rustc -`
(stdin) writes `./rust_out` by default. If a snippet must be
compiled, send the binary to a temp path (`-o` / `--out-dir`)
and delete it; never leave `rust_out` or similar artifacts.

## Report

Each finding: path, current pattern, suggested replacement, `since`,
clippy lint if any, and Usable now vs Needs MSRV.

Group **Needs MSRV** by the version required (e.g. everything that
needs 1.88 together).

End with **Keep vs bump**:

- Keep the current MSRV if Needs MSRV findings are thin or weak
- Suggest considering a bump to *X.Y* only when several findings
  that matter here cluster at that version (cite them)
- If CI already uses *X.Y* or newer, say so

Do not write "this would be more modern" without a concrete pattern
in this tree. Nested `if let` that is already clear is a judgment
call, not a must-change.

Within Usable now, mark **clear win** (dependency removal, clippy
backing, same meaning) vs **judgment call** (readability).
