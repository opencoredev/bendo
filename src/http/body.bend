# Pure connection input state. Only new octets are scanned on each feed.
import Base
import ./bytes.bend as Bytes
import ./request.bend as R
import ./parse.bend as Parse
import ./framing.bend as F
import ./chunked.bend as C

type State is Data:
  Head{parser: Parse.State, bytes: U32}
  Fixed{req: R.Req, left: U32, reverse: List<&2, U32>}
  Chunks{req: R.Req, decoder: C.State}
  Complete{req: R.Req, body: List<&2, U32>, trailers: List<&2, R.Header>, rest: List<&2, U32>}
  Bad{status: U32}
  Limited{req: R.Req}

def fixed(left: Nat, xs: List<&2, U32>, r: R.Req, rev: List<&2, U32>) -> State:
  match left xs:
    case 0n xs:
      Complete{r, List.reverse(&2, U32, rev), [], xs}
    case 1n+n Nil{}:
      Fixed{r, U32.from_nat(1n+n), rev}
    case 1n+n c <> t:
      fixed(n, t, r, c <> rev)

def chunks_result(r: R.Req, pair: C.State & C.DecodeResult) -> State:
  (s, got) = pair
  match got:
    case C.NeedMore{}:
      Chunks{r, s}
    case C.Decoded{body, trailers, rest}:
      Complete{r, body, trailers, rest}
    case C.Error{status}:
      Bad{status}

def begin(r: R.Req, xs: List<&2, U32>, frame: F.Framing, limit: U32) -> State:
  match frame:
    case F.NoBody{}:
      Complete{r, [], [], xs}
    case F.Length{n}:
      fixed(U32.to_nat(n), xs, r, [])
    case F.Chunked{}:
      chunks_result(r, C.feed(xs, C.initial(limit)))
    case F.Reject{status}:
      Bad{status}

def can_continue(s: State, expect: U32, rest_empty: Bool) -> State & Bool:
  match s:
    case Fixed{r, n, rev}:
      (Fixed{r, n, rev}, U32.is_eq(expect, 100) && rest_empty)
    case Chunks{r, d}:
      (Chunks{r, d}, U32.is_eq(expect, 100) && rest_empty)
    case s:
      (s, False{})

def expected(+r: R.Req, +xs: List<&2, U32>, +limit: U32, expect: U32) -> State & Bool:
  match expect:
    case 417:
      (Bad{417}, False{})
    case e:
      can_continue(begin(r, xs, F.framing(r, limit), limit), e, List.is_empty(&2, U32, xs))

# Limit includes leading CRLFs and the head terminator, never body/suffix bytes.
def head_step(s: Parse.State, c: U32, bytes: U32, over: Bool) -> State:
  match over:
    case True{}: Bad{431}
    case False{}: Head{Parse.advance(s, c), (bytes + 1 : U32)}

# Retain the request for negotiated route-limit errors, without buffering data.
def admitted(state: State, req: R.Req, custom: Bool) -> State:
  match state custom:
    case Bad{413} True{}: Limited{req}
    case state _: state

def admission(pair: State & Bool, req: R.Req, custom: Bool) -> State & Bool:
  (state, interim) = pair
  (admitted(state, req, custom), interim)

def expected_policy(+r: R.Req, xs: List<&2, U32>, +limit: U32, fallback: U32) -> State & Bool:
  admission(expected(r, xs, limit, F.expectation(r)), r, Bool.not(U32.is_eq(limit, fallback)))

def head_scan_policy(~Policy: Data, ~select: R.Req -> Policy -> U32, +policy: Policy, xs: List<&2, U32>, state: State, +limit: U32, +headers: U32) -> State & Bool:
  match xs state:
    case xs Head{Parse.Complete{+r}, bytes}:
      expected_policy(r, xs, select(r, policy), limit)
    case _ Head{Parse.Bad{e}, bytes}:
      (Bad{400}, False{})
    case Nil{} s:
      (s, False{})
    case c <> t Head{s, +bytes}:
      head_scan_policy(~Policy, ~select, policy, t, head_step(s, c, bytes, (bytes >= headers : U32)), limit, headers)
    case _ s:
      (s, False{})

# head_scan_policy from Head{s, bytes}, without rebuilding and matching a
# Head state per byte (BND-68). `over` is (bytes >= headers) for the next
# byte. Law hot_body_head_feed equates the two for every input.
def head_loop(~Policy: Data, ~select: R.Req -> Policy -> U32, +policy: Policy, xs: List<&2, U32>, s: Parse.State, +bytes: U32, +limit: U32, +headers: U32, over: Bool) -> State & Bool:
  match xs s over:
    case xs Parse.Complete{+r} _:
      expected_policy(r, xs, select(r, policy), limit)
    case _ Parse.Bad{e} _:
      (Bad{400}, False{})
    case Nil{} s _:
      (Head{s, bytes}, False{})
    case c <> t s True{}:
      (Bad{431}, False{})
    case c <> t s False{}:
      head_loop(~Policy, ~select, policy, t, Parse.advance(s, c), (bytes + 1 : U32), limit, headers, ((bytes + 1 : U32) >= headers : U32))

def head_feed_policy_spec(~Policy: Data, ~select: R.Req -> Policy -> U32, policy: Policy, xs: List<&2, U32>, s: Parse.State, bytes: U32, limit: U32, headers: U32) -> State & Bool:
  head_scan_policy(~Policy, ~select, policy, xs, Head{s, bytes}, limit, headers)

def head_feed_policy(~Policy: Data, ~select: R.Req -> Policy -> U32, policy: Policy, xs: List<&2, U32>, s: Parse.State, +bytes: U32, limit: U32, +headers: U32) -> State & Bool:
  head_loop(~Policy, ~select, policy, xs, s, bytes, limit, headers, (bytes >= headers : U32))

def feed_policy(~Policy: Data, ~select: R.Req -> Policy -> U32, policy: Policy, xs: List<&2, U32>, state: State, limit: U32, headers: U32) -> State & Bool:
  match state:
    case Head{s, bytes}:
      head_feed_policy(~Policy, ~select, policy, xs, s, bytes, limit, headers)
    case Fixed{r, n, rev}:
      (fixed(U32.to_nat(n), xs, r, rev), False{})
    case Chunks{+r, s}:
      (admitted(chunks_result(r, C.feed(xs, s)), r, Bool.not(U32.is_eq(select(r, policy), limit))), False{})
    case s:
      (s, False{})

def head_scan(xs: List<&2, U32>, state: State, +limit: U32, headers: U32) -> State & Bool:
  head_scan_policy(~U32, ~(req => n => n), limit, xs, state, limit, headers)

def head_feed(xs: List<&2, U32>, parser: Parse.State, bytes: U32, +limit: U32, headers: U32) -> State & Bool:
  head_feed_policy(~U32, ~(req => n => n), limit, xs, parser, bytes, limit, headers)

# Existing low-level consumers retain a constant per-connection budget.
def feed_limits(xs: List<&2, U32>, state: State, +limit: U32, headers: U32) -> State & Bool:
  feed_policy(~U32, ~(req => n => n), limit, xs, state, limit, headers)

def feed(xs: List<&2, U32>, state: State, limit: U32) -> State & Bool:
  feed_limits(xs, state, limit, 65536)

def initial() -> State:
  Head{Parse.initial(), 0}
