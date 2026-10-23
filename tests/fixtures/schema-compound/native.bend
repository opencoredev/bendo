import Base
import ../../../src/data/json.bend as J
import ./consumer.bend as C

# Reads the JSON body from a file so megabyte inputs fit, then decodes it.
def timed(name: String, parsed: Result<&2, &2, J.Error, J.Json>) -> IO(Unit):
  do IO<Unit>:
    before : Nat <- IO.now()
    result : String = C.count(C.decode_parsed(name, parsed))
    after : Nat <- IO.now()
    IO.print(result ++ ":" ++ Nat.show(Nat.sub(after, before)))

def report(mode: String, name: String, body: List<&2, U32>) -> IO(Unit):
  match mode:
    case "typed": IO.print(C.describe(C.typed(C.decode_parsed("user", J.parse(body)))))
    case "count": IO.print(C.count(C.decode_parsed(name, J.parse(body))))
    case "bench": timed(name, J.parse(body))
    case _: IO.print(C.report(C.decode_parsed(name, J.parse(body))))

def read_result(mode: String, name: String, pair: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (handle, bytes) = pair
  do IO<Unit>:
    body : List<&2, U32> <- IO.try(List<&2, U32>, IO.pure(Result<&1, &1, U32 & String, List<&2, U32>>, bytes))
    File.close(handle)
    report(mode, name, body)

def file(mode: String, name: String, path: String) -> IO(Unit):
  do IO<Unit>:
    handle : File <- IO.try(File, File.open(path, "r"))
    pair : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(handle, 4194304)
    read_result(mode, name, pair)

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case exe <> mode <> name <> path <> Nil{}: file(mode, name, path)
    case _: IO.print("bad-args")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
