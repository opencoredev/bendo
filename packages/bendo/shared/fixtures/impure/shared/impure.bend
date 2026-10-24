# Shared code must be pure; `bendo build --shared` refuses this file.
import Base

def double(+n: Nat) -> Nat:
  (n + n : Nat)

def announce(s: String) -> IO(Unit):
  IO.print(s)
