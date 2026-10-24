// Trusted host effect. Resolves the upstream host and connects to one of its
// addresses before an absolute deadline (BND-47, BND-93). Every failure path
// closes its descriptors; success hands the socket over as a Socket.
//
// A numeric IPv4 or IPv6 host is used as it is, with no lookup. A DNS name is
// resolved by getaddrinfo(3) on a detached thread of its own, so the event
// loop never blocks: the thread writes one byte to a pipe, and the work item
// parks on the pipe's read end until that byte or the deadline arrives. The
// runtime's io_work helpers cannot be abandoned at a deadline and
// getaddrinfo_a(3) is glibc-only, hence the thread. At most BENDO_RESOLVERS
// lookups run at once; one more fails with EAGAIN. A lookup still running at
// the deadline is abandoned: the work item fails with 110 and drops its
// reference, and the thread frees the result and closes the pipe when
// getaddrinfo returns.
//
// The addresses are tried one at a time (at most BENDO_ADDRS of them) in
// getaddrinfo's order, which follows RFC 6724, alternating address families
// from the first (RFC 8305 section 4). Each attempt but the last gets an equal
// share of the time left, and the last gets all of it; a refused or
// unreachable address moves on at once. A late attempt's socket is closed
// before the next one opens. There is no parallel racing.
//
// Failure codes: 110 (Linux ETIMEDOUT) on every platform when the deadline
// passes, BENDO_NO_ADDRESS when the name does not resolve, and otherwise the
// errno of the last attempt. Bendo classifies only 110 as a timeout.
#include <netdb.h>
#include <poll.h>
#include <pthread.h>

#define BENDO_ADDRS 8
#define BENDO_RESOLVERS 32
#define BENDO_NO_ADDRESS 1001

// Shared by the work item and the resolver thread; the last to drop it frees
// it. done is set, with release order, before the pipe byte is written.
typedef struct {
  int              refs;
  int              done;
  int              err;
  int              pipe[2];
  char*            host;
  struct addrinfo* res;
} BendoLookup;

typedef struct {
  struct sockaddr_storage at[BENDO_ADDRS];
  socklen_t               len[BENDO_ADDRS];
  u32                     n;
  u32                     i;
  int                     fd;
  u32                     err;
  u64                     until;
  u64                     deadline;
  uint16_t                port;
  BendoLookup*            lookup;
} BendoDial;

static int bendo_resolving;

static void bendo_lookup_drop(BendoLookup* l) {
  if (__atomic_sub_fetch(&l->refs, 1, __ATOMIC_ACQ_REL) != 0) {
    return;
  }
  if (l->res != NULL) {
    freeaddrinfo(l->res);
  }
  close(l->pipe[0]);
  close(l->pipe[1]);
  free(l->host);
  free(l);
}

static void* bendo_lookup_run(void* arg) {
  BendoLookup*    l     = arg;
  struct addrinfo hints = { 0 };
  hints.ai_family       = AF_UNSPEC;
  hints.ai_socktype     = SOCK_STREAM;
  l->err                = getaddrinfo(l->host, NULL, &hints, &l->res);
  __atomic_store_n(&l->done, 1, __ATOMIC_RELEASE);
  char b = 1;
  while (write(l->pipe[1], &b, 1) < 0 && errno == EINTR) {
  }
  __atomic_sub_fetch(&bendo_resolving, 1, __ATOMIC_ACQ_REL);
  bendo_lookup_drop(l);
  return NULL;
}

static Term bendo_dial_end(Env e, IoWork* w, u32 code, const char* text) {
  BendoDial* d = (BendoDial*)w->data;
  if (d->fd >= 0) {
    close(d->fd);
  }
  if (d->lookup != NULL) {
    bendo_lookup_drop(d->lookup);
  }
  free(d);
  w->data = NULL;
  return io_fail(e, code, text);
}

static Term bendo_dial_more(Env e, IoWork* w);

// Opens the next attempt, or fails with the last attempt's error.
static Term bendo_dial_next(Env e, IoWork* w) {
  BendoDial* d = (BendoDial*)w->data;
  for (; d->i < d->n; d->i += 1) {
    u64 now = io_tick();
    if (now >= d->deadline) {
      return bendo_dial_end(e, w, 110, NULL);
    }
    u32 left = d->n - d->i;
    d->until = left == 1 ? d->deadline : now + (d->deadline - now) / left;
    struct sockaddr* at = (struct sockaddr*)&d->at[d->i];
    int fd = socket(at->sa_family, SOCK_STREAM, 0);
    if (fd < 0) {
      d->err = (u32)errno;
      continue;
    }
    if (fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0
      || fcntl(fd, F_SETFD, FD_CLOEXEC) < 0) {
      d->err = (u32)errno;
      close(fd);
      continue;
    }
    if (connect(fd, at, d->len[d->i]) == 0) {
      d->fd = fd;
      return bendo_dial_more(e, w);
    }
    if (errno != EINPROGRESS) {
      d->err = (u32)errno;
      close(fd);
      continue;
    }
    d->fd = fd;
    return io_wait_on(w, fd, POLLOUT, d->until, bendo_dial_more);
  }
  return bendo_dial_end(e, w, d->err, d->err == BENDO_NO_ADDRESS
    ? "no usable address" : NULL);
}

// The current attempt is writable, or its share of the time ran out.
static Term bendo_dial_more(Env e, IoWork* w) {
  BendoDial*    d     = (BendoDial*)w->data;
  struct pollfd p     = { d->fd, POLLOUT, 0 };
  int           ready = poll(&p, 1, 0);
  int           err   = 0;
  socklen_t     len   = sizeof(err);
  if (ready == 0 && io_tick() < d->until) {
    return io_wait_on(w, d->fd, POLLOUT, d->until, bendo_dial_more);
  }
  if (ready == 0) {
    err = 110;
  } else if (ready < 0) {
    err = errno;
  } else if (getsockopt(d->fd, SOL_SOCKET, SO_ERROR, &err, &len) != 0) {
    err = errno;
  }
  if (err == 0) {
    int fd = d->fd;
    free(d);
    w->data = NULL;
    return io_done(e, io_hand(fd));
  }
  close(d->fd);
  d->fd  = -1;
  d->err = (u32)err;
  d->i  += 1;
  if (io_tick() >= d->deadline) {
    return bendo_dial_end(e, w, 110, NULL);
  }
  return bendo_dial_next(e, w);
}

static void bendo_dial_add(BendoDial* d, const struct sockaddr* at) {
  if (d->n >= BENDO_ADDRS) {
    return;
  }
  struct sockaddr_storage* to = &d->at[d->n];
  if (at->sa_family == AF_INET) {
    struct sockaddr_in a = *(const struct sockaddr_in*)at;
    a.sin_port = htons(d->port);
    memcpy(to, &a, sizeof a);
    d->len[d->n] = sizeof a;
  } else {
    struct sockaddr_in6 a = *(const struct sockaddr_in6*)at;
    a.sin6_port = htons(d->port);
    memcpy(to, &a, sizeof a);
    d->len[d->n] = sizeof a;
  }
  d->n += 1;
}

// Alternates families starting with the first result's family.
static void bendo_dial_order(BendoDial* d, struct addrinfo* res) {
  const struct sockaddr* fam[2][BENDO_ADDRS];
  u32                    count[2] = { 0, 0 };
  int                    first    = -1;
  for (struct addrinfo* r = res; r != NULL; r = r->ai_next) {
    int k = r->ai_family == AF_INET ? 0 : r->ai_family == AF_INET6 ? 1 : -1;
    if (k < 0 || r->ai_addr == NULL || count[k] == BENDO_ADDRS) {
      continue;
    }
    first = first < 0 ? k : first;
    fam[k][count[k]++] = r->ai_addr;
  }
  for (u32 j = 0; first >= 0 && j < BENDO_ADDRS; j += 1) {
    if (j < count[first]) {
      bendo_dial_add(d, fam[first][j]);
    }
    if (j < count[1 - first]) {
      bendo_dial_add(d, fam[1 - first][j]);
    }
  }
}

// The resolver thread finished, or the deadline passed first.
static Term bendo_resolved(Env e, IoWork* w) {
  BendoDial*   d = (BendoDial*)w->data;
  BendoLookup* l = d->lookup;
  if (!__atomic_load_n(&l->done, __ATOMIC_ACQUIRE)) {
    return io_tick() < d->deadline
      ? io_wait_on(w, l->pipe[0], POLLIN, d->deadline, bendo_resolved)
      : bendo_dial_end(e, w, 110, NULL);
  }
  if (l->err != 0) {
    return bendo_dial_end(e, w, BENDO_NO_ADDRESS, gai_strerror(l->err));
  }
  bendo_dial_order(d, l->res);
  d->lookup = NULL;
  bendo_lookup_drop(l);
  return bendo_dial_next(e, w);
}

static Term bendo_resolve(Env e, IoWork* w, char* host) {
  BendoDial* d = (BendoDial*)w->data;
  if (__atomic_add_fetch(&bendo_resolving, 1, __ATOMIC_ACQ_REL) > BENDO_RESOLVERS) {
    __atomic_sub_fetch(&bendo_resolving, 1, __ATOMIC_ACQ_REL);
    free(host);
    return bendo_dial_end(e, w, EAGAIN, NULL);
  }
  BendoLookup* l = io_mem(calloc(1, sizeof(BendoLookup)));
  l->refs        = 2;
  l->host        = host;
  if (pipe(l->pipe) != 0) {
    u32 code = (u32)errno;
    __atomic_sub_fetch(&bendo_resolving, 1, __ATOMIC_ACQ_REL);
    free(host);
    free(l);
    return bendo_dial_end(e, w, code, NULL);
  }
  fcntl(l->pipe[0], F_SETFD, FD_CLOEXEC);
  fcntl(l->pipe[1], F_SETFD, FD_CLOEXEC);
  fcntl(l->pipe[0], F_SETFL, fcntl(l->pipe[0], F_GETFL) | O_NONBLOCK);
  d->lookup = l;
  pthread_attr_t attr;
  pthread_t      tid;
  pthread_attr_init(&attr);
  pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
  int made = pthread_create(&tid, &attr, bendo_lookup_run, l);
  pthread_attr_destroy(&attr);
  if (made != 0) {
    __atomic_sub_fetch(&bendo_resolving, 1, __ATOMIC_ACQ_REL);
    l->refs = 1;
    return bendo_dial_end(e, w, EAGAIN, NULL);
  }
  return io_wait_on(w, l->pipe[0], POLLIN, d->deadline, bendo_resolved);
}

static Term bendo_upstream_connect_run(Env e, Term* f, IoWork* w) {
  u64   size;
  char* host  = io_cstr(e, f[0], &size);
  BendoDial* d = io_mem(calloc(1, sizeof(BendoDial)));
  d->fd       = -1;
  d->err      = BENDO_NO_ADDRESS;
  d->deadline = io_until(f[2]);
  d->port     = (uint16_t)f[1];
  w->data     = (char*)d;
  struct sockaddr_in  v4;
  struct sockaddr_in6 v6 = { 0 };
  if (io_nul(host, size) || size == 0 || (u32)f[1] == 0 || (u32)f[1] > 65535) {
    free(host);
    return bendo_dial_end(e, w, EINVAL, NULL);
  }
  if (io_sys_addr(host, (u32)f[1], &v4) == 0) {
    bendo_dial_add(d, (struct sockaddr*)&v4);
  } else if (inet_pton(AF_INET6, host, &v6.sin6_addr) == 1) {
    v6.sin6_family = AF_INET6;
    bendo_dial_add(d, (struct sockaddr*)&v6);
  } else {
    return bendo_resolve(e, w, host);
  }
  free(host);
  return bendo_dial_next(e, w);
}

static void __attribute__((constructor)) bendo_upstream_connect_use(void) {
  io_eff(CID(upstream_connect), bendo_upstream_connect_run);
}
