# BND-93: calls the upstream connect effect for each COUNT HOST PORT MS group
# of arguments, so the native and JS twins can be compared. A group starts
# COUNT calls at once, waits for all of them and prints one line per call;
# COUNT 0 sleeps MS milliseconds instead.
import Base
import ../../../src/effects/upstream_connect.bend as Connect

def shown(+host: String, r: Result<&1, &1, U32 & String, Socket>) -> IO(String):
  match r:
    case Fail{(code, message)}: IO.pure(String, host ++ " fail " ++ U32.show(code))
    case Done{s}:
      do IO<String>:
        Socket.close(s)
        return host ++ " ok"

def num(n: Maybe<&2, Nat>) -> U32:
  match n:
    case None{}: 0
    case Some{v}: U32.from_nat(v)

def count(n: Maybe<&2, Nat>) -> Nat:
  match n:
    case None{}: 0n
    case Some{v}: v

def dial(+host: String, +port: U32, +ms: U32) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, Socket> <- Connect.upstream_connect(host, port, ms)
    shown(host, r)

def started(+host: String, +port: U32, +ms: U32, n: Nat, acc: List<&2, Chan(String)>) -> IO(List<&2, Chan(String)>):
  match n:
    case 0n: IO.pure(List<&2, Chan(String)>, acc)
    case 1n+k:
      do IO<List<&2, Chan(String)>>:
        c : Chan(String) <- IO.fork(String, dial(host, port, ms))
        started(host, port, ms, k, c <> acc)

def finished(cs: List<&2, Chan(String)>) -> IO(Unit):
  match cs:
    case Nil{}: IO.pure(Unit, Unit{})
    case c <> t:
      do IO<Unit>:
        line : String <- IO.join(String, c)
        IO.print(line)
        finished(t)

def group(+n: Nat, +host: String, port: String, +ms: U32) -> IO(Unit):
  match n:
    case 0n: IO.sleep(ms)
    case 1n+k:
      do IO<Unit>:
        cs : List<&2, Chan(String)> <- started(host, num(Nat.read(port)), ms, n, [])
        finished(cs)

def each(args: List<String>) -> IO(Unit):
  match args:
    case n <> +host <> port <> ms <> t:
      do IO<Unit>:
        group(count(Nat.read(n)), host, port, num(Nat.read(ms)))
        each(t)
    case _: IO.pure(Unit, Unit{})

def run(args: List<String>) -> IO(Unit):
  match args:
    case program <> rest: each(rest)
    case _: IO.die(Unit, 2, "usage: dial COUNT HOST PORT MS...")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
