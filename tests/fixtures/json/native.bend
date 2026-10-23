import Base
import ../../../src/data/utf8.bend as Utf8
import ../../../src/data/json.bend as J

# This shell reads raw fixture bytes, including intentionally invalid UTF-8.
def result(r: Result<&2, &2, J.Error, J.Json>) -> String:
  match r:
    case Fail{e}: "reject"
    case Done{v}: "accept"

def written(r: Result<&2, &2, J.Error, String>) -> String:
  match r:
    case Fail{e}: "write-error"
    case Done{s}: s

def roundtrip(r: Result<&2, &2, J.Error, J.Json>, pretty: Bool, ascii: Bool) -> String:
  match r:
    case Fail{e}: "reject"
    case Done{v}: written(J.write(v, pretty, ascii))

def bench_string(s: Maybe<&2, String>) -> IO(Unit):
  match s:
    case None{}: IO.print("utf8-error")
    case Some{text}:
      do IO<Unit>:
        before : Nat <- IO.now()
        parsed : String = result(J.parse_string(text))
        after : Nat <- IO.now()
        IO.print(parsed ++ ":" ++ Nat.show(Nat.sub(after, before)))

def unsigned_result(n: Maybe<&2, U32>) -> String:
  match n:
    case Some{n}: U32.show(n)
    case None{}: "none"

def unsigned(s: Maybe<&2, String>) -> String:
  match s:
    case Some{s}: unsigned_result(J.to_u32(J.JNumber{s}))
    case None{}: "none"

def report(mode: String, +body: List<&2, U32>) -> IO(Unit):
  match mode:
    case "u32": IO.print(unsigned(Utf8.decode(body)))
    case "bench-string": bench_string(Utf8.decode(body))
    case "bench":
      do IO<Unit>:
        before : Nat <- IO.now()
        parsed : String = result(J.parse(body))
        after : Nat <- IO.now()
        IO.print(parsed ++ ":" ++ Nat.show(Nat.sub(after, before)))
    case "pretty": IO.print(roundtrip(J.parse(body), True{}, False{}))
    case "ascii": IO.print(roundtrip(J.parse(body), False{}, True{}))
    case "write": IO.print(roundtrip(J.parse(body), False{}, False{}))
    case _: IO.print(result(J.parse(body)))

def read_result(mode: String, pair: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (handle, bytes) = pair
  do IO<Unit>:
    body : List<&2, U32> <- IO.try(List<&2, U32>, IO.pure(Result<&1, &1, U32 & String, List<&2, U32>>, bytes))
    File.close(handle)
    report(mode, body)

def file(mode: String, path: String) -> IO(Unit):
  do IO<Unit>:
    handle : File <- IO.try(File, File.open(path, "r"))
    pair : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(handle, 4194304)
    read_result(mode, pair)

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case exe <> mode <> path <> Nil{}: file(mode, path)
    case _: IO.print("bad-args")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
