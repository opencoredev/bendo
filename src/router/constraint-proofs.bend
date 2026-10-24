# The stack-safe constraint loops equal their recursive specs (BND-84).
# Each `_equiv` lemma is stated spec first, so `%X_equiv(..)` rewrites a
# production term into its spec.
import Base
import ./encoding.bend as E
import ./constraint.bend as C

def digits_go_equiv(s: String, ok: Bool) -> {C.digits_go(s, ok) == ok && C.digits_spec(s) : Bool}:
  match s ok:
    case SNil{} True{}:
      {==}
    case SNil{} False{}:
      {==}
    case SCon{Chr{+n}, t} True{}:
      digits_go_equiv(t, C.digit(n))
    case SCon{Chr{+n}, t} False{}:
      digits_go_equiv(t, False{})

def digits_equiv(+s: String) -> {C.digits_spec(s) == C.digits(s) : Bool}:
  Equal.sym(Bool, C.digits(s), C.digits_spec(s), digits_go_equiv(s, True{}))

def slug_go_equiv(s: String, ok: Bool) -> {C.slug_go(s, ok) == ok && C.slug_spec(s) : Bool}:
  match s ok:
    case SNil{} True{}:
      {==}
    case SNil{} False{}:
      {==}
    case SCon{Chr{+n}, t} True{}:
      slug_go_equiv(t, C.slug_char(n))
    case SCon{Chr{+n}, t} False{}:
      slug_go_equiv(t, False{})

def slug_equiv(+s: String) -> {C.slug_spec(s) == C.slug(s) : Bool}:
  Equal.sym(Bool, C.slug(s), C.slug_spec(s), slug_go_equiv(s, True{}))

def class_chars_go_equiv(s: String, +ranges: List<&2, C.Range>, ok: Bool) -> {C.class_chars_go(s, ranges, ok) == ok && C.class_chars_spec(s, ranges) : Bool}:
  match s ok:
    case SNil{} True{}:
      {==}
    case SNil{} False{}:
      {==}
    case SCon{Chr{+n}, t} True{}:
      class_chars_go_equiv(t, ranges, C.member(ranges, n))
    case SCon{Chr{+n}, t} False{}:
      class_chars_go_equiv(t, ranges, False{})

def class_chars_equiv(+s: String, +ranges: List<&2, C.Range>) -> {C.class_chars_spec(s, ranges) == C.class_chars(s, ranges) : Bool}:
  Equal.sym(Bool, C.class_chars(s, ranges), C.class_chars_spec(s, ranges), class_chars_go_equiv(s, ranges, True{}))

def uuid_step(+n: U32, dash: Bool, +rest: Bool) ->
    {E.choose(Bool, dash, u => U32.is_eq(n, 45) && rest, u => C.hex(n) && rest) == C.uuid_char(n, dash) && rest : Bool}:
  match dash:
    case True{}:
      {==}
    case False{}:
      {==}

def uuid_go_equiv(s: String, +pos: Nat, ok: Bool) -> {C.uuid_go(s, pos, ok) == ok && C.uuid_spec(s, pos) : Bool}:
  match s ok:
    case SNil{} True{}:
      {==}
    case SNil{} False{}:
      {==}
    case SCon{Chr{+n}, +t} True{}:
      Equal.trans(Bool, C.uuid_go(t, 1n+pos, C.uuid_char(n, C.dash_at(pos))), C.uuid_char(n, C.dash_at(pos)) && C.uuid_spec(t, 1n+pos), C.uuid_spec(SCon{Chr{n}, t}, pos), uuid_go_equiv(t, 1n+pos, C.uuid_char(n, C.dash_at(pos))), Equal.sym(Bool, C.uuid_spec(SCon{Chr{n}, t}, pos), C.uuid_char(n, C.dash_at(pos)) && C.uuid_spec(t, 1n+pos), uuid_step(n, C.dash_at(pos), C.uuid_spec(t, 1n+pos))))
    case SCon{Chr{+n}, t} False{}:
      uuid_go_equiv(t, 1n+pos, False{})

def uuid_equiv(+s: String, +pos: Nat) -> {C.uuid_spec(s, pos) == C.uuid(s, pos) : Bool}:
  Equal.sym(Bool, C.uuid(s, pos), C.uuid_spec(s, pos), uuid_go_equiv(s, pos, True{}))
