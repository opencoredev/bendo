# Proofs of the BND-52 send-admission laws. Does not import LAWS.bend.
import Base
import ./ws-session-laws.bend as L
import ./ws-session-spec.bend as Spec
import ./ws-frame.bend as WF
import ./chunked-arith.bend as A
import ./ws-frame-spec.bend as FS
import ./ws-session-message.bend as MP
import ../src/ws/session.bend as S
import ../src/ws/frame.bend as F
import ../src/ws/message.bend as M
import ../src/data/utf8.bend as Utf8

def absurd(-T: Type, e: Empty) -> T:
  match e:

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def true_false(e: {True{} == False{} : Bool}) -> Empty:
  false_true(Equal.sym(Bool, True{}, False{}, e))

# ---- Nat order ----

def le_lt(n: Nat, m: Nat, +k: Nat, h: {Nat.is_le(n, m) == True{} : Bool}, g: {Cmp.is_lt(Nat.cmp(m, k)) == True{} : Bool}) -> {Nat.is_le(n, k) == True{} : Bool}:
  match n:
    case 0n:
      match k:
        case 0n: {==}
        case 1n+c: {==}
    case 1n+a:
      match m:
        case 0n: absurd({Nat.is_le(1n+a, k) == True{} : Bool}, false_true(h))
        case 1n+b:
          match k:
            case 0n: absurd({Nat.is_le(1n+a, 0n) == True{} : Bool}, false_true(g))
            case 1n+c: le_lt(a, b, c, h, g)

def le_ge(n: Nat, k: Nat, m: Nat, h: {Nat.is_le(n, k) == True{} : Bool}, g: {Cmp.is_lt(Nat.cmp(m, k)) == False{} : Bool}) -> {Nat.is_le(n, m) == True{} : Bool}:
  match n:
    case 0n:
      match m:
        case 0n: {==}
        case 1n+c: {==}
    case 1n+a:
      match k:
        case 0n: absurd({Nat.is_le(1n+a, m) == True{} : Bool}, false_true(h))
        case 1n+b:
          match m:
            case 0n: absurd({Nat.is_le(1n+a, 0n) == True{} : Bool}, true_false(g))
            case 1n+c: le_ge(a, b, c, h, g)

def lt_nat(+a: U32, +b: U32, c: Bool, e: {U32.is_lt(a, b) == c : Bool}) -> {Cmp.is_lt(Nat.cmp(U32.to_nat(a), U32.to_nat(b))) == c : Bool}:
  %A.u32_nat_cmp(a, b) : {Cmp.is_lt(_) == c : Bool}
  e

# ---- The server's frame cap is at least 125 and at least max_message ----

def cap125_go(+n: Nat, +x: Word(32n), c: Bool, e: {U32.is_lt(U32{x}, 125) == c : Bool}, h: {Nat.is_le(n, 125n) == True{} : Bool}) -> {Nat.is_le(n, U32.to_nat(Bool.pick(U32, c, 125, U32{x}))) == True{} : Bool}:
  match c:
    case True{}: h
    case False{}: le_ge(n, 125n, U32.to_nat(U32{x}), h, lt_nat(U32{x}, 125, False{}, e))

def cap_125(+n: Nat, max: U32, h: {Nat.is_le(n, 125n) == True{} : Bool}) -> {Nat.is_le(n, U32.to_nat(S.cap(max))) == True{} : Bool}:
  match max:
    case U32{+x}: cap125_go(n, x, U32.is_lt(U32{x}, 125), {==}, h)

def capmax_go(+n: Nat, +x: Word(32n), c: Bool, e: {U32.is_lt(U32{x}, 125) == c : Bool}, h: {Nat.is_le(n, U32.to_nat(U32{x})) == True{} : Bool}) -> {Nat.is_le(n, U32.to_nat(Bool.pick(U32, c, 125, U32{x}))) == True{} : Bool}:
  match c:
    case True{}: le_lt(n, U32.to_nat(U32{x}), 125n, h, lt_nat(U32{x}, 125, True{}, e))
    case False{}: h

def cap_max(+n: Nat, max: U32, h: {Nat.is_le(n, U32.to_nat(max)) == True{} : Bool}) -> {Nat.is_le(n, U32.to_nat(S.cap(max))) == True{} : Bool}:
  match max:
    case U32{+x}: capmax_go(n, x, U32.is_lt(U32{x}, 125), {==}, h)

# ---- Boolean shapes of S.admissible ----

def alg_data(x: Bool, d: Bool, b: Bool, hb: {x == True{} : Bool} -> {b == True{} : Bool}) -> {Bool.and(Bool.and(Bool.and(Bool.and(b, True{}), d), True{}), x) == Bool.and(x, d) : Bool}:
  match x:
    case False{}:
      match d:
        case True{}:
          match b:
            case True{}: {==}
            case False{}: {==}
        case False{}:
          match b:
            case True{}: {==}
            case False{}: {==}
    case True{}:
      match d:
        case True{}:
          %Equal.sym(Bool, b, True{}, hb({==})) : {Bool.and(Bool.and(Bool.and(Bool.and(_, True{}), True{}), True{}), True{}) == True{} : Bool}
          {==}
        case False{}:
          %Equal.sym(Bool, b, True{}, hb({==})) : {Bool.and(Bool.and(Bool.and(Bool.and(_, True{}), False{}), True{}), True{}) == False{} : Bool}
          {==}

def alg_ctl(x: Bool, d: Bool, b: Bool, hb: {x == True{} : Bool} -> {b == True{} : Bool}) -> {Bool.and(Bool.and(Bool.and(Bool.and(Bool.and(x, b), True{}), d), True{}), True{}) == Bool.and(x, d) : Bool}:
  match x:
    case False{}: {==}
    case True{}:
      match d:
        case True{}:
          %Equal.sym(Bool, b, True{}, hb({==})) : {Bool.and(Bool.and(Bool.and(Bool.and(Bool.and(True{}, _), True{}), True{}), True{}), True{}) == True{} : Bool}
          {==}
        case False{}:
          %Equal.sym(Bool, b, True{}, hb({==})) : {Bool.and(Bool.and(Bool.and(Bool.and(Bool.and(True{}, _), True{}), False{}), True{}), True{}) == False{} : Bool}
          {==}

def alg_close(x: Bool, d: Bool, k: Bool, b: Bool, hb: {x == True{} : Bool} -> {b == True{} : Bool}) -> {Bool.and(Bool.and(Bool.and(Bool.and(Bool.and(x, b), True{}), d), k), True{}) == Bool.and(Bool.and(k, x), d) : Bool}:
  match x:
    case False{}:
      match d:
        case True{}:
          match k:
            case True{}: {==}
            case False{}: {==}
        case False{}:
          match k:
            case True{}: {==}
            case False{}: {==}
    case True{}:
      match d:
        case True{}:
          match k:
            case True{}:
              %Equal.sym(Bool, b, True{}, hb({==})) : {Bool.and(Bool.and(Bool.and(Bool.and(Bool.and(True{}, _), True{}), True{}), True{}), True{}) == True{} : Bool}
              {==}
            case False{}:
              %Equal.sym(Bool, b, True{}, hb({==})) : {Bool.and(Bool.and(Bool.and(Bool.and(Bool.and(True{}, _), True{}), True{}), False{}), True{}) == False{} : Bool}
              {==}
        case False{}:
          match k:
            case True{}:
              %Equal.sym(Bool, b, True{}, hb({==})) : {Bool.and(Bool.and(Bool.and(Bool.and(Bool.and(True{}, _), True{}), False{}), True{}), True{}) == False{} : Bool}
              {==}
            case False{}:
              %Equal.sym(Bool, b, True{}, hb({==})) : {Bool.and(Bool.and(Bool.and(Bool.and(Bool.and(True{}, _), True{}), False{}), False{}), True{}) == False{} : Bool}
              {==}

# ---- Payload facts ----

def add_two(l: Nat) -> {Nat.add(l, 2n) == 1n+1n+l : Nat}:
  match l:
    case 0n: {==}
    case 1n+k: Equal.cong(Nat, Nat, x => 1n+x, Nat.add(k, 2n), 1n+1n+k, add_two(k))

# A close payload is two code bytes then the reason.
def close_len(+a: U32, +b: U32, +enc: List<&2, U32>) -> {Nat.is_le(F.length(a <> b <> enc), 125n) == Nat.is_le(List.length(&2, U32, enc), 123n) : Bool}:
  %Equal.sym(Nat, F.count(enc, 2n), Nat.add(List.length(&2, U32, enc), 2n), WF.count_length(enc, 2n)) : {Nat.is_le(_, 125n) == Nat.is_le(List.length(&2, U32, enc), 123n) : Bool}
  %Equal.sym(Nat, Nat.add(List.length(&2, U32, enc), 2n), 1n+1n+List.length(&2, U32, enc), add_two(List.length(&2, U32, enc))) : {Nat.is_le(_, 125n) == Nat.is_le(List.length(&2, U32, enc), 123n) : Bool}
  {==}

# ---- The laws ----

def data_law(+max: U32, +bytes: List<&2, U32>) -> {Bool.and(Bool.and(Bool.and(Bool.and(Nat.is_le(F.length(bytes), U32.to_nat(S.cap(max))), True{}), F.octets(bytes, True{})), True{}), Nat.is_le(F.length(bytes), U32.to_nat(max))) == Spec.fits(max, bytes) && FS.octets(bytes) : Bool}:
  %WF.octets_acc(bytes, True{}) : {Bool.and(Bool.and(Bool.and(Bool.and(Nat.is_le(F.length(bytes), U32.to_nat(S.cap(max))), True{}), F.octets(bytes, True{})), True{}), Nat.is_le(F.length(bytes), U32.to_nat(max))) == Nat.is_le(List.length(&2, U32, bytes), U32.to_nat(max)) && _ : Bool}
  %WF.length_eq(bytes) : {Bool.and(Bool.and(Bool.and(Bool.and(Nat.is_le(F.length(bytes), U32.to_nat(S.cap(max))), True{}), F.octets(bytes, True{})), True{}), Nat.is_le(F.length(bytes), U32.to_nat(max))) == Nat.is_le(_, U32.to_nat(max)) && F.octets(bytes, True{}) : Bool}
  alg_data(Nat.is_le(F.length(bytes), U32.to_nat(max)), F.octets(bytes, True{}), Nat.is_le(F.length(bytes), U32.to_nat(S.cap(max))), h => cap_max(F.length(bytes), max, h))

def L.ws_session_admit_text(max, text):
  data_law(max, Utf8.encode(text))

def L.ws_session_admit_binary(max, bytes):
  data_law(max, bytes)

def L.ws_session_admit_ping(max, bytes):
  %WF.octets_acc(bytes, True{}) : {S.admissible(max, S.SendPing{bytes}) == Spec.small(bytes) && _ : Bool}
  %MP.control_small(bytes) : {S.admissible(max, S.SendPing{bytes}) == _ && F.octets(bytes, True{}) : Bool}
  alg_ctl(Nat.is_le(F.length(bytes), 125n), F.octets(bytes, True{}), Nat.is_le(F.length(bytes), U32.to_nat(S.cap(max))), h => cap_125(F.length(bytes), max, h))

def L.ws_session_admit_close(max, code, reason):
  %WF.octets_acc(M.close_payload(code, reason), True{}) : {S.admissible(max, S.SendClose{code, reason}) == Spec.peer_code(code) && Nat.is_le(List.length(&2, U32, Utf8.encode(reason)), 123n) && _ : Bool}
  %close_len(U32.shrn(code, 8n), U32.and(code, 255), Utf8.encode(reason)) : {S.admissible(max, S.SendClose{code, reason}) == Spec.peer_code(code) && _ && F.octets(M.close_payload(code, reason), True{}) : Bool}
  alg_close(Nat.is_le(F.length(M.close_payload(code, reason)), 125n), F.octets(M.close_payload(code, reason), True{}), M.code_ok(code), Nat.is_le(F.length(M.close_payload(code, reason)), U32.to_nat(S.cap(max))), h => cap_125(F.length(M.close_payload(code, reason)), max, h))
