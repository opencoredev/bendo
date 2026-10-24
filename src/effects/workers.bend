# Trusted process boundary, outside the proofs: start the worker processes of
# a multi-worker server (BND-69, decision 0017).
#
# Call it after the listener is bound. Returns this process's worker index. A
# process started by this effect has BENDO_WORKER_INDEX set, reports to the
# first process that it is bound, and gets its index back. Otherwise, with a
# count above 1, the effect starts count - 1 copies of the running binary with
# the same arguments, indexes 1 to count - 1, waits until each has reported
# that it is bound, and returns 0. A count of 0 means
# one worker per CPU this process may run on. Each copy runs main from the
# start and stops when the first process stops. When a copy stops, the first
# process stops the same way, so the server never runs short-handed.
#
# Native Linux only. Elsewhere a count other than 1 fails with status 38
# (Linux's ENOSYS, on every platform).
import Base

def start_workers(count: U32) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./workers.c"
  import "./workers.js"
