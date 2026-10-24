# Proofs that the frame decoder rejects only with 1002 or 1009 (BND-52).
# Does not import LAWS.bend.
import Base
import ./ws-session-laws.bend as L
import ./ws-session-spec.bend as Spec
import ../src/ws/frame.bend as F
import ../src/data/utf8.bend as Utf8

def known(d: F.Decoded) -> Bool:
  match d:
    case F.NeedMore{n}: True{}
    case F.Partial{b}: True{}
    case F.Got{f, k, rest}: True{}
    case F.Reject{c}: Spec.decoder_code(c)

def finish_ok_k(ok: Bool, fin: Bool, op: F.Opcode, key: Maybe<&2, F.Key>, acc: List<&2, U32>, rest: List<&2, U32>) -> {known(F.finish_ok(ok, fin, op, key, acc, rest)) == True{} : Bool}:
  match ok:
    case True{}: {==}
    case False{}: {==}

def finish_k(+fin: Bool, +op: F.Opcode, +key: Maybe<&2, F.Key>, t: F.Taken) -> {known(F.finish(fin, op, key, t)) == True{} : Bool}:
  match t:
    case F.Took{ok, acc, rest}: finish_ok_k(ok, fin, op, key, acc, rest)
    case F.Short{ok, rot, left, acc}: {==}

def body_k(+fin: Bool, +op: F.Opcode, +key: Maybe<&2, F.Key>, +n: U32, +xs: List<&2, U32>) -> {known(F.body(fin, op, key, n, xs)) == True{} : Bool}:
  finish_k(fin, op, key, F.take_with(key, U32.to_nat(n), xs, [], True{}))

def with_key_k(+a: U32, +b: U32, +c: U32, +d: U32, +fin: Bool, +op: F.Opcode, +n: U32, +xs: List<&2, U32>, ok: Bool) -> {known(F.with_key(a, b, c, d, fin, op, n, xs, ok)) == True{} : Bool}:
  match ok:
    case True{}: body_k(fin, op, Some{F.MaskKey{a, b, c, d}}, n, xs)
    case False{}: {==}

def read_key_k(masked: Bool, +fin: Bool, +op: F.Opcode, +n: U32, xs: List<&2, U32>) -> {known(F.read_key(masked, fin, op, n, xs)) == True{} : Bool}:
  match masked:
    case False{}: body_k(fin, op, None{}, n, xs)
    case True{}:
      match xs:
        case Nil{}: {==}
        case +a <> Nil{}: {==}
        case +a <> +b <> Nil{}: {==}
        case +a <> +b <> +c <> Nil{}: {==}
        case +a <> +b <> +c <> +d <> +t: with_key_k(a, b, c, d, fin, op, n, t, F.key_octet(d, F.key_octet(c, F.key_octet(b, F.key_octet(a, True{})))))

def sized_k(fits: Bool, +masked: Bool, +fin: Bool, +op: F.Opcode, +n: U32, +xs: List<&2, U32>) -> {known(F.sized(fits, masked, fin, op, n, xs)) == True{} : Bool}:
  match fits:
    case True{}: read_key_k(masked, fin, op, n, xs)
    case False{}: {==}

def length_known_k(+max: U32, +masked: Bool, +fin: Bool, +op: F.Opcode, +n: U32, +xs: List<&2, U32>) -> {known(F.length_known(max, masked, fin, op, n, xs)) == True{} : Bool}:
  sized_k(U32.is_le(n, max), masked, fin, op, n, xs)

def minimal_k(ok: Bool, +max: U32, +masked: Bool, +fin: Bool, +op: F.Opcode, +n: U32, +xs: List<&2, U32>) -> {known(F.minimal(ok, max, masked, fin, op, n, xs)) == True{} : Bool}:
  match ok:
    case True{}: length_known_k(max, masked, fin, op, n, xs)
    case False{}: {==}

def octets_then_k(octs: Bool, +ok: Bool, +max: U32, +masked: Bool, +fin: Bool, +op: F.Opcode, +n: U32, +xs: List<&2, U32>) -> {known(F.octets_then(octs, ok, max, masked, fin, op, n, xs)) == True{} : Bool}:
  match octs:
    case True{}: minimal_k(ok, max, masked, fin, op, n, xs)
    case False{}: {==}

def ext16_k(+max: U32, +masked: Bool, +fin: Bool, +op: F.Opcode, xs: List<&2, U32>) -> {known(F.ext16(max, masked, fin, op, xs)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +hi <> Nil{}: {==}
    case +hi <> +lo <> +t: octets_then_k(F.byte_ok(lo, F.byte_ok(hi, True{})), Bool.not(U32.is_le(F.join16(hi, lo), 125)), max, masked, fin, op, F.join16(hi, lo), t)

def upper_k(top: Bool, zeros: Bool, +max: U32, +masked: Bool, +fin: Bool, +op: F.Opcode, +b3: U32, +b2: U32, +b1: U32, +b0: U32, +xs: List<&2, U32>) -> {known(F.upper(top, zeros, max, masked, fin, op, b3, b2, b1, b0, xs)) == True{} : Bool}:
  match top:
    case True{}: {==}
    case False{}:
      match zeros:
        case False{}: {==}
        case True{}: octets_then_k(F.byte_ok(b0, F.byte_ok(b1, F.byte_ok(b2, F.byte_ok(b3, True{})))), Bool.not(U32.is_le(F.join32(b3, b2, b1, b0), 65535)), max, masked, fin, op, F.join32(b3, b2, b1, b0), xs)

def ext64_k(+max: U32, +masked: Bool, +fin: Bool, +op: F.Opcode, xs: List<&2, U32>) -> {known(F.ext64(max, masked, fin, op, xs)) == True{} : Bool}:
  match xs:
    case +u3 <> +u2 <> +u1 <> +u0 <> +b3 <> +b2 <> +b1 <> +b0 <> +t: upper_k((u3 >= 128 : U32), F.is_zero_byte(u0, F.is_zero_byte(u1, F.is_zero_byte(u2, F.is_zero_byte(u3, True{})))), max, masked, fin, op, b3, b2, b1, b0, t)
    case Nil{}: {==}
    case _ <> Nil{}: {==}
    case _ <> _ <> Nil{}: {==}
    case _ <> _ <> _ <> Nil{}: {==}
    case _ <> _ <> _ <> _ <> Nil{}: {==}
    case _ <> _ <> _ <> _ <> _ <> Nil{}: {==}
    case _ <> _ <> _ <> _ <> _ <> _ <> Nil{}: {==}
    case _ <> _ <> _ <> _ <> _ <> _ <> _ <> Nil{}: {==}

def extended_k(control: Bool, wide: Bool, +max: U32, +masked: Bool, +fin: Bool, +op: F.Opcode, +xs: List<&2, U32>) -> {known(F.extended(control, wide, max, masked, fin, op, xs)) == True{} : Bool}:
  match control:
    case True{}: {==}
    case False{}:
      match wide:
        case False{}: ext16_k(max, masked, fin, op, xs)
        case True{}: ext64_k(max, masked, fin, op, xs)

def length7_k(short: Bool, +len7: Word(7n), +max: U32, +masked: Bool, +fin: Bool, +op: F.Opcode, +xs: List<&2, U32>) -> {known(F.length7(short, len7, max, masked, fin, op, xs)) == True{} : Bool}:
  match short:
    case True{}: length_known_k(max, masked, fin, op, U32{Utf8.join(7n, 25n, len7, Word.zero(25n))}, xs)
    case False{}:
      match len7:
        case WCon{wide, w}: extended_k(F.is_control(op), wide, max, masked, fin, op, xs)

def masked_ok_k(ok: Bool, +short: Bool, +len7: Word(7n), +max: U32, +masked: Bool, +fin: Bool, +op: F.Opcode, +xs: List<&2, U32>) -> {known(F.masked_ok(ok, short, len7, max, masked, fin, op, xs)) == True{} : Bool}:
  match ok:
    case False{}: {==}
    case True{}: length7_k(short, len7, max, masked, fin, op, xs)

def second_k(ok: Bool, w: Word(8n), +role: F.Role, +max: U32, +fin: Bool, +op: F.Opcode, +xs: List<&2, U32>) -> {known(F.second(ok, w, role, max, fin, op, xs)) == True{} : Bool}:
  match ok:
    case False{}: {==}
    case True{}:
      match w:
        case WCon{+l0, WCon{+l1, WCon{+l2, WCon{+l3, WCon{+l4, WCon{+l5, WCon{+l6, WCon{+m, WNil{}}}}}}}}}:
          masked_ok_k(F.role_mask(role, m), F.short7({WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, WNil{}}}}}}}} : Word(7n)}), {WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, WNil{}}}}}}}} : Word(7n)}, max, m, fin, op, xs)

def read_second_k(+role: F.Role, +max: U32, +fin: Bool, +op: F.Opcode, xs: List<&2, U32>) -> {known(F.read_second(role, max, fin, op, xs)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +b <> +t: second_k(F.byte_ok(b, True{}), F.bits(b), role, max, fin, op, t)

def control_fin_k(bad: Bool, +op: F.Opcode, +fin: Bool, +role: F.Role, +max: U32, +xs: List<&2, U32>) -> {known(F.control_fin(bad, op, fin, role, max, xs)) == True{} : Bool}:
  match bad:
    case True{}: {==}
    case False{}: read_second_k(role, max, fin, op, xs)

def with_opcode_k(op: Maybe<&2, F.Opcode>, +fin: Bool, +role: F.Role, +max: U32, +xs: List<&2, U32>) -> {known(F.with_opcode(op, fin, role, max, xs)) == True{} : Bool}:
  match op:
    case None{}: {==}
    case Some{+o}: control_fin_k(F.fragmented_control(F.is_control(o), fin), o, fin, role, max, xs)

def reserved_k(clear: Bool, +op: Maybe<&2, F.Opcode>, +fin: Bool, +role: F.Role, +max: U32, +xs: List<&2, U32>) -> {known(F.reserved(clear, op, fin, role, max, xs)) == True{} : Bool}:
  match clear:
    case False{}: {==}
    case True{}: with_opcode_k(op, fin, role, max, xs)

def first_k(ok: Bool, w: Word(8n), +role: F.Role, +max: U32, +xs: List<&2, U32>) -> {known(F.first(ok, w, role, max, xs)) == True{} : Bool}:
  match ok:
    case False{}: {==}
    case True{}:
      match w:
        case WCon{o0, WCon{o1, WCon{o2, WCon{o3, WCon{r1, WCon{r2, WCon{r3, WCon{fin, WNil{}}}}}}}}}:
          reserved_k(F.rsv_clear(r1, r2, r3), F.opcode_of(o0, o1, o2, o3), fin, role, max, xs)

def start_k(cfg: F.Config, xs: List<&2, U32>) -> {known(F.start(cfg, xs)) == True{} : Bool}:
  match cfg:
    case F.Config{+role, +max}:
      match xs:
        case Nil{}: {==}
        case +b <> +t: first_k(F.byte_ok(b, True{}), F.bits(b), role, max, t)

def resume_k(body: F.Body, xs: List<&2, U32>) -> {known(F.resume(body, xs)) == True{} : Bool}:
  match body:
    case F.Body{+fin, +op, +key, rot, left, acc, ok}: finish_k(fin, op, key, F.take_rot(key, rot, left, xs, acc, ok))

def L.ws_session_start_rejects(cfg, bytes, code, rejected):
  %rejected : {known(_) == True{} : Bool}
  start_k(cfg, bytes)

def L.ws_session_resume_rejects(body, bytes, code, rejected):
  %rejected : {known(_) == True{} : Bool}
  resume_k(body, bytes)
