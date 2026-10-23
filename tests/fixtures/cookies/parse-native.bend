import Base
import ../../../src/data/cookie.bend as C

def print_entries(xs: List<&2, C.Entry>) -> IO(Unit):
  match xs:
    case Nil{}: IO.pure(Unit, Unit{})
    case C.Entry{name, value} <> tail:
      do IO<Unit>:
        IO.print(C.serialize_pair(name, value))
        print_entries(tail)

def run(args: List<String>) -> IO(Unit):
  match args:
    case program <> header <> Nil{}: print_entries(C.parse(header))
    case _: IO.die(Unit, 1, "Expected one Cookie header")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
