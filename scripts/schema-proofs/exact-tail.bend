# The top-level walk fills the whole enumeration into an empty list.
def exact_top(+s: S.Schema, +v: J.Json, +okv: {S.valid(s) == True{} : Bool}) -> {proj(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap()))) == fill(Spec.failures(s, v, Spec.Node{}), PO{[], Spec.error_cap()}) : PO}:
  child(s, v, Spec.error_cap(), exact(s, v, S.cstart(s, v, Spec.error_cap()), okv))

# Reading the list back in order.

def po_rev(o: PO) -> List<&2, List<&2, S.PathPart>>:
  match o:
    case PO{r, l}: r

def fill_first(+f: List<&2, List<&2, S.PathPart>>, +x: List<&2, List<&2, S.PathPart>>, +l: Nat) -> {po_rev(fill(f, PO{x, l})) == List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), x) : List<&2, List<&2, S.PathPart>>}:
  match f l:
    case Nil{} n: {==}
    case p <> t 0n: {==}
    case p <> t 1n+n: fill_first(t, p <> x, n)

def paths_rev(+es: List<&2, S.Error>, +acc: List<&2, S.Error>) -> {Spec.paths(List.reverse.go(&2, S.Error, es, acc)) == List.reverse.go(&2, List<&2, S.PathPart>, Spec.paths(es), Spec.paths(acc)) : List<&2, List<&2, S.PathPart>>}:
  match es:
    case Nil{}: {==}
    case S.Error{c, m, p} <> t: paths_rev(t, S.Error{c, m, p} <> acc)

def rev_rev(+xs: List<&2, List<&2, S.PathPart>>, +acc: List<&2, List<&2, S.PathPart>>, +ys: List<&2, List<&2, S.PathPart>>) -> {List.reverse.go(&2, List<&2, S.PathPart>, List.reverse.go(&2, List<&2, S.PathPart>, xs, acc), ys) == List.reverse.go(&2, List<&2, S.PathPart>, acc, Spec.join(xs, ys)) : List<&2, List<&2, S.PathPart>>}:
  match xs:
    case Nil{}: {==}
    case p <> t: rev_rev(t, p <> acc, ys)

def join_nil(+xs: List<&2, List<&2, S.PathPart>>) -> {Spec.join(xs, []) == xs : List<&2, List<&2, S.PathPart>>}:
  match xs:
    case Nil{}: {==}
    case p <> t: Equal.cong(List<&2, List<&2, S.PathPart>>, List<&2, List<&2, S.PathPart>>, z => p <> z, Spec.join(t, []), t, join_nil(t))

# The errors a filled walk lists, in order, are the first l of f.
def listed_first(+o: S.Out, +f: List<&2, List<&2, S.PathPart>>, +l: Nat, h: {proj(o) == fill(f, PO{[], l}) : PO}) -> {Spec.paths(S.listed(o)) == Spec.first_paths(f, l) : List<&2, List<&2, S.PathPart>>}:
  match o:
    case S.Out{+r, +n}:
      Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.paths(List.reverse.go(&2, S.Error, r, [])), List.reverse.go(&2, List<&2, S.PathPart>, List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), []), Spec.first_paths(f, l), Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.paths(List.reverse.go(&2, S.Error, r, [])), List.reverse.go(&2, List<&2, S.PathPart>, Spec.paths(r), []), List.reverse.go(&2, List<&2, S.PathPart>, List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), []), paths_rev(r, []), Equal.cong(List<&2, List<&2, S.PathPart>>, List<&2, List<&2, S.PathPart>>, z => List.reverse.go(&2, List<&2, S.PathPart>, z, []), Spec.paths(r), List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.paths(r), po_rev(fill(f, PO{[], l})), List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), Equal.cong(PO, List<&2, List<&2, S.PathPart>>, z => po_rev(z), PO{Spec.paths(r), n}, fill(f, PO{[], l}), h), fill_first(f, [], l)))), Equal.trans(List<&2, List<&2, S.PathPart>>, List.reverse.go(&2, List<&2, S.PathPart>, List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), []), Spec.join(Spec.first_paths(f, l), []), Spec.first_paths(f, l), rev_rev(Spec.first_paths(f, l), [], []), join_nil(Spec.first_paths(f, l))))

# A walk that lists nothing with budget left had nothing to visit.

def po_empty(o: PO) -> Bool:
  match o:
    case PO{Nil{}, l}: True{}
    case PO{p <> r, l}: False{}

def fill_dirty(+f: List<&2, List<&2, S.PathPart>>, +q: List<&2, S.PathPart>, +x: List<&2, List<&2, S.PathPart>>, +l: Nat) -> {po_empty(fill(f, PO{q <> x, l})) == False{} : Bool}:
  match f l:
    case Nil{} n: {==}
    case p <> t 0n: {==}
    case p <> t 1n+n: fill_dirty(t, p, q <> x, n)

def nothing_left(+o: S.Out, +f: List<&2, List<&2, S.PathPart>>, +n: Nat, h: {proj(o) == fill(f, PO{[], 1n+n}) : PO}, hc: {SE.clean(o) == True{} : Bool}) -> {f == [] : List<&2, List<&2, S.PathPart>>}:
  match o f:
    case S.Out{r, l} Nil{}: {==}
    case S.Out{Nil{}, +l} +p <> +t: UP.absurd({p <> t == [] : List<&2, List<&2, S.PathPart>>}, UP.false_true(Equal.sym(Bool, True{}, False{}, Equal.trans(Bool, True{}, po_empty(fill(t, PO{[p], n})), False{}, Equal.cong(PO, Bool, z => po_empty(z), PO{[], l}, fill(t, PO{[p], n}), h), fill_dirty(t, p, [], n)))))
    case S.Out{e <> r, l} +p <> +t: UP.absurd({p <> t == [] : List<&2, List<&2, S.PathPart>>}, UP.false_true(hc))

# The laws.

def schema_true(+s: S.Schema, hb: {S.valid(s) == True{} : Bool}) -> {Spec.schema_ok(s) == True{} : Bool}:
  Equal.trans(Bool, Spec.schema_ok(s), S.valid(s), True{}, Equal.sym(Bool, S.valid(s), Spec.schema_ok(s), SC.valid_equiv(s)), hb)

def schema_false(+s: S.Schema, hb: {S.valid(s) == False{} : Bool}) -> {Spec.schema_ok(s) == False{} : Bool}:
  Equal.trans(Bool, Spec.schema_ok(s), S.valid(s), False{}, Equal.sym(Bool, S.valid(s), Spec.schema_ok(s), SC.valid_equiv(s)), hb)

def ok_paths(+s: S.Schema, +v: J.Json, -a: List<&2, List<&2, S.PathPart>>, hok: {Spec.schema_ok(s) == True{} : Bool}, h: {a == Spec.first_paths(Spec.failures(s, v, Spec.Node{}), Spec.error_cap()) : List<&2, List<&2, S.PathPart>>}) -> {a == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  Equal.trans(List<&2, List<&2, S.PathPart>>, a, Spec.located_paths(True{}, s, v), Spec.located_paths(Spec.schema_ok(s), s, v), h, Equal.cong(Bool, List<&2, List<&2, S.PathPart>>, z => Spec.located_paths(z, s, v), True{}, Spec.schema_ok(s), Equal.sym(Bool, Spec.schema_ok(s), True{}, hok)))

def fail_exact(+s: S.Schema, +v: J.Json, b: Bool, +hb: {S.valid(s) == b : Bool}) -> {Spec.paths(S.errors(s, v, b)) == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  match b:
    case False{}: Equal.cong(Bool, List<&2, List<&2, S.PathPart>>, z => Spec.located_paths(z, s, v), False{}, Spec.schema_ok(s), Equal.sym(Bool, Spec.schema_ok(s), False{}, schema_false(s, hb)))
    case True{}: ok_paths(s, v, Spec.paths(S.collect(s, v)), schema_true(s, hb), listed_first(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap())), Spec.failures(s, v, Spec.Node{}), Spec.error_cap(), exact_top(s, v, hb)))

def accepted_exact(+s: S.Schema, +v: J.Json, +hs: {Spec.satisfies(s, v) == True{} : Bool}) -> {[] == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  ok_paths(s, v, [], UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs), Equal.cong(List<&2, List<&2, S.PathPart>>, List<&2, List<&2, S.PathPart>>, z => Spec.first_paths(z, Spec.error_cap()), [], Spec.failures(s, v, Spec.Node{}), Equal.sym(List<&2, List<&2, S.PathPart>>, Spec.failures(s, v, Spec.Node{}), [], nothing_left(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap())), Spec.failures(s, v, Spec.Node{}), 99n, exact_top(s, v, Equal.trans(Bool, S.valid(s), Spec.schema_ok(s), True{}, SC.valid_equiv(s), UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs))), Equal.trans(Bool, SE.clean(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap()))), Spec.meets(s, Spec.Holds{}, v), True{}, SE.top_clean(s, v, Equal.trans(Bool, S.valid(s), Spec.schema_ok(s), True{}, SC.valid_equiv(s), UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs))), UP.and_right(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs))))))

def exact_go(+s: S.Schema, +v: J.Json, r: Result<&2, &2, S.Errors(), S.Value>, ha: {S.accepted(r) == Spec.satisfies(s, v) : Bool}) -> {Spec.listed_paths(S.report(r, s, v)) == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  match r:
    case Done{x}: accepted_exact(s, v, Equal.sym(Bool, True{}, Spec.satisfies(s, v), ha))
    case Fail{e}: fail_exact(s, v, S.valid(s), {==})

# BND-89 law: the decoder lists exactly the specification's paths.
def errors_exact(+s: S.Schema, +v: J.Json) -> {Spec.listed_paths(S.decode(s, v)) == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  exact_go(s, v, S.decode_first(s, v), SC.first_spec(s, v))

def coerced_exact(+s: S.Schema, +v: J.Json) -> {Spec.listed_paths(S.decode_from(S.TextSource{}, s, v)) == Spec.error_paths(s, Spec.coerce_text(s, v)) : List<&2, List<&2, S.PathPart>>}:
  Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.listed_paths(S.decode_from(S.TextSource{}, s, v)), Spec.listed_paths(S.decode(s, Spec.coerce_text(s, v))), Spec.error_paths(s, Spec.coerce_text(s, v)), Equal.cong(Result<&2, &2, S.Errors(), S.Value>, List<&2, List<&2, S.PathPart>>, z => Spec.listed_paths(z), S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), SCo.text_spec(s, v)), errors_exact(s, Spec.coerce_text(s, v)))

def invalid_go(+s: S.Schema, +v: J.Json, b: Bool, +hb: {S.valid(s) == b : Bool}, hf: {b == False{} : Bool}) -> {S.report(S.decode_valid(s, v, b), s, v) == Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]} : Result<&2, &2, S.Errors(), S.Value>}:
  match b:
    case True{}: UP.absurd({S.report(S.decode_valid(s, v, True{}), s, v) == Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]} : Result<&2, &2, S.Errors(), S.Value>}, UP.false_true(Equal.sym(Bool, True{}, False{}, hf)))
    case False{}: Equal.cong(Bool, Result<&2, &2, S.Errors(), S.Value>, z => Fail{S.errors(s, v, z)}, S.valid(s), False{}, hb)

# BND-89 law: an invalid schema is one error at the root, whatever the value.
def invalid_root(+s: S.Schema, +v: J.Json, h: {Spec.schema_ok(s) == False{} : Bool}) -> {S.decode(s, v) == Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]} : Result<&2, &2, S.Errors(), S.Value>}:
  invalid_go(s, v, S.valid(s), {==}, Equal.trans(Bool, S.valid(s), Spec.schema_ok(s), False{}, SC.valid_equiv(s), h))

def coerced_invalid_root(+s: S.Schema, +v: J.Json, h: {Spec.schema_ok(s) == False{} : Bool}) -> {S.decode_from(S.TextSource{}, s, v) == Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]} : Result<&2, &2, S.Errors(), S.Value>}:
  invalid_root(s, S.coerce(s, v), h)
