/* Test-only clock fault: keep monotonic scheduling/deadlines intact. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <time.h>

int clock_gettime(clockid_t clock, struct timespec *value) {
  if (clock == CLOCK_REALTIME) {
    errno = EIO;
    return -1;
  }
  int (*real_clock)(clockid_t, struct timespec *) = dlsym(RTLD_NEXT, "clock_gettime");
  return real_clock(clock, value);
}
