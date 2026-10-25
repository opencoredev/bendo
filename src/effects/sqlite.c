// Trusted host effect for SQLite (BND-38). See sqlite.md beside this file.
//
// libsqlite3 is loaded with dlopen at the first open, so a program that never
// opens a database needs no SQLite, and the build needs no headers and no
// link flag (bend links only -lpthread and -lm). glibc 2.34 and later have
// dlopen in libc itself.
//
// Ownership. Connections live in a table indexed by slot - 1. The loop
// thread owns each connection's gen, state and transaction gate (owner,
// inflight, pending); the connection's mutex guards its sqlite3 handle and
// its statement table, which only helper threads touch. Every operation runs
// on a helper thread under that mutex, so statements on one connection run
// one at a time and sqlite3_changes, last_insert_rowid and the autocommit
// flag always belong to the statement that just ran. A connection is closed
// only once no operation on it is in flight, and its struct is reused, with
// gen moved on, so a stale handle fails instead of reaching another database.
//
// The gate is the table src/data/sqlite.bend states as Sqlite.gate: while a
// transaction is open, only statements carrying its token run; other
// statements wait, up to the connection's busy timeout, and fail with
// SQLITE_BUSY. Only begin and its end change the transaction state: a
// statement or script statement that would (BEGIN, COMMIT, END, ROLLBACK,
// SAVEPOINT, RELEASE) is refused before it runs. sqlite.js mirrors this file.
#include <dlfcn.h>
#include <limits.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#define BSQ_OK 0
#define BSQ_BUSY 5
#define BSQ_NOMEM 7
#define BSQ_CANTOPEN 14
#define BSQ_TOOBIG 18
#define BSQ_MISMATCH 20
#define BSQ_MISUSE 21
#define BSQ_RANGE 25
#define BSQ_ROW 100
#define BSQ_DONE 101
#define BSQ_ABORT_ROLLBACK 516

#define BSQ_INTEGER 1
#define BSQ_FLOAT 2
#define BSQ_TEXT 3
#define BSQ_BLOB 4
#define BSQ_NULL 5

#define BSQ_POLL_MS 1

typedef long long bsq_i64;

typedef struct BsqLib {
  int (*open_v2)(const char*, void**, int, const char*);
  int (*close_v2)(void*);
  int (*extended_result_codes)(void*, int);
  int (*busy_timeout)(void*, int);
  const char* (*errmsg)(void*);
  const char* (*errstr)(int);
  int (*extended_errcode)(void*);
  int (*prepare_v2)(void*, const char*, int, void**, const char**);
  int (*step)(void*);
  int (*reset)(void*);
  int (*clear_bindings)(void*);
  int (*finalize)(void*);
  int (*bind_parameter_count)(void*);
  const char* (*bind_parameter_name)(void*, int);
  int (*bind_parameter_index)(void*, const char*);
  int (*bind_null)(void*, int);
  int (*bind_int64)(void*, int, bsq_i64);
  int (*bind_double)(void*, int, double);
  int (*bind_text)(void*, int, const char*, int, void (*)(void*));
  int (*bind_blob)(void*, int, const void*, int, void (*)(void*));
  int (*bind_zeroblob)(void*, int, int);
  int (*column_count)(void*);
  const char* (*column_name)(void*, int);
  int (*column_type)(void*, int);
  bsq_i64 (*column_int64)(void*, int);
  double (*column_double)(void*, int);
  const unsigned char* (*column_text)(void*, int);
  const void* (*column_blob)(void*, int);
  int (*column_bytes)(void*, int);
  int (*get_autocommit)(void*);
  bsq_i64 (*total_changes64)(void*);
  int (*total_changes)(void*);
  bsq_i64 (*last_insert_rowid)(void*);
  int (*exec)(void*, const char*, void*, void*, char**);
  void (*free)(void*);
  int (*threadsafe)(void);
} BsqLib;

static BsqLib bsq;
static int bsq_loaded;
static char bsq_load_error[512];

#define BSQ_TRANSIENT ((void (*)(void*))-1)

static int bsq_load(void) {
  if (bsq_loaded != 0) {
    return bsq_loaded;
  }
#ifdef __APPLE__
  const char* names[] = { "libsqlite3.dylib", "/usr/lib/libsqlite3.dylib" };
  const char* tried = "libsqlite3.dylib";
#else
  const char* names[] = { "libsqlite3.so.0", "libsqlite3.so" };
  const char* tried = "libsqlite3.so.0, libsqlite3.so";
#endif
  void* h = NULL;
  for (size_t i = 0; i < sizeof names / sizeof *names && h == NULL; i += 1) {
    h = dlopen(names[i], RTLD_NOW | RTLD_LOCAL);
  }
  if (h == NULL) {
    snprintf(bsq_load_error, sizeof bsq_load_error,
      "bendo sqlite: libsqlite3 was not found (tried %s); install it, "
      "for example with apt-get install libsqlite3-0", tried);
    bsq_loaded = 2;
    return bsq_loaded;
  }
  const char* missing = NULL;
#define BSQ_SYM(field, name) \
  do { \
    *(void**)&bsq.field = dlsym(h, name); \
    if (bsq.field == NULL && missing == NULL) missing = name; \
  } while (0)
  BSQ_SYM(open_v2, "sqlite3_open_v2");
  BSQ_SYM(close_v2, "sqlite3_close_v2");
  BSQ_SYM(extended_result_codes, "sqlite3_extended_result_codes");
  BSQ_SYM(busy_timeout, "sqlite3_busy_timeout");
  BSQ_SYM(errmsg, "sqlite3_errmsg");
  BSQ_SYM(errstr, "sqlite3_errstr");
  BSQ_SYM(extended_errcode, "sqlite3_extended_errcode");
  BSQ_SYM(prepare_v2, "sqlite3_prepare_v2");
  BSQ_SYM(step, "sqlite3_step");
  BSQ_SYM(reset, "sqlite3_reset");
  BSQ_SYM(clear_bindings, "sqlite3_clear_bindings");
  BSQ_SYM(finalize, "sqlite3_finalize");
  BSQ_SYM(bind_parameter_count, "sqlite3_bind_parameter_count");
  BSQ_SYM(bind_parameter_name, "sqlite3_bind_parameter_name");
  BSQ_SYM(bind_parameter_index, "sqlite3_bind_parameter_index");
  BSQ_SYM(bind_null, "sqlite3_bind_null");
  BSQ_SYM(bind_int64, "sqlite3_bind_int64");
  BSQ_SYM(bind_double, "sqlite3_bind_double");
  BSQ_SYM(bind_text, "sqlite3_bind_text");
  BSQ_SYM(bind_blob, "sqlite3_bind_blob");
  BSQ_SYM(bind_zeroblob, "sqlite3_bind_zeroblob");
  BSQ_SYM(column_count, "sqlite3_column_count");
  BSQ_SYM(column_name, "sqlite3_column_name");
  BSQ_SYM(column_type, "sqlite3_column_type");
  BSQ_SYM(column_int64, "sqlite3_column_int64");
  BSQ_SYM(column_double, "sqlite3_column_double");
  BSQ_SYM(column_text, "sqlite3_column_text");
  BSQ_SYM(column_blob, "sqlite3_column_blob");
  BSQ_SYM(column_bytes, "sqlite3_column_bytes");
  BSQ_SYM(get_autocommit, "sqlite3_get_autocommit");
  BSQ_SYM(total_changes, "sqlite3_total_changes");
  BSQ_SYM(last_insert_rowid, "sqlite3_last_insert_rowid");
  BSQ_SYM(exec, "sqlite3_exec");
  BSQ_SYM(free, "sqlite3_free");
  BSQ_SYM(threadsafe, "sqlite3_threadsafe");
#undef BSQ_SYM
  // Optional: SQLite 3.37 and later. Older ones count changes in an int.
  *(void**)&bsq.total_changes64 = dlsym(h, "sqlite3_total_changes64");
  if (missing != NULL) {
    snprintf(bsq_load_error, sizeof bsq_load_error,
      "bendo sqlite: libsqlite3 lacks %s; it is too old", missing);
    bsq_loaded = 2;
  } else if (bsq.threadsafe() == 0) {
    snprintf(bsq_load_error, sizeof bsq_load_error,
      "bendo sqlite: libsqlite3 was built without thread support");
    bsq_loaded = 2;
  } else {
    bsq_loaded = 1;
  }
  return bsq_loaded;
}

// ------------------------------------------------------------- Registry

typedef struct BsqStmt {
  void* stmt;
  u32 gen;
} BsqStmt;

enum { BSQ_FREE, BSQ_OPENING, BSQ_OPEN, BSQ_CLOSING };

typedef struct BsqConn {
  // Loop thread only.
  u32 gen;
  int state;
  u32 owner;
  u32 next_token;
  u32 inflight;
  u32 pending;
  u32 busy_ms;
  // Under lock, helper threads only.
  pthread_mutex_t lock;
  void* db;
  BsqStmt* stmts;
  u32 nstmts;
} BsqConn;

static BsqConn** bsq_conns;
static u32 bsq_nconns;

typedef struct BsqCell {
  int type;
  char* p;
  size_t n;
} BsqCell;

typedef struct BsqJob {
  u32 op, slot, gen, token, index, sgen, mode, limit, max_bytes, max_cell;
  char* text1;
  u64 n1;
  char* text2;
  u64 n2;
  BsqConn* conn;
  u64 deadline;
  int counted;
  int code;
  char* msg;
  u32 r1, r2;
  char** cols;
  u32 ncols;
  BsqCell* cells;
  size_t ncells, cap, bytes;
  u32 nrows;
  bsq_i64 changes;
  bsq_i64 rowid;
} BsqJob;

static void bsq_job_free(BsqJob* j) {
  free(j->text1);
  free(j->text2);
  free(j->msg);
  for (u32 i = 0; i < j->ncols; i += 1) {
    free(j->cols[i]);
  }
  free(j->cols);
  for (size_t i = 0; i < j->ncells; i += 1) {
    free(j->cells[i].p);
  }
  free(j->cells);
  free(j);
}

static char* bsq_dup(const char* s, size_t n) {
  char* out = io_mem(malloc(n + 1));
  memcpy(out, s, n);
  out[n] = 0;
  return out;
}

static void bsq_fail(BsqJob* j, int code, const char* msg) {
  if (j->code != 0) {
    return;
  }
  j->code = code;
  j->msg = bsq_dup(msg, strlen(msg));
}

static void bsq_fail_db(BsqJob* j, void* db) {
  bsq_fail(j, bsq.extended_errcode(db), bsq.errmsg(db));
}

// ------------------------------------------------------------- Values

// JavaScript's Number.prototype.toString: the shortest digits that read back
// as x, plain between 1e-7 and 1e21, else d.ddde+n.
static void bsq_real(double x, char* out) {
  if (isnan(x)) {
    strcpy(out, "NaN");
    return;
  }
  if (isinf(x)) {
    strcpy(out, x < 0 ? "-Infinity" : "Infinity");
    return;
  }
  if (x == 0) {
    strcpy(out, "0");
    return;
  }
  char buf[48];
  for (int p = 1; p <= 17; p += 1) {
    snprintf(buf, sizeof buf, "%.*e", p - 1, x);
    if (strtod(buf, NULL) == x) {
      break;
    }
  }
  const char* s = buf;
  int neg = *s == '-';
  s += neg;
  char digits[24];
  int k = 0;
  for (; *s != 0 && *s != 'e'; s += 1) {
    if (*s >= '0' && *s <= '9') {
      digits[k++] = *s;
    }
  }
  int n = atoi(s + 1) + 1;
  while (k > 1 && digits[k - 1] == '0') {
    k -= 1;
  }
  char* o = out;
  if (neg) {
    *o++ = '-';
  }
  if (k <= n && n <= 21) {
    memcpy(o, digits, (size_t)k);
    o += k;
    for (int i = 0; i < n - k; i += 1) {
      *o++ = '0';
    }
  } else if (0 < n && n <= 21) {
    memcpy(o, digits, (size_t)n);
    o += n;
    *o++ = '.';
    memcpy(o, digits + n, (size_t)(k - n));
    o += k - n;
  } else if (-6 < n && n <= 0) {
    *o++ = '0';
    *o++ = '.';
    for (int i = 0; i < -n; i += 1) {
      *o++ = '0';
    }
    memcpy(o, digits, (size_t)k);
    o += k;
  } else {
    *o++ = digits[0];
    if (k > 1) {
      *o++ = '.';
      memcpy(o, digits + 1, (size_t)(k - 1));
      o += k - 1;
    }
    int e = n - 1;
    o += sprintf(o, "e%c%d", e < 0 ? '-' : '+', e < 0 ? -e : e);
  }
  *o = 0;
}

// A canonical decimal in the signed 64-bit range: no sign on zero, no
// leading zeros, no plus sign.
static int bsq_int(const char* s, size_t n, bsq_i64* out) {
  size_t i = n > 0 && s[0] == '-';
  if (i == n || (s[i] == '0' && n - i > 1) || (i == 1 && s[i] == '0')) {
    return 0;
  }
  unsigned long long limit = i ? 9223372036854775808ULL : 9223372036854775807ULL;
  unsigned long long v = 0;
  for (; i < n; i += 1) {
    if (s[i] < '0' || s[i] > '9') {
      return 0;
    }
    unsigned d = (unsigned)(s[i] - '0');
    if (v > (limit - d) / 10) {
      return 0;
    }
    v = v * 10 + d;
  }
  if (n > 0 && s[0] == '-') {
    *out = v == 9223372036854775808ULL ? LLONG_MIN : -(bsq_i64)v;
  } else {
    *out = (bsq_i64)v;
  }
  return 1;
}

static int bsq_digits(const char* s, size_t n, size_t* i) {
  size_t start = *i;
  while (*i < n && s[*i] >= '0' && s[*i] <= '9') {
    *i += 1;
  }
  return *i > start;
}

// RFC 8259's number grammar, the same J.number_valid accepts.
static int bsq_number(const char* s, size_t n) {
  size_t i = 0;
  if (i < n && s[i] == '-') {
    i += 1;
  }
  if (i < n && s[i] == '0') {
    i += 1;
  } else if (!bsq_digits(s, n, &i)) {
    return 0;
  }
  if (i < n && s[i] == '.') {
    i += 1;
    if (!bsq_digits(s, n, &i)) {
      return 0;
    }
  }
  if (i < n && (s[i] == 'e' || s[i] == 'E')) {
    i += 1;
    if (i < n && (s[i] == '+' || s[i] == '-')) {
      i += 1;
    }
    if (!bsq_digits(s, n, &i)) {
      return 0;
    }
  }
  return i == n;
}

// One payload of the wire format: characters up to an unescaped ';', with
// '\' escaping the next character. Escapes are ASCII, so this works on the
// UTF-8 bytes. Writes the unescaped bytes to out (which may alias the input,
// since the output never runs ahead) and returns the index after the ';', or
// 0 when the payload has no end.
static size_t bsq_payload(const char* s, size_t n, size_t i, char* out, size_t* len) {
  size_t k = 0;
  while (i < n) {
    char c = s[i++];
    if (c == ';') {
      *len = k;
      return i;
    }
    if (c == '\\') {
      if (i == n) {
        return 0;
      }
      c = s[i++];
    }
    out[k++] = c;
  }
  return 0;
}

// Reads the UTF-8 code point at s[*i]. The payload came from io_cstr, so it
// is well formed.
static u32 bsq_point(const unsigned char* s, size_t n, size_t* i) {
  u32 c = s[(*i)++];
  int more = c < 0x80 ? 0 : c < 0xE0 ? 1 : c < 0xF0 ? 2 : 3;
  c = more == 0 ? c : more == 1 ? c & 0x1F : more == 2 ? c & 0x0F : c & 0x07;
  for (; more > 0 && *i < n; more -= 1) {
    c = (c << 6) | (s[(*i)++] & 0x3F);
  }
  return c;
}

static int bsq_named(const char* name) {
  return name != NULL && (name[0] == ':' || name[0] == '@' || name[0] == '$');
}

// Binds one value; tag is the wire tag, p the unescaped payload.
static int bsq_bind_one(BsqJob* j, void* st, int at, char tag, char* p, size_t n) {
  char msg[160];
  int rc;
  switch (tag) {
    case 'n':
      rc = bsq.bind_null(st, at);
      break;
    case 'i': {
      bsq_i64 v;
      if (!bsq_int(p, n, &v)) {
        snprintf(msg, sizeof msg,
          "parameter %d: an integer must be canonical decimal text in the signed 64-bit range", at);
        bsq_fail(j, BSQ_MISMATCH, msg);
        return 0;
      }
      rc = bsq.bind_int64(st, at, v);
      break;
    }
    case 'r':
      if (!bsq_number(p, n)) {
        snprintf(msg, sizeof msg, "parameter %d: a real must be a JSON number", at);
        bsq_fail(j, BSQ_MISMATCH, msg);
        return 0;
      }
      p[n] = 0;
      rc = bsq.bind_double(st, at, strtod(p, NULL));
      break;
    case 't':
      if (n > INT_MAX) {
        bsq_fail(j, BSQ_TOOBIG, "string or blob too big");
        return 0;
      }
      rc = bsq.bind_text(st, at, p, (int)n, BSQ_TRANSIENT);
      break;
    case 'b': {
      size_t k = 0;
      for (size_t i = 0; i < n;) {
        u32 c = bsq_point((const unsigned char*)p, n, &i);
        if (c > 255) {
          snprintf(msg, sizeof msg, "parameter %d: a blob byte must be below 256", at);
          bsq_fail(j, BSQ_MISMATCH, msg);
          return 0;
        }
        p[k++] = (char)c;
      }
      if (k > INT_MAX) {
        bsq_fail(j, BSQ_TOOBIG, "string or blob too big");
        return 0;
      }
      // A NULL pointer would bind NULL, so an empty blob binds a zero blob.
      rc = k == 0 ? bsq.bind_zeroblob(st, at, 0) : bsq.bind_blob(st, at, p, (int)k, BSQ_TRANSIENT);
      break;
    }
    default:
      bsq_fail(j, BSQ_MISUSE, "bendo sqlite: malformed parameters");
      return 0;
  }
  if (rc != BSQ_OK) {
    bsq_fail(j, rc, bsq.errstr(rc));
    return 0;
  }
  return 1;
}

// Skips one value at s[i]; returns the index after it, or 0 if malformed.
static size_t bsq_skip(const char* s, size_t n, size_t i) {
  if (i >= n) {
    return 0;
  }
  char tag = s[i++];
  if (tag == 'n') {
    return i;
  }
  while (i < n) {
    char c = s[i++];
    if (c == ';') {
      return i;
    }
    if (c == '\\') {
      if (i == n) {
        return 0;
      }
      i += 1;
    }
  }
  return 0;
}

// Binds the wire string in j->text2: 'P' then values bind positions 1, 2,
// ... and must number exactly the statement's parameters, none of them
// named; 'N' then name/value pairs must bind every parameter exactly once.
static int bsq_bind(BsqJob* j, void* st) {
  char* s = j->text2;
  size_t n = (size_t)j->n2;
  int count = bsq.bind_parameter_count(st);
  char msg[256];
  if (n == 0 || (s[0] != 'P' && s[0] != 'N')) {
    bsq_fail(j, BSQ_MISUSE, "bendo sqlite: malformed parameters");
    return 0;
  }
  int named = s[0] == 'N';
  if (!named) {
    int given = 0;
    for (size_t i = 1; i < n; given += 1) {
      i = bsq_skip(s, n, i);
      if (i == 0) {
        bsq_fail(j, BSQ_MISUSE, "bendo sqlite: malformed parameters");
        return 0;
      }
    }
    if (given != count) {
      snprintf(msg, sizeof msg, "%d parameters given, the statement has %d", given, count);
      bsq_fail(j, BSQ_RANGE, msg);
      return 0;
    }
    for (int k = 1; k <= count; k += 1) {
      const char* name = bsq.bind_parameter_name(st, k);
      if (bsq_named(name)) {
        snprintf(msg, sizeof msg,
          "parameter %d is named %.150s; bind named parameters with Sql.named", k, name);
        bsq_fail(j, BSQ_RANGE, msg);
        return 0;
      }
    }
  }
  char* bound = io_mem(calloc((size_t)count + 1, 1));
  int at = 0;
  size_t i = 1;
  int ok = 1;
  while (ok && i < n) {
    if (named) {
      size_t len = 0;
      size_t next = bsq_payload(s, n, i, s + i, &len);
      if (next == 0 || next >= n) {
        bsq_fail(j, BSQ_MISUSE, "bendo sqlite: malformed parameters");
        ok = 0;
        break;
      }
      char* name = s + i;
      name[len] = 0;
      at = bsq.bind_parameter_index(st, name);
      if (at == 0) {
        snprintf(msg, sizeof msg, "no parameter named %.200s", name);
        bsq_fail(j, BSQ_RANGE, msg);
        ok = 0;
        break;
      }
      if (bound[at]) {
        snprintf(msg, sizeof msg, "parameter %.200s is bound twice", name);
        bsq_fail(j, BSQ_RANGE, msg);
        ok = 0;
        break;
      }
      i = next;
    } else {
      at += 1;
    }
    char tag = s[i++];
    if (tag == 'n') {
      ok = bsq_bind_one(j, st, at, tag, NULL, 0);
    } else {
      size_t len = 0;
      size_t next = bsq_payload(s, n, i, s + i, &len);
      if (next == 0) {
        bsq_fail(j, BSQ_MISUSE, "bendo sqlite: malformed parameters");
        ok = 0;
        break;
      }
      char* p = s + i;
      i = next;
      ok = bsq_bind_one(j, st, at, tag, p, len);
    }
    bound[at] = 1;
  }
  for (int k = 1; ok && named && k <= count; k += 1) {
    if (!bound[k]) {
      const char* name = bsq.bind_parameter_name(st, k);
      if (name != NULL) {
        snprintf(msg, sizeof msg, "parameter %.200s is not bound", name);
      } else {
        snprintf(msg, sizeof msg, "parameter %d has no name; bind it with Sql.positional", k);
      }
      bsq_fail(j, BSQ_RANGE, msg);
      ok = 0;
    }
  }
  free(bound);
  return ok;
}

// ------------------------------------------------------------- Calls

static const char* BSQ_CONTROL_MSG =
  "bendo sqlite: a statement may not begin or end a transaction or savepoint; "
  "use Sql.begin, Sql.commit and Sql.rollback";

static int bsq_space(char c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r';
}

static int bsq_ident(unsigned char c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
    || c == '_' || c == '$' || c >= 0x80;
}

// Whether the statement text s[0..n), one statement as prepare_v2 cut it,
// begins with BEGIN, COMMIT, END, ROLLBACK, SAVEPOINT or RELEASE after
// whitespace and comments. These are the only statements that start, end or
// nest a transaction, and each starts with its keyword.
static int bsq_control(const char* s, size_t n) {
  size_t i = 0;
  for (;;) {
    while (i < n && bsq_space(s[i])) {
      i += 1;
    }
    if (i + 1 < n && s[i] == '-' && s[i + 1] == '-') {
      while (i < n && s[i] != '\n') {
        i += 1;
      }
    } else if (i + 1 < n && s[i] == '/' && s[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(s[i] == '*' && s[i + 1] == '/')) {
        i += 1;
      }
      i = i + 1 < n ? i + 2 : n;
    } else {
      break;
    }
  }
  size_t k = i;
  while (k < n && bsq_ident((unsigned char)s[k])) {
    k += 1;
  }
  static const char* words[] = { "BEGIN", "COMMIT", "END", "ROLLBACK", "SAVEPOINT", "RELEASE" };
  for (size_t w = 0; w < sizeof words / sizeof *words; w += 1) {
    size_t len = strlen(words[w]);
    if (k - i != len) {
      continue;
    }
    size_t m = 0;
    while (m < len && (s[i + m] & ~0x20) == words[w][m]) {
      m += 1;
    }
    if (m == len) {
      return 1;
    }
  }
  return 0;
}

// Prepares exactly one statement from sql. Fails when there is none, when
// anything but whitespace and comments follows it, or when it is a
// transaction-control statement.
static void* bsq_prepare_one(BsqJob* j, void* db, const char* sql, size_t n) {
  if (strlen(sql) != n) {
    bsq_fail(j, BSQ_MISUSE, "bendo sqlite: SQL contains a NUL character");
    return NULL;
  }
  if (n > INT_MAX) {
    bsq_fail(j, BSQ_TOOBIG, "string or blob too big");
    return NULL;
  }
  void* st = NULL;
  const char* tail = NULL;
  if (bsq.prepare_v2(db, sql, (int)n, &st, &tail) != BSQ_OK) {
    bsq_fail_db(j, db);
    return NULL;
  }
  if (st == NULL) {
    bsq_fail(j, BSQ_MISUSE, "bendo sqlite: no SQL statement");
    return NULL;
  }
  void* more = NULL;
  const char* rest = NULL;
  int rc = bsq.prepare_v2(db, tail, (int)(n - (size_t)(tail - sql)), &more, &rest);
  if (rc != BSQ_OK || more != NULL) {
    if (more != NULL) {
      bsq.finalize(more);
    }
    bsq.finalize(st);
    bsq_fail(j, BSQ_MISUSE,
      "bendo sqlite: one statement per call; run scripts with Sql.exec");
    return NULL;
  }
  if (bsq_control(sql, (size_t)(tail - sql))) {
    bsq.finalize(st);
    bsq_fail(j, BSQ_MISUSE, BSQ_CONTROL_MSG);
    return NULL;
  }
  return st;
}

static bsq_i64 bsq_total(void* db) {
  return bsq.total_changes64 != NULL ? bsq.total_changes64(db) : (bsq_i64)bsq.total_changes(db);
}

static void bsq_push_cell(BsqJob* j, int type, char* p, size_t n) {
  if (j->ncells == j->cap) {
    j->cap = j->cap == 0 ? 64 : j->cap * 2;
    j->cells = io_mem(realloc(j->cells, j->cap * sizeof *j->cells));
  }
  j->cells[j->ncells++] = (BsqCell){ type, p, n };
}

// Counts n more bytes of the result against its budgets; a text or blob
// cell also counts against the per-cell one.
static int bsq_budget(BsqJob* j, size_t n, int cell) {
  char msg[96];
  if (cell && n > j->max_cell) {
    snprintf(msg, sizeof msg, "bendo sqlite: a column value is larger than %u bytes", j->max_cell);
    bsq_fail(j, BSQ_TOOBIG, msg);
    return 0;
  }
  if (n > j->max_bytes - j->bytes) {
    snprintf(msg, sizeof msg, "bendo sqlite: the result is larger than %u bytes", j->max_bytes);
    bsq_fail(j, BSQ_TOOBIG, msg);
    return 0;
  }
  j->bytes += n;
  return 1;
}

// Copies the current row; fails, copying nothing more, past a budget.
static int bsq_take_row(BsqJob* j, void* st) {
  for (u32 c = 0; c < j->ncols; c += 1) {
    int type = bsq.column_type(st, (int)c);
    switch (type) {
      case BSQ_INTEGER: {
        char* p = io_mem(malloc(24));
        snprintf(p, 24, "%lld", bsq.column_int64(st, (int)c));
        if (!bsq_budget(j, strlen(p), 0)) {
          free(p);
          return 0;
        }
        bsq_push_cell(j, type, p, strlen(p));
        break;
      }
      case BSQ_FLOAT: {
        char* p = io_mem(malloc(48));
        bsq_real(bsq.column_double(st, (int)c), p);
        if (!bsq_budget(j, strlen(p), 0)) {
          free(p);
          return 0;
        }
        bsq_push_cell(j, type, p, strlen(p));
        break;
      }
      case BSQ_TEXT: {
        const unsigned char* t = bsq.column_text(st, (int)c);
        size_t n = (size_t)bsq.column_bytes(st, (int)c);
        if (!bsq_budget(j, t != NULL ? n : 0, 1)) {
          return 0;
        }
        bsq_push_cell(j, type, bsq_dup(t != NULL ? (const char*)t : "", t != NULL ? n : 0), n);
        break;
      }
      case BSQ_BLOB: {
        const void* b = bsq.column_blob(st, (int)c);
        size_t n = (size_t)bsq.column_bytes(st, (int)c);
        if (!bsq_budget(j, b != NULL ? n : 0, 1)) {
          return 0;
        }
        bsq_push_cell(j, type, bsq_dup(b != NULL ? b : "", b != NULL ? n : 0), b != NULL ? n : 0);
        break;
      }
      default:
        bsq_push_cell(j, BSQ_NULL, NULL, 0);
    }
  }
  j->nrows += 1;
  return 1;
}

// The result's column names. Read after the first step, because a step can
// recompile the statement after a schema change and change them.
static void bsq_columns(BsqJob* j, void* st) {
  j->ncols = (u32)bsq.column_count(st);
  j->cols = j->ncols == 0 ? NULL : io_mem(calloc(j->ncols, sizeof *j->cols));
  for (u32 k = 0; k < j->ncols; k += 1) {
    const char* name = bsq.column_name(st, (int)k);
    j->cols[k] = bsq_dup(name != NULL ? name : "", name != NULL ? strlen(name) : 0);
  }
}

// Before a statement: an autocommit statement needs no transaction open, a
// transaction's statement needs its transaction still open (SQLite rolls
// one back by itself after some errors).
static int bsq_before(BsqJob* j, void* db) {
  int autocommit = bsq.get_autocommit(db);
  if (j->token != 0 && autocommit) {
    bsq_fail(j, BSQ_ABORT_ROLLBACK,
      "bendo sqlite: the transaction was rolled back; roll it back and start again");
    return 0;
  }
  return 1;
}

// After a statement: it may not have begun or ended a transaction itself.
static void bsq_after(BsqJob* j, void* db) {
  int autocommit = bsq.get_autocommit(db);
  if (j->token == 0 && !autocommit) {
    bsq.exec(db, "ROLLBACK", NULL, NULL, NULL);
    j->code = 0;
    free(j->msg);
    j->msg = NULL;
    bsq_fail(j, BSQ_MISUSE, "bendo sqlite: a statement may not begin a transaction; use Sql.begin");
  } else if (j->token != 0 && autocommit && j->code == 0) {
    bsq_fail(j, BSQ_MISUSE,
      "bendo sqlite: a statement may not end a transaction; use Sql.commit or Sql.rollback");
  }
}

static void bsq_query(BsqJob* j, BsqConn* c) {
  void* db = c->db;
  void* st = NULL;
  int own = j->index == 0;
  if (!bsq_before(j, db)) {
    return;
  }
  if (own) {
    st = bsq_prepare_one(j, db, j->text1, (size_t)j->n1);
    if (st == NULL) {
      return;
    }
  } else {
    if (j->index > c->nstmts || c->stmts[j->index - 1].stmt == NULL
      || c->stmts[j->index - 1].gen != j->sgen) {
      bsq_fail(j, BSQ_MISUSE, "bendo sqlite: the statement is finalized or belongs to another connection");
      return;
    }
    st = c->stmts[j->index - 1].stmt;
    bsq.reset(st);
    bsq.clear_bindings(st);
  }
  if (bsq_bind(j, st)) {
    bsq_i64 before = bsq_total(db);
    for (int first = 1;; first = 0) {
      int rc = bsq.step(st);
      if (first && j->mode != 0 && (rc == BSQ_ROW || rc == BSQ_DONE)) {
        bsq_columns(j, st);
      }
      if (rc == BSQ_ROW) {
        if (j->mode == 0) {
          continue;
        }
        if (j->mode == 1 && j->nrows >= j->limit) {
          char msg[96];
          snprintf(msg, sizeof msg, "bendo sqlite: the query returned more than %u rows", j->limit);
          bsq_fail(j, BSQ_TOOBIG, msg);
          break;
        }
        if (!bsq_take_row(j, st)) {
          break;
        }
        if (j->mode == 2) {
          break;
        }
      } else if (rc == BSQ_DONE) {
        break;
      } else {
        bsq_fail_db(j, db);
        break;
      }
    }
    j->changes = bsq_total(db) - before;
    j->rowid = bsq.last_insert_rowid(db);
  }
  if (own) {
    bsq.finalize(st);
  } else {
    bsq.reset(st);
    bsq.clear_bindings(st);
  }
  bsq_after(j, db);
}

// Runs a script one statement at a time, as sqlite3_exec does, but refuses
// a transaction-control statement before it runs and stops at the first
// statement after which the transaction state differs.
static void bsq_exec(BsqJob* j, BsqConn* c) {
  void* db = c->db;
  const char* sql = j->text1;
  size_t n = (size_t)j->n1;
  if (strlen(sql) != n) {
    bsq_fail(j, BSQ_MISUSE, "bendo sqlite: SQL contains a NUL character");
    return;
  }
  if (n > INT_MAX) {
    bsq_fail(j, BSQ_TOOBIG, "string or blob too big");
    return;
  }
  if (!bsq_before(j, db)) {
    return;
  }
  int autocommit = bsq.get_autocommit(db);
  const char* at = sql;
  while (j->code == 0 && at < sql + n) {
    void* st = NULL;
    const char* tail = NULL;
    if (bsq.prepare_v2(db, at, (int)(sql + n - at), &st, &tail) != BSQ_OK) {
      bsq_fail_db(j, db);
      break;
    }
    if (st == NULL) {
      // Whitespace, a comment or a lone ';'.
      if (tail == NULL || tail <= at) {
        break;
      }
      at = tail;
      continue;
    }
    if (bsq_control(at, (size_t)(tail - at))) {
      bsq.finalize(st);
      bsq_fail(j, BSQ_MISUSE, BSQ_CONTROL_MSG);
      break;
    }
    int rc = bsq.step(st);
    while (rc == BSQ_ROW) {
      rc = bsq.step(st);
    }
    if (rc != BSQ_DONE) {
      bsq_fail_db(j, db);
    }
    bsq.finalize(st);
    if (bsq.get_autocommit(db) != autocommit) {
      break;
    }
    at = tail;
  }
  bsq_after(j, db);
}

static void bsq_call(IoWork* w) {
  BsqJob* j = (BsqJob*)w->data;
  BsqConn* c = j->conn;
  pthread_mutex_lock(&c->lock);
  switch (j->op) {
    case 0: {
      void* db = NULL;
      int flags = (j->mode == 2 ? 0x1 : j->mode == 1 ? 0x2 : 0x2 | 0x4) | 0x10000;
      int rc = bsq.open_v2(j->text1, &db, flags, NULL);
      if (rc != BSQ_OK) {
        if (db != NULL) {
          bsq_fail_db(j, db);
          bsq.close_v2(db);
        } else {
          bsq_fail(j, rc, bsq.errstr(rc));
        }
        break;
      }
      bsq.extended_result_codes(db, 1);
      bsq.busy_timeout(db, j->limit > INT_MAX ? INT_MAX : (int)j->limit);
      c->db = db;
      break;
    }
    case 1: {
      if (!bsq.get_autocommit(c->db)) {
        bsq.exec(c->db, "ROLLBACK", NULL, NULL, NULL);
      }
      for (u32 i = 0; i < c->nstmts; i += 1) {
        if (c->stmts[i].stmt != NULL) {
          bsq.finalize(c->stmts[i].stmt);
        }
      }
      free(c->stmts);
      c->stmts = NULL;
      c->nstmts = 0;
      if (bsq.close_v2(c->db) != BSQ_OK) {
        bsq_fail_db(j, c->db);
      }
      c->db = NULL;
      break;
    }
    case 2: {
      void* st = bsq_prepare_one(j, c->db, j->text1, (size_t)j->n1);
      if (st == NULL) {
        break;
      }
      u32 at = 0;
      while (at < c->nstmts && c->stmts[at].stmt != NULL) {
        at += 1;
      }
      if (at == c->nstmts) {
        c->stmts = io_mem(realloc(c->stmts, (c->nstmts + 1) * sizeof *c->stmts));
        c->stmts[at] = (BsqStmt){ NULL, 0 };
        c->nstmts += 1;
      }
      c->stmts[at].stmt = st;
      c->stmts[at].gen += 1;
      j->r1 = at + 1;
      j->r2 = c->stmts[at].gen;
      break;
    }
    case 3:
      if (j->index == 0 || j->index > c->nstmts || c->stmts[j->index - 1].stmt == NULL
        || c->stmts[j->index - 1].gen != j->sgen) {
        bsq_fail(j, BSQ_MISUSE, "bendo sqlite: the statement is finalized or belongs to another connection");
        break;
      }
      bsq.finalize(c->stmts[j->index - 1].stmt);
      c->stmts[j->index - 1].stmt = NULL;
      break;
    case 4:
      bsq_query(j, c);
      break;
    case 5:
      bsq_exec(j, c);
      break;
    case 6: {
      const char* sql = j->mode == 2 ? "BEGIN EXCLUSIVE" : j->mode == 1 ? "BEGIN IMMEDIATE" : "BEGIN DEFERRED";
      if (bsq.exec(c->db, sql, NULL, NULL, NULL) != BSQ_OK) {
        bsq_fail_db(j, c->db);
      }
      break;
    }
    case 7:
      if (j->mode == 1) {
        if (bsq.get_autocommit(c->db)) {
          bsq_fail(j, BSQ_ABORT_ROLLBACK,
            "bendo sqlite: the transaction was rolled back; roll it back and start again");
        } else if (bsq.exec(c->db, "COMMIT", NULL, NULL, NULL) != BSQ_OK) {
          bsq_fail_db(j, c->db);
          if (!bsq.get_autocommit(c->db)) {
            bsq.exec(c->db, "ROLLBACK", NULL, NULL, NULL);
          }
        }
      } else if (!bsq.get_autocommit(c->db)
        && bsq.exec(c->db, "ROLLBACK", NULL, NULL, NULL) != BSQ_OK) {
        bsq_fail_db(j, c->db);
      }
      break;
  }
  pthread_mutex_unlock(&c->lock);
}

// ------------------------------------------------------------- Loop side

// A four-field constructor, as io_node builds a two-field one.
static Term bsq_node4(Env e, u64 cid, Term a, Term b, Term c, Term d) {
  u64 l = heap_alloc(e, cls_fit(4));
  e.mem[l]     = io_seal(e, a, cid);
  e.mem[l + 1] = io_seal(e, b, cid);
  e.mem[l + 2] = io_seal(e, c, cid);
  e.mem[l + 3] = io_seal(e, d, cid);
  return term_ctr(cid, l);
}

static Term bsq_values(Env e, BsqJob* j, size_t from) {
  Term xs = term_pak(CID(Nil), 0);
  for (u32 k = j->ncols; k > 0; k -= 1) {
    BsqCell* cell = &j->cells[from + k - 1];
    Term v;
    switch (cell->type) {
      case BSQ_INTEGER:
        v = io_box(e, CID(CellInteger), io_str(e, cell->p, cell->n));
        break;
      case BSQ_FLOAT:
        v = io_box(e, CID(CellReal), io_str(e, cell->p, cell->n));
        break;
      case BSQ_TEXT:
        v = io_box(e, CID(CellText), io_str(e, cell->p, cell->n));
        break;
      case BSQ_BLOB:
        v = io_box(e, CID(CellBlob), io_list(e, cell->p, cell->n));
        break;
      default:
        v = term_pak(CID(CellNull), 0);
    }
    xs = io_node(e, CID(Con), v, xs);
  }
  return xs;
}

static Term bsq_reply(Env e, BsqJob* j) {
  switch (j->op) {
    case 0:
    case 2:
      return io_node(e, CID(Handle), (Term)j->r1, (Term)j->r2);
    case 6:
      return io_node(e, CID(Handle), (Term)j->token, (Term)0);
    case 4: {
      Term cols = term_pak(CID(Nil), 0);
      for (u32 k = j->ncols; k > 0; k -= 1) {
        cols = io_node(e, CID(Con), io_str(e, j->cols[k - 1], strlen(j->cols[k - 1])), cols);
      }
      Term rows = term_pak(CID(Nil), 0);
      for (u32 r = j->nrows; r > 0; r -= 1) {
        rows = io_node(e, CID(Con), bsq_values(e, j, (size_t)(r - 1) * j->ncols), rows);
      }
      u64 changes = j->changes < 0 ? 0 : (u64)j->changes;
      changes = changes > 0xFFFFFFFFFFFFULL ? 0xFFFFFFFFFFFFULL : changes;
      char rowid[24];
      snprintf(rowid, sizeof rowid, "%lld", j->rowid);
      return bsq_node4(e, CID(Ran), cols, rows, (Term)changes, io_str(e, rowid, strlen(rowid)));
    }
    default:
      return term_pak(CID(Finished), 0);
  }
}

static Term bsq_pack(Env e, IoWork* w) {
  BsqJob* j = (BsqJob*)w->data;
  BsqConn* c = j->conn;
  c->inflight -= 1;
  switch (j->op) {
    case 0:
      if (j->code != 0) {
        c->state = BSQ_FREE;
        c->gen += 1;
      } else {
        c->state = BSQ_OPEN;
        j->r1 = j->slot;
        j->r2 = c->gen;
      }
      break;
    case 1:
      c->state = BSQ_FREE;
      c->gen += 1;
      c->owner = 0;
      break;
    case 6:
      if (j->code != 0) {
        c->owner = 0;
      }
      break;
    case 7:
      c->owner = 0;
      break;
  }
  Term r = j->code != 0 ? io_fail(e, (u32)j->code, j->msg) : io_done(e, bsq_reply(e, j));
  bsq_job_free(j);
  return r;
}

static Term bsq_refuse(Env e, BsqJob* j, int code, const char* msg) {
  Term r = io_fail(e, (u32)code, msg);
  // A begin counted as waiting on a connection that has since closed counts
  // nowhere: open zeroes the count of the connection that reuses the slot.
  if (j->counted && j->conn != NULL && j->conn->gen == j->gen) {
    j->conn->pending -= 1;
  }
  bsq_job_free(j);
  return r;
}

enum { BSQ_GO, BSQ_HOLD, BSQ_NO };

// The gate (Sqlite.gate in src/data/sqlite.bend), plus close, which waits for
// in-flight work, and prepare and finalize, which never wait.
static int bsq_gate(BsqConn* c, BsqJob* j) {
  switch (j->op) {
    case 4:
    case 5:
      if (j->token == 0) {
        return c->owner == 0 && c->pending == 0 ? BSQ_GO : BSQ_HOLD;
      }
      return c->owner == j->token ? BSQ_GO : BSQ_NO;
    case 6:
      return c->owner == 0 && c->inflight == 0 ? BSQ_GO : BSQ_HOLD;
    case 7:
      if (j->token == 0 || c->owner != j->token) {
        return BSQ_NO;
      }
      return c->inflight == 0 ? BSQ_GO : BSQ_HOLD;
    case 1:
      return c->inflight == 0 ? BSQ_GO : BSQ_HOLD;
    default:
      return BSQ_GO;
  }
}

static Term bsq_try(Env e, IoWork* w) {
  BsqJob* j = (BsqJob*)w->data;
  BsqConn* c = j->conn;
  if (c->gen != j->gen || (c->state != BSQ_OPEN && !(j->op == 1 && c->state == BSQ_CLOSING))) {
    return bsq_refuse(e, j, BSQ_MISUSE, "bendo sqlite: the connection is closed");
  }
  int verdict = bsq_gate(c, j);
  if (verdict == BSQ_NO) {
    return bsq_refuse(e, j, BSQ_MISUSE, "bendo sqlite: no open transaction for this handle");
  }
  if (verdict == BSQ_HOLD) {
    u64 now = io_tick();
    if (now >= j->deadline) {
      return bsq_refuse(e, j, BSQ_BUSY,
        "bendo sqlite: the connection is busy with another transaction");
    }
    if (j->op == 6 && !j->counted) {
      j->counted = 1;
      c->pending += 1;
    }
    u64 next = io_until(BSQ_POLL_MS);
    return io_wait_on(w, 0, 0, next < j->deadline ? next : j->deadline, bsq_try);
  }
  if (j->counted) {
    j->counted = 0;
    c->pending -= 1;
  }
  if (j->op == 6) {
    c->next_token = c->next_token == 0xFFFFFFFFu ? 1 : c->next_token + 1;
    c->owner = c->next_token;
    j->token = c->owner;
  }
  c->inflight += 1;
  return io_work(w, bsq_call, bsq_pack);
}

static Term bendo_sqlite_call_run(Env e, Term* f, IoWork* w) {
  BsqJob* j = io_mem(calloc(1, sizeof *j));
  j->op = (u32)f[0];
  j->slot = (u32)f[1];
  j->gen = (u32)f[2];
  j->token = (u32)f[3];
  j->index = (u32)f[4];
  j->sgen = (u32)f[5];
  j->mode = (u32)f[6];
  j->limit = (u32)f[7];
  j->max_bytes = (u32)f[8];
  j->max_cell = (u32)f[9];
  j->text1 = io_cstr(e, f[10], &j->n1);
  j->text2 = io_cstr(e, f[11], &j->n2);
  w->data = (char*)j;
  if (j->op > 7) {
    return bsq_refuse(e, j, BSQ_MISUSE, "bendo sqlite: unknown operation");
  }
  if (bsq_load() != 1) {
    return bsq_refuse(e, j, BSQ_CANTOPEN, bsq_load_error);
  }
  if (j->op == 0) {
    if (strlen(j->text1) != j->n1) {
      return bsq_refuse(e, j, BSQ_MISUSE, "bendo sqlite: the path contains a NUL character");
    }
    u32 at = 0;
    while (at < bsq_nconns && bsq_conns[at]->state != BSQ_FREE) {
      at += 1;
    }
    if (at == bsq_nconns) {
      bsq_conns = io_mem(realloc(bsq_conns, (bsq_nconns + 1) * sizeof *bsq_conns));
      BsqConn* fresh = io_mem(calloc(1, sizeof *fresh));
      pthread_mutex_init(&fresh->lock, NULL);
      bsq_conns[at] = fresh;
      bsq_nconns += 1;
    }
    BsqConn* c = bsq_conns[at];
    c->state = BSQ_OPENING;
    c->owner = 0;
    c->pending = 0;
    c->busy_ms = j->limit;
    j->conn = c;
    j->slot = at + 1;
    c->inflight += 1;
    return io_work(w, bsq_call, bsq_pack);
  }
  if (j->slot == 0 || j->slot > bsq_nconns) {
    return bsq_refuse(e, j, BSQ_MISUSE, "bendo sqlite: the connection is closed");
  }
  j->conn = bsq_conns[j->slot - 1];
  if (j->conn->gen != j->gen || j->conn->state != BSQ_OPEN) {
    j->conn = NULL;
    return bsq_refuse(e, j, BSQ_MISUSE, "bendo sqlite: the connection is closed");
  }
  if (j->op == 1) {
    // No new work may start; work already admitted finishes first.
    j->conn->state = BSQ_CLOSING;
  }
  // Work already admitted always finishes, so close, commit and rollback wait
  // for it without a limit: an end that timed out would leave its
  // transaction open and the connection gated.
  j->deadline = j->op == 1 || j->op == 7 ? UINT64_MAX : io_until(j->conn->busy_ms);
  return bsq_try(e, w);
}

static void __attribute__((constructor)) bendo_sqlite_call_use(void) {
  io_eff(CID(sqlite_call), bendo_sqlite_call_run);
}
