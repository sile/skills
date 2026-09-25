# TUI binary — worked examples

Companion to the TUI binary section of [SKILL.md](SKILL.md).

The examples describe a crate whose product is an interactive terminal
program: it reads key input, keeps a view, and paints frames. Like the
API design companion, they are written as concepts with placeholder
names. Only the two dependencies the rule names are real, [`tuinix`]
for the terminal edge and [`termnix`] for driving the binary in tests.

[`tuinix`]: https://crates.io/crates/tuinix
[`termnix`]: https://crates.io/crates/termnix

How these crates are called is documented by their own rustdoc, which
can be generated from the source at hand. A copy of the call shape in
this file would drift out of date, so only the choice of what to build
on is stated here.

## Build the terminal edge on `tuinix`

A terminal UI has to put the terminal into raw mode, restore it on the
way out (including on an error path), learn the window size, decode
input bytes into key events, and paint styled text into frames.
`tuinix` already owns each of those: the driver, the decoder, and the
frame model.

Use them instead of hand-rolling the same ground. A raw `libc::tcsetattr`,
a home-grown escape-sequence parser, and a hand-written frame buffer
each recreate a bug the crate has already fixed, and they cost the
binary its one good seam: with the decoder and the renderer supplied by
`tuinix`, the interesting logic sits between two data types and can be
tested without a terminal.

## Keep the logic testable

Split the binary so that the behavior worth checking does not depend on
a terminal:

- the state and the rendering live where a test can reach them without
  touching a file descriptor;
- `main` only wires the pieces together: it reads the process
  arguments, owns the poll loop, and calls `tuinix`.

With that split, a unit test states input as data and asserts on the
frame as data. What is left in `main`—startup, terminal mode handling,
and the loop—is exactly what a unit test cannot reach, which is why the
end-to-end test below exists.

## Drive the real binary with `termnix`

Drive the compiled binary behind a PTY with `termnix`, as a
dev-dependency. Reach for this when the binary has behavior worth
checking at the process level—startup, terminal mode handling, redraw
on resize. A unit test cannot observe any of those, and mocking them
tests the mock.

Take the path from Cargo's `CARGO_BIN_EXE_<name>` environment variable
at compile time: it names the very artifact a user would run, so the
test never has to guess at `target/debug/`.

Points that save time in practice:

- **Wait for a condition, not a duration.** Poll for the text or state
  the test needs. A fixed sleep followed by an assertion is flaky on a
  loaded machine, and a solo `Esc` can sit in the decoder until its
  timeout fires; neither is a duration the test can pick for the
  machine it runs on. Use a fixed sleep only when nothing observable
  marks the wait, and say why in a comment.
- **Give the session a `Drop` that quits the child.** Otherwise a
  failing assertion leaves a stray process holding the PTY.
- **Put scratch files under `CARGO_TARGET_TMPDIR`.** It is cleaned with
  the build directory, and it exists where `/tmp` does not.
- **Send keys the way a terminal does.** Control keys, arrows, and
  paste arrive as byte sequences, not as characters; go through the
  session's key helpers rather than formatting the bytes by hand, so
  the test exercises the decoder path a user does.

Group the e2e tests under a subdirectory, so the shared harness has one
home and each file covers one subject:

```
tests/
  e2e/
    mod.rs        # the session harness
  e2e_startup.rs
  e2e_editing.rs
  e2e_resize.rs
```

Cargo compiles every file directly under `tests/` as its own test
target, so the harness cannot itself be `tests/e2e.rs`; it goes in
`tests/e2e/mod.rs`, reached with `mod e2e;`. This is the Tests section
of [SKILL.md](SKILL.md) applied to a harness that starts a process
instead of a helper that builds data.

## What this does not cover

Low-level terminal work—the escape sequences, the PTY, the frame
buffer—is `tuinix`'s own problem. A crate that *is* the terminal layer
needs tests at that level, not a driver for a binary that sits on top.
This section is about the product at the far end.
