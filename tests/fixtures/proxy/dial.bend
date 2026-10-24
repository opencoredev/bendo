# BND-93: calls the upstream connect effect once per HOST PORT MS triple and
# prints the outcome, so the native and JS twins can be compared.
import Base
import ../../../src/effects/upstream_connect.bend as Connect

def shown(+host: String, r: Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match r:
    case Fail{(code, message)}: IO.print(host ++ " fail " ++ U32.show(code))
    case Done{s}:
      do IO<Unit>:
        Socket.close(s)
        IO.print(host ++ " ok")

def num(n: Maybe<&2, Nat>) -> U32:
  match n:
    case None{}: 0
    case Some{v}: U32.from_nat(v)

def dial(+host: String, port: String, ms: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Socket> <- Connect.upstream_connect(host, num(Nat.read(port)), num(Nat.read(ms)))
    shown(host, r)

def each(args: List<String>) -> IO(Unit):
  match args:
    case +host <> port <> ms <> t:
      do IO<Unit>:
        dial(host, port, ms)
        each(t)
    case _: IO.pure(Unit, Unit{})

def run(args: List<String>) -> IO(Unit):
  match args:
    case program <> rest: each(rest)
    case _: IO.die(Unit, 2, "usage: dial HOST PORT MS...")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
