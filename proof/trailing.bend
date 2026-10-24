# BND-40: trailing-slash targets are safe same-origin paths for GET and HEAD.
import Base
import ../src/mw/trailing_slash_policy.bend as P
import ../src/http/request.bend as Request
import ./trailing-spec.bend as Spec
import ./csrf-spec.bend as CsrfSpec
import ./fold-tail.bend as FoldTail
import ./misc-tail.bend as MiscTail

def distinguish(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : distinguish(_)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

def and_left(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}: e
    case True{}: {==}

def and_right(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}: absurd({b == True{} : Bool}, false_true(e))
    case True{}: e

# ---- The guard is the specification ----

def clean_inner(+s: String) -> {P.clean_spec(s) == Spec.plain(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}:
      %clean_inner(t) : {Bool.not(P.unsafe_char(Chr{x})) && P.clean_spec(t) == Bool.not(Spec.resolver_char(Chr{x})) && _ : Bool}
      {==}

def clean(+s: String) -> {P.clean(s) == Spec.plain(s) : Bool}:
  Equal.trans(Bool, P.clean(s), P.clean_spec(s), Spec.plain(s), FoldTail.ts_clean_equiv(s), clean_inner(s))

def second(+s: String) -> {P.second(s) == Spec.not_slash(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{c, t}: {==}

def safe(+s: String) -> {P.safe(s) == Spec.same_origin_path(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      %second(t) : {(Char.is_eq(c, '/') && P.second(t)) && P.clean(SCon{c, t}) == (Char.is_eq(c, '/') && _) && Spec.plain(SCon{c, t}) : Bool}
      %clean(SCon{c, t}) : {(Char.is_eq(c, '/') && P.second(t)) && P.clean(SCon{c, t}) == (Char.is_eq(c, '/') && P.second(t)) && _ : Bool}
      {==}

# ---- Every produced target is safe and answers GET or HEAD ----

def out_ok(o: Maybe<&2, String>) -> Bool:
  match o:
    case None{}: True{}
    case Some{l}: Spec.same_origin_path(l)

def sound(+m: Request.Method, o: Maybe<&2, String>) -> Bool:
  match o:
    case None{}: True{}
    case Some{l}: CsrfSpec.reads_only(m) && Spec.same_origin_path(l)

def guard_ok(+loc: String, +b: Bool, e: {P.safe(loc) == b : Bool}) -> {out_ok(P.guarded(loc, b)) == True{} : Bool}:
  match b:
    case False{}: {==}
    case True{}: Equal.trans(Bool, Spec.same_origin_path(loc), P.safe(loc), True{}, Equal.sym(Bool, P.safe(loc), Spec.same_origin_path(loc), safe(loc)), e)

def checked_ok(+loc: String) -> {out_ok(P.checked(loc)) == True{} : Bool}:
  guard_ok(loc, P.safe(loc), {==})

def located_ok(+base: Maybe<&2, String>, +q: Maybe<&2, String>) -> {out_ok(P.located(base, q)) == True{} : Bool}:
  match base:
    case None{}: {==}
    case Some{+b}: checked_ok(b ++ Request.query_text(q))

def appended_ok(+path: String, +q: Maybe<&2, String>, +ends: Bool) -> {out_ok(P.appended(path, q, ends)) == True{} : Bool}:
  match ends:
    case True{}: {==}
    case False{}: checked_ok(path ++ ("/" ++ Request.query_text(q)))

def moved_ok(+mode: P.Mode, +path: String, +q: Maybe<&2, String>) -> {out_ok(P.moved(mode, path, q)) == True{} : Bool}:
  match mode:
    case P.Trim{}: located_ok(P.trim_last(path), q)
    case P.Append{}: appended_ok(path, q, P.final_slash(path))

def lift(+m: Request.Method, +x: Maybe<&2, String>, r: {CsrfSpec.reads_only(m) == True{} : Bool}, ok: {out_ok(x) == True{} : Bool}) -> {sound(m, x) == True{} : Bool}:
  match x:
    case None{}: {==}
    case Some{+l}:
      %Equal.sym(Bool, CsrfSpec.reads_only(m), True{}, r) : {_ && Spec.same_origin_path(l) == True{} : Bool}
      ok

def target_ok(+mode: P.Mode, +m: Request.Method, +path: String, +q: Maybe<&2, String>) -> {sound(m, P.target(mode, m, path, q)) == True{} : Bool}:
  match m:
    case Request.Get{}: lift(Request.Get{}, P.moved(mode, path, q), {==}, moved_ok(mode, path, q))
    case Request.Head{}: lift(Request.Head{}, P.moved(mode, path, q), {==}, moved_ok(mode, path, q))
    case Request.Post{}: {==}
    case Request.Put{}: {==}
    case Request.Delete{}: {==}
    case Request.Connect{}: {==}
    case Request.Options{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: {==}
    case Request.Extension{t}: {==}

def produced(+mode: P.Mode, +m: Request.Method, +path: String, +q: Maybe<&2, String>, +loc: String, h: {P.target(mode, m, path, q) == Some{loc} : Maybe<&2, String>}) -> {sound(m, Some{loc}) == True{} : Bool}:
  %h : {sound(m, _) == True{} : Bool}
  target_ok(mode, m, path, q)

def redirect_safe(+mode: P.Mode, +m: Request.Method, +path: String, +q: Maybe<&2, String>, +loc: String, h: {P.target(mode, m, path, q) == Some{loc} : Maybe<&2, String>}) -> {Spec.same_origin_path(loc) == True{} : Bool}:
  and_right(CsrfSpec.reads_only(m), Spec.same_origin_path(loc), produced(mode, m, path, q, loc, h))

def redirect_reads(+mode: P.Mode, +m: Request.Method, +path: String, +q: Maybe<&2, String>, +loc: String, h: {P.target(mode, m, path, q) == Some{loc} : Maybe<&2, String>}) -> {CsrfSpec.reads_only(m) == True{} : Bool}:
  and_left(CsrfSpec.reads_only(m), Spec.same_origin_path(loc), produced(mode, m, path, q, loc, h))

# ---- The targets themselves ----

def root_query(+q: Maybe<&2, String>) -> {P.located(P.trim_last("/"), q) == None{} : Maybe<&2, String>}:
  match q:
    case None{}: {==}
    case Some{s}: {==}

def root(+m: Request.Method, +q: Maybe<&2, String>) -> {P.target(P.Trim{}, m, "/", q) == None{} : Maybe<&2, String>}:
  match m:
    case Request.Get{}: root_query(q)
    case Request.Head{}: root_query(q)
    case Request.Post{}: {==}
    case Request.Put{}: {==}
    case Request.Delete{}: {==}
    case Request.Connect{}: {==}
    case Request.Options{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: {==}
    case Request.Extension{t}: {==}

def trim_step_spec(+c: Char, +t: String, ih: {P.trim_last_spec(t ++ "/") == Some{t} : Maybe<&2, String>}) -> {P.trim_last_spec(SCon{c, t} ++ "/") == Some{SCon{c, t}} : Maybe<&2, String>}:
  match t:
    case SNil{}: {==}
    case SCon{+d, +u}:
      %Equal.sym(Maybe<&2, String>, P.trim_last_spec(SCon{d, u} ++ "/"), Some{SCon{d, u}}, ih) : {P.prefixed(c, _) == Some{SCon{c, SCon{d, u}}} : Maybe<&2, String>}
      {==}



def trim_last_inner(+base: String) -> {P.trim_last_spec(base ++ "/") == Some{base} : Maybe<&2, String>}:
  match base:
    case SNil{}: {==}
    case SCon{+c, +t}: trim_step_spec(c, t, trim_last_inner(t))

def trim_last(+base: String) -> {P.trim_last(base ++ "/") == Some{base} : Maybe<&2, String>}:
  Equal.trans(Maybe<&2, String>, P.trim_last(base ++ "/"), P.trim_last_spec(base ++ "/"), Some{base}, MiscTail.trim_last_equiv(base ++ "/"), trim_last_inner(base))

def checked_some(+loc: String, ok: {Spec.same_origin_path(loc) == True{} : Bool}) -> {P.checked(loc) == Some{loc} : Maybe<&2, String>}:
  +e = Equal.trans(Bool, P.safe(loc), Spec.same_origin_path(loc), True{}, safe(loc), ok)
  %Equal.sym(Bool, P.safe(loc), True{}, e) : {P.guarded(loc, _) == Some{loc} : Maybe<&2, String>}
  {==}

def trimmed(+base: String, +q: Maybe<&2, String>, ok: {Spec.same_origin_path(base ++ Request.query_text(q)) == True{} : Bool}) -> {P.moved(P.Trim{}, base ++ "/", q) == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}:
  %Equal.sym(Maybe<&2, String>, P.trim_last(base ++ "/"), Some{base}, trim_last(base)) : {P.located(_, q) == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}
  checked_some(base ++ Request.query_text(q), ok)

# A GET or HEAD for base + "/" moves to base with the same raw query,
# whenever that target is a safe same-origin path.
def trim_target(+base: String, +q: Maybe<&2, String>, +m: Request.Method, r: {CsrfSpec.reads_only(m) == True{} : Bool}, ok: {Spec.same_origin_path(base ++ Request.query_text(q)) == True{} : Bool}) -> {P.target(P.Trim{}, m, base ++ "/", q) == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}:
  match m:
    case Request.Get{}: trimmed(base, q, ok)
    case Request.Head{}: trimmed(base, q, ok)
    case Request.Post{}: absurd({None{} == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}, false_true(r))
    case Request.Put{}: absurd({None{} == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}, false_true(r))
    case Request.Delete{}: absurd({None{} == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}, false_true(r))
    case Request.Connect{}: absurd({None{} == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}, false_true(r))
    case Request.Options{}: absurd({None{} == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}, false_true(r))
    case Request.Trace{}: absurd({None{} == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}, false_true(r))
    case Request.Patch{}: absurd({None{} == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}, false_true(r))
    case Request.Extension{t}: absurd({None{} == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}, false_true(r))

def step_eq(+c: Char, +t: String, +x: Bool) -> {P.slash_step(c, t, x) == Spec.ends_here(c, t, x) : Bool}:
  match t:
    case SNil{}: {==}
    case SCon{d, u}: {==}

def final_eq_inner(+s: String) -> {P.final_slash_spec(s) == Spec.final_slash(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      %final_eq_inner(t) : {P.slash_step(c, t, P.final_slash_spec(t)) == Spec.ends_here(c, t, _) : Bool}
      step_eq(c, t, P.final_slash_spec(t))

def final_eq(+s: String) -> {P.final_slash(s) == Spec.final_slash(s) : Bool}:
  Equal.trans(Bool, P.final_slash(s), P.final_slash_spec(s), Spec.final_slash(s), MiscTail.final_slash_equiv(s), final_eq_inner(s))

def appended(+path: String, +q: Maybe<&2, String>, ends: {Spec.final_slash(path) == False{} : Bool}, ok: {Spec.same_origin_path(path ++ ("/" ++ Request.query_text(q))) == True{} : Bool}) -> {P.moved(P.Append{}, path, q) == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}:
  +e = Equal.trans(Bool, P.final_slash(path), Spec.final_slash(path), False{}, final_eq(path), ends)
  %Equal.sym(Bool, P.final_slash(path), False{}, e) : {P.appended(path, q, _) == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}
  checked_some(path ++ ("/" ++ Request.query_text(q)), ok)

# A GET or HEAD for a path without a final '/' moves to path + "/" with the
# same raw query, whenever that target is a safe same-origin path.
def append_target(+path: String, +q: Maybe<&2, String>, +m: Request.Method, r: {CsrfSpec.reads_only(m) == True{} : Bool}, ends: {Spec.final_slash(path) == False{} : Bool}, ok: {Spec.same_origin_path(path ++ ("/" ++ Request.query_text(q))) == True{} : Bool}) -> {P.target(P.Append{}, m, path, q) == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}:
  match m:
    case Request.Get{}: appended(path, q, ends, ok)
    case Request.Head{}: appended(path, q, ends, ok)
    case Request.Post{}: absurd({None{} == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}, false_true(r))
    case Request.Put{}: absurd({None{} == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}, false_true(r))
    case Request.Delete{}: absurd({None{} == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}, false_true(r))
    case Request.Connect{}: absurd({None{} == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}, false_true(r))
    case Request.Options{}: absurd({None{} == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}, false_true(r))
    case Request.Trace{}: absurd({None{} == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}, false_true(r))
    case Request.Patch{}: absurd({None{} == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}, false_true(r))
    case Request.Extension{t}: absurd({None{} == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}, false_true(r))

# ---- The full target ----

def only_eq(+b: Bool) -> {P.slash_only(b) == Spec.empty_if(b) : Maybe<&2, String>}:
  match b:
    case True{}: {==}
    case False{}: {==}

def prefix_eq(+c: Char, +d: Char, +u: String, +x: Maybe<&2, String>) -> {P.prefixed(c, x) == Spec.last_dropped(c, SCon{d, u}, x) : Maybe<&2, String>}:
  match x:
    case None{}: {==}
    case Some{b}: {==}

def drop_eq(+c: Char, +t: String, +x: Maybe<&2, String>) -> {P.trim_step(c, t, x) == Spec.last_dropped(c, t, x) : Maybe<&2, String>}:
  match t:
    case SNil{}: only_eq(Char.is_eq(c, '/'))
    case SCon{+d, +u}: prefix_eq(c, d, u, x)

def init_eq_inner(+s: String) -> {P.trim_last_spec(s) == Spec.before_final_slash(s) : Maybe<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      %init_eq_inner(t) : {P.trim_step(c, t, P.trim_last_spec(t)) == Spec.last_dropped(c, t, _) : Maybe<&2, String>}
      drop_eq(c, t, P.trim_last_spec(t))

def init_eq(+s: String) -> {P.trim_last(s) == Spec.before_final_slash(s) : Maybe<&2, String>}:
  Equal.trans(Maybe<&2, String>, P.trim_last(s), P.trim_last_spec(s), Spec.before_final_slash(s), MiscTail.trim_last_equiv(s), init_eq_inner(s))

def guard_eq(+loc: String, +b: Bool) -> {P.guarded(loc, b) == Spec.offered(loc, b) : Maybe<&2, String>}:
  match b:
    case True{}: {==}
    case False{}: {==}

def checked_eq(+loc: String) -> {P.checked(loc) == Spec.offer(loc) : Maybe<&2, String>}:
  %safe(loc) : {P.guarded(loc, P.safe(loc)) == Spec.offered(loc, _) : Maybe<&2, String>}
  guard_eq(loc, P.safe(loc))

def located_eq(+base: Maybe<&2, String>, +q: Maybe<&2, String>) -> {P.located(base, q) == Spec.trimmed(base, q) : Maybe<&2, String>}:
  match base:
    case None{}: {==}
    case Some{+b}: checked_eq(b ++ Request.query_text(q))

def appended_eq(+path: String, +q: Maybe<&2, String>, +x: Bool) -> {P.appended(path, q, x) == Spec.extended(path, q, x) : Maybe<&2, String>}:
  match x:
    case True{}: {==}
    case False{}: checked_eq(path ++ ("/" ++ Request.query_text(q)))

def moved_eq(+mode: P.Mode, +path: String, +q: Maybe<&2, String>) -> {P.moved(mode, path, q) == Spec.moved(mode, path, q) : Maybe<&2, String>}:
  match mode:
    case P.Trim{}:
      %init_eq(path) : {P.located(P.trim_last(path), q) == Spec.trimmed(_, q) : Maybe<&2, String>}
      located_eq(P.trim_last(path), q)
    case P.Append{}:
      %final_eq(path) : {P.appended(path, q, P.final_slash(path)) == Spec.extended(path, q, _) : Maybe<&2, String>}
      appended_eq(path, q, P.final_slash(path))

# The target equals the specification for every mode, method, path and query.
def target_spec(+mode: P.Mode, +m: Request.Method, +path: String, +q: Maybe<&2, String>) -> {P.target(mode, m, path, q) == Spec.target(mode, m, path, q) : Maybe<&2, String>}:
  match m:
    case Request.Get{}: moved_eq(mode, path, q)
    case Request.Head{}: moved_eq(mode, path, q)
    case Request.Post{}: {==}
    case Request.Put{}: {==}
    case Request.Delete{}: {==}
    case Request.Connect{}: {==}
    case Request.Options{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: {==}
    case Request.Extension{t}: {==}
