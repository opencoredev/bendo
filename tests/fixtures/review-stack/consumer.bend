# Real request consumers for the BND-84 review regressions.
import Base
import ../../../src/http/request.bend as R
import ../../../src/http/parse.bend as Parse
import ../../../src/http/bytes.bend as B
import ../../../src/http/text.bend as Text
import ../../../src/http/proxy_headers.bend as Hop
import ../../../src/http/upstream.bend as Up
import ../../../src/http/websocket.bend as WS
import ../../../src/crypto/jwt.bend as Jwt
import ../../../src/data/json.bend as Json
import ../../../src/app/context.bend as C
import ../../../src/http/response.bend as Response
import ../../../src/mw/method_override.bend as Override
import ../../../src/mw/method_override_policy.bend as Policy

def verified(r: Result<&2, &2, Jwt.Error, Json.Json>) -> String:
  match r:
    case Done{j}: "ok"
    case Fail{e}: Jwt.error_text(e)

def first(vs: List<&2, List<&2, U32>>) -> String:
  match vs:
    case Nil{}: "missing"
    case v <> t: B.ascii(v)

def forwarding(+s: String) -> String:
  first(R.lookup(Up.request_headers(Up.with_forwarded(Up.defaults("http://127.0.0.1"), True{}), Up.Upstream{"127.0.0.1", 80, "127.0.0.1", ""}, [R.Header{"host", B.encode(s)}], None{}, 0n), "forwarded"))

def request_fields(r: R.ParseResult) -> String:
  match r:
    case R.Parsed{R.Req{m, p, q, v, hs}, rest}:
      Nat.show(Text.length(U32, Up.head_bytes(m, p, Up.request_headers(Up.defaults("http://127.0.0.1"), Up.Upstream{"127.0.0.1", 80, "127.0.0.1", ""}, hs, None{}, 0n))))
    case _: "malformed"

def trusted_fields(r: R.ParseResult) -> String:
  match r:
    case R.Parsed{R.Req{m, p, q, v, hs}, rest}:
      first(R.lookup(Up.request_headers(Up.with_trust(Up.defaults("http://127.0.0.1"), True{}), Up.Upstream{"127.0.0.1", 80, "127.0.0.1", ""}, hs, None{}, 0n), "x-forwarded-proto"))
    case _: "malformed"

def framed(f: Up.Framing) -> String:
  match f:
    case Up.Fixed{n}: "fixed:" ++ Nat.show(n)
    case Up.Chunks{}: "chunks"
    case Up.Invalid{}: "invalid"
    case _: "other"

def ws_decision(d: WS.Decision) -> String:
  match d:
    case WS.Accept{a, p}: "accept"
    case WS.Refuse{s}: U32.show(s)

def ws_request(+s: String) -> R.Req:
  R.Req{R.Get{}, "/", None{}, R.Http11{}, [R.Header{"connection", B.encode(s)}, R.Header{"upgrade", B.encode("websocket")}, R.Header{"sec-websocket-key", B.encode("dGhlIHNhbXBsZSBub25jZQ==")}, R.Header{"sec-websocket-version", B.encode("13")}, R.Header{"sec-websocket-protocol", B.encode(s)}]}

def probe(mode: String, +s: String) -> String:
  match mode:
    case "jwt": verified(Jwt.verify(B.encode("review-secret"), s, 100n, 0n))
    case "proxy-connection": Nat.show(Text.length(R.Header, Hop.forward([R.Header{"connection", B.encode(s)}, R.Header{"x-keep", []}, R.Header{"x-drop", []}])))
    case "proxy-host": forwarding(s)
    case "proxy-fields": request_fields(Parse.parse(B.encode(s)))
    case "proxy-trusted": trusted_fields(Parse.parse(B.encode(s)))
    case "proxy-lengths": framed(Up.framing(False{}, 200, R.Http11{}, [R.Header{"content-length", B.encode(s)}]))
    case "proxy-codings": framed(Up.framing(False{}, 200, R.Http11{}, [R.Header{"transfer-encoding", B.encode(s)}]))
    case "websocket": ws_decision(WS.decide(WS.with_protocols(WS.defaults(), ["chat"]), ws_request(s)))
    case _: "unknown"

def next(c: C.Ctx<Unit>) -> IO(Response.Res):
  IO.pure(Response.Res, Response.text(200, R.method_text(C.method(Unit, c))))

def response_text(r: Response.Res) -> String:
  Response.Res{status, hs, body, stream} = r
  U32.show(status) ++ ":" ++ B.ascii(body)

def override_form(s: String) -> IO(Response.Res):
  Override.middleware(Unit, Policy.Config{Policy.Form{"_method"}, [R.Put{}]}, C.create(R.Req{R.Post{}, "/", None{}, R.Http11{}, [R.Header{"content-type", B.encode("application/x-www-form-urlencoded")}]}, [], B.encode(s), []), next)

def override_headers(r: R.ParseResult) -> IO(Response.Res):
  match r:
    case R.Parsed{req, rest}:
      Override.middleware(Unit, Policy.Config{Policy.Header{"x"}, [R.Put{}]}, C.create(req, [], [], []), next)
    case _: IO.pure(Response.Res, Response.text(400, "malformed"))

def middleware_result(mode: String, s: String) -> IO(Response.Res):
  match mode:
    case "override-form": override_form(s)
    case _: override_headers(Parse.parse(B.encode(s)))

# The middleware only uses IO.pure here: .mjs consumers supply its final
# continuation, exercising the actual middleware without an effect interpreter.
def middleware_probe(mode: String, s: String) -> IO(String):
  do IO<String>:
    r : Response.Res <- middleware_result(mode, s)
    IO.pure(String, response_text(r))

def report(mode: String, s: String) -> IO(Unit):
  do IO<Unit>:
    result : String <- middleware_probe(mode, s)
    IO.print(result)

def run(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "override-form" <> s <> _: report("override-form", s)
    case _ <> "override-headers" <> s <> _: report("override-headers", s)
    case _ <> mode <> s <> _: IO.print(probe(mode, s))
    case _: IO.print("missing")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args
    run(args)
