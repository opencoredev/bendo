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
import ../src/app/table.bend as T
import ../src/app/config.bend as Config
import ../src/data/schema-prepared.bend as SP
import ./scoped-selection-spec.bend as Routes
import ../src/http/stream_marker.bend as Marker
import ../src/app/route-schemas.bend as RS
import ../src/http/response.bend as Response

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
# decodes; a rejection lists the failing paths of the slots in the order
# params, query, headers, body, with status 400 when a text slot fails and
# otherwise 415, 400 or 422 by what happened to the body. The list is the
# first 100 of those paths: one budget for the whole request, not per slot.
def all_decode(+p: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +q: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +h: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +b: Body) -> Bool:
  text_decodes(p) && text_decodes(q) && text_decodes(h) && body_decodes(b)

def all_errors(+p: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +q: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +h: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +b: Body) -> List<&2, S.Error>:
  List.concat(&2, S.Error, [text_errors("params", p), text_errors("query", q), text_errors("headers", h), body_errors(b)])

def reported(+p: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +q: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +h: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +b: Body) -> List<&2, S.Error>:
  List.take(&2, S.Error, all_errors(p, q, h, b), 100n)

def status_when(text_ok: Bool, b: Body) -> U32:
  match text_ok:
    case False{}: 400
    case True{}: body_status(b)

def decide(+p: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +q: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +h: Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>, +b: Body, yes: Bool) -> V.Verdict:
  match yes:
    case True{}: V.Valid{V.Values{text_value(p), text_value(q), text_value(h), body_value(b)}}
    case False{}: V.Invalid{status_when(text_decodes(p) && text_decodes(q) && text_decodes(h), b), reported(p, q, h, b)}

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
  reported(text_state(params, params_members(ps)), text_state(query, query_members(qs)), text_state(headers, header_members(hs)), body(schema, hs, bytes))

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

# What the runtime does with a response, by mode and delivery. A streamed or
# upgraded response is sent as it is: its body is never buffered, so there is
# nothing to check. A buffered response that violates its schema is replaced
# by a 500 in development; production sends it and owes one log line listing
# the errors. Every other response is sent.
def verdict_for(c: V.Check, mode: Config.Mode) -> V.Action:
  match c mode:
    case V.Unchecked{} _: V.Send{}
    case V.Conforms{} _: V.Send{}
    case V.Violates{es} Config.Development{}: V.Replace{}
    case V.Violates{es} Config.Production{}: V.Report{es}

def act(mode: Config.Mode, delivery: V.Delivery, c: V.Check) -> V.Action:
  match delivery:
    case V.Streamed{}: V.Send{}
    case V.Buffered{}: verdict_for(c, mode)

def action(mode: Config.Mode, delivery: V.Delivery, m: Maybe<&2, S.Schema>, +code: U32, hs: List<&2, Request.Header>, bytes: List<&2, U32>) -> V.Action:
  act(mode, delivery, response(m, code, hs, bytes))

# When transport hands a response to the request's registration, restated
# from docs/streaming.md and docs/websocket.md. A registration marks its
# response with a private header, x-bendo-stream-internal, whose value is the
# registration's id. A body stream takes the response only while it carries
# that header with that id, under any name case; an upgrade also needs status
# 101. Without a registration nothing is handed over, whatever the headers say.
def carries(hs: List<&2, Request.Header>, +id: String) -> Bool:
  match hs:
    case Nil{}: False{}
    case Request.Header{n, v} <> t: (String.eq(Bytes.fold(n), "x-bendo-stream-internal") && String.eq(Bytes.ascii(v), id)) || carries(t, id)

def handed_over(claim: Marker.Claim, +code: U32, hs: List<&2, Request.Header>) -> Bool:
  match claim:
    case Marker.Unclaimed{}: False{}
    case Marker.BodyClaim{id}: carries(hs, id)
    case Marker.UpgradeClaim{id}: carries(hs, id) && U32.is_eq(code, 101)

# A response transport hands over is streamed or upgraded; any other is
# buffered, and its body is checked.
def delivery_when(handed: Bool) -> V.Delivery:
  match handed:
    case True{}: V.Streamed{}
    case False{}: V.Buffered{}

def delivery(claim: Marker.Claim, +code: U32, hs: List<&2, Request.Header>) -> V.Delivery:
  delivery_when(handed_over(claim, code, hs))

# Entrypoints without a decoder: a route that declares a schema in any slot,
# the response slot included, is rejected with a 500; any other route is
# admitted with no decoded values.
def present(m: Maybe<&2, SP.Checked>) -> Bool:
  match m:
    case None{}: False{}
    case Some{c}: True{}

def any_declared(set: V.Schemas) -> Bool:
  match set:
    case V.Schemas{p, q, h, b, r}: present(p) || present(q) || present(h) || present(b) || present(r)

def plain_when(declared: Bool) -> V.Verdict:
  match declared:
    case True{}: V.Invalid{500, [S.Error{S.InvalidSchema{}, "route schemas need the validating entrypoints in src/validated.bend", []}]}
    case False{}: V.Valid{V.Values{None{}, None{}, None{}, None{}}}

def plain(set: V.Schemas) -> V.Verdict:
  plain_when(any_declared(set))

# Which schema a route uses, slot by slot (BND-36). A route's placements list
# its scopes outer to inner: guards, groups, mounts and plugins prepend theirs
# before a route's own (proof/scoped-assembly-spec.bend). For each slot the
# effective schema is the last declaration of that slot in the list; a scope
# that does not declare a slot leaves the outer one in force.
type Which is Data:
  InParams{}
  InQuery{}
  InHeaders{}
  InBody{}
  InResponse{}

def slot(w: Which, set: V.Schemas) -> Maybe<&2, SP.Checked>:
  match w set:
    case InParams{} V.Schemas{p, q, h, b, r}: p
    case InQuery{} V.Schemas{p, q, h, b, r}: q
    case InHeaders{} V.Schemas{p, q, h, b, r}: h
    case InBody{} V.Schemas{p, q, h, b, r}: b
    case InResponse{} V.Schemas{p, q, h, b, r}: r

def first_present(a: Maybe<&2, SP.Checked>, b: Maybe<&2, SP.Checked>) -> Maybe<&2, SP.Checked>:
  match a:
    case None{}: b
    case Some{x}: Some{x}

def last_declared(-Tag: Data, +w: Which, ps: List<&2, T.Placement<Tag>>) -> Maybe<&2, SP.Checked>:
  match ps:
    case Nil{}: None{}
    case T.Placement{scope, hook} <> tail: last_declared(Tag, w, tail)
    case T.Checks{scope, set} <> tail: first_present(last_declared(Tag, w, tail), slot(w, set))

# Route identities are unique in a built table, so at most one route is here.
def chosen(here: Bool, mine: Maybe<&2, SP.Checked>, rest: Maybe<&2, SP.Checked>) -> Maybe<&2, SP.Checked>:
  match here:
    case True{}: first_present(mine, rest)
    case False{}: rest

# The route whose identity, the number of routes after it in the source
# entries, is n (scoped-selection-spec.bend).
def find(-Tag: Data, +w: Which, xs: List<&2, T.Entry<Tag>>, +n: Nat) -> Maybe<&2, SP.Checked>:
  match xs:
    case Nil{}: None{}
    case T.ScopedRoute{r, ps} <> +tail: chosen(Nat.is_eq(Routes.route_count(Tag, tail), n), last_declared(Tag, w, ps), find(Tag, w, tail, n))
    case _ <> tail: find(Tag, w, tail, n)

def effective(-Tag: Data, w: Which, xs: List<&2, T.Entry<Tag>>, route: Maybe<&2, Nat>) -> Maybe<&2, SP.Checked>:
  match route:
    case None{}: None{}
    case Some{n}: find(Tag, w, xs, n)

# The manifest's schemas (BND-36/37): one bundle per route registration, in
# source order, each holding the raw schema of every slot of that route's
# effective set. A route's identity is the number of routes after it.
def raw(m: Maybe<&2, SP.Checked>) -> Maybe<&2, S.Schema>:
  match m:
    case None{}: None{}
    case Some{SP.Checked{s, ok, t}}: Some{s}

def bundle(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +n: Nat) -> RS.RouteSchemas:
  RS.RouteSchemas{raw(effective(Tag, InParams{}, xs, Some{n})), raw(effective(Tag, InQuery{}, xs, Some{n})), raw(effective(Tag, InHeaders{}, xs, Some{n})), raw(effective(Tag, InBody{}, xs, Some{n})), raw(effective(Tag, InResponse{}, xs, Some{n}))}

def in_source_order(-Tag: Data, +all: List<&2, T.Entry<Tag>>, xs: List<&2, T.Entry<Tag>>) -> List<&2, RS.RouteSchemas>:
  match xs:
    case Nil{}: []
    case T.Route{r} <> +tail: bundle(Tag, all, Routes.route_count(Tag, tail)) <> in_source_order(Tag, all, tail)
    case T.ScopedRoute{r, ps} <> +tail: bundle(Tag, all, Routes.route_count(Tag, tail)) <> in_source_order(Tag, all, tail)
    case _ <> tail: in_source_order(Tag, all, tail)

def manifest_schemas(-Tag: Data, +xs: List<&2, T.Entry<Tag>>) -> List<&2, RS.RouteSchemas>:
  in_source_order(Tag, xs, xs)

# What finalization sends for a buffered or streamed response, restated from
# docs/validation.md: the response is checked as it stands after the retained
# policies, and that same response is sent, unless development replaces it;
# the replacement carries the same policies (`replaced`).
def sent(action: V.Action, checked: Response.Res, replaced: Response.Res) -> Response.Res:
  match action:
    case V.Replace{}: replaced
    case V.Send{}: checked
    case V.Report{es}: checked

def finalized(mode: Config.Mode, claim: Marker.Claim, m: Maybe<&2, S.Schema>, checked: Response.Res, replaced: Response.Res) -> Response.Res:
  Response.Res{+code, +hs, +body, rep} = checked
  sent(action(mode, delivery(claim, code, hs), m, code, hs, body), Response.Res{code, hs, body, rep}, replaced)
