import Base
import ./shapes.bend as S
import ../../src/http.bend as Http

type Message is Data:
  Add{reply: Chan(U32)}
  Read{reply: Chan(U32)}

type Env is Data:
  Env{counter: Chan(Message), table: List<&2, S.Route>, counting: Bool}

def send_ok(-A: Type, r: Result<&1, &1, A, Unit>) -> IO(Unit):
  match r:
    case Done{u}:
      IO.pure(Unit, Unit{})
    case Fail{e}:
      IO.die(Unit, 1, "counter send failed")

def take(got: Maybe<&1, U32>) -> IO(U32):
  match got:
    case Some{n}:
      IO.pure(U32, n)
    case None{}:
      IO.die(U32, 1, "counter reply channel closed")

type ActorStep is Type:
  Poll{}
  MessageReady{message: Maybe<&1, Message>}

@unsafe
def actor(+chan: Chan(Message), +count: U32, step: ActorStep) -> IO(Unit):
  match step:
    case Poll{}:
      do IO<Unit>:
        msg : Maybe<&1, Message> <- Chan.recv(Message, chan)
        actor(chan, count, MessageReady{msg})
    case MessageReady{None{}}:
      IO.pure(Unit, Unit{})
    case MessageReady{Some{Add{reply}}}:
      do IO<Unit>:
        sent : Result<&1, &1, U32, Unit> <- Chan.send(U32, reply, (count + 1 : U32))
        send_ok(U32, sent)
        actor(chan, (count + 1 : U32), Poll{})
    case MessageReady{Some{Read{reply}}}:
      do IO<Unit>:
        sent : Result<&1, &1, U32, Unit> <- Chan.send(U32, reply, count)
        send_ok(U32, sent)
        actor(chan, count, Poll{})

def ask_send(chan: Chan(Message), +reply: Chan(U32), read: Bool) -> IO(U32):
  match read:
    case True{}:
      do IO<U32>:
        sent : Result<&1, &1, Message, Unit> <- Chan.send(Message, chan, Read{reply})
        send_ok(Message, sent)
        got : Maybe<&1, U32> <- Chan.recv(U32, reply)
        Chan.close(U32, reply)
        take(got)
    case False{}:
      do IO<U32>:
        sent : Result<&1, &1, Message, Unit> <- Chan.send(Message, chan, Add{reply})
        send_ok(Message, sent)
        got : Maybe<&1, U32> <- Chan.recv(U32, reply)
        Chan.close(U32, reply)
        take(got)

def ask(+chan: Chan(Message), read: Bool) -> IO(U32):
  do IO<U32>:
    +reply : Chan(U32) <- Chan.new(U32, 1)
    ask_send(chan, reply, read)

def respond_count(counting: Bool, counter: Chan(Message), tag: U32) -> IO(String):
  match counting:
    case False{}:
      IO.pure(String, U32.show(tag))
    case True{}:
      do IO<String>:
        n : U32 <- ask(counter, False{})
        return U32.show(n)

def respond(env: Env, tag: U32) -> IO(String):
  Env{counter, table, counting} = env
  respond_count(counting, counter, tag)

def output(+body: String) -> String:
  "HTTP/1.1 200 OK\r\nContent-Length: " ++ Nat.show(String.length(body)) ++ "\r\nContent-Type: text/plain\r\n\r\n" ++ body

def counter_of(env: Env) -> Chan(Message):
  Env{counter, table, counting} = env
  counter

def control(~app: Env -> String -> IO(String), +env: Env, path: String, read: Bool) -> IO(String):
  match read:
    case True{}:
      do IO<String>:
        n : U32 <- ask(counter_of(env), True{})
        return U32.show(n)
    case False{}:
      app(env, path)

# This shell supports sequential small ASCII GETs only, not general HTTP framing.
# No pipelining or request bodies; load clients wait for each Content-Length body.
type Step is Type:
  Receive{socket: Socket, buffer: String}
  Received{got: Socket & Result<&1, &1, U32 & String, Maybe<&1, String>>, buffer: String}
  Buffered{socket: Socket, request: String, complete: Bool}
  Sent{got: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>}

@unsafe
def talk(~app: Env -> String -> IO(String), +env: Env, step: Step) -> IO(Unit):
  match step:
    case Receive{s, buffer}:
      do IO<Unit>:
        got : Socket & Result<&1, &1, U32 & String, Maybe<&1, String>> <- TCP.recv(s, 8192)
        talk(~app, env, Received{got, buffer})
    case Received{(s, Done{Some{req}}), buffer}:
      +joined = buffer ++ req
      talk(~app, env, Buffered{s, joined, String.contains(joined, "\r\n\r\n")})
    case Buffered{s, req, False{}}:
      talk(~app, env, Receive{s, req})
    case Buffered{s, req, True{}}:
      do IO<Unit>:
        +path : String = Http.path_of(req)
        body : String <- control(~app, env, path, String.eq(path, "/__count"))
        sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(s, output(body))
        talk(~app, env, Sent{sent})
    case Received{(s, r), buffer}:
      Socket.close(s)
    case Sent{(s, Done{u})}:
      talk(~app, env, Receive{s, ""})
    case Sent{(s, Fail{e})}:
      Socket.close(s)

@unsafe
def accepted(~app: Env -> String -> IO(String), env: Env,
             got: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = got
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, talk(~app, env, Receive{s, ""}))
    return l

@unsafe
def accept(~app: Env -> String -> IO(String), +env: Env, l: Listener) -> IO(Unit):
  do IO<Unit>:
    got : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    next : Listener <- accepted(~app, env, got)
    accept(~app, env, next)

def pad(s: String) -> String:
  match s:
    case SCon{a, SNil{}}:
      "00" ++ SCon{a, SNil{}}
    case SCon{a, SCon{b, SNil{}}}:
      "0" ++ SCon{a, SCon{b, SNil{}}}
    case _:
      s

def path_for(mode: U32, +i: U32, +count: U32) -> String:
  match mode:
    case 1:
      "/r" ++ pad(U32.show(count))
    case 2:
      "/r999"
    case _:
      "/r" ++ pad(U32.show((U32.mod(i, count) + 1 : U32)))

def workload(fuel: Nat, +count: U32, +mode: U32) -> List<&2, String>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+rest:
      +r = rest
      path_for(mode, U32.from_nat(r), count) <> workload(r, count, mode)

def dispatch_paths(~dispatch: List<&2, S.Route> -> String -> U32 -> U32,
                   paths: List<&2, String>, +table: List<&2, S.Route>, sum: U32) -> U32:
  match paths:
    case Nil{}:
      sum
    case Con{path, rest}:
      value = dispatch(table, path, 0)
      dispatch_paths(~dispatch, rest, table, (sum + value : U32))

def batch(~dispatch: List<&2, S.Route> -> String -> U32 -> U32,
          fuel: Nat, +table: List<&2, S.Route>, +paths: List<&2, String>, sum: U32) -> U32:
  match fuel:
    case 0n:
      sum
    case 1n+rest:
      batch(~dispatch, rest, table, paths, dispatch_paths(~dispatch, paths, table, sum))

def measure(~dispatch: List<&2, S.Route> -> String -> U32 -> U32,
            table: List<&2, S.Route>, +count: U32, +mode: U32, +iterations: U32) -> IO(Unit):
  do IO<Unit>:
    +paths : List<&2, String> = workload(U32.to_nat(count), count, mode)
    # Force construction through an effect before the starting timestamp.
    IO.print("paths=" ++ Nat.show(List.length(&2, String, paths)))
    start : Nat <- IO.now()
    sum : U32 = batch(~dispatch, U32.to_nat(U32.div(iterations, count)), table,
                     paths, 0)
    IO.print("checksum=" ++ U32.show(sum))
    end : Nat <- IO.now()
    IO.print("mode=" ++ U32.show(mode) ++ " iterations=" ++ U32.show(iterations) ++ " ms=" ++ Nat.show(Nat.sub(end, start)))

def env_string(r: Result<&1, &1, U32 & String, String>, fallback: String) -> String:
  match r:
    case Done{s}:
      s
    case Fail{e}:
      fallback

def num(r: Maybe<&2, U32>, fallback: U32) -> U32:
  match r:
    case Some{n}:
      n
    case None{}:
      fallback

def number(r: Result<&1, &1, U32 & String, String>, fallback: U32) -> U32:
  match r:
    case Done{s}:
      num(U32.read(s), fallback)
    case Fail{e}:
      fallback

@unsafe
def run_choice(~app: Env -> String -> IO(String),
               ~dispatch: List<&2, S.Route> -> String -> U32 -> U32,
               +table: List<&2, S.Route>, +count: U32, bench: Bool, counting: Bool, +iterations: U32) -> IO(Unit):
  match bench:
    case True{}:
      do IO<Unit>:
        measure(~dispatch, table, count, 0, iterations)
        measure(~dispatch, table, count, 1, iterations)
        measure(~dispatch, table, count, 2, iterations)
    case False{}:
      do IO<Unit>:
        +counter : Chan(Message) <- Chan.new(Message, 128)
        IO.spawn(Unit, actor(counter, 0, Poll{}))
        port_env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
        l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", number(port_env, 18803)))
        IO.print("ready")
        accept(~app, Env{counter, table, counting}, l)

@unsafe
def run_selected(~app: Env -> String -> IO(String),
                 ~dispatch: List<&2, S.Route> -> String -> U32 -> U32,
                 +table: List<&2, S.Route>, +count: U32, +mode: String, +iterations: U32) -> IO(Unit):
  do IO<Unit>:
    run_choice(~app, ~dispatch, table, count, String.eq(mode, "bench"), String.eq(mode, "counter"), iterations)

@unsafe
def run_mode(~app: Env -> String -> IO(String),
             ~dispatch: List<&2, S.Route> -> String -> U32 -> U32,
             +table: List<&2, S.Route>, count: U32, mode: String) -> IO(Unit):
  do IO<Unit>:
    it : Result<&1, &1, U32 & String, String> <- IO.get_env("ITERATIONS")
    +iterations : U32 = number(it, 20000)
    run_selected(~app, ~dispatch, table, count, mode, iterations)

@unsafe
def run(~app: Env -> String -> IO(String),
        ~dispatch: List<&2, S.Route> -> String -> U32 -> U32,
        table: List<&2, S.Route>, count: U32) -> IO(Unit):
  do IO<Unit>:
    mode : Result<&1, &1, U32 & String, String> <- IO.get_env("MODE")
    run_mode(~app, ~dispatch, table, count, env_string(mode, "bench"))
