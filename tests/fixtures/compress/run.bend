# Runs the zlib effect on a file so the native and JS twins can be compared:
# run FORMAT LEVEL LIMIT IN OUT writes the coded octets of IN to OUT, or
# prints "fail CODE".
import Base
import ../../../src/effects/zlib.bend as Z

def written(out: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (file, r) = out
  File.close(file)

def save(+path: String, r: Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  match r:
    case Fail{(code, message)}: IO.print("fail " ++ U32.show(code))
    case Done{bytes}:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(path, "w"))
        out : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(file, bytes)
        written(out)
        IO.print("ok")

def coded(format: U32, level: U32, limit: U32, +out: String, read: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (file, r) = read
  do IO<Unit>:
    File.close(file)
    bytes : List<&2, U32> <- IO.pass(List<&2, U32>, r)
    z : Result<&1, &1, U32 & String, List<&2, U32>> <- Z.zlib_compress(format, level, limit, bytes)
    save(out, z)

def number(s: String) -> U32:
  Maybe.default(&2, U32, U32.read(s), 0)

def run(args: List<String>) -> IO(Unit):
  match args:
    case program <> format <> level <> limit <> input <> out <> Nil{}:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(input, "r"))
        read : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 4294967295)
        coded(number(format), number(level), number(limit), out, read)
    case _: IO.die(Unit, 2, "usage: run FORMAT LEVEL LIMIT IN OUT")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
