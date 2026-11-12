# Feature catalog

Last reviewed: 2026-11-12 against **Rust 1.100.0** (current stable, 2026-11-12).

Hand-maintained list of stable features that change how code is
written. Not a changelog. Skip pre-1.70 items that clippy already
covers (`let-else`, and similar). Do not suggest unsafe APIs.

Each `since` is the rustc version that stabilized the feature
(from rustdoc or the official release notes). `edition: any` means
no edition gate beyond what that rustc already supports.

Only report an entry when this codebase actually has the old
pattern.

## Cargo lints and resolution

These are `Cargo.toml` / `.cargo/config.toml` changes, not code
patterns. The scan can only report what the manifest says.

### Unused-dependency reporting

- since: 1.100
- edition: any
- replaces: relying on `unused_crate_dependencies` in rustc, which
  false-positives on a package with several bins and `[lints]`
- look for: `unused_crate_dependencies` in Cargo.toml or in a crate
  root; stale entries in `[dependencies]`
- when not: the warning only fires when every build target that
  could use a dependency is built. `cargo check --bin foo` will
  not report an unused `[dependencies]` entry, and dev-dependencies
  are never reported, so a crate that is only checked one target
  at a time gains nothing from deleting the rustc lint. Config is
  `[lints.cargo]` in Cargo.toml; the default level is `warn`

### `cargo install` minimum publish age

- since: 1.100
- edition: any
- replaces: nothing in a crate. It is a resolution policy for the
  registry Cargo reads from
- look for: a `.cargo/config.toml` with `[registry]`; a
  `cargo install` in docs or CI
- when not: say nothing unless the user asks for supply-chain
  hardening. `cargo install` ignores the setting, so pin with
  `foo@1.2.3` there instead. Mention it as a suggestion at most;
  never add it to a crate's manifests as part of a review

## Crate → std

### `std::sync::OnceLock` / `std::cell::OnceCell`

- since: 1.70
- edition: any
- replaces: `once_cell::sync::OnceCell`, `once_cell::unsync::OnceCell`
- look for: `once_cell` in Cargo.toml and those types
- when not: the crate still needs `once_cell` APIs std does not have
  (for example `get_or_try_init` on stable)

### `std::sync::LazyLock` / `std::cell::LazyCell`

- since: 1.80
- edition: any
- replaces: `lazy_static!`, `once_cell::sync::Lazy`,
  `once_cell::unsync::Lazy`
- look for: `lazy_static`, `once_cell::...Lazy`, `Lazy::new`
- when not: init can be `const`; init needs arguments after
  construction (use `OnceLock` instead)

### `std::io::IsTerminal`

- since: 1.70
- edition: any
- replaces: `atty`, `isatty` helpers
- look for: `atty::`, `.is_atty(`, crate `atty` in Cargo.toml
- when not: targeting a platform where `IsTerminal` is known-false
  and the old crate behaved differently on purpose

### C-string literals (`c"..."`)

- since: 1.77
- edition: 2021+ (prefix reserved in 2021)
- replaces: `CStr::from_bytes_with_nul`, `cstr` crate, `CString::new`
  for `'static` literals
- clippy: `clippy::manual_c_str_literals`
- look for: `CStr::from_bytes_with_nul(b"...\\0")`, `cstr::cstr!`
- when not: the bytes are not a literal; interior NUL is possible
  at runtime

## Async and traits

### `async fn` in traits

- since: 1.75
- edition: any
- replaces: `#[async_trait]` when the trait is not used as `dyn Trait`
- look for: `async_trait` in Cargo.toml, `#[async_trait]`
- when not: the trait must stay dyn-compatible (`dyn Trait`); keep
  `async-trait` (or an equivalent boxed-future design)

### RPITIT (`impl Trait` in trait methods)

- since: 1.75
- edition: any
- replaces: `Box<dyn Future...>` / associated-type boilerplate on
  trait methods that can name `impl Trait` in return position
- when not: the concrete type must be named; object safety requires
  a boxed return

### Async closures (`async || { ... }`)

- since: 1.85
- edition: any
- replaces: `|| async { ... }` when the future must borrow
  captures, or `Fn` + `Future` bounds that should be `AsyncFn`
- look for: `|| async {`, `impl Fn(...) -> impl Future`,
  `for<'a> Fn(&'a ...) -> Fut`
- when not: a plain `|| async {}` that does not borrow captures is
  already fine; do not rewrite those for novelty

## Errors and divergence

### The never type `!`

- since: 1.100
- edition: any for naming `!` (the coercion existed before)
- replaces: `Infallible` in the `E` position of a `Result` or as a
  phantom error type, an `enum` whose only purpose is to be
  uninhabited, and `fn ... -> !` paired with a separate uninhabited
  error type
- look for: `Infallible`, `Result<_, Infallible>`, an `enum` no
  value is ever constructed for, `fn ... -> !`
- when not: the empty error type is published API and renaming it
  churns its docs; do not rename public types on the strength of
  this entry alone. Do not propose the other direction either: a
  `!` in a signature is not a reason to lower an MSRV below 1.100,
  only a reason a bump to 1.100 costs nothing
- also: MSRV gates more than spelling here. Since 1.100 the never
  type fallback is `!` in every edition. Code whose `?`/`unwrap`
  operand type was inferred by the old `()` fallback may stop
  compiling, so a crate that builds on pre-1.100 rustc must be
  built on both versions before a claim of raising `rust-version`
  past 1.100 is made

### `std::mem::DropGuard`

- since: 1.100
- edition: any
- replaces: a hand-written guard struct plus `impl Drop` whose only
  job is to run a closure, and the `Option<T>` plus `take()` or
  `mem::forget` dance that goes with it
- look for: a struct holding a value and a closure where `Drop`
  calls the closure; `mem::forget` or `Option::take` used only to
  skip the destructor on the success path
- when not: the closure must run on success too, or the guard is
  public API. `Deref` reaches the wrapped value as `&T` and
  `DerefMut` as `&mut T`; code that needs it back by value takes
  it from `dismiss`, which skips the closure

## Edition 2024 and rustc version

### Let chains

- since: 1.88
- edition: 2024 only
- replaces: nested `if let` / `if let` plus boolean, `while let`
  plus extra conditions
- look for: nested `if let` / `if let` followed by `if cond`
- when not: the nest is two levels and already clear; skip if
  edition is not 2024 (do not propose an edition bump)

### `if let` guards on `match` arms

- since: 1.95
- edition: any
- replaces: a `match` arm whose body is immediately `if let ...`
  (or a boolean guard plus a nested `if let`)
- look for: `=> { if let`, `if let` nested in a match arm
- when not: the inner `if let` has a meaningful `else` that is not
  just falling through to `_`; `if let` guards are not used for
  exhaustiveness

### Precise capturing (`impl use<...> Trait`)

- since: 1.82
- edition: any (`use<>` itself); overcapture is the 2024 default
- replaces: dummy `Captures<'a>` parameters, extra lifetime args
  that exist only to control RPIT capture
- look for: `Captures`, RPIT that should not capture a lifetime,
  `impl Trait` in return position on edition 2024 that is hard to
  use because it captured too much
- when not: capturing every in-scope lifetime is what the API wants

## Attributes and Cargo

### `#[expect(...)]`

- since: 1.81
- edition: any
- replaces: `#[allow(...)]` when the lint is expected to fire and
  should warn if it stops
- clippy: `clippy::allow_attributes` (when enabled)
- look for: `#[allow(` on items that are waiting on a lint or a
  temporary workaround
- when not: the lint must stay silenced even if it goes quiet;
  that is rare — prefer `expect`

### `cargo::` build-script instructions

- since: 1.77
- edition: any
- replaces: `println!("cargo:key=value")` in `build.rs`
- look for: `println!("cargo:`
- when not: none; the old `cargo:` form still works, so this is a
  judgment call unless the script is being touched anyway

### `cfg(true)` / `cfg(false)`

- since: 1.88
- edition: any
- replaces: `cfg(all())` / `cfg(any())` as always-on / always-off,
  or ad-hoc dummy predicates
- look for: `cfg(all())`, `cfg(any())`, comments that a cfg is a
  hardcoded on/off switch
- when not: the predicate is a real feature/target check

### `cfg_select!`

- since: 1.95
- edition: any
- replaces: the `cfg-if` crate (`cfg_if!`)
- look for: `cfg_if`, `cfg-if` in Cargo.toml
- when not: a single `#[cfg(...)]` is enough; do not introduce
  `cfg_select!` for one predicate

## Allocator and unsafe construction

`std::mem::conjure_zst` (1.100) is not in this catalog. It is
`unsafe fn` and exists to construct a value the type's invariants
may forbid, so it belongs to the crate that owns those invariants
(and only under `deny(unsafe_code)`), never to a review that starts
from `forbid(unsafe_code)`. Treat an existing
`unsafe { transmute(()) }` / `MaybeUninit::uninit().assume_init()`
zero-sized construction as the one place `conjure_zst` is the
smaller `unsafe`, and report it as such only when the crate already
accepts `unsafe`.

### `std::alloc::Allocator`

- since: 1.100
- edition: any
- replaces: a hand-written arena or pool type that stores its
  storage next to a `Vec` / `Box` because std could not be given an
  allocator
- look for: `Arena<T>`, `Bump`, `Pool` types that own a `Vec` of
  raw storage; `Vec::new` / `Box::new` in a hot path with a comment
  about arena or pool allocation
- when not: the release stabilizes `Allocator` on `Vec` and `Box`
  only, so an allocator on `HashMap`, `String`, or `Rc`/`Arc` as a
  container is still unstable. A custom allocator is
  `unsafe impl Allocator`, which `forbid(unsafe_code)` crates
  cannot write at all. Report the allocator-taking constructors a
  crate can use from a dependency's allocator, not a proposal to
  write one

## std APIs

### `Option::is_some_and` / `Result::is_ok_and`

- since: 1.70 (`is_none_or` / `is_err_and`: 1.82)
- edition: any
- replaces: `opt.map(|x| pred(x)).unwrap_or(false)` → `is_some_and`,
  `opt.map(|x| pred(x)).unwrap_or(true)` → `is_none_or`,
  `matches!(opt, Some(x) if pred(x))` used only as a bool
- look for: `.map(...).unwrap_or(false)`, `.map(...).unwrap_or(true)`
- clippy: `clippy::manual_is_variant_and`
- when not: the `map`/`match` is clearer because the inner value
  is also used

### `Option::inspect` / `Result::inspect` / `inspect_err`

- since: 1.76
- edition: any
- replaces: `map(|x| { side_effect(x); x })` for tap-style logging
- clippy: `clippy::manual_inspect`
- when not: the closure must transform the value

### `String::from_utf8_lossy_owned` / `string::FromUtf8Error::into_utf8_lossy`

- since: 1.99
- edition: any
- replaces: `String::from_utf8_lossy(&v).into_owned()` — and the
  `Cow` round-trip it implies — when the `Vec<u8>` is owned and no
  longer needed. `into_utf8_lossy` is the same idea for an owned
  `FromUtf8Error`: it replaces
  `String::from_utf8_lossy(e.as_bytes()).into_owned()`
- look for: `from_utf8_lossy(&`, `from_utf8_lossy(` fed by an
  owned `Vec<u8>`, `from_utf8_lossy` applied to `e.as_bytes()` /
  `err.as_bytes()` after a `from_utf8` failure
- when not: the `Vec` is borrowed elsewhere, or `from_utf8_lossy`
  is already called on a slice. The error must be kept to report
  `valid_up_to()`, or it is borrowed rather than owned. Neither
  function guarantees reuse of the original allocation, so they
  are not zero-copy APIs

### `std::ptr::from_ref` / `from_mut`

- since: 1.76
- edition: any
- replaces: `x as *const T` / `x as *mut T` when converting a
  reference to a pointer
- look for: `as *const`, `as *mut` from a reference
- when not: do not add a dereference; do not introduce `unsafe`.
  Watch lifetime-extension: `from_ref(&temporary())` is not
  equivalent to `&temporary() as *const _`

### `std::io::Error::other`

- since: 1.74
- edition: any
- replaces: `Error::new(ErrorKind::Other, ...)`
- look for: `ErrorKind::Other`
- when not: a more specific `ErrorKind` is correct

### `std::fmt::from_fn`

- since: 1.93
- edition: any
- replaces: a one-off `struct` whose only job is `Display`/`Debug`
  via a closure
- look for: tiny wrapper types used once in `format!` / `write!`
- when not: the type is public or reused; a named type is clearer

### `std::num::NonZero<T>`

- since: 1.79
- edition: any
- replaces: writing `NonZeroU32` / `NonZeroIsize` / … when the
  code is generic over the integer or the generic form is clearer
- look for: long `NonZeroU*` lists, generic code that special-cases
  each alias
- when not: a concrete alias is the public API and should stay

### `{integer}::div_ceil`

- since: 1.73
- edition: any
- replaces: `(n + d - 1) / d` and similar ceil-div
- clippy: `clippy::manual_div_ceil`
- when not: overflow behavior of the manual formula is load-bearing
  and differs from `div_ceil`

### `core::range::{Range, RangeFrom, RangeInclusive}`

- since: 1.96
- edition: any
- replaces: storing `std::ops::Range*` in a `Copy` type (legacy
  ranges are not `Copy` because they are iterators)
- look for: `ops::Range`, `(start, end)` pairs kept only to stay
  `Copy`, comments about Range not being Copy
- when not: `0..n` syntax still produces the legacy types; public
  APIs should prefer `impl RangeBounds<_>`, which accepts both.
  Do not rewrite every `..` expression

### `assert_matches!` / `debug_assert_matches!`

- since: 1.96
- edition: any
- replaces: `assert!(matches!(...))` / `debug_assert!(matches!(...))`
- look for: `assert!(matches!`, `debug_assert!(matches!`
- when not: not in the prelude. Import the *module*:
  `use std::assert_matches;` (not
  `use std::assert_matches::assert_matches`). Use
  `use core::assert_matches;` only if the crate is `no_std`.
  Skip if a third-party `assert_matches` is already in use
  (name clash is why they are not prelude)

### `{integer}::format_into`

- since: 1.98
- edition: any
- replaces: `itoa` (and similar) for decimal formatting of integers
  into a stack buffer
- look for: `itoa` in Cargo.toml, `itoa::Buffer`
- when not: formatting goes through `fmt::Write` / `format!` and
  is not a hot path
- also: the buffer type is re-exported as `std::fmt::NumBuffer`
  (1.99). It was previously reachable only through `core::fmt`, so
  code outside `no_std` can now name the type without a `core`
  path

### `{float}::algebraic_{add,sub,mul,div,rem}`

- since: 1.98
- edition: any
- replaces: `+` `-` `*` `/` `%` on `f32`/`f64` (and other floats)
  in hot numeric code where the compiler may reorder using
  algebraic rules (associativity, etc.), similar in spirit to
  `-ffast-math` but local and never UB
- look for: tight `f32`/`f64` loops, reductions, comments about
  vectorization or fast-math
- when not: IEEE evaluation order, signed zero, or NaN payload
  must match the written expression (tests, bit-identical
  results, compensated summation). Do not rewrite every float
  `+`. This is a judgment call for measured hot paths, not a
  default style change
