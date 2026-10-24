// Test-only host effect: getpid(2).
static Term bendo_test_getpid_run(Env e, Term* f, IoWork* w) {
  return (Term)(u32)getpid();
}

static void __attribute__((constructor)) bendo_test_getpid_use(void) {
  io_eff(CID(getpid), bendo_test_getpid_run);
}
