import Base
import ../../../src/data/cookie.bend as C
import ./consumer.bend as Consumer

def print_error(error: C.Error) -> IO(Unit):
  match error:
    case C.InvalidName{}: IO.print("InvalidName")
    case C.InvalidValue{}: IO.print("InvalidValue")
    case C.InvalidPath{}: IO.print("InvalidPath")
    case C.InvalidDomain{}: IO.print("InvalidDomain")
    case C.InvalidExpires{}: IO.print("InvalidExpires")
    case C.SameSiteRequiresSecure{}: IO.print("SameSiteRequiresSecure")
    case C.PartitionedRequiresSecure{}: IO.print("PartitionedRequiresSecure")
    case C.InvalidSecret{}: IO.print("InvalidSecret")

def print_result(result: Result<&2, &2, C.Error, String>) -> IO(Unit):
  match result:
    case Done{value}: IO.print(value)
    case Fail{error}: print_error(error)

def run(args: List<String>) -> IO(Unit):
  match args:
    case program <> mode <> payload <> context <> Nil{}: print_result(Consumer.context_case(mode, payload))
    case program <> mode <> payload <> Nil{}: print_result(Consumer.serialization_case(mode, payload))
    case _: IO.die(Unit, 1, "Expected mode and payload")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
