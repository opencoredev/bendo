import Base
import ../../../src/data/cookie.bend as C
import ./consumer.bend as Consumer

def print_entries(xs: List<&2, C.Entry>) -> IO(Unit):
  match xs:
    case Nil{}: IO.pure(Unit, Unit{})
    case C.Entry{name, value} <> tail:
      do IO<Unit>:
        IO.print(C.serialize_pair(name, value))
        print_entries(tail)

def print_first(result: Maybe<&2, String>) -> IO(Unit):
  match result:
    case None{}: IO.print("absent")
    case Some{value}: IO.print(value)

def run(args: List<String>) -> IO(Unit):
  match args:
    case program <> header <> Nil{}: print_entries(C.parse(header))
    case program <> header <> name <> Nil{}: print_first(C.first(C.parse(header), name))
    case program <> header <> name <> mode <> Nil{}: print_first(C.first(Consumer.cookies_header(header), name))
    case _: IO.die(Unit, 1, "Expected one Cookie header")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
