// Test-only host effect. In a worker (a process whose parent runs the same
// binary), starts /proc/self/exe with this process's environment, PORT
// replaced by BENDO_TEST_CHILD_PORT, output discarded and no descriptor above
// stderr. Returns the new PID, or 0 in the first process or if it did not
// start.
#include <spawn.h>
#include <sys/stat.h>

static int bendo_test_spawn_in_worker(void) {
  char        parent[64];
  struct stat mine, theirs;
  snprintf(parent, sizeof(parent), "/proc/%d/exe", (int)getppid());
  return stat("/proc/self/exe", &mine) == 0 && stat(parent, &theirs) == 0
    && mine.st_dev == theirs.st_dev && mine.st_ino == theirs.st_ino;
}

static Term bendo_test_spawn_run(Env e, Term* f, IoWork* w) {
  extern char** environ;
  const char* port = getenv("BENDO_TEST_CHILD_PORT");
  if (!bendo_test_spawn_in_worker()) {
    return (Term)0;
  }
  u64 n = 0;
  while (environ[n] != NULL) {
    n += 1;
  }
  char** envp = calloc(n + 2, sizeof(char*));
  char   slot[32];
  if (port == NULL || envp == NULL) {
    free(envp);
    return (Term)0;
  }
  u64 k = 0;
  for (u64 i = 0; i < n; i += 1) {
    if (strncmp(environ[i], "PORT=", 5) != 0) {
      envp[k++] = environ[i];
    }
  }
  snprintf(slot, sizeof(slot), "PORT=%s", port);
  envp[k] = slot;
  posix_spawn_file_actions_t actions;
  posix_spawn_file_actions_init(&actions);
  posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0);
  posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0);
  posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0);
  posix_spawn_file_actions_addclosefrom_np(&actions, 3);
  char* argv[] = { "bendo-test-copy", NULL };
  pid_t pid    = 0;
  int   failed = posix_spawn(&pid, "/proc/self/exe", &actions, NULL, argv, envp);
  posix_spawn_file_actions_destroy(&actions);
  free(envp);
  return (Term)(u32)(failed != 0 ? 0 : pid);
}

static void __attribute__((constructor)) bendo_test_spawn_use(void) {
  io_eff(CID(spawn_copy), bendo_test_spawn_run);
}
