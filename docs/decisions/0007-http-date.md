# 0007: Wall time and HTTP Date

BND-10 adds a wall-clock boundary and strict IMF-fixdate formatting and parsing.
BND-80 proves the codec's two laws; see "Laws" below.

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

`src/http/date.bend` is pure and uses only `Nat` arithmetic, so the laws can
be proven. The calendar counts days from 1600-01-01, the first day of a 400-year
Gregorian cycle. A cycle splits into four centuries, a century into 25 four-year
groups, a group into four years and a year into twelve months. Each layer is a
list of period lengths. Decoding finds the period a day falls in and the offset
into it (`index`, `offset`), and encoding adds the earlier lengths back
(`before`). Leap days fall at the start of a group, so the lengths that vary
come first: a century's first group lacks its leap day unless the century starts
a cycle, and a group's first year has 366 days unless the group lacks its leap
day.

`format_imf(second)` always emits the English weekday and month names, pads
fields to fixed widths and ends with `GMT`. Inputs beyond the supported range
return the empty string. `parse_imf(text)` decodes the fields of exact,
29-character IMF-fixdate without range checks, encodes them back to a second,
and returns `Some{second}` only when formatting that second reproduces the text
byte for byte. That one check rejects invalid days, weekday mismatches, leap
seconds, years before 1970, extra whitespace and trailing bytes.

Obsolete RFC 850 and asctime forms are not accepted by this helper. It is a
strict IMF codec, not a general HTTP-date recipient parser. A future API that
accepts arbitrary HTTP-date fields must implement all recipient formats
required by RFC 9110 section 5.6.7.

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

A WebSocket refusal is the one final response transport builds after
finalization: it replaces a 101, which received no Date. BND-94 dates it during
transport selection, before the access log records the status, rather than at
`DateWire.ensure`. A clock failure there becomes an empty, framed 500 that keeps
the refusal's fields (retained policies, request ID, timing) but not those that
described the discarded body (coding, language, location, range, digests,
validators), so the logged
status is the one sent and the policies survive. Law
`websocket_refusal_clock_failure` states that 500 against an independent spec.

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

## Laws

`LAWS.bend` states two laws, proven in `proof/date-laws.bend` and checked by
`bend PROOF.bend --verdict`. Both cover every Unix second from
1970-01-01T00:00:00Z through 9999-12-31T23:59:59Z:

```bend
law http_date_roundtrip:
  for +second: Nat
  for bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(second, 86400n), 10957n), 146097n), 20n) == True{} : Bool}
  {HttpDate.parse_imf(HttpDate.format_imf(second)) == Some{second} : Maybe<&2, Nat>}

law http_date_imf_spec:
  for +second: Nat
  for bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(second, 86400n), 10957n), 146097n), 20n) == True{} : Bool}
  {HttpDateSpec.denotes(HttpDate.format_imf(second), second) == True{} : Bool}
```

The bound replaces `second <= 253402300799` and selects exactly the same
seconds. With `d = second / 86400`, the Unix day, `d - 10957` (0 when negative)
counts days since 2000-01-01, and fewer than 20 whole cycles of 146097 days means
`d < 10957 + 20 * 146097 = 2932897`, the day of 10000-01-01. That holds exactly
when `second < 2932897 * 86400 = 253402300800`. `format_imf` checks the same
expression. The earlier form compared against `max_seconds()`, which Bend 2.0.38
cannot check: closed numbers are expanded in unary, and the checker overflows
above roughly 20,000. Every term in the new form is a literal or depends on
`second`. `max_seconds()` remains for runtime callers.

`HttpDateSpec` is `proof/date-spec.bend`. It shares no code with the codec.
`denotes(text, second)` matches the 29-byte IMF-fixdate grammar with its literal
punctuation and `GMT`, requires every digit position to be `0`-`9`, compares the
day and month tokens with English names, and checks the fields against `second`.
The date comes from counting days forward from 1970-01-01 one at a time, with
months of fixed length and February under the divisible-by-4, except centuries,
except multiples of 400 rule. The weekday comes from counting forward from
Thursday. The hour, minute and second must be below 24, 60 and 60, and must add
up to `second mod 86400`. The round trip alone would allow a formatter that
always writes `Sun`, because the parser checks the weekday through the
formatter. The spec law rules that out.

The proof's main steps, each a lemma over variables:

- Encoding the spec's day `n` gives `n + 135140` days after 1600-01-01, by
  induction on `n`. The step shows encoding moves forward by one day within a
  month, across a month, and across a year, where the year split carries
  through the 4-, 100- and 400-year places (`proof/date-days.bend`,
  `proof/date-calendar.bend`).
- The spec's leap rule agrees with the codec's group and century flags
  (`leap_agrees`).
- Decoding inverts encoding for every valid date (`proof/date-decode.bend`), so
  the codec's calendar of day `n` is the spec's.
- A day below the bound has a year below 10000, so the year fits four digits
  (`year_lt`). The digit, name and time lemmas are in `proof/date-text.bend`.

Large constants such as 146097 stay literals in positions headed by a variable
(`Nat.mul(e, 146097n)`), and closed facts about them are checked as `Bool`
comparisons. Otherwise either checker could expand them in unary.
