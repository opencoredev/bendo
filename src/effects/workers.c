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
#include <sys/syscall.h>
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

// Child side of fork: async-signal-safe calls only. The ready pipe moves to
// descriptor 3 and every other descriptor above stderr closes. It execs
// /proc/self/exe, the inode this process runs, so a binary replaced on disk
// since startup cannot slip in.
static void bendo_workers_child(pid_t parent, int ready, long open_max,
  char** argv, char** envp) {
  prctl(PR_SET_PDEATHSIG, SIGTERM);
  if (getppid() != parent) {
    _exit(1);
  }
  if (ready == 3 ? fcntl(3, F_SETFD, 0) < 0 : dup2(ready, 3) < 0) {
    _exit(127);
  }
  int closed = -1;
#ifdef SYS_close_range
  closed = (int)syscall(SYS_close_range, 4U, ~0U, 0U);
#endif
  for (long fd = 4; closed < 0 && fd < open_max; fd += 1) {
    close((int)fd);
  }
  execve("/proc/self/exe", argv, envp);
  _exit(127);
}

// Waits until every worker reports its listener bound. A worker that stops
// first closes its end of the pipe; its watcher thread then stops this
// process with the worker's status, which the bounded sleep gives it time to do.
static int bendo_workers_barrier(int ready, u32 want) {
  u32 seen = 0;
  while (seen < want) {
    char    buf[64];
    ssize_t got = read(ready, buf, sizeof(buf));
    if (got > 0) {
      seen += (u32)got;
    } else if (got == 0 || errno != EINTR) {
      sleep(5);
      return ECHILD;
    }
  }
  return 0;
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
  char** envp  = calloc(envc + 4, sizeof(char*));
  char*  slots = calloc(want, 32);
  pid_t* pids  = calloc(want, sizeof(pid_t));
  int    pipe_fds[2];
  int    failed = envp == NULL || slots == NULL || pids == NULL ? ENOMEM
    : pipe2(pipe_fds, O_CLOEXEC) < 0 ? errno : 0;
  if (failed != 0) {
    free(envp), free(slots), free(pids), free(argv), free(buf);
    return io_fail(e, (u32)failed, NULL);
  }
  memcpy(envp, environ, envc * sizeof(char*));
  // Exec through /proc/self/exe names the process "exe"; each worker renames
  // itself to this process's name at load (bendo_start_workers_use).
  char name[16 + 18] = "BENDO_WORKER_NAME=";
  prctl(PR_GET_NAME, name + 18);
  name[sizeof(name) - 1] = 0;
  envp[envc]     = name;
  envp[envc + 1] = "BENDO_WORKER_READY=3";
  long  open_max = sysconf(_SC_OPEN_MAX);
  pid_t parent   = getpid();
  u32   started  = 0;
  int   code     = 0;
  for (u32 i = 1; i < want && code == 0; i += 1) {
    char* slot = slots + 32 * i;
    snprintf(slot, 32, "BENDO_WORKER_INDEX=%u", i);
    envp[envc + 2] = slot;
    pid_t pid = fork();
    if (pid == 0) {
      bendo_workers_child(parent, pipe_fds[1], open_max < 0 ? 65536 : open_max,
        argv, envp);
    }
    if (pid < 0) {
      code = errno;
      break;
    }
    pids[started++] = pid;
  }
  close(pipe_fds[1]);
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
  } else {
    code = bendo_workers_barrier(pipe_fds[0], want - 1);
  }
  close(pipe_fds[0]);
  free(envp), free(slots), free(pids), free(argv), free(buf);
  return code != 0 ? io_fail(e, (u32)code, NULL) : io_done(e, (Term)0);
}

#endif

// Set in a worker at load: its index and the write end of the ready pipe.
static const char* bendo_worker_index = NULL;
static int         bendo_worker_ready = -1;

static Term bendo_start_workers_run(Env e, Term* f, IoWork* w) {
  if (bendo_worker_index != NULL) {
    // The server listens before this effect runs, so the worker is bound.
    if (bendo_worker_ready >= 0) {
      ssize_t sent = write(bendo_worker_ready, "1", 1);
      (void)sent;
      close(bendo_worker_ready);
      bendo_worker_ready = -1;
    }
    return io_done(e, (Term)(u32)strtoul(bendo_worker_index, NULL, 10));
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
  // Linux's ENOSYS on every platform (macOS's is 78), as the JS twin does.
  return io_fail(e, 38, "bendo: workers > 1 needs Linux");
#endif
}

static void __attribute__((constructor)) bendo_start_workers_use(void) {
  io_eff(CID(start_workers), bendo_start_workers_run);
  bendo_worker_index = getenv("BENDO_WORKER_INDEX");
  const char* ready  = getenv("BENDO_WORKER_READY");
  if (bendo_worker_index != NULL && ready != NULL && strcmp(ready, "3") == 0
    && fcntl(3, F_SETFD, FD_CLOEXEC) == 0) {
    bendo_worker_ready = 3;
  }
  unsetenv("BENDO_WORKER_READY");
#ifdef __linux__
  const char* name = getenv("BENDO_WORKER_NAME");
  if (bendo_worker_index != NULL && name != NULL) {
    prctl(PR_SET_NAME, name);
  }
  unsetenv("BENDO_WORKER_NAME");
#endif
}
