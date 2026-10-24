import Base
import ../../src/http/request.bend as Request
import ../../src/main.bend as B
import ../../src/http/response.bend as Response
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Echo{}
  Policy{}
  Chat{}
  Subprotocol{}
  Duplicate{}
  Late{}
  Replace{}
  Forbid{}
  Garble{}
  Rewrite{}
  Observe{}
  Builtin{id: B.Builtin}

def recv_timeout() -> U32: 5000

# The interim session: send the octets read past the handshake, then echo
# raw octets until the peer closes or stays silent for five seconds.
type EchoEvent is Type:
  Received{read: Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>}
  Sent{sent: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>}

@unsafe
def echo(event: EchoEvent) -> IO(Unit):
  match event:
    case Received{(s, Ready{Done{Some{xs}}})}:
      do IO<Unit>:
        sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, xs)
        echo(Sent{sent})
    case Received{(s, _)}:
      do IO<Unit>:
        IO.print("closed")
        Socket.close(s)
    case Sent{(s, result)}:
      do IO<Unit>:
        next : Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit> <- TCP.try_recv_bytes(s, 4096, recv_timeout())
        echo(Received{next})

@unsafe
def begin(s: Socket, rest: List<&2, U32>) -> IO(Unit):
  match rest:
    case Nil{}:
      do IO<Unit>:
        next : Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit> <- TCP.try_recv_bytes(s, 4096, recv_timeout())
        echo(Received{next})
    case x <> xs: echo(Received{(s, Ready{Done{Some{x <> xs}}})})

@unsafe
def opened(label: String, s: Socket, +rest: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    IO.print("open:" ++ label ++ ":" ++ Nat.show(List.length(&2, U32, rest)))
    begin(s, rest)

@unsafe
def session(label: String, s: Socket, rest: List<&2, U32>) -> IO(Unit):
  opened(label, s, rest)

def cleanup(label: String) -> IO(Unit):
  IO.print("cleanup:" ++ label)

def chat() -> B.WebSocketConfig:
  B.websocket_protocols(B.websocket_origins(B.websocket_config(), ["https://app.example/ignored-path", "not an origin"]), ["chat.v2", "chat", "bad token"])

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  match tag:
    case Chat{}: B.websocket(~Unit, ~String, ~session, ~cleanup, c, "chat", chat())
    case Subprotocol{}: B.websocket(~Unit, ~String, ~session, ~cleanup, c, "subprotocol", B.websocket_protocols(B.websocket_config(), ["chat.v2", "chat"]))
    case Duplicate{}:
      +ctx = c
      do IO<B.Res>:
        first : B.Res <- B.websocket(~Unit, ~String, ~session, ~cleanup, ctx, "first", B.websocket_config())
        B.websocket(~Unit, ~String, ~session, ~cleanup, ctx, "second", B.websocket_config())
    case Late{}:
      do IO<B.Res>:
        IO.sleep(100)
        B.websocket(~Unit, ~String, ~session, ~cleanup, c, "late", B.websocket_config())
    case _:
      +ctx = c
      B.websocket(~Unit, ~String, ~session, ~cleanup, ctx, C.path(Unit, ctx), B.websocket_config())

def timed(result: Maybe<&1, B.Res>) -> B.Res:
  match result:
    case None{}: Response.body(504, [], [])
    case Some{res}: res

def forbid(res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{403, hs, body, rep}

# Middleware breaks the handshake fields and framing but keeps the marker.
def garble(res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, Request.Header{"sec-websocket-accept", [120]} <> (Request.Header{"connection", [99, 108, 111, 115, 101]} <> (Request.Header{"content-length", [53]} <> (Request.Header{"upgrade", [104, 50, 99]} <> hs))), [104, 105], rep}

def rewritten(c: B.Context(Unit), flag: Maybe<&2, String>, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match flag:
    case None{}: next(c)
    case Some{v}:
      +ctx = c
      next(C.rewrite(Unit, ctx, Request.Get{}, C.path(Unit, ctx)))

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case Late{}:
      do IO<B.Res>:
        result : Maybe<&1, B.Res> <- IO.within(B.Res, 10, next(c))
        return timed(result)
    case Replace{}:
      +ctx = c
      do IO<B.Res>:
        res : B.Res <- next(ctx)
        return B.text(ctx, "replacement")
    case Forbid{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return forbid(res)
    case Garble{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return garble(res)
    case Rewrite{}:
      +ctx = c
      rewritten(ctx, B.request_header(ctx, "x-rewrite-get"), next)
    case Observe{}:
      +ctx = c
      do IO<B.Res>:
        res : B.Res <- next(ctx)
        IO.print("after:" ++ C.path(Unit, ctx))
        return res
    case _: next(c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.on_request(Tag, Rewrite{}),
    B.on_request(Tag, Builtin{B.request_id()}),
    B.on_request(Tag, Builtin{B.server_timing()}),
    B.on_after_response(Tag, Observe{}),
    B.use_path(Tag, "/policy/*", Builtin{B.cors(B.cors_allow([B.cors_origin_credentials("https://app.example")]))}),
    B.use_path(Tag, "/policy/*", Builtin{B.secure_headers()}),
    B.use_path(Tag, "/override", Builtin{B.method_override_header("x-http-method-override", ["PUT"])}),
    B.use_path(Tag, "/replace", Replace{}),
    B.use_path(Tag, "/forbid", Forbid{}),
    B.use_path(Tag, "/garble", Garble{}),
    B.use_path(Tag, "/late", Late{}),
    B.all(Tag, "/ws", Echo{}),
    B.get(Tag, "/policy/ws", Policy{}),
    B.get(Tag, "/chat", Chat{}),
    B.get(Tag, "/subprotocol", Subprotocol{}),
    B.get(Tag, "/duplicate", Duplicate{}),
    B.get(Tag, "/late", Late{}),
    B.get(Tag, "/replace", Replace{}),
    B.get(Tag, "/forbid", Forbid{}),
    B.get(Tag, "/garble", Garble{}),
    B.all(Tag, "/override", Echo{})
  ]))
