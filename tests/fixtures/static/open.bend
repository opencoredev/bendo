# Calls the static open effect on each argument path beneath the first
# argument, so the native and JS twins can be compared.
import Base
import ../../../src/effects/static_file.bend as F

def shown(+path: String, +size: Nat, read: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (file, text) = read
  do IO<Unit>:
    File.close(file)
    IO.print(path ++ " file " ++ Nat.show(size) ++ " " ++ Result.default(&1, &1, U32 & String, String, text, "?"))

def report(+path: String, r: Result<&1, &1, U32 & String, File & (Nat & Nat)>) -> IO(Unit):
  match r:
    case Fail{(code, message)}: IO.print(path ++ " fail " ++ U32.show(code))
    case Done{(file, (size, mtime))}:
      do IO<Unit>:
        read : File & Result<&1, &1, U32 & String, String> <- File.read(file, 64)
        shown(path, size, read)

def each(+root: String, paths: List<String>) -> IO(Unit):
  match paths:
    case Nil{}: IO.pure(Unit, Unit{})
    case +p <> t:
      do IO<Unit>:
        r : Result<&1, &1, U32 & String, File & (Nat & Nat)> <- F.open_beneath(root, p)
        report(p, r)
        each(root, t)

def run(args: List<String>) -> IO(Unit):
  match args:
    case program <> root <> paths: each(root, paths)
    case _: IO.die(Unit, 2, "usage: open ROOT PATH...")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
