import Base
import ../../src/http/bytes.bend as Bytes
import ../../src/http/request.bend as Request
import ../../src/http/parse.bend as Parse
import ../../src/http/response.bend as Response
import ../../src/http/write_response.bend as Write

import ../../src/router/methods.bend as M
import ../../src/router/spec.bend as S
import ../../src/router/pattern.bend as P

type Tag is Data:
  Message{label: String}

def registrations() -> List<&2, M.Registration(Tag)>:
  [
    M.get(Tag, "/resource", Message{"get"}),
    M.post(Tag, "/resource", Message{"post"}),
    M.put(Tag, "/resource", Message{"put"}),
    M.patch(Tag, "/resource", Message{"patch"}),
    M.delete(Tag, "/resource", Message{"delete"}),
    M.options(Tag, "/resource", Message{"options"}),
    M.get(Tag, "/explicit/:id", Message{"get-explicit"}),
    M.head(Tag, "/explicit/:name", Message{"head-explicit"}),
    M.all(Tag, "/all", Message{"all"}),
    M.on(Tag, [Request.Post{}, Request.Patch{}, Request.Post{}], "/multi", Message{"multi"}),
    M.on(Tag, [Request.Extension{"ZETA"}, Request.Extension{"REPORT"}, Request.Extension{"PROPFIND"}, Request.Extension{"PROPFIND"}], "/extension", Message{"extension"}),
    M.get(Tag, "/Mixed/:Value", Message{"mixed"}),
    M.get(Tag, "/Slash/", Message{"slash"}),
    M.get(Tag, "/", Message{"root"}),
    M.get(Tag, "/Wild/*Tail", Message{"wild"}),
    M.get(Tag, "/Lower/:Value{[a-z]+}", Message{"lower"}),
    M.post(Tag, "/overlap/:id", Message{"overlap-post"}),
    M.get(Tag, "/overlap/new", Message{"overlap-get"}),
    M.on(Tag, [], "/empty", Message{"empty"}),
    M.get(Tag, "/unicode", Message{"hé 🌍"})
  ]

def params_text(ps: P.Params) -> String:
  match ps:
    case Nil{}:
      ""
    case P.Param{name, value} <> rest:
      "|" ++ name ++ "=" ++ value ++ params_text(rest)

# Closed app dispatcher; the router returns data, never a handler closure.
def dispatch(hit: S.Match<Tag>) -> Response.Res:
  S.Match{i, Message{label}, ps} = hit
  +body = label ++ ":" ++ Nat.show(i) ++ params_text(ps)
  Response.body(200, [Request.Header{"x-route", Response.utf8(body)}], Response.utf8(body))

def answer(result: M.Resolution<Tag>) -> Response.Res:
  match result:
    case M.Found{hit, head_from_get}:
      dispatch(hit)
    case M.NotFound{}:
      Response.text(404, "Not Found")
    case M.MethodNotAllowed{allow}:
      Response.body(405, [Request.Header{"allow", Bytes.encode(M.allow_text(allow))}], Response.utf8("Method Not Allowed"))

def options(q: Maybe<&2, String>) -> M.Options:
  match q:
    case Some{"lenient"}:
      M.Options{False{}, True{}}
    case Some{"case"}:
      M.Options{True{}, False{}}
    case Some{"relaxed"}:
      M.Options{False{}, False{}}
    case _:
      M.defaults()

def respond(table: M.Table(Tag), parsed: Request.ParseResult) -> List<&2, U32>:
  match parsed:
    case Request.Parsed{Request.Req{+m, p, q, v, hs}, rest}:
      Write.write(m, answer(M.resolve(Tag, table, p, m, options(q))))
    case _:
      Write.write(Request.Get{}, Response.body(400, [], []))

def sent(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def finished(table: M.Table(Tag), s: Socket, result: Request.ParseResult) -> IO(Unit):
  do IO<Unit>:
    out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, respond(table, result))
    sent(out)

def received(m: Socket & Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, state: Parse.State) -> Socket & (Parse.State & Request.ParseResult):
  (sock, r) = m
  match r:
    case Done{Some{bytes}}:
      (sock, Parse.feed(bytes, state))
    case _:
      (sock, (state, Request.Rejected{Request.InvalidRequestLine{}}))

def talk(+table: M.Table(Tag), fuel: Nat, m: Socket & (Parse.State & Request.ParseResult)) -> IO(Unit):
  match fuel:
    case 0n:
      (sock, step) = m
      Socket.close(sock)
    case 1n+f:
      (sock, step) = m
      (state, result) = step
      match result:
        case Request.NeedMore{}:
          do IO<Unit>:
            m : Socket & Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>> <- TCP.recv_bytes(sock, 65536)
            talk(table, f, received(m, state))
        case _:
          finished(table, sock, result)

def read(table: M.Table(Tag), s: Socket) -> IO(Unit):
  talk(table, 128n, (s, (Parse.initial(), Request.NeedMore{})))

def conn(table: M.Table(Tag), m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, read(table, s))
    return l

@unsafe
def loop(+table: M.Table(Tag), l: Listener) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(table, m)
    loop(table, l2)

def port_read(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{p}:
      p
    case None{}:
      18789

def port_or(r: Result<&1, &1, U32 & String, String>, fallback: U32) -> U32:
  match r:
    case Done{s}:
      port_read(U32.read(s))
    case Fail{e}:
      fallback

def start(table_result: Result<&2, &2, M.BuildError, M.Table(Tag)>) -> IO(Unit):
  match table_result:
    case Fail{e}:
      IO.die(Unit, 1, "invalid routes")
    case Done{table}:
      do IO<Unit>:
        env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
        port : U32 = port_or(env, 18789)
        listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
        loop(table, listener)

def main() -> IO(Unit):
  start(M.build_table(Tag, registrations()))
