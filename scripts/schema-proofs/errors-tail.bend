
# The laws: a rejection lists between one and error_cap() errors, each at a
# location the specification finds failing, and names every such location
# unless it already holds error_cap() errors.

def rev_count(+xs: List<&2, S.Error>, +acc: List<&2, S.Error>) -> {Spec.error_count(List.reverse.go(&2, S.Error, xs, acc)) == Nat.add(Spec.error_count(xs), Spec.error_count(acc)) : Nat}:
  match xs:
    case Nil{}: {==}
    case e <> t:
      %A.add_succ_r(Spec.error_count(t), Spec.error_count(acc)) : {Spec.error_count(List.reverse.go(&2, S.Error, t, e <> acc)) == _ : Nat}
      rev_count(t, e <> acc)

def rev_empty(+xs: List<&2, S.Error>, +acc: List<&2, S.Error>) -> {empty(List.reverse.go(&2, S.Error, xs, acc)) == (empty(xs) && empty(acc)) : Bool}:
  match xs:
    case Nil{}: {==}
    case e <> t: Equal.trans(Bool, empty(List.reverse.go(&2, S.Error, t, e <> acc)), (empty(t) && False{}), False{}, rev_empty(t, e <> acc), and_false(empty(t)))

def rev_all(+xs: List<&2, S.Error>, +acc: List<&2, S.Error>, +s: S.Schema, +v: J.Json) -> {Spec.all_located(List.reverse.go(&2, S.Error, xs, acc), s, v) == (Spec.all_located(xs, s, v) && Spec.all_located(acc, s, v)) : Bool}:
  match xs:
    case Nil{}: {==}
    case S.Error{c0, m0, p0} <> t:
      %Equal.sym(Bool, ((Spec.error_at(s, v, p0) && Spec.all_located(t, s, v)) && Spec.all_located(acc, s, v)), (Spec.all_located(t, s, v) && (Spec.error_at(s, v, p0) && Spec.all_located(acc, s, v))), swap3(Spec.error_at(s, v, p0), Spec.all_located(t, s, v), Spec.all_located(acc, s, v))) : {Spec.all_located(List.reverse.go(&2, S.Error, t, S.Error{c0, m0, p0} <> acc), s, v) == _ : Bool}
      rev_all(t, S.Error{c0, m0, p0} <> acc, s, v)

def or_swap3(+a: Bool, +b: Bool, -c: Bool) -> {((a || b) || c) == (b || (a || c)) : Bool}:
  match a b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def rev_names(+xs: List<&2, S.Error>, +acc: List<&2, S.Error>, +path: List<&2, S.PathPart>) -> {Spec.names(List.reverse.go(&2, S.Error, xs, acc), path) == (Spec.names(xs, path) || Spec.names(acc, path)) : Bool}:
  match xs:
    case Nil{}: {==}
    case S.Error{c0, m0, p0} <> t:
      %Equal.sym(Bool, ((Spec.same_path(p0, path) || Spec.names(t, path)) || Spec.names(acc, path)), (Spec.names(t, path) || (Spec.same_path(p0, path) || Spec.names(acc, path))), or_swap3(Spec.same_path(p0, path), Spec.names(t, path), Spec.names(acc, path))) : {Spec.names(List.reverse.go(&2, S.Error, t, S.Error{c0, m0, p0} <> acc), path) == _ : Bool}
      rev_names(t, S.Error{c0, m0, p0} <> acc, path)

def located_here(+es: List<&2, S.Error>, +s: S.Schema, +v: J.Json, +hok: {Spec.schema_ok(s) == True{} : Bool}) -> {Spec.all_located(es, s, v) == all_here(es, s, v) : Bool}:
  match es:
    case Nil{}: {==}
    case S.Error{c0, m0, p0} <> t:
      %Equal.sym(Bool, Spec.schema_ok(s), True{}, hok) : {(Spec.located(_, s, v, p0) && Spec.all_located(t, s, v)) == (Spec.fault(s, v, p0, Spec.Here{}) && all_here(t, s, v)) : Bool}
      %located_here(t, s, v, hok) : {(Spec.fault(s, v, p0, Spec.Here{}) && Spec.all_located(t, s, v)) == (Spec.fault(s, v, p0, Spec.Here{}) && _) : Bool}
      {==}

def rl_eq(+es: List<&2, S.Error>, +s: S.Schema, +v: J.Json) -> {Spec.rejection_located(es, s, v) == (Bool.not(empty(es)) && (Nat.is_le(Spec.error_count(es), Spec.error_cap()) && Spec.all_located(es, s, v))) : Bool}:
  match es:
    case Nil{}: {==}
    case e <> t: {==}

def located_out(+s: S.Schema, +v: J.Json, +o: S.Out, hq: {clean(o) == False{} : Bool}, hsz: {size(o) == Spec.error_cap() : Nat}, hs: {all_here(revs(o), s, v) == True{} : Bool}, hok: {Spec.schema_ok(s) == True{} : Bool}) -> {Spec.rejection_located(S.listed(o), s, v) == True{} : Bool}:
  match o:
    case S.Out{+r, +l}:
      %Equal.sym(Bool, Spec.rejection_located(List.reverse.go(&2, S.Error, r, []), s, v), (Bool.not(empty(List.reverse.go(&2, S.Error, r, []))) && (Nat.is_le(Spec.error_count(List.reverse.go(&2, S.Error, r, [])), Spec.error_cap()) && Spec.all_located(List.reverse.go(&2, S.Error, r, []), s, v))), rl_eq(List.reverse.go(&2, S.Error, r, []), s, v)) : {_ == True{} : Bool}
      %Equal.sym(Bool, empty(List.reverse.go(&2, S.Error, r, [])), (empty(r) && True{}), rev_empty(r, [])) : {(Bool.not(_) && (Nat.is_le(Spec.error_count(List.reverse.go(&2, S.Error, r, [])), Spec.error_cap()) && Spec.all_located(List.reverse.go(&2, S.Error, r, []), s, v))) == True{} : Bool}
      %SP.and_true(empty(r)) : {(Bool.not(_) && (Nat.is_le(Spec.error_count(List.reverse.go(&2, S.Error, r, [])), Spec.error_cap()) && Spec.all_located(List.reverse.go(&2, S.Error, r, []), s, v))) == True{} : Bool}
      %Equal.sym(Bool, empty(r), False{}, hq) : {(Bool.not(_) && (Nat.is_le(Spec.error_count(List.reverse.go(&2, S.Error, r, [])), Spec.error_cap()) && Spec.all_located(List.reverse.go(&2, S.Error, r, []), s, v))) == True{} : Bool}
      %Equal.sym(Nat, Spec.error_count(List.reverse.go(&2, S.Error, r, [])), Nat.add(Spec.error_count(r), 0n), rev_count(r, [])) : {(Nat.is_le(_, Spec.error_cap()) && Spec.all_located(List.reverse.go(&2, S.Error, r, []), s, v)) == True{} : Bool}
      %Equal.sym(Bool, Spec.all_located(List.reverse.go(&2, S.Error, r, []), s, v), (Spec.all_located(r, s, v) && True{}), rev_all(r, [], s, v)) : {(Nat.is_le(Nat.add(Spec.error_count(r), 0n), Spec.error_cap()) && _) == True{} : Bool}
      %Equal.sym(Bool, Spec.all_located(r, s, v), all_here(r, s, v), located_here(r, s, v, hok)) : {(Nat.is_le(Nat.add(Spec.error_count(r), 0n), Spec.error_cap()) && (_ && True{})) == True{} : Bool}
      %Equal.sym(Bool, all_here(r, s, v), True{}, hs) : {(Nat.is_le(Nat.add(Spec.error_count(r), 0n), Spec.error_cap()) && (_ && True{})) == True{} : Bool}
      %Equal.sym(Nat, Nat.add(Spec.error_count(r), 0n), Spec.error_count(r), A.add_zero_r(Spec.error_count(r))) : {(Nat.is_le(_, Spec.error_cap()) && True{}) == True{} : Bool}
      and_both(Nat.is_le(Spec.error_count(r), Spec.error_cap()), True{}, A.le_add_r(Spec.error_count(r), l, Spec.error_cap(), Equal.trans(Bool, Nat.is_le(Nat.add(Spec.error_count(r), l), Spec.error_cap()), Nat.is_le(Spec.error_cap(), Spec.error_cap()), True{}, Equal.cong(Nat, Bool, z => Nat.is_le(z, Spec.error_cap()), Nat.add(Spec.error_count(r), l), Spec.error_cap(), hsz), A.le_refl(Spec.error_cap()))), {==})

def schema_false(+s: S.Schema, hb: {S.valid(s) == False{} : Bool}) -> {Spec.schema_ok(s) == False{} : Bool}:
  Equal.trans(Bool, Spec.schema_ok(s), S.valid(s), False{}, Equal.sym(Bool, S.valid(s), Spec.schema_ok(s), SC.valid_equiv(s)), hb)

def schema_true(+s: S.Schema, hb: {S.valid(s) == True{} : Bool}) -> {Spec.schema_ok(s) == True{} : Bool}:
  Equal.trans(Bool, Spec.schema_ok(s), S.valid(s), True{}, Equal.sym(Bool, S.valid(s), Spec.schema_ok(s), SC.valid_equiv(s)), hb)

# The top-level walk reports nothing exactly when the value meets the schema.
def top_clean(+s: S.Schema, +v: J.Json, +okv: {S.valid(s) == True{} : Bool}) -> {clean(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap()))) == Spec.meets(s, Spec.Holds{}, v) : Bool}:
  Equal.trans(Bool, clean(S.collect_go(s, v, S.cstart(s, v, 1n+99n))), expect_c(s, S.cstart(s, v, 1n+99n), v), Spec.meets(s, Spec.Holds{}, v), quiet(s, v, S.cstart(s, v, 1n+99n), okv, cstart_live(s, v, 99n)), entry_c(s, v, 99n))

def top_size(+s: S.Schema, +v: J.Json) -> {size(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap()))) == Spec.error_cap() : Nat}:
  Equal.trans(Nat, size(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap()))), wsize(S.cstart(s, v, Spec.error_cap())), Spec.error_cap(), sized(s, v, S.cstart(s, v, Spec.error_cap())), cstart_size(s, v, Spec.error_cap()))

def located_fail(+s: S.Schema, +v: J.Json, b: Bool, +hb: {S.valid(s) == b : Bool}, hsat: {False{} == Spec.satisfies(s, v) : Bool}) -> {Spec.rejection_located(S.errors(s, v, b), s, v) == True{} : Bool}:
  match b:
    case False{}:
      %Equal.sym(Bool, Spec.schema_ok(s), False{}, schema_false(s, hb)) : {(Nat.is_le(1n, Spec.error_cap()) && (Spec.located(_, s, v, []) && True{})) == True{} : Bool}
      {==}
    case True{}: located_out(s, v, S.collect_go(s, v, S.cstart(s, v, Spec.error_cap())), Equal.trans(Bool, clean(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap()))), Spec.meets(s, Spec.Holds{}, v), False{}, top_clean(s, v, hb), Equal.sym(Bool, False{}, Spec.meets(s, Spec.Holds{}, v), Equal.trans(Bool, False{}, Spec.satisfies(s, v), Spec.meets(s, Spec.Holds{}, v), hsat, Equal.cong(Bool, Bool, z => (z && Spec.meets(s, Spec.Holds{}, v)), Spec.schema_ok(s), True{}, schema_true(s, hb))))), top_size(s, v), entry_s(s, v, Spec.error_cap(), sound(s, v, S.cstart(s, v, Spec.error_cap()), hb, cstart_reach(s, v, Spec.error_cap()))), schema_true(s, hb))

def located_go(+s: S.Schema, +v: J.Json, r: Result<&2, &2, S.Errors(), S.Value>, ha: {S.accepted(r) == Spec.satisfies(s, v) : Bool}) -> {Spec.located_errors(s, v, S.report(r, s, v)) == True{} : Bool}:
  match r:
    case Done{x}: {==}
    case Fail{e}: located_fail(s, v, S.valid(s), {==}, ha)

# BND-35 law: a rejection's errors name failing locations.
def errors_located(+s: S.Schema, +v: J.Json) -> {Spec.located_errors(s, v, S.decode(s, v)) == True{} : Bool}:
  located_go(s, v, S.decode_first(s, v), SC.first_spec(s, v))

def at_fault(+s: S.Schema, +v: J.Json, +path: List<&2, S.PathPart>, hok: {Spec.schema_ok(s) == True{} : Bool}, he: {Spec.error_at(s, v, path) == True{} : Bool}) -> {Spec.fault(s, v, path, Spec.Here{}) == True{} : Bool}:
  Equal.trans(Bool, Spec.fault(s, v, path, Spec.Here{}), Spec.located(Spec.schema_ok(s), s, v, path), True{}, Equal.cong(Bool, Bool, z => Spec.located(z, s, v, path), True{}, Spec.schema_ok(s), Equal.sym(Bool, Spec.schema_ok(s), True{}, hok)), he)

def top_found(+s: S.Schema, +v: J.Json, +path: List<&2, S.PathPart>, +okv: {S.valid(s) == True{} : Bool}, hf: {Spec.fault(s, v, path, Spec.Here{}) == True{} : Bool}) -> {found(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap())), path) == True{} : Bool}:
  entry_k(s, v, Spec.error_cap(), path, hf, hs => complete(s, v, S.cstart(s, v, Spec.error_cap()), okv, cstart_reach(s, v, Spec.error_cap()), path, hs))

def found_dirty(+o: S.Out, +path: List<&2, S.PathPart>, hf: {found(o, path) == True{} : Bool}, hsz: {size(o) == Spec.error_cap() : Nat}, hc: {clean(o) == True{} : Bool}) -> Empty:
  match o:
    case S.Out{Nil{}, l}: UP.false_true(Equal.trans(Bool, False{}, Nat.is_eq(l, 0n), True{}, Equal.cong(Nat, Bool, z => Nat.is_eq(z, 0n), Spec.error_cap(), l, Equal.sym(Nat, l, Spec.error_cap(), hsz)), hf))
    case S.Out{e <> t, l}: UP.false_true(hc)

def full_le(+r: List<&2, S.Error>, +l: Nat, hz: {Nat.is_eq(l, 0n) == True{} : Bool}, hsz: {Nat.add(Spec.error_count(r), l) == Spec.error_cap() : Nat}) -> {Nat.is_le(Spec.error_cap(), Spec.error_count(List.reverse.go(&2, S.Error, r, []))) == True{} : Bool}:
  match l:
    case 0n:
      %Equal.sym(Nat, Spec.error_count(List.reverse.go(&2, S.Error, r, [])), Nat.add(Spec.error_count(r), 0n), rev_count(r, [])) : {Nat.is_le(Spec.error_cap(), _) == True{} : Bool}
      %Equal.sym(Nat, Nat.add(Spec.error_count(r), 0n), Spec.error_cap(), hsz) : {Nat.is_le(Spec.error_cap(), _) == True{} : Bool}
      A.le_refl(Spec.error_cap())
    case 1n+j: UP.absurd({Nat.is_le(Spec.error_cap(), Spec.error_count(List.reverse.go(&2, S.Error, r, []))) == True{} : Bool}, UP.false_true(hz))


def reported_out(+o: S.Out, +path: List<&2, S.PathPart>, hf: {found(o, path) == True{} : Bool}, hsz: {size(o) == Spec.error_cap() : Nat}) -> {Spec.reported(Fail{S.listed(o)}, path) == True{} : Bool}:
  match o:
    case S.Out{+r, +l}: or_elim(Spec.names(r, path), Nat.is_eq(l, 0n), {Spec.reported(Fail{S.listed(S.Out{r, l})}, path) == True{} : Bool}, hf, hn => or_right(Nat.is_le(Spec.error_cap(), Spec.error_count(List.reverse.go(&2, S.Error, r, []))), Spec.names(List.reverse.go(&2, S.Error, r, []), path), Equal.trans(Bool, Spec.names(List.reverse.go(&2, S.Error, r, []), path), (Spec.names(r, path) || False{}), True{}, rev_names(r, [], path), Equal.trans(Bool, (Spec.names(r, path) || False{}), Spec.names(r, path), True{}, Equal.sym(Bool, Spec.names(r, path), (Spec.names(r, path) || False{}), SP.or_false(Spec.names(r, path))), hn))), hz => or_left(Nat.is_le(Spec.error_cap(), Spec.error_count(List.reverse.go(&2, S.Error, r, []))), Spec.names(List.reverse.go(&2, S.Error, r, []), path), full_le(r, l, hz, hsz)))

def invalid_reported(+s: S.Schema, +v: J.Json, +path: List<&2, S.PathPart>, he: {Spec.ends(path) == True{} : Bool}) -> {Spec.reported(Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]}, path) == True{} : Bool}:
  match path:
    case Nil{}: {==}
    case g <> r: UP.absurd({Spec.reported(Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]}, g <> r) == True{} : Bool}, UP.false_true(he))


def complete_fail(+s: S.Schema, +v: J.Json, +path: List<&2, S.PathPart>, b: Bool, +hb: {S.valid(s) == b : Bool}, he: {Spec.error_at(s, v, path) == True{} : Bool}) -> {Spec.reported(Fail{S.errors(s, v, b)}, path) == True{} : Bool}:
  match b:
    case False{}: invalid_reported(s, v, path, Equal.trans(Bool, Spec.ends(path), Spec.located(Spec.schema_ok(s), s, v, path), True{}, Equal.cong(Bool, Bool, z => Spec.located(z, s, v, path), False{}, Spec.schema_ok(s), Equal.sym(Bool, Spec.schema_ok(s), False{}, schema_false(s, hb))), he))
    case True{}: reported_out(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap())), path, top_found(s, v, path, hb, at_fault(s, v, path, schema_true(s, hb), he)), top_size(s, v))

def accepted_unreported(+s: S.Schema, +v: J.Json, +x: S.Value, +path: List<&2, S.PathPart>, +hs: {Spec.satisfies(s, v) == True{} : Bool}, he: {Spec.error_at(s, v, path) == True{} : Bool}) -> {Spec.reported(Done{x}, path) == True{} : Bool}:
  UP.absurd({Spec.reported(Done{x}, path) == True{} : Bool}, found_dirty(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap())), path, top_found(s, v, path, Equal.trans(Bool, S.valid(s), Spec.schema_ok(s), True{}, SC.valid_equiv(s), UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs)), at_fault(s, v, path, UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs), he)), top_size(s, v), Equal.trans(Bool, clean(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap()))), Spec.meets(s, Spec.Holds{}, v), True{}, top_clean(s, v, Equal.trans(Bool, S.valid(s), Spec.schema_ok(s), True{}, SC.valid_equiv(s), UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs))), UP.and_right(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs))))

# BND-35 law: every failing location is reported, unless the list is full.

def complete_go(+s: S.Schema, +v: J.Json, r: Result<&2, &2, S.Errors(), S.Value>, ha: {S.accepted(r) == Spec.satisfies(s, v) : Bool}, +path: List<&2, S.PathPart>, he: {Spec.error_at(s, v, path) == True{} : Bool}) -> {Spec.reported(S.report(r, s, v), path) == True{} : Bool}:
  match r:
    case Done{x}: accepted_unreported(s, v, x, path, Equal.sym(Bool, True{}, Spec.satisfies(s, v), ha), he)
    case Fail{e}: complete_fail(s, v, path, S.valid(s), {==}, he)

def errors_complete(+s: S.Schema, +v: J.Json, +path: List<&2, S.PathPart>, he: {Spec.error_at(s, v, path) == True{} : Bool}) -> {Spec.reported(S.decode(s, v), path) == True{} : Bool}:
  complete_go(s, v, S.decode_first(s, v), SC.first_spec(s, v), path, he)
