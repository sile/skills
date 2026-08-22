# Feature catalog

Last reviewed: 2026-08-22 against **Rust 1.98.0** (current stable, 2026-08-20).

Hand-maintained list of stable features that change how code is
written. Not a changelog. Skip pre-1.70 items that clippy already
covers (`let-else`, and similar). Do not suggest unsafe APIs.

Each `since` is the rustc version that stabilized the feature
(from rustdoc or the official release notes). `edition: any` means
no edition gate beyond what that rustc already supports.

Only report an entry when this codebase actually has the old
pattern.

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

## std APIs

### `Option::is_some_and` / `Result::is_ok_and`

- since: 1.70 (`is_none_or` / `is_err_and`: 1.82)
- edition: any
- replaces: `opt.map(|x| pred(x)).unwrap_or(false)`,
  `matches!(opt, Some(x) if pred(x))` used only as a bool
- clippy: `clippy::manual_is_variant_and`
- when not: the `map`/`match` is clearer because the inner value
  is also used

### `Option::inspect` / `Result::inspect` / `inspect_err`

- since: 1.76
- edition: any
- replaces: `map(|x| { side_effect(x); x })` for tap-style logging
- clippy: `clippy::manual_inspect`
- when not: the closure must transform the value

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
- when not: not in the prelude — import from `core` or `std`. Skip
  if a third-party `assert_matches` is already in use (name clash
  is why they are not prelude)

### `{integer}::format_into`

- since: 1.98
- edition: any
- replaces: `itoa` (and similar) for decimal formatting of integers
  into a stack buffer
- look for: `itoa` in Cargo.toml, `itoa::Buffer`
- when not: formatting goes through `fmt::Write` / `format!` and
  is not a hot path

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
