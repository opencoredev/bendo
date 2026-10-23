# Test-only shell: constructs the table once and copies it into each connection.
import Base
import ../../src/router/spec.bend as S
import ../../src/router/pattern.bend as P
import ../../src/serve.bend as Serve
import ../../src/http.bend as Http

type Tag is Data:
  Root{}
  Health{}
  About{}
  NewUser{}
  UserInt{}
  UserName{}
  Post{}
  PostRest{}
  Files{}
  Optional{}
  Year{}
  Uuid{}
  Pair{}
  First{}
  Second{}
  Encoded{}
  StaticEnd{}
  Tail{}
  Class{}
  Fallback{}

def registrations() -> List<&2, S.Registration<Tag>>:
  [
    S.Registration{"/", Root{}},
    S.Registration{"/health", Health{}},
    S.Registration{"/about", About{}},
    S.Registration{"/users/new", NewUser{}},
    S.Registration{"/users/:id{int}", UserInt{}},
    S.Registration{"/users/:name", UserName{}},
    S.Registration{"/posts/:slug{slug}", Post{}},
    S.Registration{"/posts/*rest", PostRest{}},
    S.Registration{"/files/*path", Files{}},
    S.Registration{"/opt/:value?", Optional{}},
    S.Registration{"/year/:year{[0-9]{4}}", Year{}},
    S.Registration{"/uuid/:id{uuid}", Uuid{}},
    S.Registration{"/pair/:left/:right", Pair{}},
    S.Registration{"/same/:first", First{}},
    S.Registration{"/same/:second", Second{}},
    S.Registration{"/encoded/:value", Encoded{}},
    S.Registration{"/static/end", StaticEnd{}},
    S.Registration{"/tail/*", Tail{}},
    S.Registration{"/class/:value{[a-z]+}", Class{}},
    S.Registration{"/fallback/*path", Fallback{}}
  ]

def tag_name(tag: Tag) -> String:
  match tag:
    case Root{}:
      "Root"
    case Health{}:
      "Health"
    case About{}:
      "About"
    case NewUser{}:
      "NewUser"
    case UserInt{}:
      "UserInt"
    case UserName{}:
      "UserName"
    case Post{}:
      "Post"
    case PostRest{}:
      "PostRest"
    case Files{}:
      "Files"
    case Optional{}:
      "Optional"
    case Year{}:
      "Year"
    case Uuid{}:
      "Uuid"
    case Pair{}:
      "Pair"
    case First{}:
      "First"
    case Second{}:
      "Second"
    case Encoded{}:
      "Encoded"
    case StaticEnd{}:
      "StaticEnd"
    case Tail{}:
      "Tail"
    case Class{}:
      "Class"
    case Fallback{}:
      "Fallback"

def params_text(ps: P.Params) -> String:
  match ps:
    case Nil{}:
      ""
    case P.Param{name, value} <> rest:
      "|" ++ name ++ "=" ++ value ++ params_text(rest)

def dispatch(hit: Maybe<&2, S.Match<Tag>>) -> String:
  match hit:
    case None{}:
      "miss"
    case Some{S.Match{index, tag, params}}:
      tag_name(tag) ++ ":" ++ Nat.show(index) ++ params_text(params)

def app(table: S.Table(Tag), req: String) -> String:
  Http.text(dispatch(S.route(Tag, table, Http.path_of(req))))

def reply(table: S.Table(Tag), input: Socket & Result<&1, &1, U32 & String, Maybe<&1, String>>) -> IO(Unit):
  (socket, result) = input
  match result:
    case Done{Some{request}}:
      do IO<Unit>:
        sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(socket, app(table, request))
        Serve.sent(sent)
    case _:
      Socket.close(socket)

def talk(table: S.Table(Tag), socket: Socket) -> IO(Unit):
  do IO<Unit>:
    input : Socket & Result<&1, &1, U32 & String, Maybe<&1, String>> <- TCP.recv(socket, 65536)
    reply(table, input)

def connection(table: S.Table(Tag), input: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (listener, result) = input
  do IO<Listener>:
    socket : Socket <- IO.pass(Socket, result)
    IO.spawn(Unit, talk(table, socket))
    return listener

@unsafe
def loop(+table: S.Table(Tag), listener: Listener) -> IO(Unit):
  do IO<Unit>:
    input : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
    next : Listener <- connection(table, input)
    loop(table, next)

def start(result: Result<&2, &2, S.BuildError, S.Table(Tag)>) -> IO(Unit):
  match result:
    case Fail{S.BuildError{index, source, error}}:
      IO.die(Unit, 1, "invalid route " ++ Nat.show(index) ++ ": " ++ source ++ " " ++ P.error_message(error))
    case Done{table}:
      do IO<Unit>:
        env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
        listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", Serve.port_or(env, 18915)))
        loop(table, listener)

def main() -> IO(Unit):
  start(S.build_table(Tag, registrations()))
