# The rules handle.bend checks against. Editing this file recompiles
# handle.bend too: the plugin tracks each entry's imports.
import Base

def min_length() -> Nat:
  3n

def title() -> String:
  "Pick a handle"
