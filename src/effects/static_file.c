// Trusted host effect for static files. Opens a regular file beneath a root
// directory one segment at a time; no symlink below the root is followed.
// It also reports the file's change stamp, from which the entity tag is made.
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#ifdef __APPLE__
#define st_mtim st_mtimespec
#define st_ctim st_ctimespec
#endif

#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif

static int bendo_static_bad_name(const char* p, size_t n) {
  return n == 0 || n > NAME_MAX || (n == 1 && p[0] == '.')
    || (n == 2 && p[0] == '.' && p[1] == '.');
}

static long long bendo_static_clamp(long long secs) {
  return secs < 0 ? 0 : secs > 253402300799LL ? 253402300799LL : secs;
}

// True when t is at least two seconds before now. Filesystem timestamps can
// be as coarse as two seconds, so a later write is sure to move them.
static int bendo_static_settled(struct timespec t, struct timespec now) {
  long long limit = (long long)t.tv_sec + 2;
  return limit < (long long)now.tv_sec
    || (limit == (long long)now.tv_sec && t.tv_nsec <= now.tv_nsec);
}

// The change stamp: device, inode, size, mtime and ctime with nanoseconds, in
// hex. Any write moves ctime to the current time, and no call can set it
// back, so once both times have settled the stamp changes with the content.
// It is empty while the file is still settling.
static char* bendo_static_stamp(const struct stat* st) {
  char* out = malloc(160);
  if (out == NULL) {
    return NULL;
  }
  struct timespec now;
  if (clock_gettime(CLOCK_REALTIME, &now) != 0
    || !bendo_static_settled(st->st_mtim, now)
    || !bendo_static_settled(st->st_ctim, now)) {
    out[0] = 0;
    return out;
  }
  snprintf(out, 160, "%" PRIxMAX "-%" PRIxMAX "-%" PRIxMAX "-%" PRIxMAX ".%lx-%" PRIxMAX ".%lx",
    (uintmax_t)st->st_dev, (uintmax_t)st->st_ino, (uintmax_t)st->st_size,
    (uintmax_t)st->st_mtim.tv_sec, (long)st->st_mtim.tv_nsec,
    (uintmax_t)st->st_ctim.tv_sec, (long)st->st_ctim.tv_nsec);
  return out;
}

// Runs on a helper thread. w->data is root, w->text is path. On success
// w->hand is the fd, w->size the length, w->made the mtime seconds,
// w->text the change stamp and w->data the later of mtime and ctime, in
// seconds, as a long long.
static void bendo_static_open_call(IoWork* w) {
  const char* root = w->data;
  const char* path = w->text;
  size_t n = strlen(root);
  if (n == 0 || strncmp(path, root, n) != 0 || path[n] != '/') {
    w->code = EINVAL;
    return;
  }
  int dir = open(root, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
  if (dir < 0) {
    w->code = (u32)errno;
    return;
  }
  const char* p = path + n + 1;
  char name[NAME_MAX + 1];
  for (;;) {
    const char* slash = strchr(p, '/');
    size_t len = slash != NULL ? (size_t)(slash - p) : strlen(p);
    if (bendo_static_bad_name(p, len)) {
      close(dir);
      w->code = ENOENT;
      return;
    }
    memcpy(name, p, len);
    name[len] = 0;
    if (slash != NULL) {
      // A symlinked directory fails here with ELOOP or ENOTDIR.
      int next = openat(dir, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
      int err = errno;
      close(dir);
      if (next < 0) {
        w->code = (u32)err;
        return;
      }
      dir = next;
      p = slash + 1;
      continue;
    }
    // Look before opening, so a FIFO or device is never opened.
    struct stat before;
    if (fstatat(dir, name, &before, AT_SYMLINK_NOFOLLOW) != 0) {
      w->code = (u32)errno;
      close(dir);
      return;
    }
    if (S_ISDIR(before.st_mode) || !S_ISREG(before.st_mode)) {
      close(dir);
      w->code = S_ISDIR(before.st_mode) ? EISDIR : ENOENT;
      return;
    }
    int fd = openat(dir, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_NOCTTY | O_CLOEXEC);
    int err = errno;
    close(dir);
    if (fd < 0) {
      w->code = (u32)err;
      return;
    }
    // The opened file must be the regular file inspected above.
    struct stat st;
    if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode)
      || st.st_dev != before.st_dev || st.st_ino != before.st_ino) {
      close(fd);
      w->code = ENOENT;
      return;
    }
    if ((uint64_t)st.st_size > UINT32_MAX) {
      close(fd);
      w->code = EFBIG;
      return;
    }
    char* stamp = bendo_static_stamp(&st);
    long long* changed = malloc(sizeof(long long));
    if (stamp == NULL || changed == NULL) {
      free(stamp);
      free(changed);
      close(fd);
      w->code = ENOMEM;
      return;
    }
    long long mtime = bendo_static_clamp((long long)st.st_mtime);
    long long ctime = bendo_static_clamp((long long)st.st_ctime);
    *changed = ctime > mtime ? ctime : mtime;
    free(w->data);
    free(w->text);
    w->data = (char*)changed;
    w->text = stamp;
    w->hand = fd;
    w->size = (u64)st.st_size;
    w->made = (intptr_t)mtime;
    w->code = 0;
    return;
  }
}

static Term bendo_static_open_pack(Env e, IoWork* w) {
  if (w->code != 0) {
    free(w->data);
    free(w->text);
    return io_fail(e, w->code, NULL);
  }
  u64 changed = (u64)*(long long*)w->data;
  Term stamp = io_str(e, w->text, strlen(w->text));
  free(w->data);
  free(w->text);
  return io_done(e, io_tup(e, io_hand(w->hand),
    io_tup(e, (Term)w->size, io_tup(e, (Term)(u64)w->made,
      io_tup(e, (Term)changed, stamp)))));
}

static Term bendo_static_open_run(Env e, Term* f, IoWork* w) {
  u64 rn = 0;
  u64 pn = 0;
  w->data = io_cstr(e, f[0], &rn);
  w->text = io_cstr(e, f[1], &pn);
  if (io_nul(w->data, rn) || io_nul(w->text, pn)) {
    w->code = EILSEQ;
    return bendo_static_open_pack(e, w);
  }
  return io_work(w, bendo_static_open_call, bendo_static_open_pack);
}

static void __attribute__((constructor)) bendo_static_open_use(void) {
  io_eff(CID(open_beneath), bendo_static_open_run);
}
