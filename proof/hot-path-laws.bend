# BND-68: each hot-path rewrite equals its retained definition for every
# input, so every earlier law about the original carries over unchanged.
import Base
import ../src/data/utf8.bend as Utf8
import ../src/http/bytes.bend as Bytes
import ../src/http/response.bend as Response
import ../src/app/context.bend as Context
import ../src/http/request.bend as Request
import ../src/http/connection.bend as Connection
import ../src/data/json.bend as Json
import ../src/mw/cors.bend as Cors
import ../src/mw/secure_headers.bend as SecureHeaders
import ../src/mw/cors_policy.bend as CorsPolicy
import ../src/mw/cors_request.bend as CorsRequest
import ../src/mw/response_policy.bend as ResponsePolicy

law hot_utf8_encode_char:
  for +c: U32
  {Utf8.encode_char(c) == Utf8.encode_char_spec(c) : List<&2, U32>}

law hot_bytes_tchar:
  for +c: U32
  {Bytes.tchar(c) == Bytes.tchar_spec(c) : Bool}

law hot_response_utf8:
  for +s: String
  {Response.utf8(s) == Response.utf8_spec(s) : List<&2, U32>}

law hot_context_text:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +value: String
  {Context.text(Vars, c, value) == Context.text_spec(Vars, c, value) : Response.Res}

law hot_context_html:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +value: String
  {Context.html(Vars, c, value) == Context.html_spec(Vars, c, value) : Response.Res}

law hot_context_json_result:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +result: Result<&2, &2, Json.Error, String>
  {Context.json_result(Vars, c, result) == Context.json_result_spec(Vars, c, result) : Response.Res}

# CORS retains one policy per request. For an actual (non-preflight)
# request it equals the policy the response used to be built with.
law hot_cors_actual:
  for +config: CorsPolicy.Config
  for +g: Maybe<&2, CorsPolicy.Grant>
  for +requested: Maybe<&2, String>
  for +res: Response.Res
  {ResponsePolicy.apply(CorsRequest.chosen(config, g, requested, False{}), res) == Cors.actual(config, g, res) : Response.Res}

law hot_cors_policy:
  for +config: CorsPolicy.Config
  for +req: Request.Req
  {CorsRequest.chosen(config, CorsRequest.grant(config, req), CorsRequest.requested(req), CorsRequest.preflight(req)) == CorsRequest.policy(config, req) : ResponsePolicy.Policy}

# Secure headers run a policy prepared at registration; the per-config
# middleware is that same shell with the policy built from its config.
law hot_secure_prepared:
  for -Vars: Data
  for +config: SecureHeaders.Config
  for +c: Context.Ctx<Vars>
  for next: Context.Ctx<Vars> -> IO(Response.Res)
  {SecureHeaders.middleware(Vars, config, c, next) == SecureHeaders.prepared(Vars, SecureHeaders.policy(config), c, next) : IO(Response.Res)}

law hot_connection_header_hit:
  for +n: String
  for +v: List<&2, U32>
  for +wanted: String
  {Connection.header_hit(n, v, wanted) == Connection.header_hit_spec(n, v, wanted) : Bool}
