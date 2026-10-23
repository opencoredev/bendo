# Connection info, IP restriction and rate limiting

Bendo knows the address of the socket peer for every request. On top of that
it ships an IP allow/deny built-in and a rate limiter backed by a
[store actor](store.md). They follow Hono's `getConnInfo`, `ipRestriction` and
the common rate limiters, and set the IETF `RateLimit` fields.

The complete compiled example is
[`tests/servers/mw-ip.bend`](../tests/servers/mw-ip.bend).

## Connection info

```python
case Some{info}: B.remote_address(info) ++ ":" ++ U32.show(B.remote_port(info))
```

`B.conn_info(Vars, c)` returns `Maybe<&2, B.ConnInfo>`:

| Accessor | Value |
|---|---|
| `B.remote_address(info)` | Canonical text: dotted IPv4, or RFC 5952 IPv6 (`2001:db8::1`) |
| `B.remote_port(info)` | The peer's TCP port |
| `B.address_type(info)` | `"IPv4"` or `"IPv6"` |

The server calls `getpeername(2)` once when it accepts a connection
(`src/effects/peer.c` natively, `peer.js` under Bun), and every request on that
keep-alive connection shares the result. A local request reports `127.0.0.1`.

`conn_info` is always the socket peer. It never reads `X-Forwarded-For` or any
other client-supplied header. It is `None{}` for `B.handle_with` (no socket)
and if `getpeername` fails.

IPv6: Bend's `TCP.listen` binds IPv4 literals only, so a Bendo server cannot
listen on `::1` today and the tests cannot exercise an IPv6 peer. The effect
already formats IPv6 peers, and an IPv4-mapped peer (`::ffff:127.0.0.1`) is
reported as the IPv4 address it carries.

## Address and range syntax

Rules, forwarded addresses and peers all go through one strict parser
(`src/net/ip.bend`):

- IPv4 is exactly four decimal octets, 0 to 255. Leading zeros (`01.2.3.4`),
  shorthand (`127.1`) and hex parts are refused, because other parsers read
  them as octal or fill in missing octets.
- IPv6 follows RFC 4291: one to four hex digits per group, either case, at
  most one `::` standing for one or more zero groups, and an optional dotted
  IPv4 tail. Zone ids (`fe80::1%eth0`), brackets and ports are refused.
- A range is `address/length`, with a length of 0 to 32 or 0 to 128 and no
  leading zeros. A bare address is a single host (`/32` or `/128`). Bits after
  the prefix must be zero: `10.0.0.1/8` is refused rather than silently
  widened.

IPv4-mapped IPv6 follows the IPv4 rules. `::ffff:a.b.c.d` (in any spelling)
parses as the IPv4 address `a.b.c.d`, and a range inside `::ffff:0:0/96` with
a length of 96 or more becomes the matching IPv4 range
(`::ffff:10.0.0.0/104` is `10.0.0.0/8`). So a deny rule for `10.0.0.0/8` also
catches `::ffff:10.0.0.1`. The flip side: an IPv6 range never matches an IPv4
address, so `::/0` covers every IPv6 address and no IPv4 one. List
`0.0.0.0/0` as well to cover both.

## IP restriction

```python
B.use_path(Tag, "/admin/*", Builtin{B.ip_restriction(policy)}),
```

Build the policy at startup. Every entry must parse, or the result is
`None{}`, so a typo stops the app instead of opening a hole:

```python
B.ip_rules(deny: List<&2, String>, allow: List<&2, String>) -> Maybe<&2, B.IpPolicy>
B.ip_policy(deny, allow, trusted_proxies) -> Maybe<&2, B.IpPolicy>
B.ip_restriction(policy: B.IpPolicy) -> B.Builtin
```

The decision, in order:

1. If any deny range contains the client address, refuse. Deny wins over
   allow.
2. If the allow list is empty, admit.
3. Admit if an allow range contains the address, otherwise refuse.

If the client address is unknown (no socket peer), the request is refused
unless both lists are empty. A refused request gets `403` with the usual
negotiated [error body](decisions/0011-crash.md): `Forbidden` as text, or
`{"error":"Forbidden","status":403}` for `Accept: application/json`.

### Behind a proxy

By default the client address is the socket peer and `X-Forwarded-For` is
ignored, because any client can send that header. To run behind your own
proxies, list them as `trusted_proxies` in `B.ip_policy`. Then, only when
the socket peer is one of them:

- every `X-Forwarded-For` field is read as one comma-separated list, in order;
- entries are taken from the right (the nearest hop). Trusted proxies are
  skipped, and the first other address is the client;
- a malformed entry, or running out of entries, stops at the last trusted hop
  and uses that.

Clients can prepend anything they like, but they cannot get past the entry
your own proxy appended. The `Forwarded` header (RFC 7239) is not read.

`B.client_address(Vars, c, trusted)` returns the same canonical client
address as text. Build `trusted` with `B.cidrs(["10.0.0.0/8"])`.

## Rate limiting

The limiter needs a store, so create it at startup, keep it in `env` and call
it from a middleware case:

```python
type Env is Data:
  Env{limiter: B.RateLimiter}

def middleware(tag: Tag, c: B.Context(Unit), env: Env, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag env:
    case Limit{} Env{limiter}: B.rate_limit(Unit, limiter, c, next)
    case _ _: next(c)

# in main:
#   limiter : B.RateLimiter <- B.rate_limiter(B.fixed_window(100n, 60000n))
```

### Policies

| Constructor | Meaning |
|---|---|
| `B.fixed_window(limit, window_ms)` | At most `limit` requests per window. Windows are aligned to multiples of `window_ms` on the monotonic clock. |
| `B.token_bucket(capacity, refill, every_ms)` | Bursts up to `capacity`; `refill` tokens come back every `every_ms`. Each request takes one token. |

Zero for `window_ms`, `refill` or `every_ms` is raised to 1. A limit or capacity
of 0 refuses every request. Bucket math is exact integers: the level is kept
in token-milliseconds, so no fraction of refill time is lost between requests.

`B.rate_limiter(policy)` uses the policy name `"default"`, a 10,000-key table
and no trusted proxies. For other settings:

```python
B.rate_limiter_with(B.rate_limit_config(name, policy, max_keys, trusted))
```

### Keys and clock

`B.rate_limit` keys each request by its client address (the peer, or a
forwarded address behind `trusted` proxies as above) and reads the time from
`IO.now`. Without a socket peer, every request shares the key `unknown`.

`B.rate_limit_with(Vars, limiter, key, now_ms, c, next)` takes your own key
(a user ID, an API token's hash) and your own millisecond clock. The tests use
it with a fake clock so they never wait a minute.

### Responses

Every request counted runs one store update, so concurrent requests are
serialized and none is lost: with a limit of 40, 60 simultaneous requests get
exactly 40 successes.

An allowed request passes to `next`, and the response gets the fields from
[draft-ietf-httpapi-ratelimit-headers-11](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/):

```text
RateLimit-Policy: "default";q=100;w=60
RateLimit: "default";r=99;t=60
```

`q` is the limit (bucket capacity), `w` is the window in seconds (a full
refill for a bucket), `r` is what remains and `t` is the seconds until the
quota is whole again. A refused request gets `429 Too Many Requests` with both
fields and `Retry-After` in whole seconds, at least 1. If the store does not
answer, the request gets `503` rather than being let through.

The policy name is sent as a structured-field string. Characters outside
printable ASCII are dropped, and `"` and `\` are escaped.

Requests can reach the store out of clock order. A request that read an
earlier time still counts against the newer window, and a bucket never moves
its clock backwards, so a late request can never reset a count.

### Memory and saturation

The table holds at most `max_keys` entries. When a new key arrives and the
table is full, the limiter first drops idle entries: windows that have ended
and buckets that have refilled to capacity. It does this at most once per
window (or per full-refill time). Spraying keys can never grow memory past
`max_keys`, and can never reset or share a tracked key's count.

If the table is still full of live keys, the table is saturated, and the
limiter's saturation mode decides what the new key gets:

| Mode | A new key while saturated | Trade-off |
|---|---|---|
| `B.saturation_allow()` (default) | Passes uncounted, with no `RateLimit` fields | Nobody new is denied because of other keys, but a client that can fill the table (many source addresses, an IPv6 range) is unlimited until the next sweep. |
| `B.saturation_shared()` | Shares one overflow entry with the same policy | Fails closed: a flood of new keys exhausts the shared quota and every client not yet tracked gets `429`. |
| `B.saturation_evict()` | Takes the place of the least recently used key | Everyone is counted, but under churn an evicted client's quota starts over the next time it is seen. |

Set the mode on a config:

```python
B.rate_limiter_with(B.rate_limit_saturation(B.rate_limit_config(name, policy, max_keys, trusted), B.saturation_evict()))
```

Saturation is visible in three places. The server prints one line when a
table becomes saturated, not one per request:

```text
bendo rate limit "default": key table full at 10000 keys; new keys pass uncounted until a sweep frees room
```

`B.rate_limit_stats(limiter)` returns the counters (`IO(Result<..., B.RateLimitStats>)`):
`B.stats_tracked(s)` is the number of tracked keys, `B.stats_saturated(s)` counts
requests that met a full table since startup, and `B.stats_saturating(s)` is
whether the table is saturated now. It turns false when a sweep frees room for
a new key. In the default mode, an uncounted response is also the only kind
without `RateLimit-Policy` and `RateLimit` fields.

Eviction keeps a queue of recent keys. It grows by one entry per request and
is compacted back to at most `max_keys` once it passes twice that, so the
memory bound stays proportional to `max_keys`.

## Laws

`proof/ip-laws.bend` and `proof/rate-limit-laws.bend` state the guarantees;
`proof/ip.bend` and `proof/rate-limit.bend` prove them:

- CIDR membership holds exactly when the address and network have the same
  family, both are full width, the length fits, and every bit index below the
  length reads the same bit (`ip_member_bits`, `ip_member_family`,
  `ip_member_width`, `ip_member_complete`).
- The allow/deny decision equals an independent specification. A deny hit
  always refuses, an allow hit with no deny hit always admits, and an unknown
  address is refused when any range is configured (`ip_permitted_spec`,
  `ip_deny_wins`, `ip_allow_listed`, `ip_unknown_denied`,
  `ip_unknown_not_allowed`).
- With no trusted proxies, or a peer outside them, the client address is the
  socket peer whatever headers say (`client_default_peer`,
  `client_untrusted_peer`).
- Behind a trusted peer, the forwarded entries are scanned right to left from
  the peer: a trusted hop is skipped and becomes the fallback, the first
  address outside the trusted ranges is the client, and a malformed entry or
  the end of the list stops at the last trusted hop (`client_trusted_chain`,
  `chain_skips_trusted`, `chain_first_untrusted`, `chain_malformed_stops`,
  `chain_exhausted`).
- Fixed window: in the counter's window a request is allowed exactly when
  fewer than `limit` were counted, and only allowed requests count. A later
  window starts from zero, and a zero limit refuses everything. Any run of
  requests in one window gets exactly `limit - count` yeses, then noes
  (`rate_fixed_allow`, `rate_fixed_deny`, `rate_fixed_new_window`,
  `rate_fixed_zero_limit`, `rate_fixed_quota`).
- Token bucket: the level never exceeds capacity, for any input. With a token
  available the request is allowed and takes exactly one, otherwise it is
  denied and takes nothing (`rate_bucket_capacity`, `rate_bucket_allow`,
  `rate_bucket_conserve`, `rate_bucket_deny`, `rate_full_level`).

The parser, the key table's sweep and saturation modes, and the IO shells are covered
by tests, not laws.

```sh
bun test --timeout 30000 tests/mw-ip.test.ts
```
