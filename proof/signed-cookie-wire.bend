# BND-32: universal facts behind the public signed-cookie wire laws.
import Base
import ../src/crypto/octets.bend as O
import ../src/crypto/common.bend as C
import ../src/crypto/sha256.bend as SHA
import ../src/crypto/hmac.bend as Hmac
import ./crypto-octets.bend as OctetsProof
import ./crypto-base64.bend as Base64Proof
import ./crypto-support.bend as Support
import ../src/data/base64.bend as B
import ../src/data/utf8.bend as U
import ./utf8.bend as Utf8Proof
import ../src/data/cookie.bend as Cookie
import ./signed-cookie-spec.bend as Spec

def distinguish(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : distinguish(_)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

def and_left(+a: Bool, +b: Bool, ok: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}: ok
    case True{}: {==}

def and_right(+a: Bool, +b: Bool, ok: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}: absurd({b == True{} : Bool}, false_true(ok))
    case True{}: ok

def not_true(+a: Bool, ok: {Bool.not(a) == True{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: absurd({True{} == False{} : Bool}, false_true(ok))

def both(+a: Bool, +b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, ea) : {_ && b == True{} : Bool}
  eb

# HMAC-SHA-256 output is 32 octets: every big-endian word byte is <= 255.
def fin_and_le(+t: Cmp, +ab: Bool, +bb: Bool, ok: {Cmp.is_le(t) == True{} : Bool}) -> {Cmp.is_le(Word.cmp.fin(Bool.and(ab, bb), bb, t)) == True{} : Bool}:
  match t:
    case LT{}: {==}
    case GT{}: absurd({Cmp.is_le(Word.cmp.fin(Bool.and(ab, bb), bb, GT{})) == True{} : Bool}, false_true(ok))
    case EQ{}:
      match ab bb:
        case False{} False{}: {==}
        case False{} True{}: {==}
        case True{} False{}: {==}
        case True{} True{}: {==}

def and_le(+n: Nat, +a: Word(n), +b: Word(n)) -> {Cmp.is_le(Word.cmp(n, Word.and(n, a, b), b)) == True{} : Bool}:
  match n a b:
    case 0n WNil{} WNil{}: {==}
    case 1n+p WCon{+ah, +at} WCon{+bh, +bt}:
      fin_and_le(Word.cmp(p, Word.and(p, at, bt), bt), ah, bh, and_le(p, at, bt))

def and_le_u32(+a: U32, +b: U32) -> {(U32.and(a, b) <= b : U32) == True{} : Bool}:
  match a b:
    case U32{+x} U32{+y}: and_le(32n, x, y)

# The top byte after a 24-bit shift is compared with 255 from bit 31 down.
def top_le(+b31: Bool, +b30: Bool, +b29: Bool, +b28: Bool, +b27: Bool, +b26: Bool, +b25: Bool, +b24: Bool) -> {Cmp.is_le(Word.cmp.fin(b24, True{}, Word.cmp.fin(b25, True{}, Word.cmp.fin(b26, True{}, Word.cmp.fin(b27, True{}, Word.cmp.fin(b28, True{}, Word.cmp.fin(b29, True{}, Word.cmp.fin(b30, True{}, Word.cmp.fin(b31, True{}, EQ{}))))))))) == True{} : Bool}:
  match b31:
    case False{}: {==}
    case True{}:
      match b30:
        case False{}: {==}
        case True{}:
          match b29:
            case False{}: {==}
            case True{}:
              match b28:
                case False{}: {==}
                case True{}:
                  match b27:
                    case False{}: {==}
                    case True{}:
                      match b26:
                        case False{}: {==}
                        case True{}:
                          match b25:
                            case False{}: {==}
                            case True{}:
                              match b24:
                                case False{}: {==}
                                case True{}: {==}

def shr24_le(+x: U32) -> {(U32.shrn(x, 24n) <= 255 : U32) == True{} : Bool}:
  match x:
    case U32{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WCon{+b6, WCon{+b7, WCon{+b8, WCon{+b9, WCon{+b10, WCon{+b11, WCon{+b12, WCon{+b13, WCon{+b14, WCon{+b15, WCon{+b16, WCon{+b17, WCon{+b18, WCon{+b19, WCon{+b20, WCon{+b21, WCon{+b22, WCon{+b23, WCon{+b24, WCon{+b25, WCon{+b26, WCon{+b27, WCon{+b28, WCon{+b29, WCon{+b30, WCon{+b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      top_le(b31, b30, b29, b28, b27, b26, b25, b24)

def bytes_spec(+x: U32, +tail: List<&2, U32>, ok: {OctetsProof.spec(tail) == True{} : Bool}) -> {OctetsProof.spec(List.append(&2, U32, C.bytes(x), tail)) == True{} : Bool}:
  both((U32.shrn(x, 24n) <= 255 : U32), (U32.and(U32.shrn(x, 16n), 255) <= 255 : U32) && ((U32.and(U32.shrn(x, 8n), 255) <= 255 : U32) && ((U32.and(x, 255) <= 255 : U32) && OctetsProof.spec(tail))), shr24_le(x), both((U32.and(U32.shrn(x, 16n), 255) <= 255 : U32), (U32.and(U32.shrn(x, 8n), 255) <= 255 : U32) && ((U32.and(x, 255) <= 255 : U32) && OctetsProof.spec(tail)), and_le_u32(U32.shrn(x, 16n), 255), both((U32.and(U32.shrn(x, 8n), 255) <= 255 : U32), (U32.and(x, 255) <= 255 : U32) && OctetsProof.spec(tail), and_le_u32(U32.shrn(x, 8n), 255), both((U32.and(x, 255) <= 255 : U32), OctetsProof.spec(tail), and_le_u32(x, 255), ok))))

def output_spec(+s: SHA.State) -> {OctetsProof.spec(SHA.output(s)) == True{} : Bool}:
  match s:
    case SHA.State{+a, +b, +c, +d, +e, +f, +g, +h}:
      bytes_spec(a, List.append(&2, U32, C.bytes(b), List.append(&2, U32, C.bytes(c), List.append(&2, U32, C.bytes(d), List.append(&2, U32, C.bytes(e), List.append(&2, U32, C.bytes(f), List.append(&2, U32, C.bytes(g), List.append(&2, U32, C.bytes(h), []))))))), bytes_spec(b, List.append(&2, U32, C.bytes(c), List.append(&2, U32, C.bytes(d), List.append(&2, U32, C.bytes(e), List.append(&2, U32, C.bytes(f), List.append(&2, U32, C.bytes(g), List.append(&2, U32, C.bytes(h), [])))))), bytes_spec(c, List.append(&2, U32, C.bytes(d), List.append(&2, U32, C.bytes(e), List.append(&2, U32, C.bytes(f), List.append(&2, U32, C.bytes(g), List.append(&2, U32, C.bytes(h), []))))), bytes_spec(d, List.append(&2, U32, C.bytes(e), List.append(&2, U32, C.bytes(f), List.append(&2, U32, C.bytes(g), List.append(&2, U32, C.bytes(h), [])))), bytes_spec(e, List.append(&2, U32, C.bytes(f), List.append(&2, U32, C.bytes(g), List.append(&2, U32, C.bytes(h), []))), bytes_spec(f, List.append(&2, U32, C.bytes(g), List.append(&2, U32, C.bytes(h), [])), bytes_spec(g, List.append(&2, U32, C.bytes(h), []), bytes_spec(h, [], {==}))))))))

def hash_spec(+xs: List<&2, U32>) -> {OctetsProof.spec(SHA.hash(xs)) == True{} : Bool}:
  output_spec(SHA.blocks(C.pad(xs), 0, ([0 : U32^4n], SHA.State{1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225})))

def hmac_octets(+secret: List<&2, U32>, +message: List<&2, U32>) -> {O.valid(Hmac.sha256(secret, message)) == True{} : Bool}:
  Equal.trans(Bool, O.valid(Hmac.sha256(secret, message)), OctetsProof.spec(Hmac.sha256(secret, message)), True{}, OctetsProof.valid_acc(Hmac.sha256(secret, message), True{}), hash_spec(Hmac.pad(64n, Hmac.key(secret, Hmac.long_key(secret, 64n)), 92, SHA.hash(Hmac.pad(64n, Hmac.key(secret, Hmac.long_key(secret, 64n)), 54, message)))))

# Base64 output contains only dot-free Unicode scalars.
def clean(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, t}: (U.scalar(c) && Bool.not(U32.is_eq(c, 46))) && clean(t)

# Every standard or URL Base64 symbol is a dot-free Unicode scalar.
def symbol_clean(+w: Word(6n), +url: Bool, +t: String) -> {clean(SCon{B.symbol(w, url), t}) == clean(t) : Bool}:
  match w:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      match url:
        case False{}: {==}
        case True{}: {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      match url:
        case False{}: {==}
        case True{}: {==}

def sym_ok(+w: Word(6n), +url: Bool, +t: String, +ok: {clean(t) == True{} : Bool}) -> {clean(SCon{B.symbol(w, url), t}) == True{} : Bool}:
  Equal.trans(Bool, clean(SCon{B.symbol(w, url), t}), clean(t), True{}, symbol_clean(w, url, t), ok)

def one_clean(+a: Word(8n), +url: Bool, +padded: Bool) -> {clean(B.one(a, url, padded)) == True{} : Bool}:
  match padded:
    case True{}: sym_ok(U.high(2n, 6n, a), url, SCon{B.symbol(U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url), "=="}, sym_ok(U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url, "==", {==}))
    case False{}: sym_ok(U.high(2n, 6n, a), url, SCon{B.symbol(U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url), ""}, sym_ok(U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url, "", {==}))

def two_clean(+a: Word(8n), +b: Word(8n), +url: Bool, +padded: Bool) -> {clean(B.two(a, b, url, padded)) == True{} : Bool}:
  match padded:
    case True{}: sym_ok(U.high(2n, 6n, a), url, SCon{B.symbol(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url), SCon{B.symbol(U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url), "="}}, sym_ok(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url, SCon{B.symbol(U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url), "="}, sym_ok(U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url, "=", {==})))
    case False{}: sym_ok(U.high(2n, 6n, a), url, SCon{B.symbol(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url), SCon{B.symbol(U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url), ""}}, sym_ok(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url, SCon{B.symbol(U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url), ""}, sym_ok(U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url, "", {==})))

def three_clean(+a: Word(8n), +b: Word(8n), +c: Word(8n), +url: Bool, +rest: String, +ok: {clean(rest) == True{} : Bool}) -> {clean(B.three(a, b, c, url) ++ rest) == True{} : Bool}:
  sym_ok(U.high(2n, 6n, a), url, SCon{B.symbol(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url), SCon{B.symbol(U.join(2n, 4n, U.high(6n, 2n, c), U.low(4n, 4n, b)), url), SCon{B.symbol(U.low(6n, 2n, c), url), rest}}}, sym_ok(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url, SCon{B.symbol(U.join(2n, 4n, U.high(6n, 2n, c), U.low(4n, 4n, b)), url), SCon{B.symbol(U.low(6n, 2n, c), url), rest}}, sym_ok(U.join(2n, 4n, U.high(6n, 2n, c), U.low(4n, 4n, b)), url, SCon{B.symbol(U.low(6n, 2n, c), url), rest}, sym_ok(U.low(6n, 2n, c), url, rest, ok))))

def spec_clean(+xs: List<&2, U32>, +url: Bool, +padded: Bool) -> {clean(B.encode_spec(xs, url, padded)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case U32{+a} <> Nil{}: one_clean(U.low(8n, 24n, a), url, padded)
    case U32{+a} <> U32{+b} <> Nil{}: two_clean(U.low(8n, 24n, a), U.low(8n, 24n, b), url, padded)
    case U32{+a} <> U32{+b} <> U32{+c} <> +t:
      three_clean(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url, B.encode_spec(t, url, padded), spec_clean(t, url, padded))

def encode_clean(+xs: List<&2, U32>, +url: Bool, +padded: Bool) -> {clean(B.encode(xs, url, padded)) == True{} : Bool}:
  %Equal.sym(String, B.encode(xs, url, padded), B.encode_spec(xs, url, padded), Base64Proof.encode_acc(xs, url, padded, "")) : {clean(_) == True{} : Bool}
  spec_clean(xs, url, padded)

def clean_valid_spec(+s: String, +ok: {clean(s) == True{} : Bool}) -> {U.valid_spec(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      +head = and_left(U.scalar(c) && Bool.not(U32.is_eq(c, 46)), clean(t), ok)
      both(U.scalar(c), U.valid_spec(t), and_left(U.scalar(c), Bool.not(U32.is_eq(c, 46)), head), clean_valid_spec(t, and_right(U.scalar(c) && Bool.not(U32.is_eq(c, 46)), clean(t), ok)))

def valid_append_spec(+a: String, +b: String, +oka: {U.valid_spec(a) == True{} : Bool}, +okb: {U.valid_spec(b) == True{} : Bool}) -> {U.valid_spec(a ++ b) == True{} : Bool}:
  match a:
    case SNil{}: okb
    case SCon{Chr{+c}, +t}:
      both(U.scalar(c), U.valid_spec(t ++ b), and_left(U.scalar(c), U.valid_spec(t), oka), valid_append_spec(t, b, and_right(U.scalar(c), U.valid_spec(t), oka), okb))

# The complete signed payload stays a Unicode scalar string.
def clean_valid(+s: String, +ok: {clean(s) == True{} : Bool}) -> {U.valid(s) == True{} : Bool}:
  Equal.trans(Bool, U.valid(s), U.valid_spec(s), True{}, Utf8Proof.valid_equiv(s), clean_valid_spec(s, ok))

def valid_append(+a: String, +b: String, +oka: {U.valid(a) == True{} : Bool}, +okb: {U.valid(b) == True{} : Bool}) -> {U.valid(a ++ b) == True{} : Bool}:
  Equal.trans(Bool, U.valid(a ++ b), U.valid_spec(a ++ b), True{}, Utf8Proof.valid_equiv(a ++ b), valid_append_spec(a, b, Utf8Proof.valid_spec_of(a, oka), Utf8Proof.valid_spec_of(b, okb)))

def payload_valid(+value: String, +signature: List<&2, U32>, +ok: {U.valid(value) == True{} : Bool}) -> {U.valid(value ++ "." ++ B.encode(signature, False{}, True{})) == True{} : Bool}:
  +e = B.encode(signature, False{}, True{})
  valid_append(value, "." ++ e, ok, Equal.trans(Bool, U.valid("." ++ e), U.valid_spec("." ++ e), True{}, Utf8Proof.valid_equiv("." ++ e), clean_valid_spec(e, encode_clean(signature, False{}, True{}))))

def clean_reverse(+s: String, +acc: String, +oks: {clean(s) == True{} : Bool}, +oka: {clean(acc) == True{} : Bool}) -> {clean(String.reverse.go(s, acc)) == True{} : Bool}:
  match s:
    case SNil{}: oka
    case SCon{Chr{+c}, +t}:
      clean_reverse(t, SCon{Chr{c}, acc}, and_right(U.scalar(c) && Bool.not(U32.is_eq(c, 46)), clean(t), oks), both(U.scalar(c) && Bool.not(U32.is_eq(c, 46)), clean(acc), and_left(U.scalar(c) && Bool.not(U32.is_eq(c, 46)), clean(t), oks), oka))

def split_stop(+tail: String, +rev: String) -> {Cookie.split_go(tail, True{}, '.', rev) == (String.reverse(rev), Some{tail}) : String & Maybe<&2, String>}:
  match tail:
    case SNil{}: {==}
    case SCon{+h, +t}: {==}

# Scanning a dot-free prefix stops at the separator that follows it.
def split_clean(+s: String, +tail: String, +rev: String, +ok: {clean(s) == True{} : Bool}) -> {Cookie.split_go(s ++ SCon{'.', tail}, False{}, '.', rev) == (String.reverse(String.reverse.go(s, rev)), Some{tail}) : String & Maybe<&2, String>}:
  match s:
    case SNil{}: split_stop(tail, rev)
    case SCon{Chr{+c}, +t}:
      +dot = not_true(U32.is_eq(c, 46), and_right(U.scalar(c), Bool.not(U32.is_eq(c, 46)), and_left(U.scalar(c) && Bool.not(U32.is_eq(c, 46)), clean(t), ok)))
      %Equal.sym(Bool, U32.is_eq(c, 46), False{}, dot) : {Cookie.split_go(t ++ SCon{'.', tail}, _, '.', Cookie.split_prefix(Chr{c}, rev, _)) == (String.reverse(String.reverse.go(t, SCon{Chr{c}, rev})), Some{tail}) : String & Maybe<&2, String>}
      split_clean(t, tail, SCon{Chr{c}, rev}, and_right(U.scalar(c) && Bool.not(U32.is_eq(c, 46)), clean(t), ok))

def reverse_onto(+s: String, +a: String, +x: String) -> {String.reverse.go(s, a) ++ x == String.reverse.go(s, a ++ x) : String}:
  match s:
    case SNil{}: {==}
    case SCon{+h, +t}: reverse_onto(t, SCon{h, a}, x)

def reverse_twice(+s: String) -> {String.reverse(String.reverse(s)) == s : String}:
  Equal.trans(String, String.reverse(String.reverse(s)), s ++ "", s, Support.reverse_twice(s, "", ""), Support.string_nil(s))

# reverse(value ++ "." ++ b) == reverse(b) ++ "." ++ reverse(value)
def reverse_payload(+value: String, +b: String) -> {String.reverse(value ++ "." ++ b) == String.reverse(b) ++ SCon{'.', String.reverse(value)} : String}:
  %Equal.sym(String, String.reverse.go(value ++ "." ++ b, ""), String.reverse.go("." ++ b, String.reverse.go(value, "")), Support.reverse_append(value, "." ++ b, "")) : {_ == String.reverse(b) ++ SCon{'.', String.reverse(value)} : String}
  Equal.sym(String, String.reverse(b) ++ SCon{'.', String.reverse(value)}, String.reverse.go(b, SCon{'.', String.reverse(value)}), reverse_onto(b, "", SCon{'.', String.reverse(value)}))

# The last dot of the payload separates the value from its Base64 signature.
def payload_split(+value: String, +signature: List<&2, U32>) -> {Cookie.split(String.reverse(value ++ "." ++ B.encode(signature, False{}, True{})), '.') == (String.reverse(B.encode(signature, False{}, True{})), Some{String.reverse(value)}) : String & Maybe<&2, String>}:
  %Equal.sym(String, String.reverse(value ++ "." ++ B.encode(signature, False{}, True{})), String.reverse(B.encode(signature, False{}, True{})) ++ SCon{'.', String.reverse(value)}, reverse_payload(value, B.encode(signature, False{}, True{}))) : {Cookie.split(_, '.') == (String.reverse(B.encode(signature, False{}, True{})), Some{String.reverse(value)}) : String & Maybe<&2, String>}
  %reverse_twice(String.reverse(B.encode(signature, False{}, True{}))) : {Cookie.split(String.reverse(B.encode(signature, False{}, True{})) ++ SCon{'.', String.reverse(value)}, '.') == (_, Some{String.reverse(value)}) : String & Maybe<&2, String>}
  split_clean(String.reverse(B.encode(signature, False{}, True{})), String.reverse(value), "", clean_reverse(B.encode(signature, False{}, True{}), "", encode_clean(signature, False{}, True{}), {==}))

# Arbitrary payloads: Cookie.split over the reversed payload finds exactly the
# independent last-dot parts, or reports no dot.
def expected(m: Maybe<&2, Spec.Parts>, +p: String) -> String & Maybe<&2, String>:
  match m:
    case None{}: (String.reverse(p), None{})
    case Some{Spec.Parts{v, s}}: (String.reverse(s), Some{String.reverse(v)})

def cont(r: String & Maybe<&2, String>, b: String) -> String & Maybe<&2, String>:
  (x, y) = r
  match y:
    case None{}: Cookie.split_go(b, False{}, '.', String.reverse(x))
    case Some{z}: (x, Some{z ++ b})

def stop_any(+s: String, +rev: String) -> {Cookie.split_go(s, True{}, '.', rev) == (String.reverse(rev), Some{s}) : String & Maybe<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{+h, +t}: {==}

def append_step(+h: Char, +t: String, +b: String, +rev: String, d: Bool, e: {Char.is_eq(h, '.') == d : Bool}, ih: {Cookie.split_go(t ++ b, False{}, '.', SCon{h, rev}) == cont(Cookie.split_go(t, False{}, '.', SCon{h, rev}), b) : String & Maybe<&2, String>}) -> {Cookie.split_go(SCon{h, t} ++ b, False{}, '.', rev) == cont(Cookie.split_go(SCon{h, t}, False{}, '.', rev), b) : String & Maybe<&2, String>}:
  match d:
    case True{}:
      %Equal.sym(Bool, Char.is_eq(h, '.'), True{}, e) : {Cookie.split_go(t ++ b, _, '.', Cookie.split_prefix(h, rev, _)) == cont(Cookie.split_go(t, _, '.', Cookie.split_prefix(h, rev, _)), b) : String & Maybe<&2, String>}
      %Equal.sym(String & Maybe<&2, String>, Cookie.split_go(t ++ b, True{}, '.', rev), (String.reverse(rev), Some{t ++ b}), stop_any(t ++ b, rev)) : {_ == cont(Cookie.split_go(t, True{}, '.', rev), b) : String & Maybe<&2, String>}
      %Equal.sym(String & Maybe<&2, String>, Cookie.split_go(t, True{}, '.', rev), (String.reverse(rev), Some{t}), stop_any(t, rev)) : {(String.reverse(rev), Some{t ++ b}) == cont(_, b) : String & Maybe<&2, String>}
      {==}
    case False{}:
      %Equal.sym(Bool, Char.is_eq(h, '.'), False{}, e) : {Cookie.split_go(t ++ b, _, '.', Cookie.split_prefix(h, rev, _)) == cont(Cookie.split_go(t, _, '.', Cookie.split_prefix(h, rev, _)), b) : String & Maybe<&2, String>}
      ih

# Splitting a ++ b either stops inside a or continues into b.
def split_append(+a: String, +b: String, +rev: String) -> {Cookie.split_go(a ++ b, False{}, '.', rev) == cont(Cookie.split_go(a, False{}, '.', rev), b) : String & Maybe<&2, String>}:
  match a:
    case SNil{}:
      %Equal.sym(String, String.reverse(String.reverse(rev)), rev, reverse_twice(rev)) : {Cookie.split_go(b, False{}, '.', rev) == Cookie.split_go(b, False{}, '.', _) : String & Maybe<&2, String>}
      {==}
    case SCon{+h, +t}:
      append_step(h, t, b, rev, Char.is_eq(h, '.'), {==}, split_append(t, b, SCon{h, rev}))

def last_none(+c: Char, +t: String, d: Bool, e: {Char.is_eq(c, '.') == d : Bool}) -> {cont((String.reverse(t), None{}), SCon{c, ""}) == expected(Spec.last_dot_at(c, t, None{}, Char.is_eq(c, '.')), SCon{c, t}) : String & Maybe<&2, String>}:
  match d:
    case True{}:
      %Equal.sym(String, String.reverse(String.reverse(t)), t, reverse_twice(t)) : {Cookie.split_go(SCon{c, ""}, False{}, '.', _) == expected(Spec.last_dot_at(c, t, None{}, Char.is_eq(c, '.')), SCon{c, t}) : String & Maybe<&2, String>}
      %Equal.sym(Bool, Char.is_eq(c, '.'), True{}, e) : {Cookie.split_go("", _, '.', Cookie.split_prefix(c, t, _)) == expected(Spec.last_dot_at(c, t, None{}, _), SCon{c, t}) : String & Maybe<&2, String>}
      {==}
    case False{}:
      %Equal.sym(String, String.reverse(String.reverse(t)), t, reverse_twice(t)) : {Cookie.split_go(SCon{c, ""}, False{}, '.', _) == expected(Spec.last_dot_at(c, t, None{}, Char.is_eq(c, '.')), SCon{c, t}) : String & Maybe<&2, String>}
      %Equal.sym(Bool, Char.is_eq(c, '.'), False{}, e) : {Cookie.split_go("", _, '.', Cookie.split_prefix(c, t, _)) == expected(Spec.last_dot_at(c, t, None{}, _), SCon{c, t}) : String & Maybe<&2, String>}
      {==}

def last_some(+c: Char, +t: String, +v: String, +s: String, +d: Bool) -> {cont((String.reverse(s), Some{String.reverse(v)}), SCon{c, ""}) == expected(Spec.last_dot_at(c, t, Some{Spec.Parts{v, s}}, d), SCon{c, t}) : String & Maybe<&2, String>}:
  %reverse_onto(v, "", SCon{c, ""}) : {(String.reverse(s), Some{String.reverse(v) ++ SCon{c, ""}}) == (String.reverse(s), Some{_}) : String & Maybe<&2, String>}
  {==}

def last_step(+c: Char, +t: String, +m: Maybe<&2, Spec.Parts>) -> {cont(expected(m, t), SCon{c, ""}) == expected(Spec.last_dot_at(c, t, m, Char.is_eq(c, '.')), SCon{c, t}) : String & Maybe<&2, String>}:
  match m:
    case None{}: last_none(c, t, Char.is_eq(c, '.'), {==})
    case Some{Spec.Parts{+v, +s}}: last_some(c, t, v, s, Char.is_eq(c, '.'))

# The implementation's reversed scan is the independent last-dot split.
def split_last(+p: String) -> {Cookie.split(String.reverse(p), '.') == expected(Spec.last_dot(p), p) : String & Maybe<&2, String>}:
  match p:
    case SNil{}: {==}
    case SCon{+c, +t}:
      %reverse_onto(t, "", SCon{c, ""}) : {Cookie.split_go(_, False{}, '.', "") == expected(Spec.last_dot_at(c, t, Spec.last_dot(t), Char.is_eq(c, '.')), SCon{c, t}) : String & Maybe<&2, String>}
      %Equal.sym(String & Maybe<&2, String>, Cookie.split_go(String.reverse(t) ++ SCon{c, ""}, False{}, '.', ""), cont(Cookie.split_go(String.reverse(t), False{}, '.', ""), SCon{c, ""}), split_append(String.reverse(t), SCon{c, ""}, "")) : {_ == expected(Spec.last_dot_at(c, t, Spec.last_dot(t), Char.is_eq(c, '.')), SCon{c, t}) : String & Maybe<&2, String>}
      %Equal.sym(String & Maybe<&2, String>, Cookie.split(String.reverse(t), '.'), expected(Spec.last_dot(t), t), split_last(t)) : {cont(_, SCon{c, ""}) == expected(Spec.last_dot_at(c, t, Spec.last_dot(t), Char.is_eq(c, '.')), SCon{c, t}) : String & Maybe<&2, String>}
      last_step(c, t, Spec.last_dot(t))
