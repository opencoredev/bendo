# BND-50: the handshake module agrees with proof/websocket-spec.bend.
import Base
import ../src/http/websocket.bend as W
import ../src/http/request.bend as Request
import ../src/http/bytes.bend as Bytes
import ./websocket-spec.bend as Spec
import ../src/data/base64.bend as Base64
import ../src/http/origin.bend as Origin

def accept(+key: List<&2, U32>) -> {W.accept(key) == Spec.accept(key) : String}:
  {==}

def rfc() -> {W.accept(Bytes.encode("dGhlIHNhbXBsZSBub25jZQ==")) == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" : String}:
  {==}

# Every lemma below reads {spec == runtime}: a rewrite with one replaces the
# runtime term in a goal by the spec term.

def keep_step(+v: List<&2, U32>, +rest: List<&2, List<&2, U32>>, +b: Bool) -> {Spec.keep_value(v, rest, b) == Request.lookup_step(v, rest, b) : List<&2, List<&2, U32>>}:
  match b:
    case True{}: {==}
    case False{}: {==}

# Lookup by a lowercase name selects exactly the spec's fields.
def fields(+hs: List<&2, Request.Header>, +name: String) -> {Spec.fields(hs, name) == Request.lookup_folded(hs, name) : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> +t:
      %fields(t, name) : {Spec.keep_value(v, Spec.fields(t, name), String.eq(n, name)) == Request.lookup_step(v, _, String.eq(n, name)) : List<&2, List<&2, U32>>}
      keep_step(v, Spec.fields(t, name), String.eq(n, name))

def or_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a || b) || c == a || (b || c) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def folded_append(+xs: List<&2, String>, +ys: List<&2, String>, +w: String) -> {Spec.has_folded(xs, w) || Spec.has_folded(ys, w) == Spec.has_folded(List.append(&2, String, xs, ys), w) : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> +t:
      %folded_append(t, ys, w) : {(String.eq(String.to_lower(x), w) || Spec.has_folded(t, w)) || Spec.has_folded(ys, w) == String.eq(String.to_lower(x), w) || _ : Bool}
      or_assoc(String.eq(String.to_lower(x), w), Spec.has_folded(t, w), Spec.has_folded(ys, w))

def exact_append(+xs: List<&2, String>, +ys: List<&2, String>, +w: String) -> {Spec.has_exact(xs, w) || Spec.has_exact(ys, w) == Spec.has_exact(List.append(&2, String, xs, ys), w) : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> +t:
      %exact_append(t, ys, w) : {(String.eq(x, w) || Spec.has_exact(t, w)) || Spec.has_exact(ys, w) == String.eq(x, w) || _ : Bool}
      or_assoc(String.eq(x, w), Spec.has_exact(t, w), Spec.has_exact(ys, w))

def has_element(+parts: List<&2, String>, +w: String) -> {Spec.has_folded(Spec.trimmed(parts), w) == W.has_element(parts, w) : Bool}:
  match parts:
    case Nil{}: {==}
    case +p <> +t:
      %has_element(t, w) : {Spec.has_folded(Spec.trimmed(p <> t), w) == String.eq(Bytes.fold(W.element(p)), w) || _ : Bool}
      {==}

def has_offer(+parts: List<&2, String>, +w: String) -> {Spec.has_exact(Spec.trimmed(parts), w) == W.has_offer(parts, w) : Bool}:
  match parts:
    case Nil{}: {==}
    case +p <> +t:
      %has_offer(t, w) : {Spec.has_exact(Spec.trimmed(p <> t), w) == String.eq(W.element(p), w) || _ : Bool}
      {==}

def listed(+values: List<&2, List<&2, U32>>, +w: String) -> {Spec.has_folded(Spec.elements(values), w) == W.listed(values, w) : Bool}:
  match values:
    case Nil{}: {==}
    case +v <> +t:
      +parts = String.split(Bytes.ascii(v), ',')
      %has_element(parts, w) : {Spec.has_folded(Spec.elements(v <> t), w) == _ || W.listed(t, w) : Bool}
      %listed(t, w) : {Spec.has_folded(Spec.elements(v <> t), w) == Spec.has_folded(Spec.trimmed(parts), w) || _ : Bool}
      Equal.sym(Bool, Spec.has_folded(Spec.trimmed(parts), w) || Spec.has_folded(Spec.elements(t), w), Spec.has_folded(List.append(&2, String, Spec.trimmed(parts), Spec.elements(t)), w), folded_append(Spec.trimmed(parts), Spec.elements(t), w))

def offered(+values: List<&2, List<&2, U32>>, +w: String) -> {Spec.has_exact(Spec.elements(values), w) == W.offered_any(values, w) : Bool}:
  match values:
    case Nil{}: {==}
    case +v <> +t:
      +parts = String.split(Bytes.ascii(v), ',')
      %has_offer(parts, w) : {Spec.has_exact(Spec.elements(v <> t), w) == _ || W.offered_any(t, w) : Bool}
      %offered(t, w) : {Spec.has_exact(Spec.elements(v <> t), w) == Spec.has_exact(Spec.trimmed(parts), w) || _ : Bool}
      Equal.sym(Bool, Spec.has_exact(Spec.trimmed(parts), w) || Spec.has_exact(Spec.elements(t), w), Spec.has_exact(List.append(&2, String, Spec.trimmed(parts), Spec.elements(t)), w), exact_append(Spec.trimmed(parts), Spec.elements(t), w))

def chosen(+p: String, +rest: Maybe<&2, String>, +b: Bool) -> {Spec.first_offered(p, rest, b) == W.chosen(p, rest, b) : Maybe<&2, String>}:
  match b:
    case True{}: {==}
    case False{}: {==}

def select(+protocols: List<&2, String>, +values: List<&2, List<&2, U32>>) -> {Spec.protocol(protocols, Spec.elements(values)) == W.select(protocols, values) : Maybe<&2, String>}:
  match protocols:
    case Nil{}: {==}
    case +p <> +t:
      %select(t, values) : {Spec.protocol(p <> t, Spec.elements(values)) == W.chosen(p, _, W.offered_any(values, p)) : Maybe<&2, String>}
      %offered(values, p) : {Spec.protocol(p <> t, Spec.elements(values)) == W.chosen(p, Spec.protocol(t, Spec.elements(values)), _) : Maybe<&2, String>}
      chosen(p, Spec.protocol(t, Spec.elements(values)), Spec.has_exact(Spec.elements(values), p))

def zeros(+xs: List<&2, U32>) -> {Spec.all_zero(xs) == W.zeros(xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      %zeros(t) : {Spec.all_zero(c <> t) == U32.is_eq(c, 48) && _ : Bool}
      {==}

def length_tail(+v: List<&2, U32>, +t: List<&2, List<&2, U32>>) -> {Spec.no_length(v <> t) == W.zero_lengths(v <> t) : Bool}:
  match v t:
    case Nil{} Nil{}: {==}
    case Nil{} w <> r: {==}
    case +c <> +d Nil{}: zeros(c <> d)
    case c <> d w <> r: {==}

def lengths(+values: List<&2, List<&2, U32>>) -> {Spec.no_length(values) == W.zero_lengths(values) : Bool}:
  match values:
    case Nil{}: {==}
    case +v <> +t: length_tail(v, t)

def body_parts(+codings: List<&2, List<&2, U32>>, +ls: List<&2, List<&2, U32>>) -> {Spec.no_coding(codings, ls) == List.is_empty(&2, List<&2, U32>, codings) && W.zero_lengths(ls) : Bool}:
  match codings:
    case Nil{}: lengths(ls)
    case x <> t: {==}

def bodyless(+hs: List<&2, Request.Header>) -> {Spec.no_body(hs) == W.bodyless(hs) : Bool}:
  %fields(hs, "transfer-encoding") : {Spec.no_body(hs) == List.is_empty(&2, List<&2, U32>, _) && W.zero_lengths(Request.lookup(hs, "content-length")) : Bool}
  %fields(hs, "content-length") : {Spec.no_body(hs) == List.is_empty(&2, List<&2, U32>, Spec.fields(hs, "transfer-encoding")) && W.zero_lengths(_) : Bool}
  body_parts(Spec.fields(hs, "transfer-encoding"), Spec.fields(hs, "content-length"))

def listed_field(+hs: List<&2, Request.Header>, +name: String, +w: String) -> {Spec.has_folded(Spec.elements(Spec.fields(hs, name)), w) == W.listed(Request.lookup_folded(hs, name), w) : Bool}:
  %fields(hs, name) : {Spec.has_folded(Spec.elements(Spec.fields(hs, name)), w) == W.listed(_, w) : Bool}
  listed(Spec.fields(hs, name), w)

def nonce(+text: String, +decoded: Maybe<&2, List<&2, U32>>) -> {Spec.nonce(text, decoded) == W.key_sized(text, decoded) : Bool}:
  match decoded:
    case None{}: {==}
    case Some{+xs}: {==}

def key_tail(+k: List<&2, U32>, +t: List<&2, List<&2, U32>>) -> {Spec.good_key(k <> t) == W.key_valid(k <> t) : Bool}:
  match t:
    case Nil{}: nonce(Bytes.ascii(k), Base64.decode(Bytes.ascii(k), False{}, True{}))
    case j <> r: {==}

def key(+keys: List<&2, List<&2, U32>>) -> {Spec.good_key(keys) == W.key_valid(keys) : Bool}:
  match keys:
    case Nil{}: {==}
    case +k <> +t: key_tail(k, t)

def key_value(+keys: List<&2, List<&2, U32>>) -> {Spec.the_key(keys) == W.key_value(keys) : List<&2, U32>}:
  match keys:
    case Nil{}: {==}
    case k <> t: {==}

def member(+xs: List<&2, String>, +o: String) -> {Spec.listed_origin(xs, o) == W.member(xs, o) : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> +t:
      %member(t, o) : {Spec.listed_origin(x <> t, o) == String.eq(x, o) || _ : Bool}
      {==}

def serialized(+xs: List<&2, String>, +m: Maybe<&2, String>) -> {Spec.serialized_in(xs, m) == W.origin_in(xs, m) : Bool}:
  match m:
    case None{}: {==}
    case Some{+o}: member(xs, o)

def origin_tail(+xs: List<&2, String>, +v: List<&2, U32>, +t: List<&2, List<&2, U32>>) -> {Spec.one_origin(xs, v <> t) == W.origin_sent(xs, v <> t) : Bool}:
  match t:
    case Nil{}: serialized(xs, Origin.canonical(Bytes.ascii(v)))
    case w <> r: {==}

def origin_values(+xs: List<&2, String>, +values: List<&2, List<&2, U32>>) -> {Spec.one_origin(xs, values) == W.origin_sent(xs, values) : Bool}:
  match values:
    case Nil{}: {==}
    case +v <> +t: origin_tail(xs, v, t)

def origin(+origins: W.Origins, +hs: List<&2, Request.Header>) -> {Spec.origin_ok(origins, hs) == W.origin_allowed(origins, hs) : Bool}:
  match origins:
    case W.AnyOrigin{}: {==}
    case W.Listed{+xs}:
      %fields(hs, "origin") : {Spec.origin_ok(W.Listed{xs}, hs) == W.origin_sent(xs, _) : Bool}
      origin_values(xs, Spec.fields(hs, "origin"))

def is_get(+m: Request.Method) -> {Spec.is_get(m) == W.is_get(m) : Bool}:
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

def is_http11(+v: Request.Version) -> {Spec.is_http11(v) == W.is_http11(v) : Bool}:
  match v:
    case Request.Http10{}: {==}
    case Request.Http11{}: {==}

def accepted(+keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {W.Accept{Spec.accept(Spec.the_key(keys)), Spec.protocol(ps, Spec.elements(offs))} == W.accepted(keys, ps, offs) : W.Decision}:
  %key_value(keys) : {W.Accept{Spec.accept(Spec.the_key(keys)), Spec.protocol(ps, Spec.elements(offs))} == W.Accept{W.accept(_), W.select(ps, offs)} : W.Decision}
  %select(ps, offs) : {W.Accept{Spec.accept(Spec.the_key(keys)), Spec.protocol(ps, Spec.elements(offs))} == W.Accept{W.accept(Spec.the_key(keys)), _} : W.Decision}
  {==}

def version_bool(+b: Bool, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge(True{}, Spec.thirteen(b), o, keys, ps, offs) == W.negotiated(W.supported(b), o, keys, ps, offs) : W.Decision}:
  match b o:
    case True{} True{}: accepted(keys, ps, offs)
    case True{} False{}: {==}
    case False{} o: {==}

def version_tail(+v: List<&2, U32>, +t: List<&2, List<&2, U32>>, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge(True{}, Spec.version(v <> t), o, keys, ps, offs) == W.negotiated(W.version_status(v <> t), o, keys, ps, offs) : W.Decision}:
  match t:
    case Nil{}: version_bool(String.eq(Bytes.ascii(v), "13"), o, keys, ps, offs)
    case w <> r: {==}

def negotiated(+vals: List<&2, List<&2, U32>>, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge(True{}, Spec.version(vals), o, keys, ps, offs) == W.negotiated(W.version_status(vals), o, keys, ps, offs) : W.Decision}:
  match vals:
    case Nil{}: {==}
    case +v <> +t: version_tail(v, t, o, keys, ps, offs)

def combine6(+vals: List<&2, List<&2, U32>>, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge((((((True{} && True{}) && True{}) && True{}) && True{}) && True{}), Spec.version(vals), o, keys, ps, offs) == W.decided(True{}, True{}, True{}, True{}, True{}, True{}, W.version_status(vals), o, keys, ps, offs) : W.Decision}:
  negotiated(vals, o, keys, ps, offs)

def combine5(+f: Bool, +vals: List<&2, List<&2, U32>>, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge((((((True{} && True{}) && True{}) && True{}) && True{}) && f), Spec.version(vals), o, keys, ps, offs) == W.decided(True{}, True{}, True{}, True{}, True{}, f, W.version_status(vals), o, keys, ps, offs) : W.Decision}:
  match f:
    case True{}: combine6(vals, o, keys, ps, offs)
    case False{}: {==}

def combine4(+e: Bool, +f: Bool, +vals: List<&2, List<&2, U32>>, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge((((((True{} && True{}) && True{}) && True{}) && e) && f), Spec.version(vals), o, keys, ps, offs) == W.decided(True{}, True{}, True{}, True{}, e, f, W.version_status(vals), o, keys, ps, offs) : W.Decision}:
  match e:
    case True{}: combine5(f, vals, o, keys, ps, offs)
    case False{}: {==}

def combine3(+d: Bool, +e: Bool, +f: Bool, +vals: List<&2, List<&2, U32>>, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge((((((True{} && True{}) && True{}) && d) && e) && f), Spec.version(vals), o, keys, ps, offs) == W.decided(True{}, True{}, True{}, d, e, f, W.version_status(vals), o, keys, ps, offs) : W.Decision}:
  match d:
    case True{}: combine4(e, f, vals, o, keys, ps, offs)
    case False{}: {==}

def combine2(+c: Bool, +d: Bool, +e: Bool, +f: Bool, +vals: List<&2, List<&2, U32>>, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge((((((True{} && True{}) && c) && d) && e) && f), Spec.version(vals), o, keys, ps, offs) == W.decided(True{}, True{}, c, d, e, f, W.version_status(vals), o, keys, ps, offs) : W.Decision}:
  match c:
    case True{}: combine3(d, e, f, vals, o, keys, ps, offs)
    case False{}: {==}

def combine1(+b: Bool, +c: Bool, +d: Bool, +e: Bool, +f: Bool, +vals: List<&2, List<&2, U32>>, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge((((((True{} && b) && c) && d) && e) && f), Spec.version(vals), o, keys, ps, offs) == W.decided(True{}, b, c, d, e, f, W.version_status(vals), o, keys, ps, offs) : W.Decision}:
  match b:
    case True{}: combine2(c, d, e, f, vals, o, keys, ps, offs)
    case False{}: {==}

def combine0(+a: Bool, +b: Bool, +c: Bool, +d: Bool, +e: Bool, +f: Bool, +vals: List<&2, List<&2, U32>>, +o: Bool, +keys: List<&2, List<&2, U32>>, +ps: List<&2, String>, +offs: List<&2, List<&2, U32>>) -> {Spec.judge((((((a && b) && c) && d) && e) && f), Spec.version(vals), o, keys, ps, offs) == W.decided(a, b, c, d, e, f, W.version_status(vals), o, keys, ps, offs) : W.Decision}:
  match a:
    case True{}: combine1(b, c, d, e, f, vals, o, keys, ps, offs)
    case False{}: {==}

def decide_parts(+origins: W.Origins, +protocols: List<&2, String>, +ms: U32, +m: Request.Method, +path: String, +q: Maybe<&2, String>, +v: Request.Version, +hs: List<&2, Request.Header>) -> {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) : W.Decision}:
  %is_get(m) : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(_, W.is_http11(v), W.bodyless(hs), W.listed(Request.lookup(hs, "upgrade"), "websocket"), W.listed(Request.lookup(hs, "connection"), "upgrade"), W.key_valid(Request.lookup(hs, "sec-websocket-key")), W.version_status(Request.lookup(hs, "sec-websocket-version")), W.origin_allowed(origins, hs), Request.lookup(hs, "sec-websocket-key"), protocols, Request.lookup(hs, "sec-websocket-protocol")) : W.Decision}
  %is_http11(v) : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(Spec.is_get(m), _, W.bodyless(hs), W.listed(Request.lookup(hs, "upgrade"), "websocket"), W.listed(Request.lookup(hs, "connection"), "upgrade"), W.key_valid(Request.lookup(hs, "sec-websocket-key")), W.version_status(Request.lookup(hs, "sec-websocket-version")), W.origin_allowed(origins, hs), Request.lookup(hs, "sec-websocket-key"), protocols, Request.lookup(hs, "sec-websocket-protocol")) : W.Decision}
  %bodyless(hs) : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(Spec.is_get(m), Spec.is_http11(v), _, W.listed(Request.lookup(hs, "upgrade"), "websocket"), W.listed(Request.lookup(hs, "connection"), "upgrade"), W.key_valid(Request.lookup(hs, "sec-websocket-key")), W.version_status(Request.lookup(hs, "sec-websocket-version")), W.origin_allowed(origins, hs), Request.lookup(hs, "sec-websocket-key"), protocols, Request.lookup(hs, "sec-websocket-protocol")) : W.Decision}
  %listed_field(hs, "upgrade", "websocket") : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(Spec.is_get(m), Spec.is_http11(v), Spec.no_body(hs), _, W.listed(Request.lookup(hs, "connection"), "upgrade"), W.key_valid(Request.lookup(hs, "sec-websocket-key")), W.version_status(Request.lookup(hs, "sec-websocket-version")), W.origin_allowed(origins, hs), Request.lookup(hs, "sec-websocket-key"), protocols, Request.lookup(hs, "sec-websocket-protocol")) : W.Decision}
  %listed_field(hs, "connection", "upgrade") : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(Spec.is_get(m), Spec.is_http11(v), Spec.no_body(hs), Spec.has_folded(Spec.elements(Spec.fields(hs, "upgrade")), "websocket"), _, W.key_valid(Request.lookup(hs, "sec-websocket-key")), W.version_status(Request.lookup(hs, "sec-websocket-version")), W.origin_allowed(origins, hs), Request.lookup(hs, "sec-websocket-key"), protocols, Request.lookup(hs, "sec-websocket-protocol")) : W.Decision}
  %fields(hs, "sec-websocket-key") : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(Spec.is_get(m), Spec.is_http11(v), Spec.no_body(hs), Spec.has_folded(Spec.elements(Spec.fields(hs, "upgrade")), "websocket"), Spec.has_folded(Spec.elements(Spec.fields(hs, "connection")), "upgrade"), W.key_valid(_), W.version_status(Request.lookup(hs, "sec-websocket-version")), W.origin_allowed(origins, hs), _, protocols, Request.lookup(hs, "sec-websocket-protocol")) : W.Decision}
  %key(Spec.fields(hs, "sec-websocket-key")) : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(Spec.is_get(m), Spec.is_http11(v), Spec.no_body(hs), Spec.has_folded(Spec.elements(Spec.fields(hs, "upgrade")), "websocket"), Spec.has_folded(Spec.elements(Spec.fields(hs, "connection")), "upgrade"), _, W.version_status(Request.lookup(hs, "sec-websocket-version")), W.origin_allowed(origins, hs), Spec.fields(hs, "sec-websocket-key"), protocols, Request.lookup(hs, "sec-websocket-protocol")) : W.Decision}
  %fields(hs, "sec-websocket-version") : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(Spec.is_get(m), Spec.is_http11(v), Spec.no_body(hs), Spec.has_folded(Spec.elements(Spec.fields(hs, "upgrade")), "websocket"), Spec.has_folded(Spec.elements(Spec.fields(hs, "connection")), "upgrade"), Spec.good_key(Spec.fields(hs, "sec-websocket-key")), W.version_status(_), W.origin_allowed(origins, hs), Spec.fields(hs, "sec-websocket-key"), protocols, Request.lookup(hs, "sec-websocket-protocol")) : W.Decision}
  %origin(origins, hs) : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(Spec.is_get(m), Spec.is_http11(v), Spec.no_body(hs), Spec.has_folded(Spec.elements(Spec.fields(hs, "upgrade")), "websocket"), Spec.has_folded(Spec.elements(Spec.fields(hs, "connection")), "upgrade"), Spec.good_key(Spec.fields(hs, "sec-websocket-key")), W.version_status(Spec.fields(hs, "sec-websocket-version")), _, Spec.fields(hs, "sec-websocket-key"), protocols, Request.lookup(hs, "sec-websocket-protocol")) : W.Decision}
  %fields(hs, "sec-websocket-protocol") : {Spec.decide(W.Config{origins, protocols, ms}, Request.Req{m, path, q, v, hs}) == W.decided(Spec.is_get(m), Spec.is_http11(v), Spec.no_body(hs), Spec.has_folded(Spec.elements(Spec.fields(hs, "upgrade")), "websocket"), Spec.has_folded(Spec.elements(Spec.fields(hs, "connection")), "upgrade"), Spec.good_key(Spec.fields(hs, "sec-websocket-key")), W.version_status(Spec.fields(hs, "sec-websocket-version")), Spec.origin_ok(origins, hs), Spec.fields(hs, "sec-websocket-key"), protocols, _) : W.Decision}
  combine0(Spec.is_get(m), Spec.is_http11(v), Spec.no_body(hs), Spec.has_folded(Spec.elements(Spec.fields(hs, "upgrade")), "websocket"), Spec.has_folded(Spec.elements(Spec.fields(hs, "connection")), "upgrade"), Spec.good_key(Spec.fields(hs, "sec-websocket-key")), Spec.fields(hs, "sec-websocket-version"), Spec.origin_ok(origins, hs), Spec.fields(hs, "sec-websocket-key"), protocols, Spec.fields(hs, "sec-websocket-protocol"))

def decide_spec(+config: W.Config, +req: Request.Req) -> {Spec.decide(config, req) == W.decide(config, req) : W.Decision}:
  match config req:
    case W.Config{+origins, +protocols, +ms} Request.Req{+m, +path, +q, +v, +hs}: decide_parts(origins, protocols, ms, m, path, q, v, hs)

# The law's direction: the runtime decision equals the spec.
def decide(+config: W.Config, +req: Request.Req) -> {W.decide(config, req) == Spec.decide(config, req) : W.Decision}:
  Equal.sym(W.Decision, Spec.decide(config, req), W.decide(config, req), decide_spec(config, req))
