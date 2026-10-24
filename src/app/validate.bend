# Route validation (BND-36); see docs/validation.md. Pure: the runtime builds an
# Input from the request, runs the handler only when `request` answers Valid,
# and checks the handler's response with `response`. Every schema here is
# prepared once (SP.check) when the route list is built.
import Base
import ../data/schema.bend as S
import ../data/schema-prepared.bend as SP
import ../data/json.bend as J
import ../data/utf8.bend as Utf8
import ../data/urlencoded.bend as Query
import ../http/bytes.bend as Bytes
import ../http/request.bend as Request
import ../router/pattern.bend as Pattern

# A route's schemas, one optional prepared schema per slot.
type Schemas is Data:
  Schemas{params: Maybe<&2, SP.Checked>, query: Maybe<&2, SP.Checked>, headers: Maybe<&2, SP.Checked>, body: Maybe<&2, SP.Checked>, response: Maybe<&2, SP.Checked>}

def none() -> Schemas:
  Schemas{None{}, None{}, None{}, None{}, None{}}

# One slot's schema, prepared when the slot value is built.
type Slot is Data:
  ParamsSlot{schema: SP.Checked}
  QuerySlot{schema: SP.Checked}
  HeadersSlot{schema: SP.Checked}
  BodySlot{schema: SP.Checked}
  ResponseSlot{schema: SP.Checked}

def add(set: Schemas, slot: Slot) -> Schemas:
  Schemas{p, q, h, b, r} = set
  match slot:
    case ParamsSlot{c}: Schemas{Some{c}, q, h, b, r}
    case QuerySlot{c}: Schemas{p, Some{c}, h, b, r}
    case HeadersSlot{c}: Schemas{p, q, Some{c}, b, r}
    case BodySlot{c}: Schemas{p, q, h, Some{c}, r}
    case ResponseSlot{c}: Schemas{p, q, h, b, Some{c}}

def set_go(slots: List<&2, Slot>, acc: Schemas) -> Schemas:
  match slots:
    case Nil{}: acc
    case s <> t: set_go(t, add(acc, s))

# A later slot of the same kind replaces an earlier one.
def set_of(slots: List<&2, Slot>) -> Schemas:
  set_go(slots, none())

# The set a route validates with when it holds raw schemas, each prepared.
def checked(m: Maybe<&2, S.Schema>) -> Maybe<&2, SP.Checked>:
  match m:
    case None{}: None{}
    case Some{+s}: Some{SP.check(s)}

def prepared(params: Maybe<&2, S.Schema>, query: Maybe<&2, S.Schema>, headers: Maybe<&2, S.Schema>, body: Maybe<&2, S.Schema>, response: Maybe<&2, S.Schema>) -> Schemas:
  Schemas{checked(params), checked(query), checked(headers), checked(body), checked(response)}

# Scopes nest outer to inner; per slot, the innermost schema wins.
def prefer(outer: Maybe<&2, SP.Checked>, inner: Maybe<&2, SP.Checked>) -> Maybe<&2, SP.Checked>:
  match inner:
    case None{}: outer
    case Some{c}: Some{c}

def override(outer: Schemas, inner: Schemas) -> Schemas:
  Schemas{p, q, h, b, r} = outer
  Schemas{ip, iq, ih, ib, ir} = inner
  Schemas{prefer(p, ip), prefer(q, iq), prefer(h, ih), prefer(b, ib), prefer(r, ir)}

# Whether a request has nothing to check: no params, query, headers or body schema.
def requests_nothing(set: Schemas) -> Bool:
  Schemas{p, q, h, b, r} = set
  Maybe.is_none(&2, SP.Checked, p) && Maybe.is_none(&2, SP.Checked, q) && Maybe.is_none(&2, SP.Checked, h) && Maybe.is_none(&2, SP.Checked, b)

def response_schema(set: Schemas) -> Maybe<&2, SP.Checked>:
  Schemas{p, q, h, b, r} = set
  r

# What the request offers each slot.
type Input is Data:
  Input{params: Pattern.Params, query: List<&2, Query.Entry>, headers: List<&2, Request.Header>, body: List<&2, U32>}

# Text sources become objects of strings in arrival order, repeats kept.
def params_go(ps: Pattern.Params, rev: List<&2, J.Field>) -> J.Json:
  match ps:
    case Nil{}: J.JObject{List.reverse(&2, J.Field, rev)}
    case Pattern.Param{k, v} <> t: params_go(t, J.Field{k, J.JString{v}} <> rev)

def params_json(ps: Pattern.Params) -> J.Json:
  params_go(ps, [])

def query_go(qs: List<&2, Query.Entry>, rev: List<&2, J.Field>) -> J.Json:
  match qs:
    case Nil{}: J.JObject{List.reverse(&2, J.Field, rev)}
    case Query.Entry{k, v} <> t: query_go(t, J.Field{k, J.JString{v}} <> rev)

def query_json(qs: List<&2, Query.Entry>) -> J.Json:
  query_go(qs, [])

# A header value is UTF-8 when it decodes, otherwise ISO-8859-1 octets.
def text_or_latin1(+bytes: List<&2, U32>, decoded: Maybe<&2, String>) -> String:
  match decoded:
    case Some{s}: s
    case None{}: Bytes.ascii(bytes)

def header_text(+bytes: List<&2, U32>) -> String:
  text_or_latin1(bytes, Utf8.decode(bytes))

# Names are matched case-insensitively: each is lowercased, so header schemas
# declare lowercase keys.
def headers_go(hs: List<&2, Request.Header>, rev: List<&2, J.Field>) -> J.Json:
  match hs:
    case Nil{}: J.JObject{List.reverse(&2, J.Field, rev)}
    case Request.Header{k, v} <> t: headers_go(t, J.Field{Bytes.fold(k), J.JString{header_text(v)}} <> rev)

def headers_json(hs: List<&2, Request.Header>) -> J.Json:
  headers_go(hs, [])

# A JSON media type: application/json or application/*+json, any case and
# parameters. An absent Content-Type is not JSON.
def first(parts: List<&2, String>) -> String:
  match parts:
    case Nil{}: ""
    case h <> t: h

def essence(s: String) -> String:
  Bytes.fold(Bytes.ascii(Bytes.trim(Bytes.encode(first(String.split(s, ';'))))))

def json_essence(+e: String) -> Bool:
  String.eq(e, "application/json") || (String.starts_with(e, "application/") && String.ends_with(e, "+json"))

def json_media(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: False{}
    case v <> t: json_essence(essence(Bytes.ascii(v)))

def json_body(hs: List<&2, Request.Header>) -> Bool:
  json_media(Request.lookup(hs, "content-type"))

# One slot's result. Errors carry the slot's name in front of their paths.
type Outcome is Data:
  Passed{value: Maybe<&2, S.Value>}
  Rejected{errors: List<&2, S.Error>}

def outcome(+slot: String, r: Result<&2, &2, S.Errors(), S.Value>) -> Outcome:
  match r:
    case Done{v}: Passed{Some{v}}
    case Fail{es}: Rejected{S.prefix(S.PathKey{slot}, es)}

def text_slot(+slot: String, c: Maybe<&2, SP.Checked>, v: J.Json) -> Outcome:
  match c:
    case None{}: Passed{None{}}
    case Some{k}: outcome(slot, SP.decode_from(S.TextSource{}, k, v))

# A body schema needs a JSON media type (415) and well-formed JSON (400);
# only then is the body decoded, without coercion (422).
type Body is Data:
  BodyPassed{value: Maybe<&2, S.Value>}
  WrongMedia{}
  Malformed{}
  BodyRejected{errors: List<&2, S.Error>}

def body_media() -> S.Error:
  S.Error{S.TypeMismatch{}, "expected an application/json body", [S.PathKey{"body"}]}

def body_syntax() -> S.Error:
  S.Error{S.TypeMismatch{}, "body is not valid JSON", [S.PathKey{"body"}]}

def body_decoded(r: Result<&2, &2, S.Errors(), S.Value>) -> Body:
  match r:
    case Done{x}: BodyPassed{Some{x}}
    case Fail{es}: BodyRejected{S.prefix(S.PathKey{"body"}, es)}

def body_parsed(k: SP.Checked, parsed: Result<&2, &2, J.Error, J.Json>) -> Body:
  match parsed:
    case Fail{e}: Malformed{}
    case Done{v}: body_decoded(SP.decode_from(S.JsonBody{}, k, v))

def body_typed(k: SP.Checked, bytes: List<&2, U32>, media: Bool) -> Body:
  match media:
    case False{}: WrongMedia{}
    case True{}: body_parsed(k, J.parse(bytes))

def body_slot(c: Maybe<&2, SP.Checked>, +hs: List<&2, Request.Header>, bytes: List<&2, U32>) -> Body:
  match c:
    case None{}: BodyPassed{None{}}
    case Some{k}: body_typed(k, bytes, json_body(hs))

# Decoded values, by slot; None where the route has no schema for it.
type Values is Data:
  Values{params: Maybe<&2, S.Value>, query: Maybe<&2, S.Value>, headers: Maybe<&2, S.Value>, body: Maybe<&2, S.Value>}

def no_values() -> Values:
  Values{None{}, None{}, None{}, None{}}

def params_value(v: Values) -> Maybe<&2, S.Value>:
  Values{p, q, h, b} = v
  p

def query_value(v: Values) -> Maybe<&2, S.Value>:
  Values{p, q, h, b} = v
  q

def headers_value(v: Values) -> Maybe<&2, S.Value>:
  Values{p, q, h, b} = v
  h

def body_value(v: Values) -> Maybe<&2, S.Value>:
  Values{p, q, h, b} = v
  b

# A decoded object's field by key; None when absent or not an object.
def field_go(fs: List<&2, S.VField>, +key: String) -> Maybe<&2, S.Value>:
  match fs:
    case Nil{}: None{}
    case S.VField{k, v} <> t: Bool.pick(Maybe<&2, S.Value>, String.eq(k, key), v, field_go(t, key))

def field(value: Maybe<&2, S.Value>, key: String) -> Maybe<&2, S.Value>:
  match value:
    case Some{S.VObject{fs}}: field_go(fs, key)
    case _: None{}

type Verdict is Data:
  Valid{values: Values}
  Invalid{status: U32, errors: List<&2, S.Error>}

def errors_of(o: Outcome) -> List<&2, S.Error>:
  match o:
    case Passed{v}: []
    case Rejected{es}: es

def body_errors(b: Body) -> List<&2, S.Error>:
  match b:
    case BodyPassed{v}: []
    case WrongMedia{}: [body_media()]
    case Malformed{}: [body_syntax()]
    case BodyRejected{es}: es

def text_ok(o: Outcome) -> Bool:
  match o:
    case Passed{v}: True{}
    case Rejected{es}: False{}

# Status: 400 when params, query or headers fail; otherwise 415 for the media
# type, 400 for malformed JSON and 422 for a body its schema rejects.
def body_status(b: Body) -> U32:
  match b:
    case BodyPassed{v}: 200
    case WrongMedia{}: 415
    case Malformed{}: 400
    case BodyRejected{es}: 422

def status_of(text: Bool, b: Body) -> U32:
  match text:
    case False{}: 400
    case True{}: body_status(b)

def verdict(+p: Outcome, +q: Outcome, +h: Outcome, +b: Body) -> Verdict:
  match p q h b:
    case Passed{vp} Passed{vq} Passed{vh} BodyPassed{vb}: Valid{Values{vp, vq, vh, vb}}
    case _ _ _ _: Invalid{status_of(text_ok(p) && text_ok(q) && text_ok(h), b), List.concat(&2, S.Error, [errors_of(p), errors_of(q), errors_of(h), body_errors(b)])}

# Every slot is checked, so a rejection lists every failing path of every slot.
def request(set: Schemas, input: Input) -> Verdict:
  Schemas{p, q, h, b, r} = set
  Input{ps, qs, +hs, body} = input
  verdict(text_slot("params", p, params_json(ps)), text_slot("query", q, query_json(qs)), text_slot("headers", h, headers_json(hs)), body_slot(b, hs, body))

# Responses: a 2xx response other than 204 must carry a JSON body its
# schema accepts. Other statuses, and routes without one, are not checked.
type Check is Data:
  Unchecked{}
  Conforms{}
  Violates{errors: List<&2, S.Error>}

def response_decoded(r: Result<&2, &2, S.Errors(), S.Value>) -> Check:
  match r:
    case Done{x}: Conforms{}
    case Fail{es}: Violates{S.prefix(S.PathKey{"body"}, es)}

def response_errors(k: SP.Checked, parsed: Result<&2, &2, J.Error, J.Json>) -> Check:
  match parsed:
    case Fail{e}: Violates{[body_syntax()]}
    case Done{v}: response_decoded(SP.decode_from(S.JsonBody{}, k, v))

def response_typed(k: SP.Checked, bytes: List<&2, U32>, media: Bool) -> Check:
  match media:
    case False{}: Violates{[body_media()]}
    case True{}: response_errors(k, J.parse(bytes))

def response_checked(k: SP.Checked, +status: U32, +hs: List<&2, Request.Header>, bytes: List<&2, U32>, checked: Bool) -> Check:
  match checked:
    case False{}: Unchecked{}
    case True{}: response_typed(k, bytes, json_body(hs))

def response(c: Maybe<&2, SP.Checked>, +status: U32, +hs: List<&2, Request.Header>, bytes: List<&2, U32>) -> Check:
  match c:
    case None{}: Unchecked{}
    case Some{k}: response_checked(k, status, hs, bytes, (status >= 200 : U32) && (status <= 299 : U32) && Bool.not(U32.is_eq(status, 204)))

# The response body for a rejected request:
# {"error": reason, "status": code, "errors": [{"path", "code", "message"}...]}.
def rejection(+status: U32, reason: String, errors: List<&2, S.Error>) -> J.Json:
  J.JObject{[J.Field{"error", J.JString{reason}}, J.Field{"status", J.JNumber{Nat.show(U32.to_nat(status))}}, J.Field{"errors", S.errors_json(errors)}]}
