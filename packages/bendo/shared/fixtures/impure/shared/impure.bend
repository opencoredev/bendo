# Shared code must be pure; `bendo build --shared` refuses this file, naming
# every def that returns IO, directly or through a type-level alias.
import Base
import ../lib/effects.bend as Effects

def Action() -> Type:
  IO(Unit)

def Later() -> Type:
  Action()

def Identity(A: Type) -> Type:
  A

def double(+n: Nat) -> Nat:
  (n + n : Nat)

def announce(s: String) -> IO(Unit):
  IO.print(s)

def shout(s: String) -> Action():
  IO.print(s)

def later(s: String) -> Later():
  IO.print(s)

def remote(s: String) -> Effects.Effect():
  IO.print(s)

def wrapped(s: String) -> Identity(IO(Unit)):
  IO.print(s)
