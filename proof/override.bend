# BND-40: method override rewrites only POST, only to listed unsafe methods.
import Base
import ../src/mw/method_override_policy.bend as P
import ../src/http/request.bend as Request
import ../src/http/bytes.bend as Bytes
import ./override-spec.bend as Spec
import ./csrf-spec.bend as CsrfSpec
import ../src/http/text.bend as Text
import ./text.bend as TP

def distinguish(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : distinguish(_)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

def true_false(e: {True{} == False{} : Bool}) -> Empty:
  false_true(Equal.sym(Bool, True{}, False{}, e))

def and_left(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}: e
    case True{}: {==}

def and_right(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}: absurd({b == True{} : Bool}, false_true(e))
    case True{}: e

def not_true(+b: Bool, e: {Bool.not(b) == True{} : Bool}) -> {b == False{} : Bool}:
  match b:
    case True{}: absurd({True{} == False{} : Bool}, false_true(e))
    case False{}: {==}

# What every outcome must satisfy: a rewrite comes from POST, goes to a
# method CSRF still inspects, and is listed.
def sound(+allowed: List<&2, Request.Method>, +wire: Request.Method, o: P.Outcome) -> Bool:
  match o:
    case P.Keep{}: True{}
    case P.Rewrite{+m}: ((Spec.is_post(wire) && Bool.not(CsrfSpec.reads_only(m))) && Spec.listed(m, allowed)) && Bool.not(Spec.named_safe(Request.method_text(m)))
    case P.Reject{}: True{}

def member(+m: Request.Method, +xs: List<&2, Request.Method>) -> {P.member(m, xs) == Spec.listed(m, xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> +t:
      %member(m, t) : {P.same(m, x) || P.member(m, t) == String.eq(Request.method_text(x), Request.method_text(m)) || _ : Bool}
      {==}

def listed_sound(+m: Request.Method, +allowed: List<&2, Request.Method>, +b: Bool, e: {P.member(m, allowed) == b : Bool}, nr: {CsrfSpec.reads_only(m) == False{} : Bool}, ns: {Spec.named_safe(Request.method_text(m)) == False{} : Bool}) -> {sound(allowed, Request.Post{}, P.listed(m, b)) == True{} : Bool}:
  match b:
    case False{}: {==}
    case True{}:
      +lt = Equal.trans(Bool, Spec.listed(m, allowed), P.member(m, allowed), True{}, Equal.sym(Bool, P.member(m, allowed), Spec.listed(m, allowed), member(m, allowed)), e)
      %Equal.sym(Bool, CsrfSpec.reads_only(m), False{}, nr) : {((Spec.is_post(Request.Post{}) && Bool.not(_)) && Spec.listed(m, allowed)) && Bool.not(Spec.named_safe(Request.method_text(m))) == True{} : Bool}
      %Equal.sym(Bool, Spec.listed(m, allowed), True{}, lt) : {((True{} && True{}) && _) && Bool.not(Spec.named_safe(Request.method_text(m))) == True{} : Bool}
      %Equal.sym(Bool, Spec.named_safe(Request.method_text(m)), False{}, ns) : {((True{} && True{}) && True{}) && Bool.not(_) == True{} : Bool}
      {==}

def ext_sound(+allowed: List<&2, Request.Method>, +t: String, +s: Bool, es: {P.safe_name(t) == s : Bool}) -> {sound(allowed, Request.Post{}, P.listed(Request.Extension{t}, Bool.not(s) && P.member(Request.Extension{t}, allowed))) == True{} : Bool}:
  match s:
    case True{}: {==}
    case False{}: listed_sound(Request.Extension{t}, allowed, P.member(Request.Extension{t}, allowed), {==}, {==}, es)

def chosen_sound(+allowed: List<&2, Request.Method>, +m: Request.Method) -> {sound(allowed, Request.Post{}, P.chosen(allowed, m)) == True{} : Bool}:
  match m:
    case Request.Get{}: {==}
    case Request.Head{}: {==}
    case Request.Post{}: {==}
    case Request.Put{}: listed_sound(Request.Put{}, allowed, P.member(Request.Put{}, allowed), {==}, {==}, {==})
    case Request.Delete{}: listed_sound(Request.Delete{}, allowed, P.member(Request.Delete{}, allowed), {==}, {==}, {==})
    case Request.Connect{}: {==}
    case Request.Options{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: listed_sound(Request.Patch{}, allowed, P.member(Request.Patch{}, allowed), {==}, {==}, {==})
    case Request.Extension{+t}: ext_sound(allowed, t, P.safe_name(t), {==})

def named_sound(+allowed: List<&2, Request.Method>, +s: String) -> {sound(allowed, Request.Post{}, P.named(allowed, s)) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{+h, +t}: chosen_sound(allowed, Request.method(Text.upper(SCon{h, t})))

def single_sound(+allowed: List<&2, Request.Method>, +v: String, +rest: List<&2, String>) -> {sound(allowed, Request.Post{}, P.single(allowed, v, rest)) == True{} : Bool}:
  match rest:
    case Nil{}: named_sound(allowed, String.trim(v))
    case w <> u: {==}

def posted_sound(+allowed: List<&2, Request.Method>, +values: List<&2, String>) -> {sound(allowed, Request.Post{}, P.posted(allowed, values)) == True{} : Bool}:
  match values:
    case Nil{}: {==}
    case +v <> +t: single_sound(allowed, v, t)

def decide_sound(+allowed: List<&2, Request.Method>, +wire: Request.Method, +values: List<&2, String>) -> {sound(allowed, wire, P.decide(allowed, wire, values)) == True{} : Bool}:
  match wire:
    case Request.Get{}: {==}
    case Request.Head{}: {==}
    case Request.Post{}: posted_sound(allowed, values)
    case Request.Put{}: {==}
    case Request.Delete{}: {==}
    case Request.Connect{}: {==}
    case Request.Options{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: {==}
    case Request.Extension{t}: {==}

def rewritten(+allowed: List<&2, Request.Method>, +wire: Request.Method, +values: List<&2, String>, +m: Request.Method, h: {P.decide(allowed, wire, values) == P.Rewrite{m} : P.Outcome}) -> {sound(allowed, wire, P.Rewrite{m}) == True{} : Bool}:
  %h : {sound(allowed, wire, _) == True{} : Bool}
  decide_sound(allowed, wire, values)

def only_post(+allowed: List<&2, Request.Method>, +wire: Request.Method, +values: List<&2, String>, +m: Request.Method, h: {P.decide(allowed, wire, values) == P.Rewrite{m} : P.Outcome}) -> {Spec.is_post(wire) == True{} : Bool}:
  +a = Spec.is_post(wire)
  +b = Bool.not(CsrfSpec.reads_only(m))
  +c = Spec.listed(m, allowed)
  +d = Bool.not(Spec.named_safe(Request.method_text(m)))
  and_left(a, b, and_left(a && b, c, and_left((a && b) && c, d, rewritten(allowed, wire, values, m, h))))

def unsafe_destination(+allowed: List<&2, Request.Method>, +wire: Request.Method, +values: List<&2, String>, +m: Request.Method, h: {P.decide(allowed, wire, values) == P.Rewrite{m} : P.Outcome}) -> {CsrfSpec.reads_only(m) == False{} : Bool}:
  +a = Spec.is_post(wire)
  +b = Bool.not(CsrfSpec.reads_only(m))
  +c = Spec.listed(m, allowed)
  +d = Bool.not(Spec.named_safe(Request.method_text(m)))
  not_true(CsrfSpec.reads_only(m), and_right(a, b, and_left(a && b, c, and_left((a && b) && c, d, rewritten(allowed, wire, values, m, h)))))

def destination_listed(+allowed: List<&2, Request.Method>, +wire: Request.Method, +values: List<&2, String>, +m: Request.Method, h: {P.decide(allowed, wire, values) == P.Rewrite{m} : P.Outcome}) -> {Spec.listed(m, allowed) == True{} : Bool}:
  +a = Spec.is_post(wire)
  +b = Bool.not(CsrfSpec.reads_only(m))
  +c = Spec.listed(m, allowed)
  +d = Bool.not(Spec.named_safe(Request.method_text(m)))
  and_right(a && b, c, and_left((a && b) && c, d, rewritten(allowed, wire, values, m, h)))

def safe_name_excluded(+allowed: List<&2, Request.Method>, +wire: Request.Method, +values: List<&2, String>, +m: Request.Method, h: {P.decide(allowed, wire, values) == P.Rewrite{m} : P.Outcome}) -> {Spec.named_safe(Request.method_text(m)) == False{} : Bool}:
  +a = Spec.is_post(wire)
  +b = Bool.not(CsrfSpec.reads_only(m))
  +c = Spec.listed(m, allowed)
  +d = Bool.not(Spec.named_safe(Request.method_text(m)))
  not_true(Spec.named_safe(Request.method_text(m)), and_right((a && b) && c, d, rewritten(allowed, wire, values, m, h)))

def repeated(+allowed: List<&2, Request.Method>, +v: String, +w: String, +rest: List<&2, String>) -> {P.decide(allowed, Request.Post{}, v <> (w <> rest)) == P.Reject{} : P.Outcome}:
  {==}

def non_post(+allowed: List<&2, Request.Method>, +wire: Request.Method, +values: List<&2, String>, h: {Spec.is_post(wire) == False{} : Bool}) -> {P.decide(allowed, wire, values) == P.Keep{} : P.Outcome}:
  match wire:
    case Request.Get{}: {==}
    case Request.Head{}: {==}
    case Request.Post{}: absurd({P.decide(allowed, Request.Post{}, values) == P.Keep{} : P.Outcome}, true_false(h))
    case Request.Put{}: {==}
    case Request.Delete{}: {==}
    case Request.Connect{}: {==}
    case Request.Options{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: {==}
    case Request.Extension{t}: {==}

def kept_unsafe(+m: Request.Method, +rest: List<&2, Request.Method>, +tok: Bool, ih: {Spec.all_unsafe(rest) == True{} : Bool}) -> {Spec.all_unsafe(P.kept(m, rest, P.destination(m) && tok)) == True{} : Bool}:
  match m:
    case Request.Get{}: ih
    case Request.Head{}: ih
    case Request.Post{}: ih
    case Request.Put{}:
      match tok:
        case True{}: ih
        case False{}: ih
    case Request.Delete{}:
      match tok:
        case True{}: ih
        case False{}: ih
    case Request.Connect{}: ih
    case Request.Options{}: ih
    case Request.Trace{}: ih
    case Request.Patch{}:
      match tok:
        case True{}: ih
        case False{}: ih
    case Request.Extension{t}:
      match tok:
        case True{}: ih
        case False{}: ih

def allowlist(+xs: List<&2, String>) -> {Spec.all_unsafe(P.allowlist(xs)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> +t: kept_unsafe(P.parse(x), P.allowlist(t), Bytes.token(Request.method_text(P.parse(x))), allowlist(t))

# ---- The whole decision ----

def wrap(+m: Request.Method, +b: Bool) -> {P.listed(m, b) == Spec.granted(m, b) : P.Outcome}:
  match b:
    case True{}: {==}
    case False{}: {==}

def granted(+m: Request.Method, +allowed: List<&2, Request.Method>) -> {P.listed(m, P.member(m, allowed)) == Spec.granted(m, Spec.listed(m, allowed)) : P.Outcome}:
  Equal.trans(P.Outcome, P.listed(m, P.member(m, allowed)), Spec.granted(m, P.member(m, allowed)), Spec.granted(m, Spec.listed(m, allowed)), wrap(m, P.member(m, allowed)), Equal.cong(Bool, P.Outcome, b => Spec.granted(m, b), P.member(m, allowed), Spec.listed(m, allowed), member(m, allowed)))

def ext_eq(+allowed: List<&2, Request.Method>, +t: String, +s: Bool) -> {P.listed(Request.Extension{t}, Bool.not(s) && P.member(Request.Extension{t}, allowed)) == Spec.judged(allowed, Request.Extension{t}, s) : P.Outcome}:
  match s:
    case True{}: {==}
    case False{}: granted(Request.Extension{t}, allowed)

def chosen_pick(+allowed: List<&2, Request.Method>, +m: Request.Method) -> {P.chosen(allowed, m) == Spec.pick(allowed, m, Spec.is_post(m), Spec.named_safe(Request.method_text(m))) : P.Outcome}:
  match m:
    case Request.Get{}: {==}
    case Request.Head{}: {==}
    case Request.Post{}: {==}
    case Request.Put{}: granted(Request.Put{}, allowed)
    case Request.Delete{}: granted(Request.Delete{}, allowed)
    case Request.Connect{}: {==}
    case Request.Options{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: granted(Request.Patch{}, allowed)
    case Request.Extension{+t}: ext_eq(allowed, t, P.safe_name(t))

def named_one(+allowed: List<&2, Request.Method>, +s: String) -> {P.named(allowed, s) == Spec.one(allowed, s) : P.Outcome}:
  match s:
    case SNil{}: {==}
    case SCon{+h, +t}:
      %TP.upper_equiv(SCon{h, t}) : {P.chosen(allowed, Request.method(Text.upper(SCon{h, t}))) == Spec.pick(allowed, Request.method(_), Spec.is_post(Request.method(_)), Spec.named_safe(Request.method_text(Request.method(_)))) : P.Outcome}
      chosen_pick(allowed, Request.method(Text.upper(SCon{h, t})))

# The decision equals the specification for every allowlist, method and
# list of submitted values.
def decide_spec(+allowed: List<&2, Request.Method>, +wire: Request.Method, +values: List<&2, String>) -> {P.decide(allowed, wire, values) == Spec.decide(allowed, wire, values) : P.Outcome}:
  match wire:
    case Request.Get{}: {==}
    case Request.Head{}: {==}
    case Request.Post{}:
      match values:
        case Nil{}: {==}
        case +v <> +t:
          match t:
            case Nil{}: named_one(allowed, String.trim(v))
            case w <> u: {==}
    case Request.Put{}: {==}
    case Request.Delete{}: {==}
    case Request.Connect{}: {==}
    case Request.Options{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: {==}
    case Request.Extension{t}: {==}
