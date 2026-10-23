# Route patterns

Compile a route once with `src/router/pattern.bend`. The resulting `Pattern` is
copyable `Data`: it stores segments and constraints, with no handler functions.
`match_path` returns decoded params or `None`, so a router can try its next route
when a static segment, constraint, or capture fails.

```python
import Base
import ../src/router/pattern.bend as P

def compiled_example(result: Result<&2, &2, P.PatternError, P.Pattern>) -> Maybe<&2, P.Params>:
  match result:
    case Done{pattern}:
      P.match_path(pattern, "/posts/42")
    case Fail{error}:
      None{}

def example() -> Maybe<&2, P.Params>:
  compiled_example(P.compile("/posts/:id{int}"))
```

A complete native consumer is [`tests/router-pattern-driver.bend`](../tests/router-pattern-driver.bend).

## Syntax

Patterns start with `/`; bare `*` is an alias for `/*`. Segments are separated by literal `/` and may be:

| Segment | Meaning |
| --- | --- |
| `posts` | Raw, exact static text |
| `:id` | One nonempty decoded value |
| `:id?` | Optional trailing capture; omit its slash and value together |
| `:id{int}` | One value satisfying a constraint |
| `:id{int}?` | Optional final constrained segment |
| `*` | Final wildcard, captured under the name `*` |
| `*path` | Final wildcard, captured under `path` |
| `assets*` | Final prefix wildcard; matches `/assets`, `/assets-v2`, and `/assets/app.js`, without a capture |
| interior `*` | Zero or more whole path segments, without a capture; `/a/*/b/*` matches `/a/x/b/c` |
| `:prefix{.+}` | Nonempty decoded capture that can span segments before the remaining pattern |

Names use ASCII `[A-Za-z_][A-Za-z0-9_]*` and cannot repeat within a pattern.
Optional captures form a consecutive trailing chain: `/v1/:version?/:platform?`
accepts zero, one, or two values, assigned from left to right. A present value
cannot skip an earlier optional. Named wildcards and prefix wildcards must be
last; unnamed wildcards may also appear inside a pattern. A wildcard captures the remaining
path, including separators, and may be empty. `/files/*path` therefore matches
both `/files` and `/files/`, returning `path=""` in either case. Filling that
assignment produces `/files/`.

Static segments may contain literal `:` after their first character, as in
`/v1/name:activate`. A leading `:` starts a capture. Static segments cannot
contain `*`, `{`, `}`, `?` or `#`, except for the terminal prefix-wildcard
marker. Other Unicode
scalar values, including raw percent signs, are accepted. Static text is never
percent-decoded: `/caf%C3%A9` and `/café` are different patterns. Empty static
segments preserve repeated and trailing slashes. Matching is case-sensitive:
`/a`, `/A` and `/a/` differ. Trailing-slash and case options belong to BND-18.

The root pattern `/` matches only `/`. `/:id?` with an omitted capture fills to
`/`; a present empty value is invalid. Omitting the capture in `//:id?` also
fills to `/`, because the optional segment's own separator is omitted. Its
empty static prefix remains part of that pattern's match. No empty path matches.

## Constraints

Constraints apply to the decoded value, before a match succeeds.

| Constraint | Accepted values |
| --- | --- |
| `{int}` | An optional ASCII `-`, followed by one or more ASCII digits; leading zeros and arbitrary length are allowed |
| `{uuid}` | Exactly `8-4-4-4-12` hexadecimal digits with hyphens; hex is case-insensitive; no version or variant restriction |
| `{slug}` | One or more lowercase ASCII letters, digits, or `-`; leading, trailing, and repeated hyphens are allowed |
| `{[a-z0-9-]+}` | One or more characters from the class |
| `{[0-9]{4}}` | Exactly four characters from the class |

A character class contains ASCII literals from space through `~`, or ascending
ranges such as `a-z`. It cannot be empty. `-` is literal only at the first or
last position; `[a-b-c]` is rejected. `/`, `\`, `[`, `]`, `^`, `{` and `}`
cannot be class literals (a pattern is split at every `/` before constraints
are read, so `/:x{[a/]+}` is rejected with `UnbalancedBraces`); there are no escapes, negation or nested classes. The suffix
is either `+` or `{n}`, where decimal `n` is between 1 and 4294967295 (leading
zeros are allowed). The additional constraint `{.+}` captures one or more decoded characters,
including `/`, across raw path segments. For example,
`/:prefix{.+}/contents/:id?` matches `/foo/bar/contents/123` with
`prefix="foo/bar"` and `id="123"`. Matching chooses the shortest nonempty
span that lets the remaining pattern match. Captures still decode exactly once.
Other JavaScript regex syntax remains unsupported.

A constraint failure returns `None`, exactly like a static mismatch. It does
not return a pattern error. Registration-order route selection belongs to BND-15.

## Decoding and filling

Pass only the raw path to `match_path`, without the query string or fragment.
Split on literal `/` before decoding. Captures decode `%XX` exactly once as
strict UTF-8. Hex digits may use either case; literal `+` stays `+`. Invalid or
truncated escapes, overlong UTF-8, surrogate encodings, and code points above
U+10FFFF return `None`. Raw Unicode captures must also contain only scalars.

`%2F` becomes `/` inside a captured value without changing the matched segment
boundaries. `%252F` becomes the text `%2F`. Wildcards preserve repeated and
trailing separators. A decoded value may include NUL, slash, or other controls;
consumers must validate values for their destination, especially filesystem
paths, and must not split or decode them again for routing.

`Params` is a copyable ordered list of `Param{name, value}` records, in pattern
order. An omitted optional capture has no record. `fill(pattern, params)`
returns `Some(path)` for an admissible assignment and `None` otherwise. It
requires exactly those names in order, no extras, scalar-only values, nonempty
present ordinary captures, and satisfied constraints. Wildcard values may be
empty. Every captured scalar is UTF-8 encoded and every byte is percent-encoded,
including ASCII letters and slash. Static text remains raw. Thus filling `:id`
with `a/b` produces `/%61%2F%62`.

## Errors

`compile` returns `Result<&2, &2, PatternError, Pattern>`. `PatternError` holds
an `ErrorKind` plus the offending segment, name, or constraint text.
`error_message(error)` renders `Kind: text`.

The kinds are `MissingSlash`, `EmptyName`, `InvalidName`, `DuplicateName`,
`UnbalancedBraces`, `UnknownConstraint`, `InvalidClass`, `WildcardNotLast`,
`OptionalNotLast`, and `InvalidStatic`. Constraint syntax is recognized only
inside captures; braces in static text are `InvalidStatic`. Malformed classes
are `InvalidClass`; unsupported non-class constraints are `UnknownConstraint`.
An absent outer opening or closing brace is `UnbalancedBraces`.

## Verification

Run the fixture table through the compiled native Bend consumer:

```sh
bun test --timeout 30000 tests/router-patterns.test.ts
bend src/router/proofs.bend --verdict
bun run prove
```

`LAWS.bend` states `pattern_fill_match` over every successfully compiled pattern
and every independently admissible assignment. It promises that filling
succeeds and matching that path returns the exact assignment. The predicate
`admissible` never calls `fill` or `match_path`.

The full roundtrip proof passes the strict Lean-backed kernel. Its helper
lemmas cover Unicode and percent-codec inversion, compilation cleanliness,
split/join preservation, and matching for captures, optional params and wildcards.
`bun run prove` prints `ALL PROOFS CHECK`; `bun run check` also runs the native
integration suite, TypeScript checks, lint and formatting checks.

The [spec router](router-spec.md) compiles a table of these patterns and selects
the first match in registration order.
