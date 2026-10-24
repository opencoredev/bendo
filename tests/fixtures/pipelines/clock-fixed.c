/* Test-only fixed wall clock: every Date header reads the same instant.
   Monotonic clocks stay real, so scheduling and deadlines still work. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <time.h>

int clock_gettime(clockid_t clock, struct timespec *value) {
  if (clock == CLOCK_REALTIME) {
    value->tv_sec = 1767225600; /* 2026-01-01T00:00:00Z */
    value->tv_nsec = 0;
    return 0;
  }
  int (*real_clock)(clockid_t, struct timespec *) = dlsym(RTLD_NEXT, "clock_gettime");
  return real_clock(clock, value);
}
