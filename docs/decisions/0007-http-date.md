# 0007: Wall time and HTTP Date

BND-10 adds a wall-clock boundary and strict IMF-fixdate formatting and parsing.
The runtime behavior is implemented, but the universal round-trip law remains
open. This change must not land until `bun run prove` and `bun run check` pass.

## Clock contract

`src/effects/clock.bend` exposes `wall_millis()` and `wall_seconds()`. Both return
`IO(Result<&1, &1, U32 & String, Nat>)`. Milliseconds are Unix time in the closed
range 0 through 253402300799999, and seconds are 0 through 253402300799. Those
bounds include all of 9999-12-31 and fit Bend's native 48-bit immediate `Nat` and
JavaScript's exact integers. There is no signed 2038 or unsigned 2106 truncation.

The trusted code outside the proofs is `clock.c` and `clock.js`. C calls
`clock_gettime(CLOCK_REALTIME)` once. JavaScript calls `Date.now()` once. Each
rejects negative or out-of-range time; C also reports a failed system call and
JavaScript rejects nonintegral and nonfinite host values. `wall_seconds()`
divides a millisecond sample by 1000. Durations, deadlines and timeouts continue
to use Base's monotonic `IO.now`; wall time can jump when the host clock changes.

## Date codec

`src/http/date.bend` is pure. `format_imf(second)` uses Gregorian civil-day
arithmetic, always emits the English weekday and month names, pads fields to
fixed widths and ends with `GMT`. Inputs beyond the supported range return the
empty string. `parse_imf(text)` returns `Some{second}` only for exact,
29-character IMF-fixdate in the supported range. It rejects invalid days,
weekday mismatches, leap seconds, extra whitespace and trailing bytes.

Obsolete RFC 850 and asctime forms are not accepted by this helper. It is a
strict IMF codec, not a general HTTP-date recipient parser. A future API that
accepts arbitrary HTTP-date fields must implement all recipient formats
required by RFC 9110 section 5.6.7.

The full promised law is `http_date_roundtrip` in `LAWS.bend`: for every `Nat`
second at or below `max_seconds()`, parsing its formatted string returns that
same second. It has no calendar-witness or round-trip premise. The Gregorian
inverse, fixed-width decimal and range lemmas needed for its proof are not yet
implemented. The initial attempt to print the unresolved goal with `?roundtrip`
caused Bend 2.0.38's `term_higher` normalizer to overflow the JavaScript stack.
The law remains open rather than being replaced by finite vectors.

## Response policy

The transport calls `DateWire.ensure` immediately before sending final response
bytes, including connection-level rejections and legacy byte handlers. It scans
only the head and preserves the body exactly. Network-free `B.handle` adds Date
at its return boundary through `DateResponse.ensure`. Both boundaries preserve
an existing Date and skip the clock when one is present. Legacy field detection
is case-insensitive. Structured response names retain their existing lowercase
validity requirement. Supplying repeated Date fields remains the application's
responsibility; Bendo never adds another one.

Responses with status 200 through 599 receive Date, including HEAD, 204, 304 and
5xx. Informational responses receive no generated Date; an explicit field is
preserved. The transport's raw 100 Continue already omits it. This follows RFC
9110 section 6.6.1. A clock failure preserves an existing 5xx response without a
Date; other final responses become an empty, framed 500. One clock sample is
used for each response that needs a generated field. No cache is introduced.

Date belongs to the transport or return boundary, after response middleware.
Deferred response observers retain the application response captured before
this boundary and therefore do not see the generated Date. An explicit
application Date is visible to them.

## JavaScript and publishing

Bend 2.0.38 binds the foreign effect using `CID(wall_millis)` in its declaring
module's namespace. It splices the C twin into native builds and registers the
JS twin in JavaScript builds. Rebuild and retest both twins when changing the
compiler pin; this runtime interface has no stable ABI.

The tests run native and `.js` executables against the host clock, compare
native and `.mjs` date formatting, and execute the clock registered by the
`.mjs` library. Bend's library output returns IO descriptions rather than
running its executable event loop, so that last test supplies a synchronous
fixture driver for the immediate clock effect. It also checks host values at
the supported boundaries and failures. The fixture cache follows both foreign
imports; changing the C file produces a new compiled artifact.

`bend --help` offers `--publish` with no dry-run flag. The pinned compiler's
[`pkg_files` implementation](https://github.com/bendlang/bend/blob/v2.0.38/bend2/main.ts)
includes every foreign `.c` and `.js` import in the package alongside Bend
modules and adjacent LICENSE files. Relative imports through ancestors expand
the packaged root. Absolute imports and paths above the filesystem are
rejected. No publication was attempted: publishing is public and permanent,
and BND-74 owns the actual publish test. Both twins must remain beside
`clock.bend` in the published dependency graph.

## Pending laws (BND-80)

The codec is tested, not yet proven. BND-80 will add these two laws to
`LAWS.bend` once they check with `--verdict`:

```bend
law http_date_roundtrip:
  for +second: Nat
  for bound: {Nat.is_le(second, HttpDate.max_seconds()) == True{} : Bool}
  {HttpDate.parse_imf(HttpDate.format_imf(second)) == Some{second} : Maybe<&2, Nat>}

law http_date_imf_spec:
  for +second: Nat
  for bound: {Nat.is_le(second, HttpDate.max_seconds()) == True{} : Bool}
  {HttpDateSpec.denotes(HttpDate.format_imf(second), second) == True{} : Bool}
```

The second law is needed because the round trip alone can't catch a wrong weekday:
the parser checks weekday names through the formatter. `HttpDateSpec.denotes`
must be written independently of the production codec. It must check the exact
IMF grammar and English tokens, the Gregorian calendar with century leap rules,
and the weekday, and confirm that the text denotes `second`.

Bend 2.0.38 blocks both proofs as stated. `max_seconds()` is 253402300799, above
the 2^32 literal limit, so it has to be computed. The checker expands computed
Nats in unary and overflows above roughly 20,000 to 36,000. BND-80 may restate
the bound in an equivalent form the checker can handle, such as a bound on the
day count or civil year, with the equivalence explained in the law comment.
