# Test-only effect: starts a fresh copy of the running binary, so
# tests/workers.test.ts can check what a worker's subprocess inherits.
import Base

def spawn_copy() -> IO(U32):
  import "./spawn.c"
  import "./spawn.js"
