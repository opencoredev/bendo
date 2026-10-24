# Test-only effect: the serving process's ID, so tests/workers.test.ts can see
# which worker answered.
import Base

def getpid() -> IO(U32):
  import "./pid.c"
  import "./pid.js"
