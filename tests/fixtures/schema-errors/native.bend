import Base
import ../../../src/data/json.bend as J
import ./consumer.bend as C

# One input per line; prints one result per line.
def line(mode: String, name: String, s: String) -> String:
  match mode:
    case "json": C.run(name, s)
    case "text": C.run_text(name, s)
    case "coerce": C.run_coerce(name, s)
    case "spec-coerce": C.coerce_parsed(True{}, name, J.parse_string(s))
    case "count-json": C.run_count(False{}, name, s)
    case "count-text": C.run_count(True{}, name, s)
    case _: "bad-mode"

def lines(+mode: String, +name: String, rows: List<&2, String>) -> IO(Unit):
  match rows:
    case Nil{}: IO.pure(Unit, Unit{})
    case r <> t:
      do IO<Unit>:
        IO.print(line(mode, name, r))
        lines(mode, name, t)

def timed(mode: String, name: String, s: String) -> IO(Unit):
  do IO<Unit>:
    before : Nat <- IO.now()
    result : String = line(mode, name, s)
    after : Nat <- IO.now()
    IO.print(result ++ ":" ++ Nat.show(Nat.sub(after, before)))

def run(mode: String, name: String, body: Maybe<&2, String>) -> IO(Unit):
  match body:
    case None{}: IO.print("bad-utf8")
    case Some{s}: lines(mode, name, String.split(s, '\n'))

def bench(mode: String, name: String, body: Maybe<&2, String>) -> IO(Unit):
  match body:
    case None{}: IO.print("bad-utf8")
    case Some{s}: timed(mode, name, s)

def pick(bench_mode: Bool, mode: String, name: String, body: Maybe<&2, String>) -> IO(Unit):
  match bench_mode:
    case True{}: bench(mode, name, body)
    case False{}: run(mode, name, body)

def read_result(bench_mode: Bool, mode: String, name: String, pair: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (handle, bytes) = pair
  do IO<Unit>:
    body : List<&2, U32> <- IO.try(List<&2, U32>, IO.pure(Result<&1, &1, U32 & String, List<&2, U32>>, bytes))
    File.close(handle)
    pick(bench_mode, mode, name, J.decode(body))

def file(bench_mode: Bool, mode: String, name: String, path: String) -> IO(Unit):
  do IO<Unit>:
    handle : File <- IO.try(File, File.open(path, "r"))
    pair : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(handle, 8388608)
    read_result(bench_mode, mode, name, pair)

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case exe <> "bench" <> mode <> name <> path <> Nil{}: file(True{}, mode, name, path)
    case exe <> mode <> name <> path <> Nil{}: file(False{}, mode, name, path)
    case _: IO.print("bad-args")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
