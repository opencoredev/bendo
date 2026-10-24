# Imported by src/main.ts through vite-plugin-bendo.
import Base
import ./rules.bend as Rules

def long_enough(n: Nat) -> Bool:
  (Rules.min_length() <= n : Nat)

def check(name: String) -> Bool:
  long_enough(String.length(name))

def headline() -> String:
  Rules.title()

def min_length() -> Nat:
  Rules.min_length()
