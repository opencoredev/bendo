# BND-17: the segment trie returns exactly the reference router's candidates.
import Base
import ./trie.bend as Tr
import ./spec.bend as S
import ./pattern.bend as P
import ./encoding.bend as E
import ./proofs.bend as Core
import ./equality-proofs.bend as Eq
import ./spec-proofs.bend as SpecProof

# Character-wise segment equality, in the order the trie compares characters.
def same(a: String, b: String) -> Bool:
  match a b:
    case SNil{} SNil{}:
      True{}
    case SCon{x, xt} SCon{y, yt}:
      Char.is_eq(x, y) && same(xt, yt)
    case _ _:
      False{}

# A key is a prefix of the query segments.
def prefix(key: List<&2, String>, segments: List<&2, String>) -> Bool:
  match key segments:
    case Nil{} s:
      True{}
    case k <> ks Nil{}:
      False{}
    case k <> ks s <> ss:
      same(k, s) && prefix(ks, ss)

def include(-T: Data, test: Bool, +entry: Tr.Candidate<T>, rest: List<&2, Tr.Candidate<T>>) -> List<&2, Tr.Candidate<T>>:
  match test:
    case True{}:
      entry <> rest
    case False{}:
      rest

# The table, indexed from `index`, keeping entries whose key prefixes the query.
def filtered(-T: Data, table: S.Table(T), +index: Nat, +segments: List<&2, String>) -> List<&2, Tr.Candidate<T>>:
  match table:
    case Nil{}:
      Nil{}
    case S.Route{+pattern, +tag} <> rest:
      include(T, prefix(Tr.pattern_key(pattern), segments), Tr.Candidate{index, S.Route{pattern, tag}}, filtered(T, rest, 1n+index, segments))

# Character and segment equality facts.

def char_sound(+a: Char, +b: Char, yes: {Char.is_eq(a, b) == True{} : Bool}) -> {a == b : Char}:
  match a b:
    case Chr{+x} Chr{+y}:
      Equal.cong(U32, Char, n => Chr{n}, x, y, Eq.u32_cmp_sound(x, y, yes))

def char_refl(+a: Char) -> {Char.is_eq(a, a) == True{} : Bool}:
  match a:
    case Chr{+x}:
      %Equal.sym(Cmp, U32.cmp(x, x), EQ{}, Eq.u32_cmp_refl(x)) : {Cmp.is_eq(_) == True{} : Bool}
      {==}

def same_refl(+s: String) -> {same(s, s) == True{} : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{+c, +t}:
      %Equal.sym(Bool, Char.is_eq(c, c), True{}, char_refl(c)) : {_ && same(t, t) == True{} : Bool}
      same_refl(t)

# Matching a static-headed pattern compares exactly the query's segments.
def MatchQuery(+raw: String, +rest: List<&2, P.Segment>, +path: String) -> Type:
  {P.match_path(P.Pattern{P.Static{raw} <> rest}, path) == P.match_segments(P.Static{raw} <> rest, Tr.query(path)) : Maybe<&2, P.Params>}

def match_query(+raw: String, +rest: List<&2, P.Segment>, +path: String) -> MatchQuery(raw, rest, path):
  match path:
    case SCon{'/', +tail}:
      {==}
    case SNil{}:
      {==}
    case SCon{Chr{U32{WCon{False{}, remaining}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, remaining}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, remaining}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, remaining}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, remaining}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}

def some_test(-A: Data, x: Maybe<&2, A>) -> Bool:
  match x:
    case None{}:
      False{}
    case Some{v}:
      True{}

def none_some(-A: Data, +v: A, e: {None{} == Some{v} : Maybe<&2, A>}) -> Empty:
  Core.false_true(Equal.cong(Maybe<&2, A>, Bool, x => some_test(A, x), None{}, Some{v}, e))

def static_step(+raw: String, +h: String, +rest: List<&2, P.Segment>, +tail: List<&2, String>, +ps: P.Params,
    test: Bool, decided: {String.eq(raw, h) == test : Bool},
    matched: {E.choose(Maybe<&2, P.Params>, test, u => P.match_segments(rest, tail), u => None{}) == Some{ps} : Maybe<&2, P.Params>},
    inner: {P.match_segments(rest, tail) == Some{ps} : Maybe<&2, P.Params>} -> {prefix(Tr.key(rest), tail) == True{} : Bool}) ->
    {prefix(Tr.key(P.Static{raw} <> rest), h <> tail) == True{} : Bool}:
  match test:
    case True{}:
      %Equal.sym(String, raw, h, Eq.string_eq_sound(raw, h, decided)) : {prefix(Tr.key(P.Static{_} <> rest), h <> tail) == True{} : Bool}
      %Equal.sym(Bool, same(h, h), True{}, same_refl(h)) : {_ && prefix(Tr.key(rest), tail) == True{} : Bool}
      inner(matched)
    case False{}:
      Core.absurd({prefix(Tr.key(P.Static{raw} <> rest), h <> tail) == True{} : Bool}, none_some(P.Params, ps, matched))

# Every successful segment match passes the pattern's static key.
def key_prefix(+segs: List<&2, P.Segment>, +paths: List<&2, String>, +ps: P.Params) ->
    {P.match_segments(segs, paths) == Some{ps} : Maybe<&2, P.Params>} -> {prefix(Tr.key(segs), paths) == True{} : Bool}:
  match segs paths:
    case P.Static{+raw} <> +rest +h <> +tail:
      matched => static_step(raw, h, rest, tail, ps, String.eq(raw, h), {==}, matched, key_prefix(rest, tail, ps))
    case P.Static{+raw} <> +rest Nil{}:
      matched => Core.absurd({prefix(Tr.key(P.Static{raw} <> rest), Nil{}) == True{} : Bool}, none_some(P.Params, ps, matched))
    case Nil{} p:
      matched => {==}
    case P.Capture{name, c, optional} <> rest p:
      matched => {==}
    case P.Wildcard{name} <> rest p:
      matched => {==}

def pattern_prefix(+pattern: P.Pattern, +path: String, +ps: P.Params,
    matched: {P.match_path(pattern, path) == Some{ps} : Maybe<&2, P.Params>}) ->
    {prefix(Tr.pattern_key(pattern), Tr.query(path)) == True{} : Bool}:
  match pattern:
    case P.Pattern{P.Static{+raw} <> +rest}:
      key_prefix(P.Static{raw} <> rest, Tr.query(path), ps, Equal.trans(Maybe<&2, P.Params>, P.match_segments(P.Static{raw} <> rest, Tr.query(path)), P.match_path(P.Pattern{P.Static{raw} <> rest}, path), Some{ps}, Equal.sym(Maybe<&2, P.Params>, P.match_path(P.Pattern{P.Static{raw} <> rest}, path), P.match_segments(P.Static{raw} <> rest, Tr.query(path)), match_query(raw, rest, path)), matched))
    case P.Pattern{Nil{}}:
      {==}
    case P.Pattern{P.Capture{name, c, optional} <> rest}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest}:
      {==}

# Trie lookup after building a fresh chain.
def FreshFind(-T: Data, +rest: List<&2, String>, +segment: String, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +w: String, +ws: List<&2, String>) -> Type:
  {Tr.find(T, Tr.fresh(T, rest, segment, entry, parent), w, ws, parent) == include(T, same(segment, w) && prefix(rest, ws), entry, parent) : List<&2, Tr.Candidate<T>>}

def fresh_fork(-T: Data, +h: Char, +t: String, +rest: List<&2, String>, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +h2: Char, +t2: String, +ws: List<&2, String>,
    test: Bool, decided: {Char.is_eq(h, h2) == test : Bool},
    inner: FreshFind(T, rest, t, entry, parent, t2, ws)) ->
    {E.choose(List<&2, Tr.Candidate<T>>, Char.is_eq(h, h2), u => Tr.find(T, Tr.fresh(T, rest, t, entry, parent), t2, ws, parent), u => parent) == include(T, (Char.is_eq(h, h2) && same(t, t2)) && prefix(rest, ws), entry, parent) : List<&2, Tr.Candidate<T>>}:
  match test:
    case True{}:
      %Equal.sym(Bool, Char.is_eq(h, h2), True{}, decided) : {E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, Tr.fresh(T, rest, t, entry, parent), t2, ws, parent), u => parent) == include(T, (_ && same(t, t2)) && prefix(rest, ws), entry, parent) : List<&2, Tr.Candidate<T>>}
      inner
    case False{}:
      %Equal.sym(Bool, Char.is_eq(h, h2), False{}, decided) : {E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, Tr.fresh(T, rest, t, entry, parent), t2, ws, parent), u => parent) == include(T, (_ && same(t, t2)) && prefix(rest, ws), entry, parent) : List<&2, Tr.Candidate<T>>}
      {==}

def fresh_find(-T: Data, +rest: List<&2, String>, +segment: String, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +w: String, +ws: List<&2, String>) -> FreshFind(T, rest, segment, entry, parent, w, ws):
  match rest segment w ws:
    case Nil{} SCon{+h, +t} SNil{} +q:
      {==}
    case +n <> +m SCon{+h, +t} SNil{} +q:
      {==}
    case Nil{} SCon{+h, +t} SCon{+h2, +t2} +q:
      fresh_fork(T, h, t, Nil{}, entry, parent, h2, t2, q, Char.is_eq(h, h2), {==}, fresh_find(T, Nil{}, t, entry, parent, t2, q))
    case +n <> +m SCon{+h, +t} SCon{+h2, +t2} +q:
      fresh_fork(T, h, t, n <> m, entry, parent, h2, t2, q, Char.is_eq(h, h2), {==}, fresh_find(T, n <> m, t, entry, parent, t2, q))
    case Nil{} SNil{} SNil{} Nil{}:
      {==}
    case Nil{} SNil{} SNil{} n <> m:
      {==}
    case Nil{} SNil{} SCon{h, t} q:
      {==}
    case next <> more SNil{} SNil{} Nil{}:
      {==}
    case +next <> +more SNil{} SNil{} +n <> +m:
      fresh_find(T, more, next, entry, parent, n, m)
    case next <> more SNil{} SCon{h, t} q:
      {==}

# Prepending to every node below adds the entry to whatever lookup returns.
def PrependFind(-T: Data, +trie: Tr.Trie<T>, +w: String, +ws: List<&2, String>, +entry: Tr.Candidate<T>, +c: List<&2, Tr.Candidate<T>>) -> Type:
  {Tr.find(T, Tr.prepend(T, trie, entry), w, ws, entry <> c) == entry <> Tr.find(T, trie, w, ws, c) : List<&2, Tr.Candidate<T>>}

def prepend_fork(-T: Data, +ch: Char, +eq: Tr.Trie<T>, +other: Tr.Trie<T>, +h: Char, +t: String, +ws: List<&2, String>, +entry: Tr.Candidate<T>, +c: List<&2, Tr.Candidate<T>>,
    test: Bool, decided: {Char.is_eq(ch, h) == test : Bool},
    left: PrependFind(T, eq, t, ws, entry, c), right: PrependFind(T, other, SCon{h, t}, ws, entry, c)) ->
    {E.choose(List<&2, Tr.Candidate<T>>, Char.is_eq(ch, h), u => Tr.find(T, Tr.prepend(T, eq, entry), t, ws, entry <> c), u => Tr.find(T, Tr.prepend(T, other, entry), SCon{h, t}, ws, entry <> c)) == entry <> E.choose(List<&2, Tr.Candidate<T>>, Char.is_eq(ch, h), u => Tr.find(T, eq, t, ws, c), u => Tr.find(T, other, SCon{h, t}, ws, c)) : List<&2, Tr.Candidate<T>>}:
  match test:
    case True{}:
      %Equal.sym(Bool, Char.is_eq(ch, h), True{}, decided) : {E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, Tr.prepend(T, eq, entry), t, ws, entry <> c), u => Tr.find(T, Tr.prepend(T, other, entry), SCon{h, t}, ws, entry <> c)) == entry <> E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, eq, t, ws, c), u => Tr.find(T, other, SCon{h, t}, ws, c)) : List<&2, Tr.Candidate<T>>}
      left
    case False{}:
      %Equal.sym(Bool, Char.is_eq(ch, h), False{}, decided) : {E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, Tr.prepend(T, eq, entry), t, ws, entry <> c), u => Tr.find(T, Tr.prepend(T, other, entry), SCon{h, t}, ws, entry <> c)) == entry <> E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, eq, t, ws, c), u => Tr.find(T, other, SCon{h, t}, ws, c)) : List<&2, Tr.Candidate<T>>}
      right

def prepend_find(-T: Data, +trie: Tr.Trie<T>, +w: String, +ws: List<&2, String>, +entry: Tr.Candidate<T>, +c: List<&2, Tr.Candidate<T>>) -> PrependFind(T, trie, w, ws, entry, c):
  match trie w:
    case Tr.Tip{} s:
      {==}
    case Tr.Fork{ch, eq, other} SNil{}:
      {==}
    case Tr.Fork{+ch, +eq, +other} SCon{+h, +t}:
      prepend_fork(T, ch, eq, other, h, t, ws, entry, c, Char.is_eq(ch, h), {==}, prepend_find(T, eq, t, ws, entry, c), prepend_find(T, other, SCon{h, t}, ws, entry, c))
    case Tr.Node{+c2, +kids, +other} SNil{}:
      match ws:
        case Nil{}:
          {==}
        case +n <> +m:
          prepend_find(T, kids, n, m, entry, c2)
    case Tr.Node{+c2, +kids, +other} SCon{+h, +t}:
      prepend_find(T, other, SCon{h, t}, ws, entry, c)

# A false character test is symmetric.
def char_differ(+a: Char, +b: Char, differ: {Char.is_eq(a, b) == False{} : Bool}, test: Bool, decided: {Char.is_eq(b, a) == test : Bool}) -> {Char.is_eq(b, a) == False{} : Bool}:
  match test:
    case False{}:
      decided
    case True{}:
      +flip = Equal.sym(Char, b, a, char_sound(b, a, decided))
      Core.absurd({Char.is_eq(b, a) == False{} : Bool}, Core.false_true(Equal.trans(Bool, False{}, Char.is_eq(a, a), True{}, Equal.trans(Bool, False{}, Char.is_eq(a, b), Char.is_eq(a, a), Equal.sym(Bool, Char.is_eq(a, b), False{}, differ), Equal.cong(Char, Bool, x => Char.is_eq(a, x), b, a, Equal.sym(Char, a, b, flip))), char_refl(a))))

def char_flip(+a: Char, +b: Char, differ: {Char.is_eq(a, b) == False{} : Bool}) -> {Char.is_eq(b, a) == False{} : Bool}:
  char_differ(a, b, differ, Char.is_eq(b, a), {==})

# Lookup after insertion: the entry joins exactly when its key prefixes the query.
def InsertFind(-T: Data, +trie: Tr.Trie<T>, +segment: String, +rest: List<&2, String>, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +w: String, +ws: List<&2, String>) -> Type:
  {Tr.find(T, Tr.insert(T, trie, segment, rest, entry, parent), w, ws, parent) == include(T, same(segment, w) && prefix(rest, ws), entry, Tr.find(T, trie, w, ws, parent)) : List<&2, Tr.Candidate<T>>}

def insert_fork_end(-T: Data, +ch: Char, +eq: Tr.Trie<T>, +other: Tr.Trie<T>, +h: Char, +t: String, +rest: List<&2, String>, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +ws: List<&2, String>,
    test: Bool, decided: {Char.is_eq(ch, h) == test : Bool}) ->
    {Tr.find(T, E.choose(Tr.Trie<T>, Char.is_eq(ch, h), u => Tr.Fork{ch, Tr.insert(T, eq, t, rest, entry, parent), other}, u => Tr.Fork{ch, eq, Tr.insert(T, other, SCon{h, t}, rest, entry, parent)}), SNil{}, ws, parent) == parent : List<&2, Tr.Candidate<T>>}:
  match test:
    case True{}:
      %Equal.sym(Bool, Char.is_eq(ch, h), True{}, decided) : {Tr.find(T, E.choose(Tr.Trie<T>, _, u => Tr.Fork{ch, Tr.insert(T, eq, t, rest, entry, parent), other}, u => Tr.Fork{ch, eq, Tr.insert(T, other, SCon{h, t}, rest, entry, parent)}), SNil{}, ws, parent) == parent : List<&2, Tr.Candidate<T>>}
      {==}
    case False{}:
      %Equal.sym(Bool, Char.is_eq(ch, h), False{}, decided) : {Tr.find(T, E.choose(Tr.Trie<T>, _, u => Tr.Fork{ch, Tr.insert(T, eq, t, rest, entry, parent), other}, u => Tr.Fork{ch, eq, Tr.insert(T, other, SCon{h, t}, rest, entry, parent)}), SNil{}, ws, parent) == parent : List<&2, Tr.Candidate<T>>}
      {==}

# Goal after the inserted fork's first decision.
def ForkStep(-T: Data, +ch: Char, +eq: Tr.Trie<T>, +other: Tr.Trie<T>, +h: Char, +t: String, +rest: List<&2, String>, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +h2: Char, +t2: String, +ws: List<&2, String>, +inserted: Tr.Trie<T>) -> Type:
  {Tr.find(T, inserted, SCon{h2, t2}, ws, parent) == include(T, (Char.is_eq(h, h2) && same(t, t2)) && prefix(rest, ws), entry, E.choose(List<&2, Tr.Candidate<T>>, Char.is_eq(ch, h2), u => Tr.find(T, eq, t2, ws, parent), u => Tr.find(T, other, SCon{h2, t2}, ws, parent))) : List<&2, Tr.Candidate<T>>}

# Same character at the fork: descend into `equal`.
def fork_equal(-T: Data, +ch: Char, +eq: Tr.Trie<T>, +other: Tr.Trie<T>, +h: Char, +t: String, +rest: List<&2, String>, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +h2: Char, +t2: String, +ws: List<&2, String>,
    same_head: {ch == h : Char}, test: Bool, decided: {Char.is_eq(ch, h2) == test : Bool},
    left: InsertFind(T, eq, t, rest, entry, parent, t2, ws)) ->
    ForkStep(T, ch, eq, other, h, t, rest, entry, parent, h2, t2, ws, Tr.Fork{ch, Tr.insert(T, eq, t, rest, entry, parent), other}):
  match test:
    case True{}:
    %same_head : {Tr.find(T, Tr.Fork{ch, Tr.insert(T, eq, t, rest, entry, parent), other}, SCon{h2, t2}, ws, parent) == include(T, (Char.is_eq(_, h2) && same(t, t2)) && prefix(rest, ws), entry, E.choose(List<&2, Tr.Candidate<T>>, Char.is_eq(ch, h2), u => Tr.find(T, eq, t2, ws, parent), u => Tr.find(T, other, SCon{h2, t2}, ws, parent))) : List<&2, Tr.Candidate<T>>}
      %Equal.sym(Bool, Char.is_eq(ch, h2), True{}, decided) : {E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, Tr.insert(T, eq, t, rest, entry, parent), t2, ws, parent), u => Tr.find(T, other, SCon{h2, t2}, ws, parent)) == include(T, (_ && same(t, t2)) && prefix(rest, ws), entry, E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, eq, t2, ws, parent), u => Tr.find(T, other, SCon{h2, t2}, ws, parent))) : List<&2, Tr.Candidate<T>>}
      left
    case False{}:
    %same_head : {Tr.find(T, Tr.Fork{ch, Tr.insert(T, eq, t, rest, entry, parent), other}, SCon{h2, t2}, ws, parent) == include(T, (Char.is_eq(_, h2) && same(t, t2)) && prefix(rest, ws), entry, E.choose(List<&2, Tr.Candidate<T>>, Char.is_eq(ch, h2), u => Tr.find(T, eq, t2, ws, parent), u => Tr.find(T, other, SCon{h2, t2}, ws, parent))) : List<&2, Tr.Candidate<T>>}
      %Equal.sym(Bool, Char.is_eq(ch, h2), False{}, decided) : {E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, Tr.insert(T, eq, t, rest, entry, parent), t2, ws, parent), u => Tr.find(T, other, SCon{h2, t2}, ws, parent)) == include(T, (_ && same(t, t2)) && prefix(rest, ws), entry, E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, eq, t2, ws, parent), u => Tr.find(T, other, SCon{h2, t2}, ws, parent))) : List<&2, Tr.Candidate<T>>}
      {==}

# Different character at the fork: insertion went into `other`.
def fork_other(-T: Data, +ch: Char, +eq: Tr.Trie<T>, +other: Tr.Trie<T>, +h: Char, +t: String, +rest: List<&2, String>, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +h2: Char, +t2: String, +ws: List<&2, String>,
    differ: {Char.is_eq(ch, h) == False{} : Bool}, test: Bool, +decided: {Char.is_eq(ch, h2) == test : Bool},
    right: InsertFind(T, other, SCon{h, t}, rest, entry, parent, SCon{h2, t2}, ws)) ->
    ForkStep(T, ch, eq, other, h, t, rest, entry, parent, h2, t2, ws, Tr.Fork{ch, eq, Tr.insert(T, other, SCon{h, t}, rest, entry, parent)}):
  match test:
    case True{}:
      +meet = char_sound(ch, h2, decided)
      +apart = Equal.trans(Bool, Char.is_eq(h, h2), Char.is_eq(h, ch), False{}, Equal.cong(Char, Bool, x => Char.is_eq(h, x), h2, ch, Equal.sym(Char, ch, h2, meet)), char_flip(ch, h, differ))
      %Equal.sym(Bool, Char.is_eq(ch, h2), True{}, decided) : {E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, eq, t2, ws, parent), u => Tr.find(T, Tr.insert(T, other, SCon{h, t}, rest, entry, parent), SCon{h2, t2}, ws, parent)) == include(T, (Char.is_eq(h, h2) && same(t, t2)) && prefix(rest, ws), entry, E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, eq, t2, ws, parent), u => Tr.find(T, other, SCon{h2, t2}, ws, parent))) : List<&2, Tr.Candidate<T>>}
      %Equal.sym(Bool, Char.is_eq(h, h2), False{}, apart) : {Tr.find(T, eq, t2, ws, parent) == include(T, (_ && same(t, t2)) && prefix(rest, ws), entry, Tr.find(T, eq, t2, ws, parent)) : List<&2, Tr.Candidate<T>>}
      {==}
    case False{}:
      %Equal.sym(Bool, Char.is_eq(ch, h2), False{}, decided) : {E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, eq, t2, ws, parent), u => Tr.find(T, Tr.insert(T, other, SCon{h, t}, rest, entry, parent), SCon{h2, t2}, ws, parent)) == include(T, (Char.is_eq(h, h2) && same(t, t2)) && prefix(rest, ws), entry, E.choose(List<&2, Tr.Candidate<T>>, _, u => Tr.find(T, eq, t2, ws, parent), u => Tr.find(T, other, SCon{h2, t2}, ws, parent))) : List<&2, Tr.Candidate<T>>}
      right

def insert_fork(-T: Data, +ch: Char, +eq: Tr.Trie<T>, +other: Tr.Trie<T>, +h: Char, +t: String, +rest: List<&2, String>, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +h2: Char, +t2: String, +ws: List<&2, String>,
    test: Bool, +decided: {Char.is_eq(ch, h) == test : Bool},
    left: InsertFind(T, eq, t, rest, entry, parent, t2, ws),
    right: InsertFind(T, other, SCon{h, t}, rest, entry, parent, SCon{h2, t2}, ws)) ->
    ForkStep(T, ch, eq, other, h, t, rest, entry, parent, h2, t2, ws, E.choose(Tr.Trie<T>, Char.is_eq(ch, h), u => Tr.Fork{ch, Tr.insert(T, eq, t, rest, entry, parent), other}, u => Tr.Fork{ch, eq, Tr.insert(T, other, SCon{h, t}, rest, entry, parent)})):
  match test:
    case True{}:
      %Equal.sym(Bool, Char.is_eq(ch, h), True{}, decided) : ForkStep(T, ch, eq, other, h, t, rest, entry, parent, h2, t2, ws, E.choose(Tr.Trie<T>, _, u => Tr.Fork{ch, Tr.insert(T, eq, t, rest, entry, parent), other}, u => Tr.Fork{ch, eq, Tr.insert(T, other, SCon{h, t}, rest, entry, parent)}))
      fork_equal(T, ch, eq, other, h, t, rest, entry, parent, h2, t2, ws, char_sound(ch, h, decided), Char.is_eq(ch, h2), {==}, left)
    case False{}:
      %Equal.sym(Bool, Char.is_eq(ch, h), False{}, decided) : ForkStep(T, ch, eq, other, h, t, rest, entry, parent, h2, t2, ws, E.choose(Tr.Trie<T>, _, u => Tr.Fork{ch, Tr.insert(T, eq, t, rest, entry, parent), other}, u => Tr.Fork{ch, eq, Tr.insert(T, other, SCon{h, t}, rest, entry, parent)}))
      fork_other(T, ch, eq, other, h, t, rest, entry, parent, h2, t2, ws, decided, Char.is_eq(ch, h2), {==}, right)

def insert_find(-T: Data, +trie: Tr.Trie<T>, +segment: String, +rest: List<&2, String>, +entry: Tr.Candidate<T>, +parent: List<&2, Tr.Candidate<T>>, +w: String, +ws: List<&2, String>) -> InsertFind(T, trie, segment, rest, entry, parent, w, ws):
  match trie segment:
    case Tr.Tip{} +s:
      fresh_find(T, rest, s, entry, parent, w, ws)
    case Tr.Fork{+ch, +eq, +other} SCon{+h, +t}:
      match w:
        case SNil{}:
          insert_fork_end(T, ch, eq, other, h, t, rest, entry, parent, ws, Char.is_eq(ch, h), {==})
        case SCon{+h2, +t2}:
          insert_fork(T, ch, eq, other, h, t, rest, entry, parent, h2, t2, ws, Char.is_eq(ch, h), {==}, insert_find(T, eq, t, rest, entry, parent, t2, ws), insert_find(T, other, SCon{h, t}, rest, entry, parent, SCon{h2, t2}, ws))
    case Tr.Fork{+ch, +eq, +other} SNil{}:
      match rest w ws:
        case Nil{} SNil{} Nil{}:
          {==}
        case Nil{} SNil{} n <> m:
          {==}
        case Nil{} SCon{h, t} q:
          {==}
        case n <> m SNil{} Nil{}:
          {==}
        case +n <> +m SNil{} +n2 <> +m2:
          fresh_find(T, m, n, entry, parent, n2, m2)
        case n <> m SCon{h, t} q:
          {==}
    case Tr.Node{+c2, +kids, +other} SNil{}:
      match rest w ws:
        case Nil{} SNil{} Nil{}:
          {==}
        case Nil{} SNil{} +n2 <> +m2:
          prepend_find(T, kids, n2, m2, entry, c2)
        case Nil{} SCon{h, t} q:
          {==}
        case n <> m SNil{} Nil{}:
          {==}
        case +n <> +m SNil{} +n2 <> +m2:
          insert_find(T, kids, n, m, entry, c2, n2, m2)
        case n <> m SCon{h, t} q:
          {==}
    case Tr.Node{+c2, +kids, +other} SCon{+h, +t}:
      match w ws:
        case SNil{} Nil{}:
          {==}
        case SNil{} n <> m:
          {==}
        case SCon{+h2, +t2} +q:
          insert_find(T, other, SCon{h, t}, rest, entry, parent, SCon{h2, t2}, q)

# Building from a table yields exactly the prefix-filtered indexed table.
def build_find(-T: Data, +table: S.Table(T), +index: Nat, +ws: List<&2, String>) ->
    {Tr.find(T, Tr.build_go(T, table, index), "", ws, Nil{}) == filtered(T, table, index, ws) : List<&2, Tr.Candidate<T>>}:
  match table:
    case Nil{}:
      {==}
    case S.Route{+pattern, +tag} <> +rest:
      +entry = {Tr.Candidate{index, S.Route{pattern, tag}} : Tr.Candidate<T>}
      Equal.trans(List<&2, Tr.Candidate<T>>, Tr.find(T, Tr.insert(T, Tr.build_go(T, rest, 1n+index), "", Tr.pattern_key(pattern), entry, Nil{}), "", ws, Nil{}), include(T, prefix(Tr.pattern_key(pattern), ws), entry, Tr.find(T, Tr.build_go(T, rest, 1n+index), "", ws, Nil{})), filtered(T, S.Route{pattern, tag} <> rest, index, ws),
        insert_find(T, Tr.build_go(T, rest, 1n+index), "", Tr.pattern_key(pattern), entry, Nil{}, "", ws),
        Equal.cong(List<&2, Tr.Candidate<T>>, List<&2, Tr.Candidate<T>>, xs => include(T, prefix(Tr.pattern_key(pattern), ws), entry, xs), Tr.find(T, Tr.build_go(T, rest, 1n+index), "", ws, Nil{}), filtered(T, rest, 1n+index, ws), build_find(T, rest, 1n+index, ws)))

def candidates_filtered(-T: Data, +table: S.Table(T), +path: String) ->
    {Tr.candidates(T, Tr.build_trie(T, table), path) == filtered(T, table, 0n, Tr.query(path)) : List<&2, Tr.Candidate<T>>}:
  build_find(T, table, 0n, Tr.query(path))

def no_prefix(+pattern: P.Pattern, +path: String, +ps: P.Params,
    found: {P.match_path(pattern, path) == Some{ps} : Maybe<&2, P.Params>},
    decided: {prefix(Tr.pattern_key(pattern), Tr.query(path)) == False{} : Bool}) -> Empty:
  Core.false_true(Equal.trans(Bool, False{}, prefix(Tr.pattern_key(pattern), Tr.query(path)), True{}, Equal.sym(Bool, prefix(Tr.pattern_key(pattern), Tr.query(path)), False{}, decided), pattern_prefix(pattern, path, ps, found)))

# Skipped entries cannot match, so the first match is unchanged.
def first_step(-T: Data, +pattern: P.Pattern, +tag: T, +index: Nat, +path: String, +xs: List<&2, Tr.Candidate<T>>, +ys: List<&2, Tr.Candidate<T>>,
    hit: Maybe<&2, P.Params>, +found: {P.match_path(pattern, path) == hit : Maybe<&2, P.Params>},
    test: Bool, +decided: {prefix(Tr.pattern_key(pattern), Tr.query(path)) == test : Bool},
    same_rest: {Tr.first(T, xs, path) == Tr.first(T, ys, path) : Maybe<&2, S.Match<T>>}) ->
    {Tr.first(T, include(T, prefix(Tr.pattern_key(pattern), Tr.query(path)), Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.candidate_hit(T, index, tag, P.match_path(pattern, path), u => Tr.first(T, ys, path)) : Maybe<&2, S.Match<T>>}:
  match hit test:
    case Some{+ps} True{}:
      %Equal.sym(Bool, prefix(Tr.pattern_key(pattern), Tr.query(path)), True{}, decided) : {Tr.first(T, include(T, _, Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.candidate_hit(T, index, tag, P.match_path(pattern, path), u => Tr.first(T, ys, path)) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Maybe<&2, P.Params>, P.match_path(pattern, path), Some{ps}, found) : {Tr.candidate_hit(T, index, tag, _, u => Tr.first(T, xs, path)) == Tr.candidate_hit(T, index, tag, _, u => Tr.first(T, ys, path)) : Maybe<&2, S.Match<T>>}
      {==}
    case Some{+ps} False{}:
      Core.absurd({Tr.first(T, include(T, prefix(Tr.pattern_key(pattern), Tr.query(path)), Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.candidate_hit(T, index, tag, P.match_path(pattern, path), u => Tr.first(T, ys, path)) : Maybe<&2, S.Match<T>>}, no_prefix(pattern, path, ps, found, decided))
    case None{} True{}:
      %Equal.sym(Bool, prefix(Tr.pattern_key(pattern), Tr.query(path)), True{}, decided) : {Tr.first(T, include(T, _, Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.candidate_hit(T, index, tag, P.match_path(pattern, path), u => Tr.first(T, ys, path)) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Maybe<&2, P.Params>, P.match_path(pattern, path), None{}, found) : {Tr.candidate_hit(T, index, tag, _, u => Tr.first(T, xs, path)) == Tr.candidate_hit(T, index, tag, _, u => Tr.first(T, ys, path)) : Maybe<&2, S.Match<T>>}
      same_rest
    case None{} False{}:
      %Equal.sym(Bool, prefix(Tr.pattern_key(pattern), Tr.query(path)), False{}, decided) : {Tr.first(T, include(T, _, Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.candidate_hit(T, index, tag, P.match_path(pattern, path), u => Tr.first(T, ys, path)) : Maybe<&2, S.Match<T>>}
      %Equal.sym(Maybe<&2, P.Params>, P.match_path(pattern, path), None{}, found) : {Tr.first(T, xs, path) == Tr.candidate_hit(T, index, tag, _, u => Tr.first(T, ys, path)) : Maybe<&2, S.Match<T>>}
      same_rest

def drop_first(-T: Data, +table: S.Table(T), +index: Nat, +path: String) ->
    {Tr.first(T, filtered(T, table, index, Tr.query(path)), path) == Tr.first(T, Tr.indexed(T, table, index), path) : Maybe<&2, S.Match<T>>}:
  match table:
    case Nil{}:
      {==}
    case S.Route{+pattern, +tag} <> +rest:
      first_step(T, pattern, tag, index, path, filtered(T, rest, 1n+index, Tr.query(path)), Tr.indexed(T, rest, 1n+index), P.match_path(pattern, path), {==}, prefix(Tr.pattern_key(pattern), Tr.query(path)), {==}, drop_first(T, rest, 1n+index, path))

def hits_step(-T: Data, +pattern: P.Pattern, +tag: T, +index: Nat, +path: String, +xs: List<&2, Tr.Candidate<T>>, +ys: List<&2, Tr.Candidate<T>>,
    hit: Maybe<&2, P.Params>, +found: {P.match_path(pattern, path) == hit : Maybe<&2, P.Params>},
    test: Bool, +decided: {prefix(Tr.pattern_key(pattern), Tr.query(path)) == test : Bool},
    same_rest: {Tr.hits(T, xs, path) == Tr.hits(T, ys, path) : List<&2, S.Match<T>>}) ->
    {Tr.hits(T, include(T, prefix(Tr.pattern_key(pattern), Tr.query(path)), Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.keep(T, index, tag, P.match_path(pattern, path), Tr.hits(T, ys, path)) : List<&2, S.Match<T>>}:
  match hit test:
    case Some{+ps} True{}:
      %Equal.sym(Bool, prefix(Tr.pattern_key(pattern), Tr.query(path)), True{}, decided) : {Tr.hits(T, include(T, _, Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.keep(T, index, tag, P.match_path(pattern, path), Tr.hits(T, ys, path)) : List<&2, S.Match<T>>}
      %Equal.sym(Maybe<&2, P.Params>, P.match_path(pattern, path), Some{ps}, found) : {Tr.keep(T, index, tag, _, Tr.hits(T, xs, path)) == Tr.keep(T, index, tag, _, Tr.hits(T, ys, path)) : List<&2, S.Match<T>>}
      Equal.cong(List<&2, S.Match<T>>, List<&2, S.Match<T>>, rs => S.Match{index, tag, ps} <> rs, Tr.hits(T, xs, path), Tr.hits(T, ys, path), same_rest)
    case Some{+ps} False{}:
      Core.absurd({Tr.hits(T, include(T, prefix(Tr.pattern_key(pattern), Tr.query(path)), Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.keep(T, index, tag, P.match_path(pattern, path), Tr.hits(T, ys, path)) : List<&2, S.Match<T>>}, no_prefix(pattern, path, ps, found, decided))
    case None{} True{}:
      %Equal.sym(Bool, prefix(Tr.pattern_key(pattern), Tr.query(path)), True{}, decided) : {Tr.hits(T, include(T, _, Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.keep(T, index, tag, P.match_path(pattern, path), Tr.hits(T, ys, path)) : List<&2, S.Match<T>>}
      %Equal.sym(Maybe<&2, P.Params>, P.match_path(pattern, path), None{}, found) : {Tr.keep(T, index, tag, _, Tr.hits(T, xs, path)) == Tr.keep(T, index, tag, _, Tr.hits(T, ys, path)) : List<&2, S.Match<T>>}
      same_rest
    case None{} False{}:
      %Equal.sym(Bool, prefix(Tr.pattern_key(pattern), Tr.query(path)), False{}, decided) : {Tr.hits(T, include(T, _, Tr.Candidate{index, S.Route{pattern, tag}}, xs), path) == Tr.keep(T, index, tag, P.match_path(pattern, path), Tr.hits(T, ys, path)) : List<&2, S.Match<T>>}
      %Equal.sym(Maybe<&2, P.Params>, P.match_path(pattern, path), None{}, found) : {Tr.hits(T, xs, path) == Tr.keep(T, index, tag, _, Tr.hits(T, ys, path)) : List<&2, S.Match<T>>}
      same_rest

def drop_hits(-T: Data, +table: S.Table(T), +index: Nat, +path: String) ->
    {Tr.hits(T, filtered(T, table, index, Tr.query(path)), path) == Tr.hits(T, Tr.indexed(T, table, index), path) : List<&2, S.Match<T>>}:
  match table:
    case Nil{}:
      {==}
    case S.Route{+pattern, +tag} <> +rest:
      hits_step(T, pattern, tag, index, path, filtered(T, rest, 1n+index, Tr.query(path)), Tr.indexed(T, rest, 1n+index), P.match_path(pattern, path), {==}, prefix(Tr.pattern_key(pattern), Tr.query(path)), {==}, drop_hits(T, rest, 1n+index, path))

# Relating candidate indexes to the reference router's relative indexes.
def shift(-T: Data, i: Nat, hit: Maybe<&2, S.Match<T>>) -> Maybe<&2, S.Match<T>>:
  match i:
    case 0n:
      hit
    case 1n+p:
      S.bump(T, shift(T, p, hit))

def shift_none(-T: Data, +i: Nat) -> {shift(T, i, None{}) == None{} : Maybe<&2, S.Match<T>>}:
  match i:
    case 0n:
      {==}
    case 1n+p:
      %Equal.sym(Maybe<&2, S.Match<T>>, shift(T, p, None{}), None{}, shift_none(T, p)) : {S.bump(T, _) == None{} : Maybe<&2, S.Match<T>>}
      {==}

def shift_hit(-T: Data, +i: Nat, +tag: T, +ps: P.Params) -> {shift(T, i, Some{S.Match{0n, tag, ps}}) == Some{S.Match{i, tag, ps}} : Maybe<&2, S.Match<T>>}:
  match i:
    case 0n:
      {==}
    case 1n+p:
      %Equal.sym(Maybe<&2, S.Match<T>>, shift(T, p, Some{S.Match{0n, tag, ps}}), Some{S.Match{p, tag, ps}}, shift_hit(T, p, tag, ps)) : {S.bump(T, _) == Some{S.Match{1n+p, tag, ps}} : Maybe<&2, S.Match<T>>}
      {==}

def shift_bump(-T: Data, +i: Nat, +hit: Maybe<&2, S.Match<T>>) -> {S.bump(T, shift(T, i, hit)) == shift(T, i, S.bump(T, hit)) : Maybe<&2, S.Match<T>>}:
  match i:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Maybe<&2, S.Match<T>>, Maybe<&2, S.Match<T>>, x => S.bump(T, x), S.bump(T, shift(T, p, hit)), shift(T, p, S.bump(T, hit)), shift_bump(T, p, hit))

def indexed_step(-T: Data, +pattern: P.Pattern, +tag: T, +index: Nat, +path: String, +rest: S.Table(T),
    hit: Maybe<&2, P.Params>, +found: {P.match_path(pattern, path) == hit : Maybe<&2, P.Params>},
    inner: {Tr.first(T, Tr.indexed(T, rest, 1n+index), path) == shift(T, 1n+index, S.route(T, rest, path)) : Maybe<&2, S.Match<T>>}) ->
    {Tr.candidate_hit(T, index, tag, P.match_path(pattern, path), u => Tr.first(T, Tr.indexed(T, rest, 1n+index), path)) == shift(T, index, S.select(T, tag, P.match_path(pattern, path), u => S.route(T, rest, path))) : Maybe<&2, S.Match<T>>}:
  match hit:
    case Some{+ps}:
      %Equal.sym(Maybe<&2, P.Params>, P.match_path(pattern, path), Some{ps}, found) : {Tr.candidate_hit(T, index, tag, _, u => Tr.first(T, Tr.indexed(T, rest, 1n+index), path)) == shift(T, index, S.select(T, tag, _, u => S.route(T, rest, path))) : Maybe<&2, S.Match<T>>}
      Equal.sym(Maybe<&2, S.Match<T>>, shift(T, index, Some{S.Match{0n, tag, ps}}), Some{S.Match{index, tag, ps}}, shift_hit(T, index, tag, ps))
    case None{}:
      %Equal.sym(Maybe<&2, P.Params>, P.match_path(pattern, path), None{}, found) : {Tr.candidate_hit(T, index, tag, _, u => Tr.first(T, Tr.indexed(T, rest, 1n+index), path)) == shift(T, index, S.select(T, tag, _, u => S.route(T, rest, path))) : Maybe<&2, S.Match<T>>}
      Equal.trans(Maybe<&2, S.Match<T>>, Tr.first(T, Tr.indexed(T, rest, 1n+index), path), S.bump(T, shift(T, index, S.route(T, rest, path))), shift(T, index, S.bump(T, S.route(T, rest, path))), inner, shift_bump(T, index, S.route(T, rest, path)))

def first_indexed(-T: Data, +table: S.Table(T), +index: Nat, +path: String) ->
    {Tr.first(T, Tr.indexed(T, table, index), path) == shift(T, index, S.route(T, table, path)) : Maybe<&2, S.Match<T>>}:
  match table:
    case Nil{}:
      Equal.sym(Maybe<&2, S.Match<T>>, shift(T, index, None{}), None{}, shift_none(T, index))
    case S.Route{+pattern, +tag} <> +rest:
      indexed_step(T, pattern, tag, index, path, rest, P.match_path(pattern, path), {==}, first_indexed(T, rest, 1n+index, path))

# Main results.
def route_equal(-T: Data, +table: S.Table(T), +path: String) ->
    {Tr.trie_route(T, Tr.build_trie(T, table), path) == S.route(T, table, path) : Maybe<&2, S.Match<T>>}:
  %Equal.sym(List<&2, Tr.Candidate<T>>, Tr.candidates(T, Tr.build_trie(T, table), path), filtered(T, table, 0n, Tr.query(path)), candidates_filtered(T, table, path)) : {Tr.first(T, _, path) == S.route(T, table, path) : Maybe<&2, S.Match<T>>}
  Equal.trans(Maybe<&2, S.Match<T>>, Tr.first(T, filtered(T, table, 0n, Tr.query(path)), path), Tr.first(T, Tr.indexed(T, table, 0n), path), S.route(T, table, path), drop_first(T, table, 0n, path), first_indexed(T, table, 0n, path))

def matches_indexed(-T: Data, +table: S.Table(T), +path: String) ->
    {Tr.matches(T, Tr.build_trie(T, table), path) == Tr.hits(T, Tr.indexed(T, table, 0n), path) : List<&2, S.Match<T>>}:
  %Equal.sym(List<&2, Tr.Candidate<T>>, Tr.candidates(T, Tr.build_trie(T, table), path), filtered(T, table, 0n, Tr.query(path)), candidates_filtered(T, table, path)) : {Tr.hits(T, _, path) == Tr.hits(T, Tr.indexed(T, table, 0n), path) : List<&2, S.Match<T>>}
  drop_hits(T, table, 0n, path)

def keep_found(-T: Data, +i: Nat, +tag: T, +hit: Maybe<&2, P.Params>, +rest: List<&2, S.Match<T>>) ->
    {Tr.keep(T, i, tag, hit, rest) == SpecProof.found(T, i, tag, hit, rest) : List<&2, S.Match<T>>}:
  match hit:
    case None{}:
      {==}
    case Some{ps}:
      {==}

def hits_indexed(-T: Data, +table: S.Table(T), +index: Nat, +path: String) ->
    {Tr.hits(T, Tr.indexed(T, table, index), path) == SpecProof.matching_from(T, table, path, index) : List<&2, S.Match<T>>}:
  match table:
    case Nil{}:
      {==}
    case S.Route{+pattern, +tag} <> +rest:
      Equal.trans(List<&2, S.Match<T>>, Tr.keep(T, index, tag, P.match_path(pattern, path), Tr.hits(T, Tr.indexed(T, rest, 1n+index), path)), Tr.keep(T, index, tag, P.match_path(pattern, path), SpecProof.matching_from(T, rest, path, 1n+index)), SpecProof.found(T, index, tag, P.match_path(pattern, path), SpecProof.matching_from(T, rest, path, 1n+index)),
        Equal.cong(List<&2, S.Match<T>>, List<&2, S.Match<T>>, xs => Tr.keep(T, index, tag, P.match_path(pattern, path), xs), Tr.hits(T, Tr.indexed(T, rest, 1n+index), path), SpecProof.matching_from(T, rest, path, 1n+index), hits_indexed(T, rest, 1n+index, path)),
        keep_found(T, index, tag, P.match_path(pattern, path), SpecProof.matching_from(T, rest, path, 1n+index)))

def matches_equal(-T: Data, +table: S.Table(T), +path: String) ->
    {Tr.matches(T, Tr.build_trie(T, table), path) == SpecProof.matching(T, table, path) : List<&2, S.Match<T>>}:
  Equal.trans(List<&2, S.Match<T>>, Tr.matches(T, Tr.build_trie(T, table), path), Tr.hits(T, Tr.indexed(T, table, 0n), path), SpecProof.matching(T, table, path), matches_indexed(T, table, path), hits_indexed(T, table, 0n, path))
