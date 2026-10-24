// Trusted host effect. Starts worker copies of this binary with fork and
// execve. The runtime already runs threads here, so a child only calls
// async-signal-safe functions before execve and starts with a fresh runtime;
// everything it needs is prepared before fork. Each child asks for SIGTERM when
// the parent dies. A detached thread per child waits for it and, when it
// stops, stops this process the same way.
#include <sys/wait.h>
#ifdef __linux__
#include <sched.h>
#include <sys/prctl.h>
#endif

#define BENDO_WORKERS_MAX 256

static u32 bendo_workers_cpus(void) {
#ifdef __linux__
  cpu_set_t set;
  if (sched_getaffinity(0, sizeof(set), &set) == 0) {
    return (u32)CPU_COUNT(&set);
  }
#endif
  long n = sysconf(_SC_NPROCESSORS_ONLN);
  return n < 1 ? 1 : (u32)n;
}

static void* bendo_workers_watch(void* arg) {
  pid_t pid    = (pid_t)(intptr_t)arg;
  int   status = 0;
  while (waitpid(pid, &status, 0) < 0) {
    if (errno != EINTR) {
      return NULL;
    }
  }
  if (WIFSIGNALED(status)) {
    int sig = WTERMSIG(status);
    fprintf(stderr, "bendo: worker %d stopped by signal %d; stopping the server\n",
      (int)pid, sig);
    signal(sig, SIG_DFL);
    kill(getpid(), sig);
    _exit(128 + sig);
  }
  int code = WIFEXITED(status) ? WEXITSTATUS(status) : 1;
  fprintf(stderr, "bendo: worker %d exited with status %d; stopping the server\n",
    (int)pid, code);
  _exit(code);
}

#ifdef __linux__

// /proc/self/cmdline holds the original arguments, +RTS options included.
static char** bendo_workers_argv(char** buf) {
  int fd = open("/proc/self/cmdline", O_RDONLY);
  if (fd < 0) {
    return NULL;
  }
  u64   cap = 4096, len = 0;
  char* b   = malloc(cap + 1);
  for (;;) {
    ssize_t got = b == NULL ? -1 : read(fd, b + len, cap - len);
    if (got <= 0) {
      if (got < 0) {
        free(b);
        b = NULL;
      }
      break;
    }
    len += (u64)got;
    if (len == cap) {
      cap *= 2;
      char* more = realloc(b, cap + 1);
      if (more == NULL) {
        free(b);
        b = NULL;
        break;
      }
      b = more;
    }
  }
  close(fd);
  if (b == NULL || len == 0) {
    free(b);
    return NULL;
  }
  b[len] = 0;
  u64 n = 0;
  for (u64 i = 0; i < len; i += 1) {
    n += b[i] == 0;
  }
  char** argv = calloc(n + 2, sizeof(char*));
  if (argv == NULL) {
    free(b);
    return NULL;
  }
  u64 k = 0;
  for (u64 i = 0; i < len; i += strlen(b + i) + 1) {
    argv[k++] = b + i;
  }
  *buf = b;
  return argv;
}

static void bendo_workers_stop(pid_t* pids, u32 n) {
  for (u32 i = 0; i < n; i += 1) {
    kill(pids[i], SIGTERM);
    waitpid(pids[i], NULL, 0);
  }
}

static Term bendo_workers_spawn(Env e, u32 want) {
  extern char** environ;
  char*  buf  = NULL;
  char** argv = bendo_workers_argv(&buf);
  if (argv == NULL) {
    return io_fail(e, errno != 0 ? (u32)errno : EIO, NULL);
  }
  u64 envc = 0;
  while (environ[envc] != NULL) {
    envc += 1;
  }
  char** envp  = calloc(envc + 2, sizeof(char*));
  char*  slots = calloc(want, 32);
  pid_t* pids  = calloc(want, sizeof(pid_t));
  if (envp == NULL || slots == NULL || pids == NULL) {
    free(envp), free(slots), free(pids), free(argv), free(buf);
    return io_fail(e, ENOMEM, NULL);
  }
  memcpy(envp, environ, envc * sizeof(char*));
  // Exec the resolved path so the workers keep the server's process name;
  // /proc/self/exe (the same file) is the fallback.
  char exe[4096];
  ssize_t got = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
  exe[got > 0 ? got : 0] = 0;
  const char* path = got > 0 && access(exe, X_OK) == 0 ? exe : "/proc/self/exe";
  pid_t parent  = getpid();
  u32   started = 0;
  int   code    = 0;
  for (u32 i = 1; i < want && code == 0; i += 1) {
    char* slot = slots + 32 * i;
    snprintf(slot, 32, "BENDO_WORKER_INDEX=%u", i);
    envp[envc] = slot;
    pid_t pid = fork();
    if (pid == 0) {
      prctl(PR_SET_PDEATHSIG, SIGTERM);
      if (getppid() != parent) {
        _exit(1);
      }
      for (int fd = 3; fd < 1024; fd += 1) {
        close(fd);
      }
      execve(path, argv, envp);
      _exit(127);
    }
    if (pid < 0) {
      code = errno;
      break;
    }
    pids[started++] = pid;
  }
  for (u32 i = 0; i < started && code == 0; i += 1) {
    pthread_t tid;
    code = pthread_create(&tid, NULL, bendo_workers_watch,
      (void*)(intptr_t)pids[i]);
    if (code == 0) {
      pthread_detach(tid);
    }
  }
  if (code != 0) {
    bendo_workers_stop(pids, started);
  }
  free(envp), free(slots), free(pids), free(argv), free(buf);
  return code != 0 ? io_fail(e, (u32)code, NULL) : io_done(e, (Term)0);
}

#endif

static Term bendo_start_workers_run(Env e, Term* f, IoWork* w) {
  const char* mine = getenv("BENDO_WORKER_INDEX");
  if (mine != NULL) {
    return io_done(e, (Term)(u32)strtoul(mine, NULL, 10));
  }
  u32 want = (u32)f[0];
  want = want == 0 ? bendo_workers_cpus() : want;
  if (want > BENDO_WORKERS_MAX) {
    return io_fail(e, EINVAL, NULL);
  }
  if (want == 1) {
    return io_done(e, (Term)0);
  }
#ifdef __linux__
  return bendo_workers_spawn(e, want);
#else
  return io_fail(e, ENOSYS, NULL);
#endif
}

static void __attribute__((constructor)) bendo_start_workers_use(void) {
  io_eff(CID(start_workers), bendo_start_workers_run);
}
