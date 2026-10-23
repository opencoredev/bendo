import Base
import ../src/data/hex.bend as H
import ../src/data/utf8.bend as U
import ../src/crypto/octets.bend as O
import ./utf8.bend as UP
import ./crypto-support.bend as S
import ./crypto-octets.bend as OctetsProof

def alphabet(+w: Word(4n)) -> {H.value(H.symbol(w)) == Some{w} : Maybe<&2, Word(4n)>}:
  match w:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      {==}

def encode_acc(+xs: List<&2, U32>, +rev: String) -> {H.encode_go(xs, rev) == String.reverse.go(rev, H.encode_spec(xs)) : String}:
  match xs:
    case Nil{}:
      {==}
    case U32{+w} <> +t:
      +block = H.byte(U.low(8n, 24n, w))
      %Equal.sym(String, H.encode_go(t, String.reverse(block) ++ rev), String.reverse.go(String.reverse(block) ++ rev, H.encode_spec(t)), encode_acc(t, String.reverse(block) ++ rev)) : {_ == String.reverse.go(rev, block ++ H.encode_spec(t)) : String}
      S.reverse_block(block, rev, H.encode_spec(t))

def byte_pair(+w: Word(8n), +rev: List<&2, U32>) -> {H.pair(H.value(H.symbol(U.high(4n, 4n, w))), H.value(H.symbol(U.low(4n, 4n, w))), Some{rev}) == Some{U32{U.join(8n, 24n, w, Word.zero(24n))} <> rev} : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(4n)>, H.value(H.symbol(U.high(4n, 4n, w))), Some{U.high(4n, 4n, w)}, alphabet(U.high(4n, 4n, w))) : {H.pair(_, H.value(H.symbol(U.low(4n, 4n, w))), Some{rev}) == Some{U32{U.join(8n, 24n, w, Word.zero(24n))} <> rev} : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(4n)>, H.value(H.symbol(U.low(4n, 4n, w))), Some{U.low(4n, 4n, w)}, alphabet(U.low(4n, 4n, w))) : {H.pair(Some{U.high(4n, 4n, w)}, _, Some{rev}) == Some{U32{U.join(8n, 24n, w, Word.zero(24n))} <> rev} : Maybe<&2, List<&2, U32>>}
  Equal.cong(Word(8n), Maybe<&2, List<&2, U32>>, x => Some{U32{U.join(8n, 24n, x, Word.zero(24n))} <> rev}, U.join(4n, 4n, U.low(4n, 4n, w), U.high(4n, 4n, w)), w, UP.join_split(4n, 4n, w))

def byte_step(+w: Word(32n), +tail: String, +rev: List<&2, U32>, ok: {(U32{w} <= 255 : U32) == True{} : Bool}) -> {H.decode_go(H.byte(U.low(8n, 24n, w)) ++ tail, Some{rev}) == H.decode_go(tail, Some{U32{w} <> rev}) : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, List<&2, U32>>, H.pair(H.value(H.symbol(U.high(4n, 4n, U.low(8n, 24n, w)))), H.value(H.symbol(U.low(4n, 4n, U.low(8n, 24n, w)))), Some{rev}), Some{U32{U.join(8n, 24n, U.low(8n, 24n, w), Word.zero(24n))} <> rev}, byte_pair(U.low(8n, 24n, w), rev)) : {H.decode_go(tail, _) == H.decode_go(tail, Some{U32{w} <> rev}) : Maybe<&2, List<&2, U32>>}
  Equal.cong(U32, Maybe<&2, List<&2, U32>>, x => H.decode_go(tail, Some{x <> rev}), U32{U.join(8n, 24n, U.low(8n, 24n, w), Word.zero(24n))}, U32{w}, S.byte_reconstruct(w, ok))

def roundtrip_go(+xs: List<&2, U32>, +rev: List<&2, U32>, +ok: {OctetsProof.spec(xs) == True{} : Bool}) -> {H.decode_go(H.encode_spec(xs), Some{rev}) == Some{List.reverse.go(&2, U32, rev, xs)} : Maybe<&2, List<&2, U32>>}:
  match xs:
    case Nil{}:
      {==}
    case U32{+w} <> +t:
      head = UP.and_left((U32{w} <= 255 : U32), OctetsProof.spec(t), ok)
      tail = UP.and_right((U32{w} <= 255 : U32), OctetsProof.spec(t), ok)
      %Equal.sym(Maybe<&2, List<&2, U32>>, H.decode_go(H.byte(U.low(8n, 24n, w)) ++ H.encode_spec(t), Some{rev}), H.decode_go(H.encode_spec(t), Some{U32{w} <> rev}), byte_step(w, H.encode_spec(t), rev, head)) : {_ == Some{List.reverse.go(&2, U32, rev, U32{w} <> t)} : Maybe<&2, List<&2, U32>>}
      roundtrip_go(t, U32{w} <> rev, tail)

def roundtrip(+xs: List<&2, U32>, ok: {O.valid(xs) == True{} : Bool}) -> {H.decode(H.encode(xs)) == Some{xs} : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(String, H.encode(xs), H.encode_spec(xs), encode_acc(xs, "")) : {H.decode(_) == Some{xs} : Maybe<&2, List<&2, U32>>}
  roundtrip_go(xs, [], OctetsProof.valid(xs, ok))
