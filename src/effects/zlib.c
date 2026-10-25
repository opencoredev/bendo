// Trusted host effect. Compresses a list of octets with the system zlib on a
// helper thread, so the event loop keeps serving while it runs.
//
// bend links native programs with -lpthread -lm only, so zlib is loaded with
// dlopen: libz.so.1 comes with zlib1g, which every Ubuntu and Debian system
// has (Priority: required), and macOS ships /usr/lib/libz.1.dylib. No headers
// are needed: the three calls used below take plain pointers and integers.
//
// Format 2 is compress2's own output, a zlib stream (RFC 1950): what HTTP
// calls "deflate". Format 1 is a gzip member (RFC 1952) built from the same
// stream: compress2 never sets a preset dictionary, so the raw deflate data
// is the stream without its 2-octet header and 4-octet Adler-32 trailer. The
// member is a 10-octet header, that data, then CRC-32 and the input length
// mod 2^32, both little-endian.
//
// Memory is bounded by the limit argument: the input is at most limit
// octets, and the output buffer is compressBound(n) plus the gzip framing.
// Allocation failure, a zlib error or a missing zlib answer Fail; nothing
// aborts the process.
#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

typedef int (*bendo_zlib_compress2_t)(unsigned char*, unsigned long*, const unsigned char*, unsigned long, int);
typedef unsigned long (*bendo_zlib_bound_t)(unsigned long);
typedef unsigned long (*bendo_zlib_crc32_t)(unsigned long, const unsigned char*, unsigned int);

static bendo_zlib_compress2_t bendo_zlib_compress2;
static bendo_zlib_bound_t     bendo_zlib_bound;
static bendo_zlib_crc32_t     bendo_zlib_crc32;
static pthread_once_t         bendo_zlib_once = PTHREAD_ONCE_INIT;

static void bendo_zlib_load(void) {
  static const char* const names[] = {
#ifdef __APPLE__
    "libz.1.dylib", "/usr/lib/libz.1.dylib",
#else
    "libz.so.1", "libz.so",
#endif
    NULL
  };
  for (int i = 0; names[i] != NULL; i += 1) {
    void* h = dlopen(names[i], RTLD_NOW | RTLD_LOCAL);
    if (h == NULL) {
      continue;
    }
    bendo_zlib_compress2_t c = (bendo_zlib_compress2_t)dlsym(h, "compress2");
    bendo_zlib_bound_t     b = (bendo_zlib_bound_t)dlsym(h, "compressBound");
    bendo_zlib_crc32_t     r = (bendo_zlib_crc32_t)dlsym(h, "crc32");
    if (c != NULL && b != NULL && r != NULL) {
      bendo_zlib_compress2 = c;
      bendo_zlib_bound = b;
      bendo_zlib_crc32 = r;
      return;
    }
    dlclose(h);
  }
}

static void bendo_zlib_put32(unsigned char* p, unsigned long v) {
  p[0] = (unsigned char)(v & 255);
  p[1] = (unsigned char)((v >> 8) & 255);
  p[2] = (unsigned char)((v >> 16) & 255);
  p[3] = (unsigned char)((v >> 24) & 255);
}

// Runs on a helper thread. In: w->data and w->size the input, w->word the
// format in its high byte and the level in its low byte. Out: w->text and
// w->made the coded octets, or w->code an errno. The input is freed here.
static void bendo_zlib_call(IoWork* w) {
  const unsigned char* in = (const unsigned char*)w->data;
  unsigned long        n = (unsigned long)w->size;
  u32                  format = w->word >> 8;
  int                  level = (int)(w->word & 255);
  w->text = NULL;
  w->made = 0;
  pthread_once(&bendo_zlib_once, bendo_zlib_load);
  if (bendo_zlib_compress2 == NULL) {
    w->code = ENOSYS;
    free(w->data);
    return;
  }
  unsigned long  cap = bendo_zlib_bound(n);
  unsigned char* z = malloc(cap > 0 ? cap : 1);
  if (z == NULL) {
    w->code = ENOMEM;
    free(w->data);
    return;
  }
  unsigned long got = cap;
  int           rc = bendo_zlib_compress2(z, &got, in, n, level);
  if (rc != 0 || got < 6) {
    w->code = rc == -4 ? ENOMEM : EIO;
    free(z);
    free(w->data);
    return;
  }
  if (format == 2) {
    free(w->data);
    w->text = (char*)z;
    w->made = (intptr_t)got;
    return;
  }
  unsigned long  raw = got - 6;
  unsigned char* g = malloc(raw + 18);
  if (g == NULL) {
    w->code = ENOMEM;
    free(z);
    free(w->data);
    return;
  }
  // ID1 ID2 CM=8 FLG=0 MTIME=0, XFL (2 slowest, 4 fastest), OS=255 unknown.
  static const unsigned char head[10] = { 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 255 };
  memcpy(g, head, 10);
  g[8] = level >= 9 ? 2 : level <= 1 ? 4 : 0;
  memcpy(g + 10, z + 2, raw);
  bendo_zlib_put32(g + 10 + raw, bendo_zlib_crc32(0, in, (unsigned int)n));
  bendo_zlib_put32(g + 14 + raw, n);
  free(z);
  free(w->data);
  w->text = (char*)g;
  w->made = (intptr_t)(raw + 18);
}

static Term bendo_zlib_pack(Env e, IoWork* w) {
  if (w->code != 0) {
    const char* why = w->code == ENOSYS ? "zlib is not available"
      : w->code == EIO ? "zlib compression failed" : NULL;
    return io_fail(e, w->code, why);
  }
  Term r = io_done(e, io_list(e, w->text, (u64)w->made));
  free(w->text);
  return r;
}

static Term bendo_zlib_run(Env e, Term* f, IoWork* w) {
  u32   format = (u32)f[0];
  u32   level = (u32)f[1];
  u64   limit = (u32)f[2];
  u64   n = 0;
  char* data = io_cbuf(e, f[3], &n, CID(Con));
  w->code = 0;
  if (data == NULL) {
    return io_fail(e, EINVAL, "an octet is above 255");
  }
  if ((format != 1 && format != 2) || level < 1 || level > 9) {
    free(data);
    return io_fail(e, EINVAL, "unknown zlib format or level");
  }
  if (n > limit) {
    free(data);
    return io_fail(e, EFBIG, NULL);
  }
  w->data = data;
  w->size = n;
  w->word = (format << 8) | level;
  return io_work(w, bendo_zlib_call, bendo_zlib_pack);
}

static void __attribute__((constructor)) bendo_zlib_use(void) {
  io_eff(CID(zlib_compress), bendo_zlib_run);
}
