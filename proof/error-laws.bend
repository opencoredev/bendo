# BND-25: laws about the response Context.error renders, before app hooks.
# A fresh context has no accumulated response headers; the request, route
# captures, body, query, status, variables and observation are arbitrary.
import Base
import ../src/app/context.bend as C
import ../src/app/errors.bend as Errors
import ../src/app/observability.bend as Obs
import ../src/router/pattern.bend as Pattern
import ../src/data/urlencoded.bend as Query
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes
import ../src/http/write_response.bend as WriteResponse
import ./error-spec.bend as Spec

# Two private errors with the same code render the same response and the same
# wire bytes, whatever their messages, request, method and accumulated headers.
law http_error_private_independent:
  for -Vars: Data
  for +c: C.Ctx<Vars>
  for +code: U32
  for m1: String
  for m2: String
  {C.error(Vars, c, Errors.HttpError{code, m1, False{}}) == C.error(Vars, c, Errors.HttpError{code, m2, False{}}) : Response.Res}

law http_error_private_wire_independent:
  for -Vars: Data
  for +c: C.Ctx<Vars>
  for +method: Request.Method
  for +code: U32
  for m1: String
  for m2: String
  {WriteResponse.write(method, C.error(Vars, c, Errors.HttpError{code, m1, False{}})) == WriteResponse.write(method, C.error(Vars, c, Errors.HttpError{code, m2, False{}})) : List<&2, U32>}

# Exact private output for either negotiated representation: status code for
# 400..599 and 500 otherwise, Content-Type, Vary: Accept, and exact body bytes.
law http_error_private_rendered:
  for -Vars: Data
  for +req: Request.Req
  for +params: List<&2, Pattern.Param>
  for +body: List<&2, U32>
  for +pairs: List<&2, Query.Entry>
  for +status: U32
  for +vars: Maybe<&2, Vars>
  for +observation: Obs.State
  for +code: U32
  for message: String
  for +json: Bool
  for negotiated: {Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, status, [], vars, observation}, "accept")) == json : Bool}
  {C.error(Vars, C.Ctx{req, params, body, pairs, status, [], vars, observation}, Errors.HttpError{code, message, False{}}) == Spec.private(json, code) : Response.Res}

# The same, end to end from the first Accept field, for representative fields
# whose representation the documented policy states independently.
law http_error_private_accept_samples:
  for -Vars: Data
  for +req: Request.Req
  for +params: List<&2, Pattern.Param>
  for +body: List<&2, U32>
  for +pairs: List<&2, Query.Entry>
  for +status: U32
  for +vars: Maybe<&2, Vars>
  for +observation: Obs.State
  for +code: U32
  for message: String
  for +sample: Spec.Sample
  for accept: {C.request_header(Vars, C.Ctx{req, params, body, pairs, status, [], vars, observation}, "accept") == Spec.sample_field(sample) : Maybe<&2, String>}
  {C.error(Vars, C.Ctx{req, params, body, pairs, status, [], vars, observation}, Errors.HttpError{code, message, False{}}) == Spec.private(Spec.sample_json(sample), code) : Response.Res}

# An exposed 4xx or 5xx error carries its configured message exactly: the
# message's UTF-8 bytes as text, or the JSON writer's escaping of it. An empty
# message uses the reason phrase. Only an invalid response becomes the empty 500.
law http_error_exposed_rendered:
  for -Vars: Data
  for +req: Request.Req
  for +params: List<&2, Pattern.Param>
  for +body: List<&2, U32>
  for +pairs: List<&2, Query.Entry>
  for +status: U32
  for +vars: Maybe<&2, Vars>
  for +observation: Obs.State
  for +code: U32
  for +message: String
  for +json: Bool
  for in_range: {(code >= 400 : U32) && (code <= 599 : U32) == True{} : Bool}
  for negotiated: {Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, status, [], vars, observation}, "accept")) == json : Bool}
  {C.error(Vars, C.Ctx{req, params, body, pairs, status, [], vars, observation}, Errors.HttpError{code, message, True{}}) == Spec.exposed(json, code, message) : Response.Res}

# The smart constructor's exposed example from the docs, exactly.
law http_error_tea_only_rendered:
  for -Vars: Data
  for +req: Request.Req
  for +params: List<&2, Pattern.Param>
  for +body: List<&2, U32>
  for +pairs: List<&2, Query.Entry>
  for +status: U32
  for +vars: Maybe<&2, Vars>
  for +observation: Obs.State
  for +json: Bool
  for negotiated: {Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, status, [], vars, observation}, "accept")) == json : Bool}
  {C.error(Vars, C.Ctx{req, params, body, pairs, status, [], vars, observation}, Errors.http_error(418, "Tea only")) == Spec.tea_only(json) : Response.Res}

# An invalid accumulated header makes any error render the empty 500.
law http_error_invalid_header_fallback:
  for -Vars: Data
  for +req: Request.Req
  for +params: List<&2, Pattern.Param>
  for +body: List<&2, U32>
  for +pairs: List<&2, Query.Entry>
  for +status: U32
  for +vars: Maybe<&2, Vars>
  for +observation: Obs.State
  for +failure: Errors.HttpError
  {C.error(Vars, C.Ctx{req, params, body, pairs, status, [Request.Header{"x-note", Bytes.encode("a\nb")}], vars, observation}, failure) == Response.Res{500, [], [], None{}} : Response.Res}

# A HEAD request's error response is written with no payload.
law http_error_head_no_payload:
  for -Vars: Data
  for +c: C.Ctx<Vars>
  for +failure: Errors.HttpError
  {WriteResponse.payload(Request.Head{}, C.error(Vars, c, failure)) == [] : List<&2, U32>}
