# API design — worked examples

Companion to the API design section of [SKILL.md](SKILL.md).

The examples come from low-level Unix TUI libraries—the kind that read
a terminal's bytes and write rendered frames—but the patterns apply to
any foundational layer: a codec, a parser, a buffer, a transport.

They are written as concepts. The names shown are placeholders, not
imports from a real crate; a sketch in each example sets the scene.

The general shape, before the details:

```rust
// A foundational layer that hides its policy.
let stream = ByteStream::new();     // internally caps at some size
stream.feed(&bytes);                // silently drops the oldest bytes
// The caller sees the data; it cannot see the cap or the loss.

// A foundational layer that exposes mechanism and state.
let stream = ByteStream::new();     // no cap of its own
stream.feed(&bytes);                // appends
let limit = 1 << 20;                // the app's limit, not the library's
stream.trim_to(limit);              // carries out the app's choice
// The caller states the policy; the library carries it out.
```

## Do not impose an implicit policy

A library is composed by its callers, so a policy baked into it decides
for code it cannot see. The clearest case is a capacity limit.

**Imposing a policy.** A byte stream owns a constant such as
`MAX_PENDING_BYTES`. Its `feed()` appends the new bytes and, when the
buffer grows past the constant, silently drops the oldest bytes. The
limit encodes one answer—"too much input"—for every caller, and the
drop is invisible: the caller cannot tell a truncated paste from a
complete one.

**Exposing mechanism.** The same stream keeps no constant. `feed()`
only appends. Alongside it, the type publishes two things:

- a query that reports the state the caller needs in order to decide,
- an operation that carries out the caller's decision in one step.

How those are spelled is the layer's own business. A query might report
how much is buffered, and the operation might discard down to a length
the caller names. Another layer might offer no drop path at all and
instead report a failure the caller handles. What matters is that the
caller can observe the condition and act on it.

The caller reads the query and decides. A stream processor may accept a
large buffer; an interactive terminal may treat the same size as a
freeze worth dropping. Both are legitimate, and only the caller knows
which it is. The limit and the drop policy live where that knowledge
is.

The caller now writes a few extra lines. Those lines *are* the policy,
in the one place it can be reviewed and changed. Extra caller code is a
cost; a forced policy is a defect.

The rule is about who decides, not about method count. A query and an
operation satisfy it; so does a single operation that takes the caller's
bound as an argument ("keep at most this much"), which folds the
comparison into the layer without moving the decision there. Reach for
the shape that reads best at the call site. What a layer must not do is
choose the bound for the caller.

## Do not hide a decision with a user-visible trade-off

A timeout, a retry count, a buffer cap, and an automatic recovery all
pick a side of a trade-off the user will feel. Keep them out of the
mechanism, or make the choice explicit.

**Hiding it.** A parser that reads key sequences notices that a single
ESC byte is ambiguous: it may be an Escape key pressed, or the start of
a longer sequence. So the parser waits a fixed number of milliseconds
before treating it as Escape. The value is a constant inside the
parser, the caller cannot change it, and the two failure modes are
invisible: too short and a fast arrow-key press degrades into stray
`[` and `A`; too long and a solo Escape is reported as Alt+something.

**Exposing it.** The parser reports two facts and one operation:
whether a single ESC byte is currently uncommitted, and a way to
commit it. The caller then chooses whether to wait, for how long, and
what to do when the wait ends. The core stays free of I/O and of time,
which is exactly what lets it stay testable and reusable.

A default is still allowed—but only when it is explicit, documented,
and overridable. The problem is never that a default exists; it is that
the caller cannot see it or change it.

## Do not encode a policy in a name

A name is documentation that cannot be corrected later. Name the
observable fact, not the mechanism the library happens to use.

- State the condition: "an uncommitted escape is pending."
- Do not state the mechanism: "the escape timeout has expired."

The second name freezes one implementation into the API. The first
leaves the caller free to wait, to poll, or to commit immediately, and
still reads correctly if the mechanism changes.

This is the naming face of the same rule: the library reports what is
true, the caller decides what to do about it.

## Where this matters

The pull toward integrated defaults grows with the layer. A convenience
layer built for end users can reasonably ship a timeout, a retry, or a
sensible cap; that is what makes it convenient. The rule above applies
most strongly to a low-level, foundational layer: the more code sits on
top of it, the more freedom and choice it must preserve. A foundation
that hides a policy restricts every layer above it at once.

## Two questions

Before adding a default, a limit, or a recovery path to a low-level
type, ask:

1. Can the caller see it? (Is the effect observable, or does it happen
   silently on the caller's behalf?)
2. Can the caller override it? (Is there a public way to change or
   bypass the choice?)

If both answers are no, the library has taken a decision that belongs
to the caller.
