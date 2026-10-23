import Base
import ../../src/main.bend as B
import ../../src/http/sse.bend as Sse
import ../../src/http/sse_types.bend as E
import ../../src/http/stream_types.bend as S
import ../../src/http/response.bend as Response
import ../../src/app/config.bend as Config
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Page{}
  Events{}
  Frames{}
  Reject{}
  Heartbeat{}
  Quiet{}
  Last{}
  Encoded{}

# Paced numbered events. `left` counts the events this connection still sends.
type Tick is Data:
  Tick{left: Nat, next: U32, after: String, retry: Maybe<&2, U32>}

def cleanup(state: Tick) -> IO(Unit):
  IO.pure(Unit, Unit{})

def tick_frame(+next: U32, after: String, retry: Maybe<&2, U32>) -> Sse.Frame:
  B.sse_message(Some{"tick"}, "event " ++ U32.show(next) ++ " after " ++ after, Some{U32.show(next)}, retry)

def tick(state: Tick) -> IO(E.Step<Tick>):
  match state:
    case Tick{0n, next, after, retry}: IO.pure(E.Step<Tick>, E.End{Tick{0n, next, after, retry}})
    case Tick{1n+left, +next, +after, retry}:
      do IO<E.Step<Tick>>:
        IO.sleep(40)
        return E.Send{tick_frame(next, after, retry), Tick{left, (next + 1 : U32), after, None{}}}

# Fixed frames, sent in order, then End or an unsafe frame.
type Script is Data:
  Script{frames: List<&2, Sse.Frame>}

def script_cleanup(state: Script) -> IO(Unit):
  IO.pure(Unit, Unit{})

def script(state: Script) -> IO(E.Step<Script>):
  match state:
    case Script{Nil{}}: IO.pure(E.Step<Script>, E.End{Script{[]}})
    case Script{f <> rest}: IO.pure(E.Step<Script>, E.Send{f, Script{rest}})

# Stays idle until `until` (epoch ms), then sends one event and ends.
type Hold is Data:
  Hold{until: Nat, done: Bool}

def wait_cleanup(state: Hold) -> IO(Unit):
  IO.pure(Unit, Unit{})

def ready_at(until: Nat, ready: Bool) -> E.Step<Hold>:
  match ready:
    case True{}: E.Send{B.sse_data("ready"), Hold{until, True{}}}
    case False{}: E.Idle{Hold{until, False{}}}

def waited(+until: Nat, now: Nat) -> E.Step<Hold>:
  ready_at(until, Nat.is_le(until, now))

def waiting(state: Hold) -> IO(E.Step<Hold>):
  match state:
    case Hold{until, True{}}: IO.pure(E.Step<Hold>, E.End{Hold{until, True{}}})
    case Hold{until, False{}}:
      do IO<E.Step<Hold>>:
        now : Nat <- IO.now()
        return waited(until, now)

def number(value: Maybe<&2, String>, fallback: U32) -> U32:
  match value:
    case None{}: fallback
    case Some{s}: Maybe.default(&2, U32, U32.read(s), fallback)

def label(value: Maybe<&2, String>) -> String:
  match value:
    case None{}: "start"
    case Some{s}: s

def started(+c: B.Context(Unit), +start: U32, +left: Nat, after: String, finished: Bool) -> IO(B.Res):
  match finished:
    case True{}: IO.pure(B.Res, B.text(B.status(c, 204), ""))
    case False{}: B.stream_sse(~Unit, ~Tick, ~tick, ~cleanup, c, Tick{left, start, after, Some{250}}, B.sse_config())

# Resume after Last-Event-ID. The first connection sends `drop` events, then
# ends so the browser reconnects. A reconnect after the last event gets 204,
# which tells EventSource to stop.
def resume(+c: B.Context(Unit), +count: U32, +drop: U32, +last: Maybe<&2, String>) -> IO(B.Res):
  +start = (number(last, 0) + 1 : U32)
  +budget = Bool.pick(U32, U32.is_eq(number(last, 0), 0), drop, count)
  +left = U32.to_nat(U32.min(budget, Bool.pick(U32, (start <= count : U32), (count + 1 - start : U32), 0)))
  started(c, start, left, label(last), Nat.is_eq(left, 0n))

def frames() -> List<&2, Sse.Frame>:
  [
    Sse.Comment{[32, 104, 101, 108, 108, 111]},
    Sse.Message{Some{[117, 112, 100, 97, 116, 101]}, [108, 102, 10, 99, 114, 13, 99, 114, 108, 102, 13, 10, 101, 110, 100], Some{[55]}, Some{1500}},
    Sse.Message{None{}, [32, 108, 101, 97, 100, 58, 32, 120], None{}, None{}},
    Sse.Message{None{}, [], Some{[]}, Some{0}},
    Sse.Message{Some{[]}, [13, 13, 10, 10], None{}, Some{4294967295}},
    B.sse_message(Some{"ünï"}, "snow ☃ and 🎉", Some{"id ✓"}, None{})
  ]

def unsafe(kind: Maybe<&2, String>) -> Sse.Frame:
  match kind:
    case Some{"id"}: Sse.Message{None{}, [120], Some{[49, 10, 100, 97, 116, 97, 58, 32, 120]}, None{}}
    case Some{"nul"}: Sse.Message{None{}, [120], Some{[49, 0]}, None{}}
    case Some{"comment"}: Sse.Comment{[120, 13, 100, 97, 116, 97, 58, 32, 120]}
    case Some{"utf8"}: Sse.Message{None{}, [104, 105, 255], None{}, None{}}
    case Some{"overlong"}: Sse.Message{Some{[192, 175]}, [120], None{}, None{}}
    case _: Sse.Message{Some{[120, 10, 10, 100, 97, 116, 97, 58, 32, 120]}, [120], None{}, None{}}

def custom(+heartbeat: U32, +idle: U32) -> E.Config:
  E.Config{S.Config{2000, 65536}, heartbeat, idle, [32, 107, 101, 101, 112, 97, 108, 105, 118, 101]}

def page() -> String:
  "<!doctype html><html lang=en><meta charset=utf-8><meta name=viewport content='width=device-width'>"
  ++ "<title>Bendo SSE check</title><style>body{font:16px system-ui;margin:2rem;max-width:40rem}"
  ++ "#status{font-weight:600}li{font-family:ui-monospace,monospace}</style>"
  ++ "<h1>Bendo SSE check</h1><p>Expects events 1 to 10 in order over two connections: the server ends the first after 4 events, the browser reconnects with Last-Event-ID 4, and a final reconnect gets 204.</p>"
  ++ "<p id=status>running</p><p id=detail></p><ol id=log></ol><script>"
  ++ "const total=10,drop=4,seen=[],opens=[];const status=document.getElementById('status');"
  ++ "const es=new EventSource('/events?count='+total+'&drop='+drop);"
  ++ "es.onopen=()=>opens.push(Date.now());"
  ++ "es.addEventListener('tick',e=>{seen.push({id:e.lastEventId,data:e.data});const li=document.createElement('li');li.textContent=e.lastEventId+': '+e.data;document.getElementById('log').append(li);});"
  ++ "es.onerror=()=>{if(es.readyState!==EventSource.CLOSED)return;"
  ++ "const ids=seen.map(s=>s.id).join(',');const want=Array.from({length:total},(_,i)=>String(i+1)).join(',');"
  ++ "const resumed=seen.length>drop&&seen[drop].data==='event '+(drop+1)+' after '+drop;"
  ++ "const ok=ids===want&&opens.length===2&&resumed;document.body.dataset.result=ok?'pass':'fail';"
  ++ "status.textContent=ok?'PASS':'FAIL';document.getElementById('detail').textContent='ids '+ids+'; connections '+opens.length+'; resumed '+resumed;};"
  ++ "</script></html>"

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  match tag:
    case Page{}: IO.pure(B.Res, B.html(c, page()))
    case Events{}:
      +ctx = c
      resume(ctx, number(B.query(ctx, "count"), 10), number(B.query(ctx, "drop"), 4), B.last_event_id(Unit, ctx))
    case Frames{}: B.stream_sse(~Unit, ~Script, ~script, ~script_cleanup, c, Script{frames()}, B.sse_config())
    case Reject{}:
      +ctx = c
      B.stream_sse(~Unit, ~Script, ~script, ~script_cleanup, ctx, Script{[B.sse_data("before"), unsafe(B.query(ctx, "field")), B.sse_data("after")]}, B.sse_config())
    case Heartbeat{}:
      +ctx = c
      do IO<B.Res>:
        now : Nat <- IO.now()
        B.stream_sse(~Unit, ~Hold, ~waiting, ~wait_cleanup, ctx, Hold{Nat.add(now, U32.to_nat(number(B.query(ctx, "wait"), 450))), False{}}, custom(number(B.query(ctx, "every"), 100), 20))
    case Quiet{}:
      +ctx = c
      do IO<B.Res>:
        now : Nat <- IO.now()
        B.stream_sse(~Unit, ~Hold, ~waiting, ~wait_cleanup, ctx, Hold{Nat.add(now, 300n), False{}}, custom(0, 20))
    case Last{}:
      +ctx = c
      B.stream_sse(~Unit, ~Script, ~script, ~script_cleanup, ctx, Script{[B.sse_data(label(B.last_event_id(Unit, ctx)))]}, B.sse_config())
    case Encoded{}:
      +ctx = c
      B.stream_sse(~Unit, ~Script, ~script, ~script_cleanup, B.header(B.header(ctx, "content-encoding", "gzip"), "cache-control", "public, max-age=60"), Script{[B.sse_data("plain")]}, B.sse_config())

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  next(c)

def host(value: Result<&1, &1, U32 & String, String>) -> String:
  match value:
    case Fail{error}: "127.0.0.1"
    case Done{s}: s

def with_host(config: Config.Config, host: String) -> Config.Config:
  Config.Config{old, port, body, header, idle, head, timeout, max, keep, router} = config
  Config.Config{host, port, body, header, idle, head, timeout, max, keep, router}

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>, address: String) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, with_host(B.config(), address))

# HOST=<Tailscale IPv4> serves the browser check to other devices; tests use 127.0.0.1.
def main() -> IO(Unit):
  do IO<Unit>:
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("HOST")
    ready(B.routes(Tag, [
      B.get(Tag, "/", Page{}),
      B.get(Tag, "/events", Events{}),
      B.get(Tag, "/frames", Frames{}),
      B.get(Tag, "/reject", Reject{}),
      B.get(Tag, "/heartbeat", Heartbeat{}),
      B.get(Tag, "/quiet", Quiet{}),
      B.get(Tag, "/last", Last{}),
      B.get(Tag, "/encoded", Encoded{})
    ]), host(env))
