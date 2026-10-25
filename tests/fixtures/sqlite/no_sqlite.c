// An LD_PRELOAD stand-in for dlopen that hides libsqlite3, so the SQLite
// effect's missing-library failure can be tested on a machine that has it.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>

void* dlopen(const char* file, int flags) {
  if (file != NULL && strstr(file, "libsqlite3") != NULL) {
    return NULL;
  }
  void* (*real)(const char*, int) = (void* (*)(const char*, int))dlsym(RTLD_NEXT, "dlopen");
  return real(file, flags);
}
