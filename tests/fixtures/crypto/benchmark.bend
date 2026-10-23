import Base
import ../../../src/crypto/sha256.bend as SHA256
import ../../../src/data/hex.bend as Hex
import ./repeat.bend as R

def main() -> IO(Unit):
  do IO<Unit>:
    input : List<&2, U32> = R.repeat(1000000n, [])
    start : Nat <- IO.now()
    digest : String = Hex.encode(SHA256.hash(input))
    finish : Nat <- IO.now()
    IO.print(digest)
    IO.print(Nat.show(Nat.sub(finish, start)))
