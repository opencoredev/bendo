import Base
import ../src/data/schema.bend as S
import ../src/data/json.bend as J
import ../src/data/decimal.bend as D
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-text.bend as TP
import ./schema-number.bend as NP
import ./schema-format.bend as FP
import ./schema-pattern.bend as PP
import ./schema-pattern-automaton.bend as AP
import ./utf8.bend as UP

def finish_accept(v: S.Value, c: Bool) -> {S.accepted(S.finish(v, c)) == c : Bool}:
  match c:
    case True{}: {==}
    case False{}: {==}

def finish_preserves(+v: S.Value, c: Bool) -> S.Preserves(Some{v}, S.finish(v, c)):
  match c:
    case True{}: {==}
    case False{}: Unit{}

def scalar_preserves(+s: S.Schema, +v: J.Json) -> S.Preserves(S.value_for(s, v), S.decode_scalar(s, v)):
  match s v:
    case S.StringSchema{a, b, c, d} J.JString{x}: finish_preserves(S.VString{x}, S.string_check(a, b, c, d, x))
    case S.NumberSchema{a, b} J.JNumber{x}: finish_preserves(S.VNumber{x}, S.number_check(a, b, x))
    case S.IntegerSchema{a, b} J.JNumber{x}: finish_preserves(S.VInteger{x}, D.is_integer(x) && S.number_check(a, b, x))
    case S.BooleanSchema{} J.JBool{x}: {==}
    case S.LiteralSchema{x} y: finish_preserves(S.VLiteral{y}, S.scalar(y) && S.same(x, y))
    case S.EnumSchema{xs} y: finish_preserves(S.VLiteral{y}, S.scalar(y) && S.one_of(xs, y, False{}))
    case S.StringSchema{a, b, c, d} J.JNull{}: Unit{}
    case S.StringSchema{a, b, c, d} J.JBool{x}: Unit{}
    case S.StringSchema{a, b, c, d} J.JNumber{x}: Unit{}
    case S.StringSchema{a, b, c, d} J.JArray{xs}: Unit{}
    case S.StringSchema{a, b, c, d} J.JObject{fs}: Unit{}
    case S.NumberSchema{a, b} J.JNull{}: Unit{}
    case S.NumberSchema{a, b} J.JBool{x}: Unit{}
    case S.NumberSchema{a, b} J.JString{x}: Unit{}
    case S.NumberSchema{a, b} J.JArray{xs}: Unit{}
    case S.NumberSchema{a, b} J.JObject{fs}: Unit{}
    case S.IntegerSchema{a, b} J.JNull{}: Unit{}
    case S.IntegerSchema{a, b} J.JBool{x}: Unit{}
    case S.IntegerSchema{a, b} J.JString{x}: Unit{}
    case S.IntegerSchema{a, b} J.JArray{xs}: Unit{}
    case S.IntegerSchema{a, b} J.JObject{fs}: Unit{}
    case S.BooleanSchema{} J.JNull{}: Unit{}
    case S.BooleanSchema{} J.JNumber{x}: Unit{}
    case S.BooleanSchema{} J.JString{x}: Unit{}
    case S.BooleanSchema{} J.JArray{xs}: Unit{}
    case S.BooleanSchema{} J.JObject{fs}: Unit{}

def preservation(+s: S.Schema, +v: J.Json, c: Bool) -> S.Preserves(S.value_for(s, v), S.decode_valid(s, v, c)):
  match c:
    case True{}: scalar_preserves(s, v)
    case False{}: Unit{}

# BND-33 acceptance against the independent specification.

def and_eq(-a: Bool, -a2: Bool, -b: Bool, -b2: Bool, ea: {a == a2 : Bool}, eb: {b == b2 : Bool}) -> {(a && b) == (a2 && b2) : Bool}:
  %ea : {(a && b) == (_ && b2) : Bool}
  %eb : {(a && b) == (a && _) : Bool}
  {==}

def and_true(+a: Bool) -> {a == (a && True{}) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def and_assoc(+a: Bool, -b: Bool, -c: Bool) -> {((a && b) && c) == (a && (b && c)) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_false(+a: Bool) -> {a == (a || False{}) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_assoc(+a: Bool, -b: Bool, -c: Bool) -> {((a || b) || c) == (a || (b || c)) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def max_equiv(+m: Maybe<&2, Nat>, -n: Nat) -> {S.max_length(m, n) == Spec.at_most(m, n) : Bool}:
  match m:
    case None{}: {==}
    case Some{k}: {==}

def optional_pattern_equiv(+p: Maybe<&2, P.Pattern>) -> {S.optional_pattern_valid(p) == Spec.optional_pattern_ok(p) : Bool}:
  match p:
    case None{}: {==}
    case Some{q}: PP.valid_equiv(q)

def pattern_equiv(+p: Maybe<&2, P.Pattern>, +x: String) -> {S.pattern_check(p, x) == Spec.pattern(p, x) : Bool}:
  match p:
    case None{}: {==}
    case Some{q}: AP.matches_equiv(q, x)

def format_equiv(+f: S.Format, +x: String) -> {S.format_check(f, x) == Spec.format(f, x) : Bool}:
  match f:
    case S.Plain{}: {==}
    case S.Email{}: FP.email_equiv(x)
    case S.Url{}: FP.url_equiv(x)

def bound_equiv(+b: Maybe<&2, String>) -> {S.bound_valid(b) == Spec.bound(b) : Bool}:
  match b:
    case None{}: {==}
    case Some{x}: NP.number_equiv(x)

def order_bounds(+min: Maybe<&2, String>, +max: Maybe<&2, String>, vmin: {S.bound_valid(min) == True{} : Bool}, vmax: {S.bound_valid(max) == True{} : Bool}) -> {S.bounds_order(min, max) == Spec.ordered(min, max) : Bool}:
  match min max:
    case Some{a} Some{b}: Equal.cong(Cmp, Bool, o => Cmp.is_le(o), D.order(a, b), Spec.order(a, b), NP.order_equiv(a, b, vmin, vmax))
    case None{} None{}: {==}
    case None{} Some{b}: {==}
    case Some{a} None{}: {==}

def bounds_go(+min: Maybe<&2, String>, +max: Maybe<&2, String>, c: Bool, d: Bool) -> {S.bound_valid(min) == c : Bool} -> {S.bound_valid(max) == d : Bool} -> {(c && d && S.bounds_order(min, max)) == (c && d && Spec.ordered(min, max)) : Bool}:
  match c d:
    case True{} True{}: e => f => order_bounds(min, max, e, f)
    case True{} False{}: e => f => {==}
    case False{} True{}: e => f => {==}
    case False{} False{}: e => f => {==}

def bounds_equiv(+min: Maybe<&2, String>, +max: Maybe<&2, String>) -> {S.bounds_valid(min, max) == (Spec.bound(min) && Spec.bound(max) && Spec.ordered(min, max)) : Bool}:
  %bound_equiv(min) : {S.bounds_valid(min, max) == (_ && Spec.bound(max) && Spec.ordered(min, max)) : Bool}
  %bound_equiv(max) : {S.bounds_valid(min, max) == (S.bound_valid(min) && _ && Spec.ordered(min, max)) : Bool}
  bounds_go(min, max, S.bound_valid(min), S.bound_valid(max))({==})({==})

def scalar_equiv(+v: J.Json) -> {S.scalar(v) == Spec.literal_value(v) : Bool}:
  match v:
    case J.JNull{}: {==}
    case J.JBool{b}: {==}
    case J.JString{x}: TP.scalars_equiv(x)
    case J.JNumber{x}: NP.number_equiv(x)
    case J.JArray{xs}: {==}
    case J.JObject{fs}: {==}

def literals_go(+xs: List<&2, J.Json>, +ok: Bool) -> {S.literals_valid(xs, ok) == (ok && Spec.literal_values(xs)) : Bool}:
  match xs:
    case Nil{}: and_true(ok)
    case h <> t:
      %and_assoc(ok, Spec.literal_value(h), Spec.literal_values(t)) : {S.literals_valid(h <> t, ok) == _ : Bool}
      %scalar_equiv(h) : {S.literals_valid(h <> t, ok) == ((ok && _) && Spec.literal_values(t)) : Bool}
      literals_go(t, ok && S.scalar(h))

def valid_equiv(+s: S.Schema) -> {S.valid(s) == Spec.schema_ok(s) : Bool}:
  match s:
    case S.StringSchema{min, max, p, f}: and_eq(S.max_length(max, min), Spec.at_most(max, min), S.optional_pattern_valid(p), Spec.optional_pattern_ok(p), max_equiv(max, min), optional_pattern_equiv(p))
    case S.NumberSchema{min, max}: bounds_equiv(min, max)
    case S.IntegerSchema{min, max}: bounds_equiv(min, max)
    case S.BooleanSchema{}: {==}
    case S.LiteralSchema{v}: scalar_equiv(v)
    case S.EnumSchema{xs}: literals_go(xs, True{})

def format_after_and(+ok: Bool, +f: S.Format, +x: String) -> {S.format_after(ok, f, x) == (ok && S.format_check(f, x)) : Bool}:
  match ok:
    case True{}: {==}
    case False{}: {==}

def pattern_after_and(+ok: Bool, +p: Maybe<&2, P.Pattern>, +f: S.Format, +x: String) -> {S.pattern_after(ok, p, f, x) == ((ok && S.pattern_check(p, x)) && S.format_check(f, x)) : Bool}:
  match ok:
    case True{}: format_after_and(S.pattern_check(p, x), f, x)
    case False{}: {==}

def string_equiv(+min: Nat, +max: Maybe<&2, Nat>, +p: Maybe<&2, P.Pattern>, +f: S.Format, +x: String) -> {S.string_check(min, max, p, f, x) == (Spec.scalars(x) && Nat.is_le(min, Spec.length(x)) && Spec.at_most(max, Spec.length(x)) && Spec.pattern(p, x) && Spec.format(f, x)) : Bool}:
  %TP.scalars_equiv(x) : {S.string_check(min, max, p, f, x) == (_ && Nat.is_le(min, Spec.length(x)) && Spec.at_most(max, Spec.length(x)) && Spec.pattern(p, x) && Spec.format(f, x)) : Bool}
  %TP.length_equiv(x) : {S.string_check(min, max, p, f, x) == (J.scalars(x) && Nat.is_le(min, _) && Spec.at_most(max, _) && Spec.pattern(p, x) && Spec.format(f, x)) : Bool}
  %max_equiv(max, D.length(x)) : {S.string_check(min, max, p, f, x) == (J.scalars(x) && Nat.is_le(min, D.length(x)) && _ && Spec.pattern(p, x) && Spec.format(f, x)) : Bool}
  %pattern_equiv(p, x) : {S.string_check(min, max, p, f, x) == (J.scalars(x) && Nat.is_le(min, D.length(x)) && S.max_length(max, D.length(x)) && _ && Spec.format(f, x)) : Bool}
  %format_equiv(f, x) : {S.string_check(min, max, p, f, x) == (J.scalars(x) && Nat.is_le(min, D.length(x)) && S.max_length(max, D.length(x)) && S.pattern_check(p, x) && _) : Bool}
  pattern_after_and(J.scalars(x) && Nat.is_le(min, D.length(x)) && S.max_length(max, D.length(x)), p, f, x)

def lower_equiv(+b: Maybe<&2, String>, +x: String, vb: {S.bound_valid(b) == True{} : Bool}, vx: {J.number_valid(x) == True{} : Bool}) -> {S.lower(b, x) == Spec.at_least_number(b, x) : Bool}:
  match b:
    case None{}: {==}
    case Some{m}: Equal.cong(Cmp, Bool, o => Cmp.is_ge(o), D.order(x, m), Spec.order(x, m), NP.order_equiv(x, m, vx, vb))

def upper_equiv(+b: Maybe<&2, String>, +x: String, vb: {S.bound_valid(b) == True{} : Bool}, vx: {J.number_valid(x) == True{} : Bool}) -> {S.upper(b, x) == Spec.at_most_number(b, x) : Bool}:
  match b:
    case None{}: {==}
    case Some{m}: Equal.cong(Cmp, Bool, o => Cmp.is_le(o), D.order(x, m), Spec.order(x, m), NP.order_equiv(x, m, vx, vb))

def number_go(+min: Maybe<&2, String>, +max: Maybe<&2, String>, +x: String, vmin: {S.bound_valid(min) == True{} : Bool}, vmax: {S.bound_valid(max) == True{} : Bool}, c: Bool) -> {J.number_valid(x) == c : Bool} -> {(c && S.lower(min, x) && S.upper(max, x)) == (c && Spec.at_least_number(min, x) && Spec.at_most_number(max, x)) : Bool}:
  match c:
    case False{}: e => {==}
    case True{}: +e => and_eq(S.lower(min, x), Spec.at_least_number(min, x), S.upper(max, x), Spec.at_most_number(max, x), lower_equiv(min, x, vmin, e), upper_equiv(max, x, vmax, e))

def number_check_equiv(+min: Maybe<&2, String>, +max: Maybe<&2, String>, +x: String, vmin: {S.bound_valid(min) == True{} : Bool}, vmax: {S.bound_valid(max) == True{} : Bool}) -> {S.number_check(min, max, x) == (Spec.number(x) && Spec.at_least_number(min, x) && Spec.at_most_number(max, x)) : Bool}:
  %NP.number_equiv(x) : {S.number_check(min, max, x) == (_ && Spec.at_least_number(min, x) && Spec.at_most_number(max, x)) : Bool}
  number_go(min, max, x, vmin, vmax, J.number_valid(x))({==})

def integer_go(+min: Maybe<&2, String>, +max: Maybe<&2, String>, +x: String, vmin: {S.bound_valid(min) == True{} : Bool}, vmax: {S.bound_valid(max) == True{} : Bool}, c: Bool) -> {D.is_integer(x) == c : Bool} -> {(c && S.number_check(min, max, x)) == (c && Spec.at_least_number(min, x) && Spec.at_most_number(max, x)) : Bool}:
  match c:
    case False{}: e => {==}
    case True{}: +e =>
      %Equal.sym(Bool, J.number_valid(x), True{}, NP.integer_number(x, e)) : {(_ && S.lower(min, x) && S.upper(max, x)) == (Spec.at_least_number(min, x) && Spec.at_most_number(max, x)) : Bool}
      number_go(min, max, x, vmin, vmax, True{})(NP.integer_number(x, e))

def integer_check_equiv(+min: Maybe<&2, String>, +max: Maybe<&2, String>, +x: String, vmin: {S.bound_valid(min) == True{} : Bool}, vmax: {S.bound_valid(max) == True{} : Bool}) -> {(D.is_integer(x) && S.number_check(min, max, x)) == (Spec.integer(x) && Spec.at_least_number(min, x) && Spec.at_most_number(max, x)) : Bool}:
  %NP.integer_equiv(x) : {(D.is_integer(x) && S.number_check(min, max, x)) == (_ && Spec.at_least_number(min, x) && Spec.at_most_number(max, x)) : Bool}
  integer_go(min, max, x, vmin, vmax, D.is_integer(x))({==})

def same_equiv(+a: J.Json, +b: J.Json, +va: {S.scalar(a) == True{} : Bool}, +vb: {S.scalar(b) == True{} : Bool}) -> {S.same(a, b) == Spec.equal(a, b) : Bool}:
  match a b:
    case J.JNull{} J.JNull{}: {==}
    case J.JNull{} J.JBool{True{}}: {==}
    case J.JNull{} J.JBool{False{}}: {==}
    case J.JNull{} J.JNumber{y}: {==}
    case J.JNull{} J.JString{y}: {==}
    case J.JNull{} J.JArray{ys}: {==}
    case J.JNull{} J.JObject{gs}: {==}
    case J.JBool{True{}} J.JNull{}: {==}
    case J.JBool{True{}} J.JBool{True{}}: {==}
    case J.JBool{True{}} J.JBool{False{}}: {==}
    case J.JBool{True{}} J.JNumber{y}: {==}
    case J.JBool{True{}} J.JString{y}: {==}
    case J.JBool{True{}} J.JArray{ys}: {==}
    case J.JBool{True{}} J.JObject{gs}: {==}
    case J.JBool{False{}} J.JNull{}: {==}
    case J.JBool{False{}} J.JBool{True{}}: {==}
    case J.JBool{False{}} J.JBool{False{}}: {==}
    case J.JBool{False{}} J.JNumber{y}: {==}
    case J.JBool{False{}} J.JString{y}: {==}
    case J.JBool{False{}} J.JArray{ys}: {==}
    case J.JBool{False{}} J.JObject{gs}: {==}
    case J.JNumber{x} J.JNull{}: {==}
    case J.JNumber{x} J.JBool{True{}}: {==}
    case J.JNumber{x} J.JBool{False{}}: {==}
    case J.JNumber{x} J.JNumber{y}: Equal.cong(Cmp, Bool, o => Cmp.is_eq(o), D.order(x, y), Spec.order(x, y), NP.order_equiv(x, y, va, vb))
    case J.JNumber{x} J.JString{y}: {==}
    case J.JNumber{x} J.JArray{ys}: {==}
    case J.JNumber{x} J.JObject{gs}: {==}
    case J.JString{x} J.JNull{}: {==}
    case J.JString{x} J.JBool{True{}}: {==}
    case J.JString{x} J.JBool{False{}}: {==}
    case J.JString{x} J.JNumber{y}: {==}
    case J.JString{x} J.JString{y}: {==}
    case J.JString{x} J.JArray{ys}: {==}
    case J.JString{x} J.JObject{gs}: {==}
    case J.JArray{xs} J.JNull{}: {==}
    case J.JArray{xs} J.JBool{True{}}: {==}
    case J.JArray{xs} J.JBool{False{}}: {==}
    case J.JArray{xs} J.JNumber{y}: {==}
    case J.JArray{xs} J.JString{y}: {==}
    case J.JArray{xs} J.JArray{ys}: {==}
    case J.JArray{xs} J.JObject{gs}: {==}
    case J.JObject{fs} J.JNull{}: {==}
    case J.JObject{fs} J.JBool{True{}}: {==}
    case J.JObject{fs} J.JBool{False{}}: {==}
    case J.JObject{fs} J.JNumber{y}: {==}
    case J.JObject{fs} J.JString{y}: {==}
    case J.JObject{fs} J.JArray{ys}: {==}
    case J.JObject{fs} J.JObject{gs}: {==}

def literal_go(+x: J.Json, +y: J.Json, vx: {S.scalar(x) == True{} : Bool}, c: Bool) -> {S.scalar(y) == c : Bool} -> {(c && S.same(x, y)) == (c && Spec.equal(x, y)) : Bool}:
  match c:
    case False{}: e => {==}
    case True{}: e => same_equiv(x, y, vx, e)

def literal_equiv(+x: J.Json, +y: J.Json, vx: {S.scalar(x) == True{} : Bool}) -> {(S.scalar(y) && S.same(x, y)) == (Spec.literal_value(y) && Spec.equal(x, y)) : Bool}:
  %scalar_equiv(y) : {(S.scalar(y) && S.same(x, y)) == (_ && Spec.equal(x, y)) : Bool}
  literal_go(x, y, vx, S.scalar(y))({==})

def valid_scalar(+h: J.Json, e: {Spec.literal_value(h) == True{} : Bool}) -> {S.scalar(h) == True{} : Bool}:
  Equal.trans(Bool, S.scalar(h), Spec.literal_value(h), True{}, scalar_equiv(h), e)

def one_of_equiv(+xs: List<&2, J.Json>, +v: J.Json, +found: Bool, +vxs: {Spec.literal_values(xs) == True{} : Bool}, +vv: {S.scalar(v) == True{} : Bool}) -> {S.one_of(xs, v, found) == (found || Spec.any_equal(xs, v)) : Bool}:
  match xs:
    case Nil{}: or_false(found)
    case h <> t:
      %or_assoc(found, Spec.equal(h, v), Spec.any_equal(t, v)) : {S.one_of(h <> t, v, found) == _ : Bool}
      %same_equiv(h, v, valid_scalar(h, UP.and_left(Spec.literal_value(h), Spec.literal_values(t), vxs)), vv) : {S.one_of(h <> t, v, found) == ((found || _) || Spec.any_equal(t, v)) : Bool}
      one_of_equiv(t, v, found || S.same(h, v), UP.and_right(Spec.literal_value(h), Spec.literal_values(t), vxs), vv)

def enum_go(+xs: List<&2, J.Json>, +y: J.Json, vxs: {Spec.literal_values(xs) == True{} : Bool}, c: Bool) -> {S.scalar(y) == c : Bool} -> {(c && S.one_of(xs, y, False{})) == (c && Spec.any_equal(xs, y)) : Bool}:
  match c:
    case False{}: e => {==}
    case True{}: e => one_of_equiv(xs, y, False{}, vxs, e)

def enum_equiv(+xs: List<&2, J.Json>, +y: J.Json, vxs: {Spec.literal_values(xs) == True{} : Bool}) -> {(S.scalar(y) && S.one_of(xs, y, False{})) == (Spec.literal_value(y) && Spec.any_equal(xs, y)) : Bool}:
  %scalar_equiv(y) : {(S.scalar(y) && S.one_of(xs, y, False{})) == (_ && Spec.any_equal(xs, y)) : Bool}
  enum_go(xs, y, vxs, S.scalar(y))({==})

def accept_finish(v: S.Value, c: Bool, -d: Bool, e: {c == d : Bool}) -> {S.accepted(S.finish(v, c)) == d : Bool}:
  Equal.trans(Bool, S.accepted(S.finish(v, c)), c, d, finish_accept(v, c), e)

def accepts_equiv(+s: S.Schema, +v: J.Json, +ok: {S.valid(s) == True{} : Bool}) -> {S.accepted(S.decode_scalar(s, v)) == Spec.accepts(s, v) : Bool}:
  match s v:
    case S.StringSchema{a, b, c, d} J.JString{x}: accept_finish(S.VString{x}, S.string_check(a, b, c, d, x), Spec.accepts(S.StringSchema{a, b, c, d}, J.JString{x}), string_equiv(a, b, c, d, x))
    case S.NumberSchema{a, b} J.JNumber{x}: accept_finish(S.VNumber{x}, S.number_check(a, b, x), Spec.accepts(S.NumberSchema{a, b}, J.JNumber{x}), number_check_equiv(a, b, x, UP.and_left(S.bound_valid(a), S.bound_valid(b), UP.and_left(S.bound_valid(a) && S.bound_valid(b), S.bounds_order(a, b), ok)), UP.and_right(S.bound_valid(a), S.bound_valid(b), UP.and_left(S.bound_valid(a) && S.bound_valid(b), S.bounds_order(a, b), ok))))
    case S.IntegerSchema{a, b} J.JNumber{x}: accept_finish(S.VInteger{x}, D.is_integer(x) && S.number_check(a, b, x), Spec.accepts(S.IntegerSchema{a, b}, J.JNumber{x}), integer_check_equiv(a, b, x, UP.and_left(S.bound_valid(a), S.bound_valid(b), UP.and_left(S.bound_valid(a) && S.bound_valid(b), S.bounds_order(a, b), ok)), UP.and_right(S.bound_valid(a), S.bound_valid(b), UP.and_left(S.bound_valid(a) && S.bound_valid(b), S.bounds_order(a, b), ok))))
    case S.BooleanSchema{} J.JBool{x}: {==}
    case S.LiteralSchema{x} y: accept_finish(S.VLiteral{y}, S.scalar(y) && S.same(x, y), Spec.accepts(S.LiteralSchema{x}, y), literal_equiv(x, y, ok))
    case S.EnumSchema{xs} y: accept_finish(S.VLiteral{y}, S.scalar(y) && S.one_of(xs, y, False{}), Spec.accepts(S.EnumSchema{xs}, y), enum_equiv(xs, y, Equal.trans(Bool, Spec.literal_values(xs), S.literals_valid(xs, True{}), True{}, Equal.sym(Bool, S.literals_valid(xs, True{}), Spec.literal_values(xs), literals_go(xs, True{})), ok)))
    case S.StringSchema{a, b, c, d} J.JNull{}: {==}
    case S.StringSchema{a, b, c, d} J.JBool{x}: {==}
    case S.StringSchema{a, b, c, d} J.JNumber{x}: {==}
    case S.StringSchema{a, b, c, d} J.JArray{xs}: {==}
    case S.StringSchema{a, b, c, d} J.JObject{fs}: {==}
    case S.NumberSchema{a, b} J.JNull{}: {==}
    case S.NumberSchema{a, b} J.JBool{x}: {==}
    case S.NumberSchema{a, b} J.JString{x}: {==}
    case S.NumberSchema{a, b} J.JArray{xs}: {==}
    case S.NumberSchema{a, b} J.JObject{fs}: {==}
    case S.IntegerSchema{a, b} J.JNull{}: {==}
    case S.IntegerSchema{a, b} J.JBool{x}: {==}
    case S.IntegerSchema{a, b} J.JString{x}: {==}
    case S.IntegerSchema{a, b} J.JArray{xs}: {==}
    case S.IntegerSchema{a, b} J.JObject{fs}: {==}
    case S.BooleanSchema{} J.JNull{}: {==}
    case S.BooleanSchema{} J.JNumber{x}: {==}
    case S.BooleanSchema{} J.JString{x}: {==}
    case S.BooleanSchema{} J.JArray{xs}: {==}
    case S.BooleanSchema{} J.JObject{fs}: {==}

def spec_go(+s: S.Schema, +v: J.Json, c: Bool) -> {S.valid(s) == c : Bool} -> {S.accepted(S.decode_valid(s, v, c)) == (c && Spec.accepts(s, v)) : Bool}:
  match c:
    case False{}: e => {==}
    case True{}: e => accepts_equiv(s, v, e)

def acceptance_spec(+s: S.Schema, +v: J.Json) -> {S.accepted(S.decode(s, v)) == Spec.satisfies(s, v) : Bool}:
  %valid_equiv(s) : {S.accepted(S.decode(s, v)) == (_ && Spec.accepts(s, v)) : Bool}
  spec_go(s, v, S.valid(s))({==})
