# BND-40: the CORS decision equals the independent specification.
import Base
import ../src/mw/cors_policy.bend as P
import ../src/http/request.bend as Request
import ../src/http/origin.bend as Origin
import ./origin-spec.bend as OriginSpec
import ./origin.bend as OriginProof
import ./cors-spec.bend as Spec

def is_none(-A: Data, m: Maybe<&2, A>) -> Type:
  match m:
    case None{}: Unit
    case Some{x}: Empty

# None is not Some.
def none_not_some(-A: Data, +x: A, e: {None{} == Some{x} : Maybe<&2, A>}) -> Empty:
  %e : is_none(A, _)
  Unit{}

def is_some(-A: Data, m: Maybe<&2, A>) -> Type:
  match m:
    case None{}: Empty
    case Some{x}: Unit

def some_not_none(-A: Data, +x: A, e: {Some{x} == None{} : Maybe<&2, A>}) -> Empty:
  %e : is_some(A, _)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

# ---- Grants ----

def pick(+o: String, +c: Bool, +t: List<&2, P.Entry>, +here: Bool, ih: {P.lookup(o, t) == Spec.credited(o, Spec.credentials_for(o, t)) : Maybe<&2, P.Grant>}) -> {P.lookup_pick(o, c, P.lookup(o, t), here) == Spec.credited(o, Spec.first_flag(c, Spec.credentials_for(o, t), here)) : Maybe<&2, P.Grant>}:
  match here:
    case True{}: {==}
    case False{}: ih

def lookup(+o: String, +es: List<&2, P.Entry>) -> {P.lookup(o, es) == Spec.credited(o, Spec.credentials_for(o, es)) : Maybe<&2, P.Grant>}:
  match es:
    case Nil{}: {==}
    case P.Entry{+x, +c} <> +t: pick(o, c, t, String.eq(x, o), lookup(o, t))

def listed(+es: List<&2, P.Entry>, +m: Maybe<&2, String>) -> {P.listed_grant(es, m) == Spec.found(m, es) : Maybe<&2, P.Grant>}:
  match m:
    case None{}: {==}
    case Some{+o}: lookup(o, es)

# The grant equals the specification for every policy and Origin field.
def grant(+origins: P.Origins, +sent: P.Sent) -> {P.grant(origins, sent) == Spec.grant(origins, sent) : Maybe<&2, P.Grant>}:
  match origins:
    case P.Any{}: {==}
    case P.Listed{+es}:
      match sent:
        case P.Absent{}: {==}
        case P.Sent{+v}: Equal.trans(Maybe<&2, P.Grant>, P.listed_grant(es, Origin.canonical(v)), Spec.found(Origin.canonical(v), es), Spec.found(OriginSpec.canonical(v), es), listed(es, Origin.canonical(v)), Equal.cong(Maybe<&2, String>, Maybe<&2, P.Grant>, m => Spec.found(m, es), Origin.canonical(v), OriginSpec.canonical(v), OriginProof.canonical_same(v)))
        case P.Repeated{}: {==}

def wildcard(+sent: P.Sent) -> {P.grant(P.Any{}, sent) == Some{P.Grant{"*", False{}}} : Maybe<&2, P.Grant>}:
  {==}

def unparsed(+es: List<&2, P.Entry>, +sent: P.Sent, h: {Spec.request_origin(sent) == None{} : Maybe<&2, String>}) -> {P.grant(P.Listed{es}, sent) == None{} : Maybe<&2, P.Grant>}:
  match sent:
    case P.Absent{}: {==}
    case P.Sent{+v}:
      %Equal.sym(Maybe<&2, String>, Origin.canonical(v), None{}, Equal.trans(Maybe<&2, String>, Origin.canonical(v), OriginSpec.canonical(v), None{}, OriginProof.canonical_same(v), h)) : {P.listed_grant(es, _) == None{} : Maybe<&2, P.Grant>}
      {==}
    case P.Repeated{}: {==}

# ---- A listed grant echoes the request's origin ----

def origin_of(g: Maybe<&2, P.Grant>) -> Maybe<&2, String>:
  match g:
    case None{}: None{}
    case Some{P.Grant{o, c}}: Some{o}

def keep(+o: String, here: Bool) -> Maybe<&2, String>:
  match here:
    case True{}: Some{o}
    case False{}: None{}

def found_in(+o: String, es: List<&2, P.Entry>) -> Bool:
  match es:
    case Nil{}: False{}
    case P.Entry{x, c} <> t: String.eq(x, o) || found_in(o, t)

def echo_pick(+o: String, +c: Bool, +t: List<&2, P.Entry>, +here: Bool, ih: {origin_of(P.lookup(o, t)) == keep(o, found_in(o, t)) : Maybe<&2, String>}) -> {origin_of(P.lookup_pick(o, c, P.lookup(o, t), here)) == keep(o, here || found_in(o, t)) : Maybe<&2, String>}:
  match here:
    case True{}: {==}
    case False{}: ih

def echo_lookup(+o: String, +es: List<&2, P.Entry>) -> {origin_of(P.lookup(o, es)) == keep(o, found_in(o, es)) : Maybe<&2, String>}:
  match es:
    case Nil{}: {==}
    case P.Entry{+x, +c} <> +t: echo_pick(o, c, t, String.eq(x, o), echo_lookup(o, t))

def echo_keep(+o: String, +o2: String, +b: Bool, h: {Some{o2} == keep(o, b) : Maybe<&2, String>}) -> {Some{o} == Some{o2} : Maybe<&2, String>}:
  match b:
    case True{}: Equal.sym(Maybe<&2, String>, Some{o2}, Some{o}, h)
    case False{}: absurd({Some{o} == Some{o2} : Maybe<&2, String>}, some_not_none(String, o2, h))

def echo_found(+es: List<&2, P.Entry>, +m: Maybe<&2, String>, +o: String, +c: Bool, h: {P.listed_grant(es, m) == Some{P.Grant{o, c}} : Maybe<&2, P.Grant>}) -> {m == Some{o} : Maybe<&2, String>}:
  match m:
    case None{}: absurd({None{} == Some{o} : Maybe<&2, String>}, none_not_some(P.Grant, P.Grant{o, c}, h))
    case Some{+o1}:
      lifted = Equal.cong(Maybe<&2, P.Grant>, Maybe<&2, String>, g => origin_of(g), P.lookup(o1, es), Some{P.Grant{o, c}}, h)
      kept = Equal.trans(Maybe<&2, String>, Some{o}, origin_of(P.lookup(o1, es)), keep(o1, found_in(o1, es)), Equal.sym(Maybe<&2, String>, origin_of(P.lookup(o1, es)), Some{o}, lifted), echo_lookup(o1, es))
      echo_keep(o1, o, found_in(o1, es), kept)

# A listed grant names exactly the request's own serialized origin.
def echo(+es: List<&2, P.Entry>, +sent: P.Sent, +o: String, +c: Bool, h: {P.grant(P.Listed{es}, sent) == Some{P.Grant{o, c}} : Maybe<&2, P.Grant>}) -> {Spec.request_origin(sent) == Some{o} : Maybe<&2, String>}:
  match sent:
    case P.Absent{}: absurd({None{} == Some{o} : Maybe<&2, String>}, none_not_some(P.Grant, P.Grant{o, c}, h))
    case P.Sent{+v}: Equal.trans(Maybe<&2, String>, OriginSpec.canonical(v), Origin.canonical(v), Some{o}, Equal.sym(Maybe<&2, String>, Origin.canonical(v), OriginSpec.canonical(v), OriginProof.canonical_same(v)), echo_found(es, Origin.canonical(v), o, c, h))
    case P.Repeated{}: absurd({None{} == Some{o} : Maybe<&2, String>}, none_not_some(P.Grant, P.Grant{o, c}, h))

# ---- Configuration ----

def kept(+m: Maybe<&2, String>, +c: Bool, +rest: List<&2, P.Entry>) -> {P.entry_kept(m, c, rest) == List.append(&2, P.Entry, Spec.present(m, c), rest) : List<&2, P.Entry>}:
  match m:
    case None{}: {==}
    case Some{o}: {==}

def serialized(+xs: List<&2, P.Entry>) -> {P.serialized(xs) == Spec.configured(xs) : List<&2, P.Entry>}:
  match xs:
    case Nil{}: {==}
    case P.Entry{+o, +c} <> +t:
      %serialized(t) : {P.entry_kept(Origin.of_url(o), c, P.serialized(t)) == List.append(&2, P.Entry, Spec.present(OriginSpec.of_url(o), c), _) : List<&2, P.Entry>}
      Equal.trans(List<&2, P.Entry>, P.entry_kept(Origin.of_url(o), c, P.serialized(t)), List.append(&2, P.Entry, Spec.present(Origin.of_url(o), c), P.serialized(t)), List.append(&2, P.Entry, Spec.present(OriginSpec.of_url(o), c), P.serialized(t)), kept(Origin.of_url(o), c, P.serialized(t)), Equal.cong(Maybe<&2, String>, List<&2, P.Entry>, m => List.append(&2, P.Entry, Spec.present(m, c), P.serialized(t)), Origin.of_url(o), OriginSpec.of_url(o), OriginProof.of_url_same(o)))

def configured(+xs: List<&2, P.Entry>) -> {P.listed(xs) == P.Listed{Spec.configured(xs)} : P.Origins}:
  Equal.cong(List<&2, P.Entry>, P.Origins, es => P.Listed{es}, P.serialized(xs), Spec.configured(xs), serialized(xs))

# ---- Preflight classification ----

def preflight(+method: Request.Method, +sent: P.Sent, +r: Bool) -> {P.preflight(method, sent, r) == Spec.preflight(method, sent, r) : Bool}:
  match method:
    case Request.Get{}: {==}
    case Request.Head{}: {==}
    case Request.Post{}: {==}
    case Request.Put{}: {==}
    case Request.Delete{}: {==}
    case Request.Connect{}: {==}
    case Request.Options{}:
      match sent:
        case P.Absent{}: {==}
        case P.Sent{v}: {==}
        case P.Repeated{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: {==}
    case Request.Extension{t}: {==}

# ---- Field lists ----

def cred(+c: Bool) -> {P.credential_fields(c) == Spec.flag(c) : List<&2, P.Field>}:
  match c:
    case True{}: {==}
    case False{}: {==}

def csv(+name: String, +xs: List<&2, String>) -> {P.list_field(name, xs) == Spec.csv(name, xs) : List<&2, P.Field>}:
  match xs:
    case Nil{}: {==}
    case x <> t: {==}

def headers(+h: List<&2, String>, +r: Maybe<&2, String>) -> {P.allow_headers(h, r) == Spec.headers_answer(h, r) : List<&2, P.Field>}:
  match h:
    case Nil{}:
      match r:
        case None{}: {==}
        case Some{v}: {==}
    case x <> t: {==}

def age(+m: Maybe<&2, Nat>) -> {P.age_field(m) == Spec.age(m) : List<&2, P.Field>}:
  match m:
    case None{}: {==}
    case Some{n}: {==}

def app2(+a1: List<&2, P.Field>, +a2: List<&2, P.Field>, +b1: List<&2, P.Field>, +b2: List<&2, P.Field>, ea: {a1 == a2 : List<&2, P.Field>}, eb: {b1 == b2 : List<&2, P.Field>}) -> {List.append(&2, P.Field, a1, b1) == List.append(&2, P.Field, a2, b2) : List<&2, P.Field>}:
  %ea : {List.append(&2, P.Field, a1, b1) == List.append(&2, P.Field, _, b2) : List<&2, P.Field>}
  %eb : {List.append(&2, P.Field, a1, b1) == List.append(&2, P.Field, a1, _) : List<&2, P.Field>}
  {==}

def consed(+f: P.Field, +x: List<&2, P.Field>, +y: List<&2, P.Field>, e: {x == y : List<&2, P.Field>}) -> {f <> x == f <> y : List<&2, P.Field>}:
  Equal.cong(List<&2, P.Field>, List<&2, P.Field>, l => f <> l, x, y, e)

# The preflight fields equal the specification for every configuration,
# grant and reflected header list.
def preflight_fields(+config: P.Config, +g: Maybe<&2, P.Grant>, +r: Maybe<&2, String>) -> {P.preflight_fields(config, g, r) == Spec.preflight_fields(config, g, r) : List<&2, P.Field>}:
  match config:
    case P.Config{+origins, +methods, +hs, +expose, +max}:
      match g:
        case None{}: {==}
        case Some{P.Grant{+o, +c}}:
          tail = app2(P.list_field("access-control-allow-methods", methods), Spec.csv("access-control-allow-methods", methods), P.cat(P.allow_headers(hs, r), P.age_field(max)), List.append(&2, P.Field, Spec.headers_answer(hs, r), Spec.age(max)), csv("access-control-allow-methods", methods), app2(P.allow_headers(hs, r), Spec.headers_answer(hs, r), P.age_field(max), Spec.age(max), headers(hs, r), age(max)))
          consed(P.Field{"access-control-allow-origin", o}, P.cat(P.credential_fields(c), P.cat(P.list_field("access-control-allow-methods", methods), P.cat(P.allow_headers(hs, r), P.age_field(max)))), List.append(&2, P.Field, Spec.flag(c), List.append(&2, P.Field, Spec.csv("access-control-allow-methods", methods), List.append(&2, P.Field, Spec.headers_answer(hs, r), Spec.age(max)))), app2(P.credential_fields(c), Spec.flag(c), P.cat(P.list_field("access-control-allow-methods", methods), P.cat(P.allow_headers(hs, r), P.age_field(max))), List.append(&2, P.Field, Spec.csv("access-control-allow-methods", methods), List.append(&2, P.Field, Spec.headers_answer(hs, r), Spec.age(max))), cred(c), tail))

# The ordinary-response fields equal the specification.
def actual_fields(+config: P.Config, +g: Maybe<&2, P.Grant>) -> {P.actual_fields(config, g) == Spec.actual_fields(config, g) : List<&2, P.Field>}:
  match config:
    case P.Config{+origins, +methods, +hs, +expose, +max}:
      match g:
        case None{}: {==}
        case Some{P.Grant{+o, +c}}:
          consed(P.Field{"access-control-allow-origin", o}, P.cat(P.credential_fields(c), P.list_field("access-control-expose-headers", expose)), List.append(&2, P.Field, Spec.flag(c), Spec.csv("access-control-expose-headers", expose)), app2(P.credential_fields(c), Spec.flag(c), P.list_field("access-control-expose-headers", expose), Spec.csv("access-control-expose-headers", expose), cred(c), csv("access-control-expose-headers", expose)))
