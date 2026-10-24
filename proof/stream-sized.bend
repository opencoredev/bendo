# BND-91: a sized stream writes exactly its declared length or aborts.
# Induction over the producer chunks, generalized over the octets owed.
import Base
import ../src/http/stream_framing.bend as F
import ../src/http/request.bend as Request
import ../src/http/write_response.bend as Write

def Bytes() -> Data: List<&2, U32>
def Out() -> Data: Maybe<&2, List<&2, U32>>

def cons_opt(b: U32, r: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match r:
    case None{}: None{}
    case Some{tail}: Some{b <> tail}

def over(rest: List<&2, List<&2, U32>>) -> {F.sent(rest, F.Over{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match rest:
    case Nil{}: {==}
    case +bytes <> +t:
      %Equal.sym(Out(), F.sent(t, F.Over{}), None{}, over(t)) : {F.prepend(bytes, _) == None{} : Maybe<&2, List<&2, U32>>}
      {==}

def prepend_nil(r: Maybe<&2, List<&2, U32>>) -> {F.prepend([], r) == r : Maybe<&2, List<&2, U32>>}:
  match r:
    case None{}: {==}
    case Some{tail}: {==}

def prepend_cons(b: U32, t: List<&2, U32>, r: Maybe<&2, List<&2, U32>>) -> {F.prepend(b <> t, r) == cons_opt(b, F.prepend(t, r)) : Maybe<&2, List<&2, U32>>}:
  match r:
    case None{}: {==}
    case Some{tail}: {==}

def pick_cons(b: U32, y: List<&2, U32>, ok: Bool) -> {F.pick(ok, b <> y) == cons_opt(b, F.pick(ok, y)) : Maybe<&2, List<&2, U32>>}:
  match ok:
    case True{}: {==}
    case False{}: {==}

def step(bytes: List<&2, U32>, n: Nat, +rest: List<&2, List<&2, U32>>, ih: @m:Nat -> {F.sent(rest, F.Left{m}) == F.exactly(List.concat(&2, U32, rest), m) : Maybe<&2, List<&2, U32>>}) -> {F.prepend(bytes, F.sent(rest, F.left_of(F.spend(bytes, n)))) == F.exactly(List.append(&2, U32, bytes, List.concat(&2, U32, rest)), n) : Maybe<&2, List<&2, U32>>}:
  match bytes n:
    case Nil{} +n:
      Equal.trans(Out(), F.prepend([], F.sent(rest, F.Left{n})), F.sent(rest, F.Left{n}), F.exactly(List.concat(&2, U32, rest), n), prepend_nil(F.sent(rest, F.Left{n})), ih(n))
    case +b <> +t 0n:
      %Equal.sym(Out(), F.sent(rest, F.Over{}), None{}, over(rest)) : {F.prepend(b <> t, _) == None{} : Maybe<&2, List<&2, U32>>}
      {==}
    case +b <> +t 1n+(+m):
      +x = F.sent(rest, F.left_of(F.spend(t, m)))
      +c = List.concat(&2, U32, rest)
      +y = List.append(&2, U32, t, c)
      Equal.trans(Out(), F.prepend(b <> t, x), cons_opt(b, F.prepend(t, x)), F.pick(F.exact(y, m), b <> y), prepend_cons(b, t, x), Equal.trans(Out(), cons_opt(b, F.prepend(t, x)), cons_opt(b, F.pick(F.exact(y, m), y)), F.pick(F.exact(y, m), b <> y), Equal.cong(Out(), Out(), r => cons_opt(b, r), F.prepend(t, x), F.exactly(y, m), step(t, m, rest, ih)), Equal.sym(Out(), F.pick(F.exact(y, m), b <> y), cons_opt(b, F.pick(F.exact(y, m), y)), pick_cons(b, y, F.exact(y, m)))))

# The model of every successful sized stream: exactly the concatenated
# chunks when they total n octets, otherwise an abort.
def sized(chunks: List<&2, List<&2, U32>>, n: Nat) -> {F.sent(chunks, F.Left{n}) == F.exactly(List.concat(&2, U32, chunks), n) : Maybe<&2, List<&2, U32>>}:
  match chunks:
    case Nil{}:
      match n:
        case 0n: {==}
        case 1n+m: {==}
    case bytes <> +rest:
      step(bytes, n, rest, m => sized(rest, m))

def exact_length(bytes: List<&2, U32>, n: Nat) -> {F.exact(bytes, n) == Nat.is_eq(List.length(&2, U32, bytes), n) : Bool}:
  match bytes n:
    case Nil{} 0n: {==}
    case Nil{} 1n+m: {==}
    case b <> t 0n: {==}
    case b <> t 1n+m: exact_length(t, m)

def head_matches_get(+status: U32, +n: Nat, +hs: List<&2, Request.Header>, allowed: {Write.allows_body(status) == True{} : Bool}) -> {F.bodyless_fields(Request.Head{}, status, Some{n}, hs) == F.body_fields(Some{n}, hs) : List<&2, Request.Header>}:
  %Equal.sym(Bool, Write.allows_body(status), True{}, allowed) : {F.head_fields(Request.Head{}, status, Some{n}, hs, _ && True{}) == F.body_fields(Some{n}, hs) : List<&2, Request.Header>}
  {==}
