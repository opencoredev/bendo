# The stack-safe URI codec loops equal their recursive specs (BND-84).
# Each `_equiv` lemma is stated spec first, so `%X_equiv(..)` rewrites a
# production term into its spec. The unescape cases split a character bit by
# bit, low bit first, wherever unescape_spec tests for '%' (37): a plain
# `case SCon{Chr{n}, t}` leaves the high bits opaque and the spec stuck.
import Base
import ./encoding.bend as E
import ./utf8-code.bend as Code
import ./reverse-proofs.bend as Rev

def scalars_go_equiv(s: String, ok: Bool) -> {E.scalars_go(s, ok) == ok && E.scalars_spec(s) : Bool}:
  match s ok:
    case SNil{} True{}:
      {==}
    case SNil{} False{}:
      {==}
    case SCon{Chr{+n}, t} True{}:
      scalars_go_equiv(t, E.scalar(n))
    case SCon{Chr{+n}, t} False{}:
      scalars_go_equiv(t, False{})

def scalars_equiv(+s: String) -> {E.scalars_spec(s) == E.scalars(s) : Bool}:
  Equal.sym(Bool, E.scalars(s), E.scalars_spec(s), scalars_go_equiv(s, True{}))

def scalars_cons(+n: U32, +t: String) -> {E.scalar(n) && E.scalars(t) == E.scalars(SCon{Chr{n}, t}) : Bool}:
  %scalars_equiv(t) : {E.scalar(n) && _ == E.scalars(SCon{Chr{n}, t}) : Bool}
  scalars_equiv(SCon{Chr{n}, t})

def encode_go_equiv(s: String, +out: String) -> {E.encode_go(s, out) == String.reverse.go(out, E.encode_spec(s)) : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      Equal.trans(String, E.encode_go(t, String.reverse.go(E.encode_char(n), out)), String.reverse.go(String.reverse.go(E.encode_char(n), out), E.encode_spec(t)), String.reverse.go(out, E.encode_char(n) ++ E.encode_spec(t)), encode_go_equiv(t, String.reverse.go(E.encode_char(n), out)), Rev.string_onto(E.encode_char(n), out, E.encode_spec(t)))

def encode_equiv(+s: String) -> {E.encode_spec(s) == E.encode(s) : String}:
  Equal.sym(String, E.encode(s), E.encode_spec(s), encode_go_equiv(s, ""))

def encode_cons(+n: U32, +t: String) -> {E.encode_char(n) ++ E.encode(t) == E.encode(SCon{Chr{n}, t}) : String}:
  %encode_equiv(t) : {E.encode_char(n) ++ _ == E.encode(SCon{Chr{n}, t}) : String}
  encode_equiv(SCon{Chr{n}, t})

def onto(acc: List<&2, U32>, m: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match m:
    case None{}:
      None{}
    case Some{xs}:
      Some{List.reverse.go(&2, U32, acc, xs)}

def unescape_failed(s: String) -> {E.unescape_go(s, None{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, SCon{Chr{+a}, SCon{Chr{+b}, +t}}}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, SCon{Chr{a}, SNil{}}}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, SNil{}}:
      {==}
    case SCon{Chr{U32{WCon{False{}, +w}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, +w}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{False{}, +w}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, +w}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, +w}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, +w}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, +w}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      unescape_failed(t)

def onto_byte(+b: U32, +acc: List<&2, U32>, m: Maybe<&2, List<&2, U32>>) ->
    {onto(b <> acc, m) == onto(acc, Maybe.bind(&2, List<&2, U32>, List<&2, U32>, m, rest => Some{b <> rest})) : Maybe<&2, List<&2, U32>>}:
  match m:
    case None{}:
      {==}
    case Some{xs}:
      {==}

def onto_bytes(+bs: List<&2, U32>, +acc: List<&2, U32>, m: Maybe<&2, List<&2, U32>>) ->
    {onto(List.reverse.go(&2, U32, bs, acc), m) == onto(acc, Maybe.bind(&2, List<&2, U32>, List<&2, U32>, m, rest => Some{List.append(&2, U32, bs, rest)})) : Maybe<&2, List<&2, U32>>}:
  match m:
    case None{}:
      {==}
    case Some{xs}:
      Equal.cong(List<&2, U32>, Maybe<&2, List<&2, U32>>, ys => Some{ys}, List.reverse.go(&2, U32, List.reverse.go(&2, U32, bs, acc), xs), List.reverse.go(&2, U32, acc, List.append(&2, U32, bs, xs)), Rev.list_onto(U32, bs, acc, xs))

def escape_equiv(hi: Maybe<&2, U32>, lo: Maybe<&2, U32>, +acc: List<&2, U32>, +t: String,
    ih: @c: List<&2, U32> -> {E.unescape_go(t, Some{c}) == onto(c, E.unescape_spec(t)) : Maybe<&2, List<&2, U32>>}) ->
    {E.unescape_go(t, E.push_escape(Some{acc}, hi, lo)) == onto(acc, Maybe.bind(&2, U32, List<&2, U32>, hi, h => Maybe.bind(&2, U32, List<&2, U32>, lo, l => Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape_spec(t), rest => Some{(h * 16 + l : U32) <> rest})))) : Maybe<&2, List<&2, U32>>}:
  match hi lo:
    case Some{+h} Some{+l}:
      Equal.trans(Maybe<&2, List<&2, U32>>, E.unescape_go(t, Some{(h * 16 + l : U32) <> acc}), onto((h * 16 + l : U32) <> acc, E.unescape_spec(t)), onto(acc, Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape_spec(t), rest => Some{(h * 16 + l : U32) <> rest})), ih((h * 16 + l : U32) <> acc), onto_byte((h * 16 + l : U32), acc, E.unescape_spec(t)))
    case Some{h} None{}:
      unescape_failed(t)
    case None{} l:
      unescape_failed(t)

def char_equiv(+n: U32, ok: Bool, +acc: List<&2, U32>, +t: String,
    ih: @c: List<&2, U32> -> {E.unescape_go(t, Some{c}) == onto(c, E.unescape_spec(t)) : Maybe<&2, List<&2, U32>>}) ->
    {E.unescape_go(t, E.push_char(Some{acc}, n, ok)) == onto(acc, E.choose(Maybe<&2, List<&2, U32>>, ok, u => Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape_spec(t), rest => Some{List.append(&2, U32, E.char_bytes(n), rest)}), u => None{})) : Maybe<&2, List<&2, U32>>}:
  match ok:
    case True{}:
      Equal.trans(Maybe<&2, List<&2, U32>>, E.unescape_go(t, Some{List.reverse.go(&2, U32, E.char_bytes(n), acc)}), onto(List.reverse.go(&2, U32, E.char_bytes(n), acc), E.unescape_spec(t)), onto(acc, Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape_spec(t), rest => Some{List.append(&2, U32, E.char_bytes(n), rest)})), ih(List.reverse.go(&2, U32, E.char_bytes(n), acc)), onto_bytes(E.char_bytes(n), acc, E.unescape_spec(t)))
    case False{}:
      unescape_failed(t)

def unescape_go_equiv(s: String, +acc: List<&2, U32>) -> {E.unescape_go(s, Some{acc}) == onto(acc, E.unescape_spec(s)) : Maybe<&2, List<&2, U32>>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, SCon{Chr{+a}, SCon{Chr{+b}, +t}}}:
      escape_equiv(E.hex(a), E.hex(b), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, SCon{Chr{a}, SNil{}}}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, SNil{}}:
      {==}
    case SCon{Chr{U32{WCon{False{}, +w}}}, +t}:
      char_equiv(U32{WCon{False{}, w}}, E.scalar(U32{WCon{False{}, w}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, +w}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{True{}, w}}}, E.scalar(U32{WCon{True{}, WCon{True{}, w}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{False{}, +w}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{False{}, w}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{False{}, w}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, +w}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, w}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, w}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, +w}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, w}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, w}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, +w}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, w}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, w}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, +w}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, w}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, w}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, w}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, w}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, +w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, +t}:
      char_equiv(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, E.scalar(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, w}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}), acc, t, c => unescape_go_equiv(t, c))

def onto_nil(m: Maybe<&2, List<&2, U32>>) -> {onto([], m) == m : Maybe<&2, List<&2, U32>>}:
  match m:
    case None{}:
      {==}
    case Some{xs}:
      {==}

def unescape_equiv(+s: String) -> {E.unescape_spec(s) == E.unescape(s) : Maybe<&2, List<&2, U32>>}:
  Equal.sym(Maybe<&2, List<&2, U32>>, E.unescape(s), E.unescape_spec(s), Equal.trans(Maybe<&2, List<&2, U32>>, E.unescape(s), onto([], E.unescape_spec(s)), E.unescape_spec(s), unescape_go_equiv(s, []), onto_nil(E.unescape_spec(s))))

def decode_bytes_equiv(m: Maybe<&2, List<&2, U32>>) ->
    {Maybe.bind(&2, List<&2, U32>, String, m, bytes => Code.decode_spec(bytes, Code.Start{})) == Maybe.bind(&2, List<&2, U32>, String, m, bytes => Code.decode(bytes, Code.Start{})) : Maybe<&2, String>}:
  match m:
    case None{}:
      {==}
    case Some{+bytes}:
      Code.decode_equiv(bytes, Code.Start{})

def decode_equiv(+s: String) -> {E.decode_spec(s) == E.decode(s) : Maybe<&2, String>}:
  %unescape_equiv(s) : {E.decode_spec(s) == Maybe.bind(&2, List<&2, U32>, String, _, bytes => Code.decode(bytes, Code.Start{})) : Maybe<&2, String>}
  decode_bytes_equiv(E.unescape_spec(s))
