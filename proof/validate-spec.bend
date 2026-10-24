# Route validation (BND-36), restated from docs/validation.md against the raw
# schemas and Schema.decode_from, whose meaning the BND-33/34/35 laws fix. It
# shares data types with src/app/validate.bend and calls none of its helpers;
# string, header and JSON primitives come from the libraries both use.
import Base
import ../src/data/schema.bend as S
import ../src/data/json.bend as J
import ../src/data/utf8.bend as Utf8
import ../src/data/urlencoded.bend as Query
import ../src/http/bytes.bend as Bytes
import ../src/http/request.bend as Request
import ../src/router/pattern.bend as Pattern
import ../src/app/validate.bend as V

# Each text slot is an object of strings: params and query pairs in order,
# header names lowercased, header values UTF-8 or else ISO-8859-1.
def params_members(ps: Pattern.Params) -> List<&2, J.Field>:
  match ps:
    case Nil{}: []
    case Pattern.Param{k, v} <> t: J.Field{k, J.JString{v}} <> params_members(t)

def query_members(qs: List<&2, Query.Entry>) -> List<&2, J.Field>:
  match qs:
    case Nil{}: []
    case Query.Entry{k, v} <> t: J.Field{k, J.JString{v}} <> query_members(t)

def latin1(+bytes: List<&2, U32>, utf8: Maybe<&2, String>) -> String:
  match utf8:
    case Some{s}: s
    case None{}: Bytes.ascii(bytes)

def header_members(hs: List<&2, Request.Header>) -> List<&2, J.Field>:
  match hs:
    case Nil{}: []
    case Request.Header{k, +v} <> t: J.Field{Bytes.fold(k), J.JString{latin1(v, Utf8.decode(v))}} <> header_members(t)

# The first Content-Type names a JSON media type: application/json or
# application/*+json, in any case, with any parameters.
def before_semicolon(parts: List<&2, String>) -> String:
  match parts:
    case Nil{}: ""
    case h <> t: h

def media(s: String) -> String:
  Bytes.fold(Bytes.ascii(Bytes.trim(Bytes.encode(before_semicolon(String.split(s, ';'))))))

def json_media(+m: String) -> Bool:
  String.eq(m, "application/json") || (String.starts_with(m, "application/") && String.ends_with(m, "+json"))

def first_json(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: False{}
    case v <> t: json_media(media(Bytes.ascii(v)))

def json_type(hs: List<&2, Request.Header>) -> Bool:
  first_json(Request.lookup(hs, "content-type"))

# A slot's errors carry its name in front of every path.
def under(+slot: String, es: List<&2, S.Error>) -> List<&2, S.Error>:
  match es:
    case Nil{}: []
    case S.Error{c, m, p} <> t: S.Error{c, m, S.PathKey{slot} <> p} <> under(slot, t)

def failures(+slot: String, r: Result<&2, &2, S.Errors(), S.Value>) -> List<&2, S.Error>:
  match r:
    case Done{x}: []
    case Fail{es}: under(slot, es)

def decodes(r: Result<&2, &2, S.Errors(), S.Value>) -> Bool:
  match r:
    case Done{x}: True{}
    case Fail{es}: False{}

def value(r: Result<&2, &2, S.Errors(), S.Value>) -> Maybe<&2, S.Value>:
  match r:
    case Done{x}: Some{x}
    case Fail{es}: None{}

# A text slot with schema s decodes its object with coercion. A slot's state
# is None when the route declares no schema for it, else its decode result.
def text(s: S.Schema, members: List<&2, J.Field>) -> Result<&2, &2, S.Errors(), S.Value>:
  S.decode_from(S.TextSource{}, s, J.JObject{members})

def text_state(m: Maybe<&2, S.Schema>, members: List<&2, J.Field>) -> Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>:
  match m:
    case None{}: None{}
    case Some{s}: Some{text(s, members)}

def text_decodes(t: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>) -> Bool:
  match t:
    case None{}: True{}
    case Some{r}: decodes(r)

def text_errors(+slot: String, t: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>) -> List<&2, S.Error>:
  match t:
    case None{}: []
    case Some{r}: failures(slot, r)

def text_value(t: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>) -> Maybe<&2, S.Value>:
  match t:
    case None{}: None{}
    case Some{r}: value(r)

# A body schema needs a JSON media type and well-formed JSON, then decodes
# without coercion. What happens to the body, in the order it is checked:
type Body is Data:
  NoBody{}
  NotJsonType{}
  NotJson{}
  Decoded{result: Result<&2, &2, S.Errors(), S.Value>}

def parsed(s: S.Schema, p: Result<&2, &2, J.Error, J.Json>) -> Body:
  match p:
    case Fail{e}: NotJson{}
    case Done{v}: Decoded{S.decode_from(S.JsonBody{}, s, v)}

def typed(s: S.Schema, bytes: List<&2, U32>, json: Bool) -> Body:
  match json:
    case False{}: NotJsonType{}
    case True{}: parsed(s, J.parse(bytes))

def body(m: Maybe<&2, S.Schema>, hs: List<&2, Request.Header>, bytes: List<&2, U32>) -> Body:
  match m:
    case None{}: NoBody{}
    case Some{s}: typed(s, bytes, json_type(hs))

def body_errors(b: Body) -> List<&2, S.Error>:
  match b:
    case NoBody{}: []
    case NotJsonType{}: [S.Error{S.TypeMismatch{}, "expected an application/json body", [S.PathKey{"body"}]}]
    case NotJson{}: [S.Error{S.TypeMismatch{}, "body is not valid JSON", [S.PathKey{"body"}]}]
    case Decoded{r}: failures("body", r)

def body_decodes(b: Body) -> Bool:
  match b:
    case NoBody{}: True{}
    case NotJsonType{}: False{}
    case NotJson{}: False{}
    case Decoded{r}: decodes(r)

def body_value(b: Body) -> Maybe<&2, S.Value>:
  match b:
    case NoBody{}: None{}
    case NotJsonType{}: None{}
    case NotJson{}: None{}
    case Decoded{r}: value(r)

def body_status(b: Body) -> U32:
  match b:
    case NoBody{}: 422
    case NotJsonType{}: 415
    case NotJson{}: 400
    case Decoded{r}: 422

# Combining the four slots. The request is admitted exactly when every slot
# decodes; a rejection lists every failing path of every slot, in the order
# params, query, headers, body, with status 400 when a text slot fails and
# otherwise 415, 400 or 422 by what happened to the body.
def all_decode(+p: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +q: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +h: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +b: Body) -> Bool:
  text_decodes(p) && text_decodes(q) && text_decodes(h) && body_decodes(b)

def all_errors(+p: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +q: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +h: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +b: Body) -> List<&2, S.Error>:
  List.concat(&2, S.Error, [text_errors("params", p), text_errors("query", q), text_errors("headers", h), body_errors(b)])

def status_when(text_ok: Bool, b: Body) -> U32:
  match text_ok:
    case False{}: 400
    case True{}: body_status(b)

def decide(+p: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +q: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +h: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +b: Body, yes: Bool) -> V.Verdict:
  match yes:
    case True{}: V.Valid{V.Values{text_value(p), text_value(q), text_value(h), body_value(b)}}
    case False{}: V.Invalid{status_when(text_decodes(p) && text_decodes(q) && text_decodes(h), b), all_errors(p, q, h, b)}

def combine(+p: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +q: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +h: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +b: Body) -> V.Verdict:
  decide(p, q, h, b, all_decode(p, q, h, b))

# The verdict for a route with these schemas and this request.
def verdict(+params: Maybe<&2, S.Schema>, +query: Maybe<&2, S.Schema>, +headers: Maybe<&2, S.Schema>, +schema: Maybe<&2, S.Schema>, input: V.Input) -> V.Verdict:
  V.Input{ps, qs, +hs, bytes} = input
  combine(text_state(params, params_members(ps)), text_state(query, query_members(qs)), text_state(headers, header_members(hs)), body(schema, hs, bytes))

def admitted(+params: Maybe<&2, S.Schema>, +query: Maybe<&2, S.Schema>, +headers: Maybe<&2, S.Schema>, +schema: Maybe<&2, S.Schema>, input: V.Input) -> Bool:
  V.Input{ps, qs, +hs, bytes} = input
  all_decode(text_state(params, params_members(ps)), text_state(query, query_members(qs)), text_state(headers, header_members(hs)), body(schema, hs, bytes))

def errors(+params: Maybe<&2, S.Schema>, +query: Maybe<&2, S.Schema>, +headers: Maybe<&2, S.Schema>, +schema: Maybe<&2, S.Schema>, input: V.Input) -> List<&2, S.Error>:
  V.Input{ps, qs, +hs, bytes} = input
  all_errors(text_state(params, params_members(ps)), text_state(query, query_members(qs)), text_state(headers, header_members(hs)), body(schema, hs, bytes))

# A 2xx response other than 204 must carry a JSON body its schema decodes.
def response_result(r: Result<&2, &2, S.Errors(), S.Value>) -> V.Check:
  match r:
    case Done{x}: V.Conforms{}
    case Fail{es}: V.Violates{under("body", es)}

def response_body(s: S.Schema, p: Result<&2, &2, J.Error, J.Json>) -> V.Check:
  match p:
    case Fail{e}: V.Violates{[S.Error{S.TypeMismatch{}, "body is not valid JSON", [S.PathKey{"body"}]}]}
    case Done{v}: response_result(S.decode_from(S.JsonBody{}, s, v))

def response_typed(s: S.Schema, bytes: List<&2, U32>, json: Bool) -> V.Check:
  match json:
    case False{}: V.Violates{[S.Error{S.TypeMismatch{}, "expected an application/json body", [S.PathKey{"body"}]}]}
    case True{}: response_body(s, J.parse(bytes))

def response_when(s: S.Schema, hs: List<&2, Request.Header>, bytes: List<&2, U32>, checked: Bool) -> V.Check:
  match checked:
    case False{}: V.Unchecked{}
    case True{}: response_typed(s, bytes, json_type(hs))

def checked_status(+code: U32) -> Bool:
  (code >= 200 : U32) && (code <= 299 : U32) && Bool.not(U32.is_eq(code, 204))

def response(m: Maybe<&2, S.Schema>, +code: U32, hs: List<&2, Request.Header>, bytes: List<&2, U32>) -> V.Check:
  match m:
    case None{}: V.Unchecked{}
    case Some{s}: response_when(s, hs, bytes, checked_status(code))
