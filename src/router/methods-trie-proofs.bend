# BND-17: method resolution through the configured router equals resolve.
import Base
import ./spec.bend as S
import ./pattern.bend as P
import ./methods.bend as M
import ./trie.bend as Tr
import ./router.bend as Router
import ./trie-proofs.bend as TP
import ./methods-proofs.bend as MP
import ./proofs.bend as Core
import ./encoding.bend as E
import ../http/request.bend as H

# Under the default options, a skipped registration cannot match the path.
def hits_step(-T: Data, +pattern: P.Pattern, +binding: M.Binding<T>, +index: Nat, +path: String, +xs: List<&2, Tr.Candidate<M.Binding<T>>>, +ys: List<&2, Tr.Candidate<M.Binding<T>>>,
    hit: Maybe<&2, P.Params>, +found: {M.match_path(pattern, path, M.defaults()) == hit : Maybe<&2, P.Params>},
    test: Bool, +decided: {TP.prefix(Tr.pattern_key(pattern), Tr.query(path)) == test : Bool},
    same_rest: {M.hits(T, xs, path, M.defaults()) == M.hits(T, ys, path, M.defaults()) : List<&2, S.Match<M.Binding<T>>>}) ->
    {M.hits(T, TP.include(M.Binding<T>, TP.prefix(Tr.pattern_key(pattern), Tr.query(path)), Tr.Candidate{index, S.Route{pattern, binding}}, xs), path, M.defaults()) == Tr.keep(M.Binding<T>, index, binding, M.match_path(pattern, path, M.defaults()), M.hits(T, ys, path, M.defaults())) : List<&2, S.Match<M.Binding<T>>>}:
  match hit test:
    case Some{+ps} True{}:
      %Equal.sym(Bool, TP.prefix(Tr.pattern_key(pattern), Tr.query(path)), True{}, decided) : {M.hits(T, TP.include(M.Binding<T>, _, Tr.Candidate{index, S.Route{pattern, binding}}, xs), path, M.defaults()) == Tr.keep(M.Binding<T>, index, binding, M.match_path(pattern, path, M.defaults()), M.hits(T, ys, path, M.defaults())) : List<&2, S.Match<M.Binding<T>>>}
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, M.defaults()), Some{ps}, found) : {Tr.keep(M.Binding<T>, index, binding, _, M.hits(T, xs, path, M.defaults())) == Tr.keep(M.Binding<T>, index, binding, _, M.hits(T, ys, path, M.defaults())) : List<&2, S.Match<M.Binding<T>>>}
      Equal.cong(List<&2, S.Match<M.Binding<T>>>, List<&2, S.Match<M.Binding<T>>>, rs => S.Match{index, binding, ps} <> rs, M.hits(T, xs, path, M.defaults()), M.hits(T, ys, path, M.defaults()), same_rest)
    case Some{+ps} False{}:
      +plain = Equal.trans(Maybe<&2, P.Params>, P.match_path(pattern, path), M.match_path(pattern, path, M.defaults()), Some{ps}, Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, M.defaults()), P.match_path(pattern, path), MP.default_path(pattern, path)), found)
      Core.absurd({M.hits(T, TP.include(M.Binding<T>, TP.prefix(Tr.pattern_key(pattern), Tr.query(path)), Tr.Candidate{index, S.Route{pattern, binding}}, xs), path, M.defaults()) == Tr.keep(M.Binding<T>, index, binding, M.match_path(pattern, path, M.defaults()), M.hits(T, ys, path, M.defaults())) : List<&2, S.Match<M.Binding<T>>>}, TP.no_prefix(pattern, path, ps, plain, decided))
    case None{} True{}:
      %Equal.sym(Bool, TP.prefix(Tr.pattern_key(pattern), Tr.query(path)), True{}, decided) : {M.hits(T, TP.include(M.Binding<T>, _, Tr.Candidate{index, S.Route{pattern, binding}}, xs), path, M.defaults()) == Tr.keep(M.Binding<T>, index, binding, M.match_path(pattern, path, M.defaults()), M.hits(T, ys, path, M.defaults())) : List<&2, S.Match<M.Binding<T>>>}
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, M.defaults()), None{}, found) : {Tr.keep(M.Binding<T>, index, binding, _, M.hits(T, xs, path, M.defaults())) == Tr.keep(M.Binding<T>, index, binding, _, M.hits(T, ys, path, M.defaults())) : List<&2, S.Match<M.Binding<T>>>}
      same_rest
    case None{} False{}:
      %Equal.sym(Bool, TP.prefix(Tr.pattern_key(pattern), Tr.query(path)), False{}, decided) : {M.hits(T, TP.include(M.Binding<T>, _, Tr.Candidate{index, S.Route{pattern, binding}}, xs), path, M.defaults()) == Tr.keep(M.Binding<T>, index, binding, M.match_path(pattern, path, M.defaults()), M.hits(T, ys, path, M.defaults())) : List<&2, S.Match<M.Binding<T>>>}
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, M.defaults()), None{}, found) : {M.hits(T, xs, path, M.defaults()) == Tr.keep(M.Binding<T>, index, binding, _, M.hits(T, ys, path, M.defaults())) : List<&2, S.Match<M.Binding<T>>>}
      same_rest

def drop_hits(-T: Data, +table: M.Table(T), +index: Nat, +path: String) ->
    {M.hits(T, TP.filtered(M.Binding<T>, table, index, Tr.query(path)), path, M.defaults()) == M.hits(T, Tr.indexed(M.Binding<T>, table, index), path, M.defaults()) : List<&2, S.Match<M.Binding<T>>>}:
  match table:
    case Nil{}:
      {==}
    case S.Route{+pattern, +binding} <> +rest:
      hits_step(T, pattern, binding, index, path, TP.filtered(M.Binding<T>, rest, 1n+index, Tr.query(path)), Tr.indexed(M.Binding<T>, rest, 1n+index), M.match_path(pattern, path, M.defaults()), {==}, TP.prefix(Tr.pattern_key(pattern), Tr.query(path)), {==}, drop_hits(T, rest, 1n+index, path))

# Every option combination sees the same matching list as a full scan.
def entries_hits(-T: Data, +table: M.Table(T), ok: {M.TableValid(T, table) == True{} : Bool}, +path: String, +opts: M.Options) ->
    {M.hits(T, M.entries(T, M.Valid{table, ok}, Tr.build_trie(M.Binding<T>, table), path, opts), path, opts) == M.hits(T, Tr.indexed(M.Binding<T>, table, 0n), path, opts) : List<&2, S.Match<M.Binding<T>>>}:
  match opts:
    case M.Options{True{}, True{}}:
      %Equal.sym(List<&2, Tr.Candidate<M.Binding<T>>>, Tr.candidates(M.Binding<T>, Tr.build_trie(M.Binding<T>, table), path), TP.filtered(M.Binding<T>, table, 0n, Tr.query(path)), TP.candidates_filtered(M.Binding<T>, table, path)) : {M.hits(T, _, path, M.defaults()) == M.hits(T, Tr.indexed(M.Binding<T>, table, 0n), path, M.defaults()) : List<&2, S.Match<M.Binding<T>>>}
      drop_hits(T, table, 0n, path)
    case M.Options{True{}, False{}}:
      {==}
    case M.Options{False{}, sensitive}:
      {==}

def allowed_step(-T: Data, +pattern: P.Pattern, +methods: M.MethodSelector, +tag: T, +index: Nat, +path: String, +method: H.Method, +opts: M.Options, +rest: M.Table(T),
    hit: Maybe<&2, P.Params>, +found: {M.match_path(pattern, path, opts) == hit : Maybe<&2, P.Params>},
    test: Bool, +decided: {M.accepts(methods, method) == test : Bool},
    inner: {M.first_allowed(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts), method) == TP.shift(T, 1n+index, M.find(T, rest, path, method, opts)) : Maybe<&2, S.Match<T>>}) ->
    {M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, M.match_path(pattern, path, opts), M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts)), method) == TP.shift(T, index, M.select(T, tag, M.eligible(methods, method, M.match_path(pattern, path, opts)), u => M.find(T, rest, path, method, opts))) : Maybe<&2, S.Match<T>>}:
  match hit test:
    case Some{+ps} True{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), Some{ps}, found) : {M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts)), method) == TP.shift(T, index, M.select(T, tag, M.eligible(methods, method, _), u => M.find(T, rest, path, method, opts))) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Bool, M.accepts(methods, method), True{}, decided) : {E.choose(Maybe<&2, S.Match<T>>, _, u => Some{S.Match{index, tag, ps}}, u => M.first_allowed(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts), method)) == TP.shift(T, index, M.select(T, tag, E.choose(Maybe<&2, P.Params>, _, u => Some{ps}, u => None{}), u => M.find(T, rest, path, method, opts))) : Maybe<&2, S.Match<T>>}
      Equal.sym(Maybe<&2, S.Match<T>>, TP.shift(T, index, Some{S.Match{0n, tag, ps}}), Some{S.Match{index, tag, ps}}, TP.shift_hit(T, index, tag, ps))
    case Some{+ps} False{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), Some{ps}, found) : {M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts)), method) == TP.shift(T, index, M.select(T, tag, M.eligible(methods, method, _), u => M.find(T, rest, path, method, opts))) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Bool, M.accepts(methods, method), False{}, decided) : {E.choose(Maybe<&2, S.Match<T>>, _, u => Some{S.Match{index, tag, ps}}, u => M.first_allowed(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts), method)) == TP.shift(T, index, M.select(T, tag, E.choose(Maybe<&2, P.Params>, _, u => Some{ps}, u => None{}), u => M.find(T, rest, path, method, opts))) : Maybe<&2, S.Match<T>>}
      Equal.trans(Maybe<&2, S.Match<T>>, M.first_allowed(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts), method), S.bump(T, TP.shift(T, index, M.find(T, rest, path, method, opts))), TP.shift(T, index, S.bump(T, M.find(T, rest, path, method, opts))), inner, TP.shift_bump(T, index, M.find(T, rest, path, method, opts)))
    case None{} True{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), None{}, found) : {M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts)), method) == TP.shift(T, index, M.select(T, tag, M.eligible(methods, method, _), u => M.find(T, rest, path, method, opts))) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Bool, M.accepts(methods, method), True{}, decided) : {M.first_allowed(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts), method) == TP.shift(T, index, M.select(T, tag, E.choose(Maybe<&2, P.Params>, _, u => None{}, u => None{}), u => M.find(T, rest, path, method, opts))) : Maybe<&2, S.Match<T>>}
      Equal.trans(Maybe<&2, S.Match<T>>, M.first_allowed(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts), method), S.bump(T, TP.shift(T, index, M.find(T, rest, path, method, opts))), TP.shift(T, index, S.bump(T, M.find(T, rest, path, method, opts))), inner, TP.shift_bump(T, index, M.find(T, rest, path, method, opts)))
    case None{} False{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), None{}, found) : {M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts)), method) == TP.shift(T, index, M.select(T, tag, M.eligible(methods, method, _), u => M.find(T, rest, path, method, opts))) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Bool, M.accepts(methods, method), False{}, decided) : {M.first_allowed(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts), method) == TP.shift(T, index, M.select(T, tag, E.choose(Maybe<&2, P.Params>, _, u => None{}, u => None{}), u => M.find(T, rest, path, method, opts))) : Maybe<&2, S.Match<T>>}
      Equal.trans(Maybe<&2, S.Match<T>>, M.first_allowed(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts), method), S.bump(T, TP.shift(T, index, M.find(T, rest, path, method, opts))), TP.shift(T, index, S.bump(T, M.find(T, rest, path, method, opts))), inner, TP.shift_bump(T, index, M.find(T, rest, path, method, opts)))

def allowed_indexed(-T: Data, +table: M.Table(T), +index: Nat, +path: String, +method: H.Method, +opts: M.Options) ->
    {M.first_allowed(T, M.hits(T, Tr.indexed(M.Binding<T>, table, index), path, opts), method) == TP.shift(T, index, M.find(T, table, path, method, opts)) : Maybe<&2, S.Match<T>>}:
  match table:
    case Nil{}:
      Equal.sym(Maybe<&2, S.Match<T>>, TP.shift(T, index, None{}), None{}, TP.shift_none(T, index))
    case S.Route{+pattern, M.Binding{+methods, +tag}} <> +rest:
      allowed_step(T, pattern, methods, tag, index, path, method, opts, rest, M.match_path(pattern, path, opts), {==}, M.accepts(methods, method), {==}, allowed_indexed(T, rest, 1n+index, path, method, opts))

def exists_step(-T: Data, +pattern: P.Pattern, +methods: M.MethodSelector, +tag: T, +index: Nat, +path: String, +opts: M.Options, +rest: M.Table(T),
    hit: Maybe<&2, P.Params>, +found: {M.match_path(pattern, path, opts) == hit : Maybe<&2, P.Params>},
    inner: {M.any_hit(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts)) == M.path_exists(T, rest, path, opts) : Bool}) ->
    {M.any_hit(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, M.match_path(pattern, path, opts), M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts))) == Maybe.is_some(&2, P.Params, M.match_path(pattern, path, opts)) || M.path_exists(T, rest, path, opts) : Bool}:
  match hit:
    case Some{+ps}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), Some{ps}, found) : {M.any_hit(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts))) == Maybe.is_some(&2, P.Params, _) || M.path_exists(T, rest, path, opts) : Bool}
      {==}
    case None{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), None{}, found) : {M.any_hit(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts))) == Maybe.is_some(&2, P.Params, _) || M.path_exists(T, rest, path, opts) : Bool}
      inner

def exists_indexed(-T: Data, +table: M.Table(T), +index: Nat, +path: String, +opts: M.Options) ->
    {M.any_hit(T, M.hits(T, Tr.indexed(M.Binding<T>, table, index), path, opts)) == M.path_exists(T, table, path, opts) : Bool}:
  match table:
    case Nil{}:
      {==}
    case S.Route{+pattern, M.Binding{+methods, +tag}} <> +rest:
      exists_step(T, pattern, methods, tag, index, path, opts, rest, M.match_path(pattern, path, opts), {==}, exists_indexed(T, rest, 1n+index, path, opts))

def methods_step(-T: Data, +pattern: P.Pattern, +methods: M.MethodSelector, +tag: T, +index: Nat, +path: String, +opts: M.Options, +rest: M.Table(T),
    hit: Maybe<&2, P.Params>, +found: {M.match_path(pattern, path, opts) == hit : Maybe<&2, P.Params>},
    inner: {M.hit_methods(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts)) == M.matching_methods(T, rest, path, opts) : List<&2, H.Method>}) ->
    {M.hit_methods(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, M.match_path(pattern, path, opts), M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts))) == E.choose(List<&2, H.Method>, Maybe.is_some(&2, P.Params, M.match_path(pattern, path, opts)), u => List.append(&2, H.Method, M.finite(methods), M.matching_methods(T, rest, path, opts)), u => M.matching_methods(T, rest, path, opts)) : List<&2, H.Method>}:
  match hit:
    case Some{+ps}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), Some{ps}, found) : {M.hit_methods(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts))) == E.choose(List<&2, H.Method>, Maybe.is_some(&2, P.Params, _), u => List.append(&2, H.Method, M.finite(methods), M.matching_methods(T, rest, path, opts)), u => M.matching_methods(T, rest, path, opts)) : List<&2, H.Method>}
      Equal.cong(List<&2, H.Method>, List<&2, H.Method>, xs => List.append(&2, H.Method, M.finite(methods), xs), M.hit_methods(T, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts)), M.matching_methods(T, rest, path, opts), inner)
    case None{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), None{}, found) : {M.hit_methods(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, Tr.indexed(M.Binding<T>, rest, 1n+index), path, opts))) == E.choose(List<&2, H.Method>, Maybe.is_some(&2, P.Params, _), u => List.append(&2, H.Method, M.finite(methods), M.matching_methods(T, rest, path, opts)), u => M.matching_methods(T, rest, path, opts)) : List<&2, H.Method>}
      inner

def methods_indexed(-T: Data, +table: M.Table(T), +index: Nat, +path: String, +opts: M.Options) ->
    {M.hit_methods(T, M.hits(T, Tr.indexed(M.Binding<T>, table, index), path, opts)) == M.matching_methods(T, table, path, opts) : List<&2, H.Method>}:
  match table:
    case Nil{}:
      {==}
    case S.Route{+pattern, M.Binding{+methods, +tag}} <> +rest:
      methods_step(T, pattern, methods, tag, index, path, opts, rest, M.match_path(pattern, path, opts), {==}, methods_indexed(T, rest, 1n+index, path, opts))

# Stopping at the first allowed match agrees with filtering the full list.
def direct_step(-T: Data, +pattern: P.Pattern, +methods: M.MethodSelector, +tag: T, +index: Nat, +path: String, +method: H.Method, +opts: M.Options, +rest: List<&2, Tr.Candidate<M.Binding<T>>>,
    hit: Maybe<&2, P.Params>, +found: {M.match_path(pattern, path, opts) == hit : Maybe<&2, P.Params>},
    test: Bool, +decided: {M.accepts(methods, method) == test : Bool},
    inner: {M.first_direct(T, rest, path, method, opts) == M.first_allowed(T, M.hits(T, rest, path, opts), method) : Maybe<&2, S.Match<T>>}) ->
    {Tr.candidate_hit(T, index, tag, M.eligible(methods, method, M.match_path(pattern, path, opts)), u => M.first_direct(T, rest, path, method, opts)) == M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, M.match_path(pattern, path, opts), M.hits(T, rest, path, opts)), method) : Maybe<&2, S.Match<T>>}:
  match hit test:
    case Some{+ps} True{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), Some{ps}, found) : {Tr.candidate_hit(T, index, tag, M.eligible(methods, method, _), u => M.first_direct(T, rest, path, method, opts)) == M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, rest, path, opts)), method) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Bool, M.accepts(methods, method), True{}, decided) : {Tr.candidate_hit(T, index, tag, E.choose(Maybe<&2, P.Params>, _, u => Some{ps}, u => None{}), u => M.first_direct(T, rest, path, method, opts)) == E.choose(Maybe<&2, S.Match<T>>, _, u => Some{S.Match{index, tag, ps}}, u => M.first_allowed(T, M.hits(T, rest, path, opts), method)) : Maybe<&2, S.Match<T>>}
      {==}
    case Some{+ps} False{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), Some{ps}, found) : {Tr.candidate_hit(T, index, tag, M.eligible(methods, method, _), u => M.first_direct(T, rest, path, method, opts)) == M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, rest, path, opts)), method) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Bool, M.accepts(methods, method), False{}, decided) : {Tr.candidate_hit(T, index, tag, E.choose(Maybe<&2, P.Params>, _, u => Some{ps}, u => None{}), u => M.first_direct(T, rest, path, method, opts)) == E.choose(Maybe<&2, S.Match<T>>, _, u => Some{S.Match{index, tag, ps}}, u => M.first_allowed(T, M.hits(T, rest, path, opts), method)) : Maybe<&2, S.Match<T>>}
      inner
    case None{} True{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), None{}, found) : {Tr.candidate_hit(T, index, tag, M.eligible(methods, method, _), u => M.first_direct(T, rest, path, method, opts)) == M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, rest, path, opts)), method) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Bool, M.accepts(methods, method), True{}, decided) : {Tr.candidate_hit(T, index, tag, E.choose(Maybe<&2, P.Params>, _, u => None{}, u => None{}), u => M.first_direct(T, rest, path, method, opts)) == M.first_allowed(T, M.hits(T, rest, path, opts), method) : Maybe<&2, S.Match<T>>}
      inner
    case None{} False{}:
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), None{}, found) : {Tr.candidate_hit(T, index, tag, M.eligible(methods, method, _), u => M.first_direct(T, rest, path, method, opts)) == M.first_allowed(T, Tr.keep(M.Binding<T>, index, M.Binding{methods, tag}, _, M.hits(T, rest, path, opts)), method) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Bool, M.accepts(methods, method), False{}, decided) : {Tr.candidate_hit(T, index, tag, E.choose(Maybe<&2, P.Params>, _, u => None{}, u => None{}), u => M.first_direct(T, rest, path, method, opts)) == M.first_allowed(T, M.hits(T, rest, path, opts), method) : Maybe<&2, S.Match<T>>}
      inner

def direct_hits(-T: Data, +entries: List<&2, Tr.Candidate<M.Binding<T>>>, +path: String, +method: H.Method, +opts: M.Options) ->
    {M.first_direct(T, entries, path, method, opts) == M.first_allowed(T, M.hits(T, entries, path, opts), method) : Maybe<&2, S.Match<T>>}:
  match entries:
    case Nil{}:
      {==}
    case Tr.Candidate{+index, S.Route{+pattern, M.Binding{+methods, +tag}}} <> +rest:
      direct_step(T, pattern, methods, tag, index, path, method, opts, rest, M.match_path(pattern, path, opts), {==}, M.accepts(methods, method), {==}, direct_hits(T, rest, path, method, opts))

# The configured candidates reproduce find, path existence and the Allow list.
def direct_find(-T: Data, +table: M.Table(T), +ok: {M.TableValid(T, table) == True{} : Bool}, +path: String, +method: H.Method, +opts: M.Options) ->
    {M.first_direct(T, M.entries(T, M.Valid{table, ok}, Tr.build_trie(M.Binding<T>, table), path, opts), path, method, opts) == M.find(T, table, path, method, opts) : Maybe<&2, S.Match<T>>}:
  +es = M.entries(T, M.Valid{table, ok}, Tr.build_trie(M.Binding<T>, table), path, opts)
  +all = M.hits(T, Tr.indexed(M.Binding<T>, table, 0n), path, opts)
  Equal.trans(Maybe<&2, S.Match<T>>, M.first_direct(T, es, path, method, opts), M.first_allowed(T, M.hits(T, es, path, opts), method), M.find(T, table, path, method, opts),
    direct_hits(T, es, path, method, opts),
    Equal.trans(Maybe<&2, S.Match<T>>, M.first_allowed(T, M.hits(T, es, path, opts), method), M.first_allowed(T, all, method), M.find(T, table, path, method, opts),
      Equal.cong(List<&2, S.Match<M.Binding<T>>>, Maybe<&2, S.Match<T>>, xs => M.first_allowed(T, xs, method), M.hits(T, es, path, opts), all, entries_hits(T, table, ok, path, opts)),
      allowed_indexed(T, table, 0n, path, method, opts)))

def direct_exists(-T: Data, +table: M.Table(T), +ok: {M.TableValid(T, table) == True{} : Bool}, +path: String, +opts: M.Options) ->
    {M.any_hit(T, M.hits(T, M.entries(T, M.Valid{table, ok}, Tr.build_trie(M.Binding<T>, table), path, opts), path, opts)) == M.path_exists(T, table, path, opts) : Bool}:
  +es = M.entries(T, M.Valid{table, ok}, Tr.build_trie(M.Binding<T>, table), path, opts)
  +all = M.hits(T, Tr.indexed(M.Binding<T>, table, 0n), path, opts)
  Equal.trans(Bool, M.any_hit(T, M.hits(T, es, path, opts)), M.any_hit(T, all), M.path_exists(T, table, path, opts),
    Equal.cong(List<&2, S.Match<M.Binding<T>>>, Bool, xs => M.any_hit(T, xs), M.hits(T, es, path, opts), all, entries_hits(T, table, ok, path, opts)),
    exists_indexed(T, table, 0n, path, opts))

def direct_allow(-T: Data, +table: M.Table(T), +ok: {M.TableValid(T, table) == True{} : Bool}, +path: String, +opts: M.Options) ->
    {M.hit_methods(T, M.hits(T, M.entries(T, M.Valid{table, ok}, Tr.build_trie(M.Binding<T>, table), path, opts), path, opts)) == M.matching_methods(T, table, path, opts) : List<&2, H.Method>}:
  +es = M.entries(T, M.Valid{table, ok}, Tr.build_trie(M.Binding<T>, table), path, opts)
  +all = M.hits(T, Tr.indexed(M.Binding<T>, table, 0n), path, opts)
  Equal.trans(List<&2, H.Method>, M.hit_methods(T, M.hits(T, es, path, opts)), M.hit_methods(T, all), M.matching_methods(T, table, path, opts),
    Equal.cong(List<&2, S.Match<M.Binding<T>>>, List<&2, H.Method>, xs => M.hit_methods(T, xs), M.hits(T, es, path, opts), all, entries_hits(T, table, ok, path, opts)),
    methods_indexed(T, table, 0n, path, opts))

# The 404/405 outcome reads equal existence and Allow inputs.
def miss_equal(-T: Data, +xs: List<&2, S.Match<M.Binding<T>>>, +table: M.Table(T), +path: String, +opts: M.Options,
    exists: {M.any_hit(T, xs) == M.path_exists(T, table, path, opts) : Bool},
    allow: {M.hit_methods(T, xs) == M.matching_methods(T, table, path, opts) : List<&2, H.Method>}) ->
    {M.miss_hits(T, xs) == M.miss(T, M.path_exists(T, table, path, opts), M.canonical(M.matching_methods(T, table, path, opts))) : M.Resolution<T>}:
  %Equal.sym(Bool, M.any_hit(T, xs), M.path_exists(T, table, path, opts), exists) : {M.miss(T, _, M.canonical(M.hit_methods(T, xs))) == M.miss(T, M.path_exists(T, table, path, opts), M.canonical(M.matching_methods(T, table, path, opts))) : M.Resolution<T>}
  %Equal.sym(List<&2, H.Method>, M.hit_methods(T, xs), M.matching_methods(T, table, path, opts), allow) : {M.miss(T, M.path_exists(T, table, path, opts), M.canonical(_)) == M.miss(T, M.path_exists(T, table, path, opts), M.canonical(M.matching_methods(T, table, path, opts))) : M.Resolution<T>}
  {==}

def decide_equal(-T: Data, +hit: Maybe<&2, S.Match<T>>, +es: List<&2, Tr.Candidate<M.Binding<T>>>, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options,
    get: {M.first_direct(T, es, path, H.Get{}, opts) == M.find(T, table, path, H.Get{}, opts) : Maybe<&2, S.Match<T>>},
    exists: {M.any_hit(T, M.hits(T, es, path, opts)) == M.path_exists(T, table, path, opts) : Bool},
    allow: {M.hit_methods(T, M.hits(T, es, path, opts)) == M.matching_methods(T, table, path, opts) : List<&2, H.Method>}) ->
    {M.decide(T, hit, es, path, method, opts) == M.resolve_direct(T, hit, table, path, method, opts) : M.Resolution<T>}:
  match hit method:
    case Some{h} m:
      {==}
    case None{} H.Head{}:
      %Equal.sym(Maybe<&2, S.Match<T>>, M.first_direct(T, es, path, H.Get{}, opts), M.find(T, table, path, H.Get{}, opts), get) : {M.fallback(T, _, u => M.miss_hits(T, M.hits(T, es, path, opts))) == M.fallback(T, M.find(T, table, path, H.Get{}, opts), u => M.miss(T, M.path_exists(T, table, path, opts), M.canonical(M.matching_methods(T, table, path, opts)))) : M.Resolution<T>}
      %Equal.sym(M.Resolution<T>, M.miss_hits(T, M.hits(T, es, path, opts)), M.miss(T, M.path_exists(T, table, path, opts), M.canonical(M.matching_methods(T, table, path, opts))), miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)) : {M.fallback(T, M.find(T, table, path, H.Get{}, opts), u => _) == M.fallback(T, M.find(T, table, path, H.Get{}, opts), u => M.miss(T, M.path_exists(T, table, path, opts), M.canonical(M.matching_methods(T, table, path, opts)))) : M.Resolution<T>}
      {==}
    case None{} H.Get{}:
      miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)
    case None{} H.Post{}:
      miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)
    case None{} H.Put{}:
      miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)
    case None{} H.Delete{}:
      miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)
    case None{} H.Connect{}:
      miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)
    case None{} H.Options{}:
      miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)
    case None{} H.Trace{}:
      miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)
    case None{} H.Patch{}:
      miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)
    case None{} H.Extension{token}:
      miss_equal(T, M.hits(T, es, path, opts), table, path, opts, exists, allow)

# Main result: every router kind gives the reference resolution.
def resolve_equal(-T: Data, +kind: Router.RouterKind, +valid: M.Valid<T>, +path: String, +method: H.Method, +opts: M.Options) ->
    {M.resolve_with(T, kind, M.prepare(T, valid), path, method, opts) == M.resolve(T, valid, path, method, opts) : M.Resolution<T>}:
  match kind valid:
    case Router.Spec{} v:
      {==}
    case Router.Trie{} M.Valid{+table, +ok}:
      +es = M.entries(T, M.Valid{table, ok}, Tr.build_trie(M.Binding<T>, table), path, opts)
      %Equal.sym(Maybe<&2, S.Match<T>>, M.first_direct(T, es, path, method, opts), M.find(T, table, path, method, opts), direct_find(T, table, ok, path, method, opts)) : {M.decide(T, _, es, path, method, opts) == M.resolve_direct(T, M.find(T, table, path, method, opts), table, path, method, opts) : M.Resolution<T>}
      decide_equal(T, M.find(T, table, path, method, opts), es, table, path, method, opts, direct_find(T, table, ok, path, H.Get{}, opts), direct_exists(T, table, ok, path, opts), direct_allow(T, table, ok, path, opts))
