// Test-only host effect: the process ID.
function bendo_test_getpid() {
  return typeof process === "object" ? process.pid >>> 0 : 0;
}

io_eff(CID(getpid), bendo_test_getpid);
