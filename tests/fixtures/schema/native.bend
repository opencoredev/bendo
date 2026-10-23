import Base
import ./consumer.bend as C

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case exe <> name <> text <> Nil{}: IO.print(C.run(name, C.parse(text)))
    case _: IO.print("bad-args")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
