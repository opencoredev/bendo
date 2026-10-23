import Base
import ./consumer.bend as C
import ./repeat.bend as R
import ../../../src/crypto/random.bend as Random
import ../../../src/data/hex.bend as Hex

def report(result: Result<&1, &1, Random.RandomError(), List<&2, U32>>) -> String:
  match result:
    case Fail{error}:
      (code, message) = error
      "error:" ++ U32.show(code) ++ ":" ++ message
    case Done{bytes}:
      Hex.encode(bytes)

def random() -> IO(Unit):
  do IO<Unit>:
    empty : Result<&1, &1, Random.RandomError(), List<&2, U32>> <- Random.random_bytes(0n)
    a : Result<&1, &1, Random.RandomError(), List<&2, U32>> <- Random.random_bytes(32n)
    b : Result<&1, &1, Random.RandomError(), List<&2, U32>> <- Random.random_bytes(32n)
    IO.print(report(empty))
    IO.print(report(a))
    IO.print(report(b))

def run(mode: String, a: Maybe<&2, List<&2, U32>>, b: Maybe<&2, List<&2, U32>>) -> IO(Unit):
  match mode a b:
    case "sha1" Some{xs} _:
      IO.print(C.sha1(xs))
    case "sha256" Some{xs} _:
      IO.print(C.sha256(xs))
    case "hmac" Some{k} Some{xs}:
      IO.print(C.hmac(k, xs))
    case _ _ _:
      IO.die(Unit, 1, "bad arguments")

def million() -> IO(Unit):
  do IO<Unit>:
    input : List<&2, U32> = R.repeat(1000000n, [])
    IO.print(C.sha1(input))
    IO.print(C.sha256(R.repeat(1000000n, [])))

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case _ <> "million" <> _:
      million()
    case _ <> "random" <> _:
      random()
    case _ <> mode <> a <> b <> _:
      run(mode, Hex.decode(a), Hex.decode(b))
    case _ <> mode <> a <> _:
      run(mode, Hex.decode(a), None{})
    case _:
      IO.die(Unit, 1, "bad arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
