# Test-only effect: holds back every process of a multi-worker server after
# the first, so tests/workers.test.ts can delay or fail a worker's startup.
import Base

def stall() -> IO(Unit):
  import "./stall.c"
  import "./stall.js"
