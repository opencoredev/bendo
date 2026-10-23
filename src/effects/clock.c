// Trusted host effect. Read realtime once; never use it for elapsed time.
#include <time.h>

static Term bendo_wall_millis_run(Env e, Term* f, IoWork* w) {
  struct timespec now;
  if (clock_gettime(CLOCK_REALTIME, &now) != 0) {
    return io_fail(e, errno, NULL);
  }
  if (now.tv_sec < 0 || (uint64_t)now.tv_sec > 253402300799ULL) {
    return io_fail(e, ERANGE, "wall clock outside years 1970..9999");
  }
  uint64_t millis = (uint64_t)now.tv_sec * 1000ULL + (uint64_t)now.tv_nsec / 1000000ULL;
  return io_done(e, (Term)millis);
}

static void __attribute__((constructor)) bendo_wall_millis_use(void) {
  io_eff(CID(wall_millis), bendo_wall_millis_run);
}
