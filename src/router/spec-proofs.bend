# Independent indexed specification and constructive first-match proofs.
import Base
import ./spec.bend as R
import ./pattern.bend as P
import ./proofs.bend as Core

type AtMatch<-T: Data> is Data:
  At{tag: T, params: P.Params}

# Neither indexed lookup nor the first-match predicate calls the router.
def entry_match(-T: Data, tag: T, hit: Maybe<&2, P.Params>) -> Maybe<&2, AtMatch<T>>:
  match hit:
    case None{}:
      None{}
    case Some{ps}:
      Some{At{tag, ps}}

def lookup_match(-T: Data, entry: Maybe<&2, R.Route<T>>, path: String) -> Maybe<&2, AtMatch<T>>:
  match entry:
    case None{}:
      None{}
    case Some{R.Route{pattern, tag}}:
      entry_match(T, tag, P.match_path(pattern, path))

def match_at(-T: Data, table: R.Table(T), path: String, i: Nat) -> Maybe<&2, AtMatch<T>>:
  lookup_match(T, List.get(&2, R.Route<T>, table, i), path)

def NoEarlier(-T: Data, +table: R.Table(T), +path: String, +i: Nat) -> Type:
  @j: Nat -> {Nat.is_lt(j, i) == True{} : Bool} ->
    {match_at(T, table, path, j) == None{} : Maybe<&2, AtMatch<T>>}

def First(-T: Data, +table: R.Table(T), +path: String, +i: Nat, +tag: T, +ps: P.Params) -> Type:
  {match_at(T, table, path, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>} & NoEarlier(T, table, path, i)

def Outcome(-T: Data, +table: R.Table(T), +path: String, hit: Maybe<&2, R.Match<T>>) -> Type:
  match hit:
    case None{}:
      @i: Nat -> {match_at(T, table, path, i) == None{} : Maybe<&2, AtMatch<T>>}
    case Some{R.Match{i, tag, ps}}:
      First(T, table, path, i, tag, ps)

def index(-T: Data, hit: R.Match<T>) -> Nat:
  R.Match{i, tag, ps} = hit
  i

def some_test(-A: Data, x: Maybe<&2, A>) -> Bool:
  match x:
    case None{}:
      False{}
    case Some{v}:
      True{}

def none_some(-A: Data, +v: A, e: {None{} == Some{v} : Maybe<&2, A>}) -> Empty:
  Core.false_true(Equal.cong(Maybe<&2, A>, Bool, x => some_test(A, x), None{}, Some{v}, e))

def no_before_zero(-T: Data, +table: R.Table(T), +path: String, j: Nat,
    lt: {Nat.is_lt(j, 0n) == True{} : Bool}) ->
    {match_at(T, table, path, j) == None{} : Maybe<&2, AtMatch<T>>}:
  match j:
    case 0n:
      Core.absurd({match_at(T, table, path, 0n) == None{} : Maybe<&2, AtMatch<T>>}, Core.false_true(lt))
    case 1n+p:
      Core.absurd({match_at(T, table, path, 1n+p) == None{} : Maybe<&2, AtMatch<T>>}, Core.false_true(lt))

def cons_none(-T: Data, +pattern: P.Pattern, +tag: T, +tail: R.Table(T), +path: String,
    +head_miss: {P.match_path(pattern, path) == None{} : Maybe<&2, P.Params>},
    misses: @i: Nat -> {match_at(T, tail, path, i) == None{} : Maybe<&2, AtMatch<T>>}, i: Nat) ->
    {match_at(T, R.Route{pattern, tag} <> tail, path, i) == None{} : Maybe<&2, AtMatch<T>>}:
  match i:
    case 0n:
      Equal.cong(Maybe<&2, P.Params>, Maybe<&2, AtMatch<T>>, x => entry_match(T, tag, x), P.match_path(pattern, path), None{}, head_miss)
    case 1n+p:
      misses(p)

def cons_earlier(-T: Data, +pattern: P.Pattern, +tag: T, +tail: R.Table(T), +path: String, +i: Nat,
    +head_miss: {P.match_path(pattern, path) == None{} : Maybe<&2, P.Params>},
    earlier: NoEarlier(T, tail, path, i), j: Nat,
    lt: {Nat.is_lt(j, 1n+i) == True{} : Bool}) ->
    {match_at(T, R.Route{pattern, tag} <> tail, path, j) == None{} : Maybe<&2, AtMatch<T>>}:
  match j:
    case 0n:
      Equal.cong(Maybe<&2, P.Params>, Maybe<&2, AtMatch<T>>, x => entry_match(T, tag, x), P.match_path(pattern, path), None{}, head_miss)
    case 1n+p:
      earlier(p, lt)

def select_correct(-T: Data, +pattern: P.Pattern, +tag: T, +tail: R.Table(T), +path: String,
    +head: Maybe<&2, P.Params>, +rest: Maybe<&2, R.Match<T>>,
    +head_eq: {P.match_path(pattern, path) == head : Maybe<&2, P.Params>},
    correct: Outcome(T, tail, path, rest)) ->
    Outcome(T, R.Route{pattern, tag} <> tail, path, R.select(T, tag, head, u => rest)):
  match head rest:
    case Some{+ps} r:
      (Equal.cong(Maybe<&2, P.Params>, Maybe<&2, AtMatch<T>>, x => entry_match(T, tag, x), P.match_path(pattern, path), Some{ps}, head_eq), j => lt => no_before_zero(T, R.Route{pattern, tag} <> tail, path, j, lt))
    case None{} None{}:
      i => cons_none(T, pattern, tag, tail, path, head_eq, correct, i)
    case None{} Some{R.Match{+i, +other_tag, +ps}}:
      (found, earlier) = correct
      (found, j => lt => cons_earlier(T, pattern, tag, tail, path, i, head_eq, earlier, j, lt))

def route_correct(-T: Data, +table: R.Table(T), +path: String) -> Outcome(T, table, path, R.route(T, table, path)):
  match table:
    case Nil{}:
      i => {==}
    case R.Route{+pattern, +tag} <> +tail:
      select_correct(T, pattern, tag, tail, path, P.match_path(pattern, path), R.route(T, tail, path), {==}, route_correct(T, tail, path))

# A failed strict-order comparison supplies the complementary weak order.
def le_from_not_lt(+a: Nat, +b: Nat,
    impossible: {Nat.is_lt(b, a) == True{} : Bool} -> Empty) ->
    {Nat.is_le(a, b) == True{} : Bool}:
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+bp:
      {==}
    case 1n+ap 0n:
      Core.absurd({Nat.is_le(1n+ap, 0n) == True{} : Bool}, impossible({==}))
    case 1n+ap 1n+bp:
      le_from_not_lt(ap, bp, impossible)

def winner_bound(-T: Data, +table: R.Table(T), +path: String, +i: Nat, +tag: T, +ps: P.Params,
    at: {match_at(T, table, path, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>},
    +k: Nat, earlier: NoEarlier(T, table, path, k)) -> {Nat.is_le(k, i) == True{} : Bool}:
  le_from_not_lt(k, i, lt => none_some(AtMatch<T>, At{tag, ps}, Equal.trans(Maybe<&2, AtMatch<T>>, None{}, match_at(T, table, path, i), Some{At{tag, ps}}, Equal.sym(Maybe<&2, AtMatch<T>>, match_at(T, table, path, i), None{}, earlier(i, lt)), at)))

def complete_result(-T: Data, +table: R.Table(T), +path: String, +i: Nat, +tag: T, +ps: P.Params,
    at: {match_at(T, table, path, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>},
    +result: Maybe<&2, R.Match<T>>, correct: Outcome(T, table, path, result)) ->
    &hit: R.Match<T> -> {result == Some{hit} : Maybe<&2, R.Match<T>>} & {Nat.is_le(index(T, hit), i) == True{} : Bool}:
  match result:
    case None{}:
      Core.absurd(&hit: R.Match<T> -> {None{} == Some{hit} : Maybe<&2, R.Match<T>>} & {Nat.is_le(index(T, hit), i) == True{} : Bool}, none_some(AtMatch<T>, At{tag, ps}, Equal.trans(Maybe<&2, AtMatch<T>>, None{}, match_at(T, table, path, i), Some{At{tag, ps}}, Equal.sym(Maybe<&2, AtMatch<T>>, match_at(T, table, path, i), None{}, correct(i)), at)))
    case Some{R.Match{+k, +winner_tag, +winner_ps}}:
      (found, earlier) = correct
      (R.Match{k, winner_tag, winner_ps}, ({==}, winner_bound(T, table, path, i, tag, ps, at, k, earlier)))

def complete(-T: Data, +table: R.Table(T), +path: String, +i: Nat, +tag: T, +ps: P.Params,
    at: {match_at(T, table, path, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>}) ->
    &hit: R.Match<T> -> {R.route(T, table, path) == Some{hit} : Maybe<&2, R.Match<T>>} & {Nat.is_le(index(T, hit), i) == True{} : Bool}:
  complete_result(T, table, path, i, tag, ps, at, R.route(T, table, path), route_correct(T, table, path))

def sound(-T: Data, +table: R.Table(T), +path: String, +i: Nat, +tag: T, +ps: P.Params,
    returned: {R.route(T, table, path) == Some{R.Match{i, tag, ps}} : Maybe<&2, R.Match<T>>}) -> First(T, table, path, i, tag, ps):
  %returned : Outcome(T, table, path, _)
  route_correct(T, table, path)

def le_antisymm(+a: Nat, +b: Nat,
    ab: {Nat.is_le(a, b) == True{} : Bool}, ba: {Nat.is_le(b, a) == True{} : Bool}) -> {a == b : Nat}:
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+bp:
      Core.absurd({0n == 1n+bp : Nat}, Core.false_true(ba))
    case 1n+ap 0n:
      Core.absurd({1n+ap == 0n : Nat}, Core.false_true(ab))
    case 1n+ap 1n+bp:
      Equal.cong(Nat, Nat, x => 1n+x, ap, bp, le_antisymm(ap, bp, ab, ba))

def at_or(-T: Data, fallback: AtMatch<T>, value: Maybe<&2, AtMatch<T>>) -> AtMatch<T>:
  match value:
    case None{}:
      fallback
    case Some{v}:
      v

def rebuild(-T: Data, i: Nat, value: AtMatch<T>) -> Maybe<&2, R.Match<T>>:
  At{tag, ps} = value
  Some{R.Match{i, tag, ps}}

def exact_result(-T: Data, +table: R.Table(T), +path: String, +i: Nat, +tag: T, +ps: P.Params,
    +at: {match_at(T, table, path, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>},
    earlier: NoEarlier(T, table, path, i), +result: Maybe<&2, R.Match<T>>,
    correct: Outcome(T, table, path, result)) ->
    {result == Some{R.Match{i, tag, ps}} : Maybe<&2, R.Match<T>>}:
  match result:
    case None{}:
      Core.absurd({None{} == Some{R.Match{i, tag, ps}} : Maybe<&2, R.Match<T>>}, none_some(AtMatch<T>, At{tag, ps}, Equal.trans(Maybe<&2, AtMatch<T>>, None{}, match_at(T, table, path, i), Some{At{tag, ps}}, Equal.sym(Maybe<&2, AtMatch<T>>, match_at(T, table, path, i), None{}, correct(i)), at)))
    case Some{R.Match{+k, +winner_tag, +winner_ps}}:
      (+found, winner_earlier) = correct
      +same = le_antisymm(k, i, winner_bound(T, table, path, i, tag, ps, at, k, winner_earlier), winner_bound(T, table, path, k, winner_tag, winner_ps, found, i, earlier))
      shifted = Equal.trans(Maybe<&2, AtMatch<T>>, match_at(T, table, path, k), match_at(T, table, path, i), Some{At{tag, ps}}, Equal.cong(Nat, Maybe<&2, AtMatch<T>>, n => match_at(T, table, path, n), k, i, same), at)
      values = Equal.cong(Maybe<&2, AtMatch<T>>, AtMatch<T>, x => at_or(T, At{tag, ps}, x), Some{At{winner_tag, winner_ps}}, Some{At{tag, ps}}, Equal.trans(Maybe<&2, AtMatch<T>>, Some{At{winner_tag, winner_ps}}, match_at(T, table, path, k), Some{At{tag, ps}}, Equal.sym(Maybe<&2, AtMatch<T>>, match_at(T, table, path, k), Some{At{winner_tag, winner_ps}}, found), shifted))
      Equal.trans(Maybe<&2, R.Match<T>>, Some{R.Match{k, winner_tag, winner_ps}}, Some{R.Match{k, tag, ps}}, Some{R.Match{i, tag, ps}}, Equal.cong(AtMatch<T>, Maybe<&2, R.Match<T>>, x => rebuild(T, k, x), At{winner_tag, winner_ps}, At{tag, ps}, values), Equal.cong(Nat, Maybe<&2, R.Match<T>>, n => Some{R.Match{n, tag, ps}}, k, i, same))

def exact(-T: Data, +table: R.Table(T), +path: String, +i: Nat, +tag: T, +ps: P.Params,
    +at: {match_at(T, table, path, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>},
    earlier: NoEarlier(T, table, path, i)) ->
    {R.route(T, table, path) == Some{R.Match{i, tag, ps}} : Maybe<&2, R.Match<T>>}:
  exact_result(T, table, path, i, tag, ps, at, earlier, R.route(T, table, path), route_correct(T, table, path))

def le_lt(+a: Nat, +b: Nat, +c: Nat,
    ab: {Nat.is_le(a, b) == True{} : Bool}, bc: {Nat.is_lt(b, c) == True{} : Bool}) -> {Nat.is_lt(a, c) == True{} : Bool}:
  match a b c:
    case 0n 0n 0n:
      Core.absurd({Nat.is_lt(0n, 0n) == True{} : Bool}, Core.false_true(bc))
    case 0n 0n 1n+cp:
      {==}
    case 0n 1n+bp 0n:
      Core.absurd({Nat.is_lt(0n, 0n) == True{} : Bool}, Core.false_true(bc))
    case 0n 1n+bp 1n+cp:
      {==}
    case 1n+ap 0n c:
      Core.absurd({Nat.is_lt(1n+ap, c) == True{} : Bool}, Core.false_true(ab))
    case 1n+ap 1n+bp 0n:
      Core.absurd({Nat.is_lt(1n+ap, 0n) == True{} : Bool}, Core.false_true(bc))
    case 1n+ap 1n+bp 1n+cp:
      le_lt(ap, bp, cp, ab, bc)

def at_of_route(-T: Data, +table: R.Table(T), +path: String, +i: Nat, +pattern: P.Pattern, +tag: T, +ps: P.Params,
    entry: {List.get(&2, R.Route<T>, table, i) == Some{R.Route{pattern, tag}} : Maybe<&2, R.Route<T>>},
    matched: {P.match_path(pattern, path) == Some{ps} : Maybe<&2, P.Params>}) ->
    {match_at(T, table, path, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>}:
  %Equal.sym(Maybe<&2, R.Route<T>>, List.get(&2, R.Route<T>, table, i), Some{R.Route{pattern, tag}}, entry) : {lookup_match(T, _, path) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>}
  Equal.cong(Maybe<&2, P.Params>, Maybe<&2, AtMatch<T>>, x => entry_match(T, tag, x), P.match_path(pattern, path), Some{ps}, matched)

# Eliminate dependent witnesses only after passing them as parameters.
def priority_witness(-T: Data, +a: Nat, +b: Nat, +result: Maybe<&2, R.Match<T>>,
    before: {Nat.is_lt(a, b) == True{} : Bool},
    witness: &hit: R.Match<T> -> {result == Some{hit} : Maybe<&2, R.Match<T>>} & {Nat.is_le(index(T, hit), a) == True{} : Bool}) ->
    &hit: R.Match<T> -> {result == Some{hit} : Maybe<&2, R.Match<T>>} & ({Nat.is_le(index(T, hit), a) == True{} : Bool} & {Nat.is_lt(index(T, hit), b) == True{} : Bool}):
  (+hit, (returned, +bound)) = witness
  (hit, (returned, (bound, le_lt(index(T, hit), a, b, bound, before))))

def Filled(-T: Data, +table: R.Table(T), +i: Nat, +pattern: P.Pattern, +tag: T, +ps: P.Params, +path: String) -> Type:
  &hit: R.Match<T> -> {P.fill(pattern, ps) == Some{path} : Maybe<&2, String>} &
    ({R.route(T, table, path) == Some{hit} : Maybe<&2, R.Match<T>>} &
    ({Nat.is_le(index(T, hit), i) == True{} : Bool} &
    (NoEarlier(T, table, path, i) -> {R.route(T, table, path) == Some{R.Match{i, tag, ps}} : Maybe<&2, R.Match<T>>})))

def filled_witness(-T: Data, +table: R.Table(T), +i: Nat, +pattern: P.Pattern, +tag: T, +ps: P.Params, +path: String,
    filled: {P.fill(pattern, ps) == Some{path} : Maybe<&2, String>},
    +at: {match_at(T, table, path, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>},
    witness: &hit: R.Match<T> -> {R.route(T, table, path) == Some{hit} : Maybe<&2, R.Match<T>>} & {Nat.is_le(index(T, hit), i) == True{} : Bool}) ->
    Filled(T, table, i, pattern, tag, ps, path):
  (+hit, (returned, bound)) = witness
  (hit, (filled, (returned, (bound, earlier => exact(T, table, path, i, tag, ps, at, earlier)))))

def filled_route(-T: Data, +table: R.Table(T), +i: Nat, +pattern: P.Pattern, +tag: T, +ps: P.Params, +path: String,
    entry: {List.get(&2, R.Route<T>, table, i) == Some{R.Route{pattern, tag}} : Maybe<&2, R.Route<T>>},
    filled: {P.fill(pattern, ps) == Some{path} : Maybe<&2, String>},
    matched: {P.match_path(pattern, path) == Some{ps} : Maybe<&2, P.Params>}) -> Filled(T, table, i, pattern, tag, ps, path):
  +at = at_of_route(T, table, path, i, pattern, tag, ps, entry, matched)
  filled_witness(T, table, i, pattern, tag, ps, path, filled, at, complete(T, table, path, i, tag, ps, at))

# A root wrapper supplies the existing pattern law's witness; this module does
# not import LAWS.bend or PROOF.bend, so the import graph remains acyclic.
def filled_roundtrip(-T: Data, +table: R.Table(T), +i: Nat, +pattern: P.Pattern, +tag: T, +ps: P.Params,
    entry: {List.get(&2, R.Route<T>, table, i) == Some{R.Route{pattern, tag}} : Maybe<&2, R.Route<T>>},
    roundtrip: &path: String -> {P.fill(pattern, ps) == Some{path} : Maybe<&2, String>} & {P.match_path(pattern, path) == Some{ps} : Maybe<&2, P.Params>}) ->
    &path: String -> Filled(T, table, i, pattern, tag, ps, path):
  (+path, (filled, matched)) = roundtrip
  (path, filled_route(T, table, i, pattern, tag, ps, path, entry, filled, matched))

# BND-17: every registration that matches, ascending by index, with its tag
# and params. Like match_at, this never calls a router.
def found(-T: Data, i: Nat, tag: T, hit: Maybe<&2, P.Params>, rest: List<&2, R.Match<T>>) -> List<&2, R.Match<T>>:
  match hit:
    case None{}:
      rest
    case Some{ps}:
      R.Match{i, tag, ps} <> rest

def matching_from(-T: Data, table: R.Table(T), +path: String, +i: Nat) -> List<&2, R.Match<T>>:
  match table:
    case Nil{}:
      Nil{}
    case R.Route{pattern, tag} <> rest:
      found(T, i, tag, P.match_path(pattern, path), matching_from(T, rest, path, 1n+i))

def matching(-T: Data, table: R.Table(T), +path: String) -> List<&2, R.Match<T>>:
  matching_from(T, table, path, 0n)
