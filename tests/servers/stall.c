// Test-only host effect. With BENDO_TEST_STALL_FILE set, the first process to
// run it creates that file and returns at once. Every later process (a worker,
// since the first process runs main before it starts workers) sleeps
// BENDO_TEST_STALL_MS milliseconds and then, if BENDO_TEST_STALL_EXIT is set,
// exits with that status.
static Term bendo_test_stall_run(Env e, Term* f, IoWork* w) {
  const char* path = getenv("BENDO_TEST_STALL_FILE");
  int fd = path == NULL ? -1 : open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
  if (fd >= 0) {
    close(fd);
  } else if (path != NULL && errno == EEXIST) {
    const char* ms = getenv("BENDO_TEST_STALL_MS");
    unsigned long wait = ms == NULL ? 0 : strtoul(ms, NULL, 10);
    struct timespec t = { (time_t)(wait / 1000), (long)(wait % 1000) * 1000000L };
    while (nanosleep(&t, &t) < 0 && errno == EINTR) {
    }
    const char* code = getenv("BENDO_TEST_STALL_EXIT");
    if (code != NULL) {
      _exit((int)strtoul(code, NULL, 10));
    }
  }
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) bendo_test_stall_use(void) {
  io_eff(CID(stall), bendo_test_stall_run);
}
