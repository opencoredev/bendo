# BND-84: the native build of the same helpers. `./fixture MODE N` builds its
# input in a tail loop, so no argument has to be 64 KiB long.
import Base
import ./common.bend as R

# `unit` repeated `n` times.
def rep(n: Nat, +unit: String, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      rep(p, unit, String.reverse.go(String.reverse(unit), acc))

def run(+mode: String, +n: Nat) -> String:
  match mode:
    case "encode":
      R.encode(rep(n, "é", ""))
    case "decode":
      R.decode(rep(n, "%41", ""))
    case "scalars":
      R.scalars(rep(n, "a", ""))
    case "digits":
      R.digits(rep(n, "1", ""))
    case "slug":
      R.slug(rep(n, "a", ""))
    case "uuid":
      R.uuid(rep(n, "a", ""))
    case "letters":
      R.letters(rep(n, "a", ""))
    case "segments":
      R.segments(rep(n, "a/", ""))
    case "wildcard":
      R.wildcard(rep(n, "a/", ""))
    case "capture":
      R.route("/:id", "/" ++ rep(n, "a", ""))
    case "int":
      R.route("/:id{int}", "/" ++ rep(n, "1", ""))
    case "named-wildcard":
      R.route("/*rest", "/" ++ rep(n, "a/", ""))
    case "interior-wildcard":
      R.route("/*/x", "/" ++ rep(n, "a/", "") ++ "x")
    case "options":
      R.route_options("/*rest", "/" ++ rep(n, "a/", ""))
    case "span":
      R.route("/:p{.+}/x", "/" ++ rep(n, "a/", "") ++ "x")
    case "resolve":
      R.resolve("/" ++ rep(n, "a/", "") ++ "b")
    case "resolve-escaped":
      R.resolve("/" ++ rep(n, "%61", ""))
    case _:
      "bad-mode"

def size(m: Maybe<&2, U32>) -> Nat:
  match m:
    case Some{n}:
      U32.to_nat(n)
    case None{}:
      0n

def args(xs: List<String>) -> String:
  match xs:
    case exe <> mode <> n <> Nil{}:
      run(mode, size(U32.read(n)))
    case _:
      "bad-args"

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    IO.print(args(xs))
