# BND-43: the CSRF decision equals the independent request policy.
import Base
import ../src/mw/csrf_policy.bend as P
import ../src/http/request.bend as Request
import ../src/http/origin.bend as Origin
import ../src/http/bytes.bend as Bytes
import ./csrf-spec.bend as Spec

def or_false(+a: Bool) -> {a == (a || False{}) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def safe_reads(+m: Request.Method) -> {P.safe(m) == Spec.reads_only(m) : Bool}:
  match m:
    case Request.Get{}: {==}
    case Request.Head{}: {==}
    case Request.Post{}: {==}
    case Request.Put{}: {==}
    case Request.Delete{}: {==}
    case Request.Connect{}: {==}
    case Request.Options{}: {==}
    case Request.Trace{}: {==}
    case Request.Patch{}: {==}
    case Request.Extension{t}: {==}

def form_simple(+ct: Maybe<&2, String>) -> {P.form(ct) == Spec.simple_body(ct) : Bool}:
  match ct:
    case None{}: {==}
    case Some{v}: {==}

def member_listed(+o: String, +xs: List<&2, String>) -> {P.member(o, xs) == Spec.listed(o, xs) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +t:
      %member_listed(o, t) : {String.eq(x, o) || P.member(o, t) == String.eq(x, o) || _ : Bool}
      {==}

def claimed_source(+origin: Maybe<&2, String>, +referer: Maybe<&2, String>) -> {P.claimed(origin, referer) == Spec.source(origin, referer) : Maybe<&2, String>}:
  match origin referer:
    case Some{o} Some{r}: {==}
    case Some{o} None{}: {==}
    case None{} Some{r}: {==}
    case None{} None{}: {==}

def same_names(+o: String, +m: Maybe<&2, String>) -> {P.same(o, m) == Spec.names(m, o) : Bool}:
  match m:
    case None{}: {==}
    case Some{a}: {==}

def own_names(+o: String, +scheme: Maybe<&2, String>, +host: Maybe<&2, String>) -> {P.own(o, scheme, host) == Spec.names(Spec.addressed(scheme, host), o) : Bool}:
  match scheme host:
    case Some{s} Some{h}: same_names(o, Origin.of_host(s, h))
    case Some{s} None{}: {==}
    case None{} Some{h}: {==}
    case None{} None{}: {==}

# Without Sec-Fetch-Site: cross-site, a source is trusted when listed or
# addressed.
def unknown_src(+origins: List<&2, String>, +scheme: Maybe<&2, String>, +host: Maybe<&2, String>, +site: Maybe<&2, String>, +src: Maybe<&2, String>, nc: {Spec.site_is(site, "cross-site") == False{} : Bool}) -> {P.vouched(origins, scheme, host, P.Unknown{}, src) == Spec.trusted(origins, scheme, site, src, host) : Bool}:
  match src:
    case None{}:
      {==}
    case Some{+o}:
      %Equal.sym(Bool, Spec.site_is(site, "cross-site"), False{}, nc) : {P.member(o, origins) || P.own(o, scheme, host) == Spec.listed(o, origins) || (Bool.not(_) && Spec.names(Spec.addressed(scheme, host), o)) : Bool}
      %member_listed(o, origins) : {P.member(o, origins) || P.own(o, scheme, host) == _ || (True{} && Spec.names(Spec.addressed(scheme, host), o)) : Bool}
      %own_names(o, scheme, host) : {P.member(o, origins) || P.own(o, scheme, host) == P.member(o, origins) || (True{} && _) : Bool}
      {==}

# With Sec-Fetch-Site: cross-site, only a listed source is trusted.
def cross_src(+origins: List<&2, String>, +scheme: Maybe<&2, String>, +host: Maybe<&2, String>, +v: String, +src: Maybe<&2, String>, cs: {String.eq(Bytes.fold(v), "cross-site") == True{} : Bool}) -> {P.vouched(origins, scheme, host, P.CrossSite{}, src) == Spec.trusted(origins, scheme, Some{v}, src, host) : Bool}:
  match src:
    case None{}:
      {==}
    case Some{+o}:
      %Equal.sym(Bool, String.eq(Bytes.fold(v), "cross-site"), True{}, cs) : {P.member(o, origins) == Spec.listed(o, origins) || (Bool.not(_) && Spec.names(Spec.addressed(scheme, host), o)) : Bool}
      Equal.trans(Bool, P.member(o, origins), Spec.listed(o, origins), Spec.listed(o, origins) || False{}, member_listed(o, origins), or_false(Spec.listed(o, origins)))

def cross_site(+origins: List<&2, String>, +scheme: Maybe<&2, String>, +host: Maybe<&2, String>, +v: String, +src: Maybe<&2, String>, +cs: Bool, ecs: {String.eq(Bytes.fold(v), "cross-site") == cs : Bool}) -> {P.vouched(origins, scheme, host, P.site_cross(cs), src) == Spec.trusted(origins, scheme, Some{v}, src, host) : Bool}:
  match cs:
    case True{}:
      cross_src(origins, scheme, host, v, src, ecs)
    case False{}:
      unknown_src(origins, scheme, host, Some{v}, src, ecs)

def same_true(+origins: List<&2, String>, +scheme: Maybe<&2, String>, +host: Maybe<&2, String>, +src: Maybe<&2, String>) -> {P.vouched(origins, scheme, host, P.SameOrigin{}, src) == True{} : Bool}:
  match src:
    case None{}: {==}
    case Some{o}: {==}

def some_site(+origins: List<&2, String>, +scheme: Maybe<&2, String>, +host: Maybe<&2, String>, +v: String, +src: Maybe<&2, String>, +so: Bool, eso: {String.eq(Bytes.fold(v), "same-origin") == so : Bool}) -> {P.vouched(origins, scheme, host, P.site_named(Bytes.fold(v), so), src) == so || Spec.trusted(origins, scheme, Some{v}, src, host) : Bool}:
  match so:
    case True{}:
      same_true(origins, scheme, host, src)
    case False{}:
      cross_site(origins, scheme, host, v, src, String.eq(Bytes.fold(v), "cross-site"), {==})

def judge_site(+origins: List<&2, String>, +scheme: Maybe<&2, String>, +host: Maybe<&2, String>, +site: Maybe<&2, String>, +src: Maybe<&2, String>) -> {P.vouched(origins, scheme, host, P.site(site), src) == Spec.site_is(site, "same-origin") || Spec.trusted(origins, scheme, site, src, host) : Bool}:
  match site:
    case None{}:
      unknown_src(origins, scheme, host, None{}, src, {==})
    case Some{+v}:
      some_site(origins, scheme, host, v, src, String.eq(Bytes.fold(v), "same-origin"), {==})

def gate(+origins: List<&2, String>, +scheme: Maybe<&2, String>, +site: Maybe<&2, String>, +origin: Maybe<&2, String>, +referer: Maybe<&2, String>, +host: Maybe<&2, String>, +x: Bool) -> {P.inspect(x, P.Policy{origins, scheme}, site, origin, referer, host) == Bool.not(x) || Spec.site_is(site, "same-origin") || Spec.trusted(origins, scheme, site, Spec.source(origin, referer), host) : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      %Equal.sym(Maybe<&2, String>, P.claimed(origin, referer), Spec.source(origin, referer), claimed_source(origin, referer)) : {P.vouched(origins, scheme, host, P.site(site), _) == Spec.site_is(site, "same-origin") || Spec.trusted(origins, scheme, site, Spec.source(origin, referer), host) : Bool}
      judge_site(origins, scheme, host, site, Spec.source(origin, referer))

# The pure decision the middleware runs equals the policy specification for
# every policy, method and header combination.
def decide(+origins: List<&2, String>, +scheme: Maybe<&2, String>, +method: Request.Method, +content_type: Maybe<&2, String>, +site: Maybe<&2, String>, +origin: Maybe<&2, String>, +referer: Maybe<&2, String>, +host: Maybe<&2, String>) -> {P.decide(P.Policy{origins, scheme}, method, content_type, site, origin, referer, host) == Spec.allows(origins, scheme, method, content_type, site, origin, referer, host) : Bool}:
  %Equal.sym(Bool, P.safe(method), Spec.reads_only(method), safe_reads(method)) : {P.inspect(Bool.not(_) && P.form(content_type), P.Policy{origins, scheme}, site, origin, referer, host) == Spec.allows(origins, scheme, method, content_type, site, origin, referer, host) : Bool}
  %Equal.sym(Bool, P.form(content_type), Spec.simple_body(content_type), form_simple(content_type)) : {P.inspect(Bool.not(Spec.reads_only(method)) && _, P.Policy{origins, scheme}, site, origin, referer, host) == Spec.allows(origins, scheme, method, content_type, site, origin, referer, host) : Bool}
  gate(origins, scheme, site, origin, referer, host, Spec.inspected(method, content_type))

# ---- The configured policy ----

def kept_present(+m: Maybe<&2, String>, +rest: List<&2, String>) -> {P.kept(m, rest) == List.append(&2, String, Spec.present(m), rest) : List<&2, String>}:
  match m:
    case None{}: {==}
    case Some{o}: {==}

def serialized(+xs: List<&2, String>) -> {P.serialized(xs) == Spec.configured(xs) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case +x <> +t:
      %serialized(t) : {P.kept(Origin.of_url(x), P.serialized(t)) == List.append(&2, String, Spec.present(Origin.of_url(x)), _) : List<&2, String>}
      kept_present(Origin.of_url(x), P.serialized(t))

def scheme_of(+s: Maybe<&2, String>) -> {P.scheme_of(s) == Spec.configured_scheme(s) : Maybe<&2, String>}:
  match s:
    case None{}: {==}
    case Some{v}: {==}

# The decision of a policy built from configuration is the specification's
# decision over the configured origins and scheme.
def configured(+origins: List<&2, String>, +scheme: Maybe<&2, String>, +method: Request.Method, +content_type: Maybe<&2, String>, +site: Maybe<&2, String>, +origin: Maybe<&2, String>, +referer: Maybe<&2, String>, +host: Maybe<&2, String>) -> {P.decide(P.policy(origins, scheme), method, content_type, site, origin, referer, host) == Spec.allows(Spec.configured(origins), Spec.configured_scheme(scheme), method, content_type, site, origin, referer, host) : Bool}:
  %Equal.sym(List<&2, String>, P.serialized(origins), Spec.configured(origins), serialized(origins)) : {P.decide(P.Policy{_, P.scheme_of(scheme)}, method, content_type, site, origin, referer, host) == Spec.allows(Spec.configured(origins), Spec.configured_scheme(scheme), method, content_type, site, origin, referer, host) : Bool}
  %Equal.sym(Maybe<&2, String>, P.scheme_of(scheme), Spec.configured_scheme(scheme), scheme_of(scheme)) : {P.decide(P.Policy{Spec.configured(origins), _}, method, content_type, site, origin, referer, host) == Spec.allows(Spec.configured(origins), Spec.configured_scheme(scheme), method, content_type, site, origin, referer, host) : Bool}
  decide(Spec.configured(origins), Spec.configured_scheme(scheme), method, content_type, site, origin, referer, host)
