# Framing lookups on canonical fields, separate from wire parsing.
import Base
import ../LAWS.bend as Laws
import ../src/http/bytes.bend as B
import ../src/http/request.bend as R
import ../src/http/response.bend as Response
import ../src/http/write_response.bend as W
import ./tokens.bend as Tokens
import ./response-runtime.bend as Runtime
import ./response-framing-spec.bend as Spec
import ./parse-tail.bend as PT

def key(length: Bool) -> String:
  match length:
    case True{}:
      "content-length"
    case False{}:
      "transfer-encoding"

def retained(+n: String, v: List<&2, U32>, length: Bool, keep: {W.user_header(R.Header{n, v}) == True{} : Bool}) -> {String.eq(n, key(length)) == False{} : Bool}:
  match length:
    case True{}:
      Tokens.or_false_left(String.eq(n, "content-length"), String.eq(n, "transfer-encoding"), Tokens.not_true_false(String.eq(n, "content-length") || String.eq(n, "transfer-encoding"), keep))
    case False{}:
      Tokens.or_false_right(String.eq(n, "content-length"), String.eq(n, "transfer-encoding"), Tokens.not_true_false(String.eq(n, "content-length") || String.eq(n, "transfer-encoding"), keep))

def filtered_step(+h: R.Header, +rest: List<&2, R.Header>, +length: Bool, keep: Bool, eq: {W.user_header(h) == keep : Bool}, absent: {R.lookup_folded_spec(rest, key(length)) == [] : List<&2, List<&2, U32>>}) -> {R.lookup_folded_spec(List.filter.put(R.Header, h, rest, keep), key(length)) == [] : List<&2, List<&2, U32>>}:
  match h keep:
    case R.Header{n, v} False{}:
      absent
    case R.Header{n, v} True{}:
      %Equal.sym(Bool, String.eq(n, key(length)), False{}, retained(n, v, length, eq)) : {R.lookup_step(v, R.lookup_folded_spec(rest, key(length)), _) == [] : List<&2, List<&2, U32>>}
      absent

def filtered_spec(+hs: List<&2, R.Header>, +length: Bool) -> {R.lookup_folded_spec(W.headers(hs), key(length)) == [] : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}:
      {==}
    case h <> t:
      filtered_step(h, W.headers(t), length, W.user_header(h), {==}, filtered_spec(t, length))

# lookup_folded is a tail loop over the reversed fields (BND-84); the
# induction above runs on its spec.
def filtered(+hs: List<&2, R.Header>, +length: Bool) -> {R.lookup_folded(W.headers(hs), key(length)) == [] : List<&2, List<&2, U32>>}:
  Equal.trans(List<&2, List<&2, U32>>, R.lookup_folded(W.headers(hs), key(length)), R.lookup_folded_spec(W.headers(hs), key(length)), [], PT.lookup_equiv(W.headers(hs), key(length)), filtered_spec(hs, length))

# One lookup step at the head field, as the spec's right fold.
def lookup_cons(+n: String, +v: List<&2, U32>, +t: List<&2, R.Header>, +k: String) -> {R.lookup_folded(R.Header{n, v} <> t, k) == R.lookup_step(v, R.lookup_folded(t, k), String.eq(n, k)) : List<&2, List<&2, U32>>}:
  Equal.trans(List<&2, List<&2, U32>>, R.lookup_folded(R.Header{n, v} <> t, k), R.lookup_folded_spec(R.Header{n, v} <> t, k), R.lookup_step(v, R.lookup_folded(t, k), String.eq(n, k)), PT.lookup_equiv(R.Header{n, v} <> t, k), Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => R.lookup_step(v, l, String.eq(n, k)), R.lookup_folded_spec(t, k), R.lookup_folded(t, k), Equal.sym(List<&2, List<&2, U32>>, R.lookup_folded(t, k), R.lookup_folded_spec(t, k), PT.lookup_equiv(t, k))))


def length(+hs: List<&2, R.Header>) -> {R.lookup(W.headers(hs), "content-length") == [] : List<&2, List<&2, U32>>}:
  filtered(hs, True{})

def transfer(+hs: List<&2, R.Header>) -> {R.lookup(W.headers(hs), "transfer-encoding") == [] : List<&2, List<&2, U32>>}:
  filtered(hs, False{})

def added_length(+n: Nat, +hs: List<&2, R.Header>) -> {R.lookup(W.length_header(n) <> W.headers(hs), "content-length") == [B.encode(Nat.show(n))] : List<&2, List<&2, U32>>}:
  +k = B.fold("content-length")
  Equal.trans(List<&2, List<&2, U32>>, R.lookup(W.length_header(n) <> W.headers(hs), "content-length"), R.lookup_step(B.encode(Nat.show(n)), R.lookup_folded(W.headers(hs), k), String.eq("content-length", k)), [B.encode(Nat.show(n))], lookup_cons("content-length", B.encode(Nat.show(n)), W.headers(hs), k), Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => B.encode(Nat.show(n)) <> l, R.lookup(W.headers(hs), "content-length"), [], length(hs)))


def added_transfer(+n: Nat, +hs: List<&2, R.Header>) -> {R.lookup(W.length_header(n) <> W.headers(hs), "transfer-encoding") == [] : List<&2, List<&2, U32>>}:
  +k = B.fold("transfer-encoding")
  Equal.trans(List<&2, List<&2, U32>>, R.lookup(W.length_header(n) <> W.headers(hs), "transfer-encoding"), R.lookup_step(B.encode(Nat.show(n)), R.lookup_folded(W.headers(hs), k), String.eq("content-length", k)), [], lookup_cons("content-length", B.encode(Nat.show(n)), W.headers(hs), k), transfer(hs))



def representation_length(+rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>) -> {R.lookup(W.representation_length(rep, W.headers(hs)), "content-length") == Spec.representation_lengths(rep) : List<&2, List<&2, U32>>}:
  match rep:
    case None{}:
      length(hs)
    case Some{b}:
      %Equal.sym(Nat, Response.length(b), List.length(&2, U32, b), Runtime.length(b)) : {R.lookup(W.length_header(_) <> W.headers(hs), "content-length") == [B.encode(Nat.show(List.length(&2, U32, b)))] : List<&2, List<&2, U32>>}
      added_length(List.length(&2, U32, b), hs)

def representation_transfer(+rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>) -> {R.lookup(W.representation_length(rep, W.headers(hs)), "transfer-encoding") == [] : List<&2, List<&2, U32>>}:
  match rep:
    case None{}:
      transfer(hs)
    case Some{b}:
      added_transfer(Response.length(b), hs)

def reset_length(+b: List<&2, U32>, +hs: List<&2, R.Header>, +reset: Bool) -> {R.lookup(W.reset_headers(b, W.headers(hs), reset), "content-length") == Spec.content_lengths(b, reset) : List<&2, List<&2, U32>>}:
  match reset:
    case True{}:
      added_length(0n, hs)
    case False{}:
      %Equal.sym(Nat, Response.length(b), List.length(&2, U32, b), Runtime.length(b)) : {R.lookup(W.length_header(_) <> W.headers(hs), "content-length") == [B.encode(Nat.show(List.length(&2, U32, b)))] : List<&2, List<&2, U32>>}
      added_length(List.length(&2, U32, b), hs)

def reset_transfer(+b: List<&2, U32>, +hs: List<&2, R.Header>, reset: Bool) -> {R.lookup(W.reset_headers(b, W.headers(hs), reset), "transfer-encoding") == [] : List<&2, List<&2, U32>>}:
  match reset:
    case True{}:
      added_transfer(0n, hs)
    case False{}:
      added_transfer(Response.length(b), hs)

def modified_length(+b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, +reset: Bool, unmodified: Bool) -> {R.lookup(W.modified_headers(b, rep, W.headers(hs), reset, unmodified), "content-length") == Spec.selected_lengths(b, rep, reset, unmodified) : List<&2, List<&2, U32>>}:
  match unmodified:
    case True{}:
      representation_length(rep, hs)
    case False{}:
      reset_length(b, hs, reset)

def modified_transfer(+b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, reset: Bool, unmodified: Bool) -> {R.lookup(W.modified_headers(b, rep, W.headers(hs), reset, unmodified), "transfer-encoding") == [] : List<&2, List<&2, U32>>}:
  match unmodified:
    case True{}:
      representation_transfer(rep, hs)
    case False{}:
      reset_transfer(b, hs, reset)

def framing_length(+s: U32, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, none: Bool) -> {R.lookup(W.framing_headers(s, b, rep, W.headers(hs), none), "content-length") == Spec.permitted_lengths(s, b, rep, none) : List<&2, List<&2, U32>>}:
  match none:
    case True{}:
      length(hs)
    case False{}:
      modified_length(b, rep, hs, U32.is_eq(s, 205), U32.is_eq(s, 304))

def framing_transfer(+s: U32, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, none: Bool) -> {R.lookup(W.framing_headers(s, b, rep, W.headers(hs), none), "transfer-encoding") == [] : List<&2, List<&2, U32>>}:
  match none:
    case True{}:
      transfer(hs)
    case False{}:
      modified_transfer(b, rep, hs, U32.is_eq(s, 205), U32.is_eq(s, 304))

def or_false(+b: Bool) -> {b || False{} == b : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def get_length(+r: Response.Res) -> {R.lookup(W.response_headers(R.Get{}, r), "content-length") == Spec.get_lengths(r) : List<&2, List<&2, U32>>}:
  match r:
    case Response.Res{s, hs, b, rep}:
      %Equal.sym(Bool, W.forbidden(s) || False{}, W.forbidden(s), or_false(W.forbidden(s))) : {R.lookup(W.framing_headers(s, b, rep, W.headers(hs), _), "content-length") == Spec.get_lengths(Response.Res{s, hs, b, rep}) : List<&2, List<&2, U32>>}
      framing_length(s, b, rep, hs, W.forbidden(s))

def response_transfer(+method: R.Method, +r: Response.Res) -> {R.lookup(W.response_headers(method, r), "transfer-encoding") == [] : List<&2, List<&2, U32>>}:
  match r:
    case Response.Res{s, hs, b, rep}:
      framing_transfer(s, b, rep, hs, W.forbidden(s) || W.tunnel(method, s))
