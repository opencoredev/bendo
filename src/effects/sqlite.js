// Trusted host effect for SQLite, the JS twin of sqlite.c. It loads the same
// libsqlite3 through bun:ffi and makes the same calls in the same order, so
// both builds give the same rows, codes and messages. bun:sqlite and
// node:sqlite were not used: both run Bun's bundled SQLite (a different
// version from the system library), and neither reports a statement's unused
// tail or its parameter names, so neither can refuse a second statement or an
// unbound named parameter as sqlite.c does.
//
// The JS lane runs each operation to completion on the loop, so nothing is
// ever in flight between effects; the transaction gate still makes a
// statement wait while another computation's transaction is open, polling
// every BSQ_POLL_MS up to the connection's busy timeout. As in sqlite.c, a
// transaction-control statement is refused by the connection's authorizer
// when it compiles, and a progress handler interrupts a statement past the
// connection's max_ms. Both are bun:ffi JSCallbacks, which SQLite calls on
// the loop thread inside prepare and step.
const BSQ_BUSY = 5;
const BSQ_INTERRUPT = 9;
const BSQ_CANTOPEN = 14;
const BSQ_TOOBIG = 18;
const BSQ_MISMATCH = 20;
const BSQ_MISUSE = 21;
const BSQ_RANGE = 25;
const BSQ_ROW = 100;
const BSQ_DONE = 101;
const BSQ_ABORT_ROLLBACK = 516;
const BSQ_POLL_MS = 1;
const BSQ_INT_MAX = 2147483647;
const BSQ_AUTH_TRANSACTION = 22;
const BSQ_AUTH_SAVEPOINT = 32;
const BSQ_DENY = 1;
const BSQ_PROGRESS_OPS = 1000;

const BSQ_SYMBOLS = [
  ["sqlite3_open_v2", ["ptr", "ptr", "i32", "ptr"], "i32"],
  ["sqlite3_close_v2", ["ptr"], "i32"],
  ["sqlite3_extended_result_codes", ["ptr", "i32"], "i32"],
  ["sqlite3_busy_timeout", ["ptr", "i32"], "i32"],
  ["sqlite3_errmsg", ["ptr"], "cstring"],
  ["sqlite3_errstr", ["i32"], "cstring"],
  ["sqlite3_extended_errcode", ["ptr"], "i32"],
  ["sqlite3_prepare_v2", ["ptr", "ptr", "i32", "ptr", "ptr"], "i32"],
  ["sqlite3_step", ["ptr"], "i32"],
  ["sqlite3_reset", ["ptr"], "i32"],
  ["sqlite3_clear_bindings", ["ptr"], "i32"],
  ["sqlite3_finalize", ["ptr"], "i32"],
  ["sqlite3_bind_parameter_count", ["ptr"], "i32"],
  ["sqlite3_bind_parameter_name", ["ptr", "i32"], "ptr"],
  ["sqlite3_bind_parameter_index", ["ptr", "ptr"], "i32"],
  ["sqlite3_bind_null", ["ptr", "i32"], "i32"],
  ["sqlite3_bind_int64", ["ptr", "i32", "i64"], "i32"],
  ["sqlite3_bind_double", ["ptr", "i32", "f64"], "i32"],
  // The destructor is SQLITE_TRANSIENT, (void*)-1, passed as an i64.
  ["sqlite3_bind_text", ["ptr", "i32", "ptr", "i32", "i64"], "i32"],
  ["sqlite3_bind_blob", ["ptr", "i32", "ptr", "i32", "i64"], "i32"],
  ["sqlite3_bind_zeroblob", ["ptr", "i32", "i32"], "i32"],
  ["sqlite3_column_count", ["ptr"], "i32"],
  ["sqlite3_column_name", ["ptr", "i32"], "ptr"],
  ["sqlite3_column_type", ["ptr", "i32"], "i32"],
  ["sqlite3_column_int64", ["ptr", "i32"], "i64"],
  ["sqlite3_column_double", ["ptr", "i32"], "f64"],
  ["sqlite3_column_text", ["ptr", "i32"], "ptr"],
  ["sqlite3_column_blob", ["ptr", "i32"], "ptr"],
  ["sqlite3_column_bytes", ["ptr", "i32"], "i32"],
  ["sqlite3_get_autocommit", ["ptr"], "i32"],
  ["sqlite3_total_changes", ["ptr"], "i32"],
  ["sqlite3_last_insert_rowid", ["ptr"], "i64"],
  ["sqlite3_exec", ["ptr", "ptr", "ptr", "ptr", "ptr"], "i32"],
  ["sqlite3_free", ["ptr"], "void"],
  ["sqlite3_threadsafe", [], "i32"],
  ["sqlite3_set_authorizer", ["ptr", "ptr", "ptr"], "i32"],
  ["sqlite3_progress_handler", ["ptr", "i32", "ptr", "ptr"], "void"],
];

function bsq_state() {
  if (globalThis.BENDO_SQLITE === undefined) {
    globalThis.BENDO_SQLITE = { lib: undefined, error: undefined, conns: [] };
  }
  return globalThis.BENDO_SQLITE;
}

function bsq_load(state) {
  if (state.lib !== undefined || state.error !== undefined) {
    return state.lib !== undefined;
  }
  const ffi = require("bun:ffi");
  const mac = process.platform === "darwin";
  const names = mac
    ? ["libsqlite3.dylib", "/usr/lib/libsqlite3.dylib"]
    : ["libsqlite3.so.0", "libsqlite3.so"];
  const tried = mac ? "libsqlite3.dylib" : "libsqlite3.so.0, libsqlite3.so";
  const spec = (name, args, returns) => ({ [name]: { args, returns } });
  let found;
  for (const name of names) {
    try {
      ffi.dlopen(name, spec("sqlite3_libversion", [], "cstring")).close();
      found = name;
      break;
    } catch {}
  }
  if (found === undefined) {
    state.error = `bendo sqlite: libsqlite3 was not found (tried ${tried}); install it, for example with apt-get install libsqlite3-0`;
    return false;
  }
  const all = {};
  for (const [name, args, returns] of BSQ_SYMBOLS) {
    all[name] = { args, returns };
  }
  let s;
  try {
    s = ffi.dlopen(found, all).symbols;
  } catch {
    // Name the first missing function, as sqlite.c does.
    for (const [name, args, returns] of BSQ_SYMBOLS) {
      try {
        ffi.dlopen(found, spec(name, args, returns)).close();
      } catch {
        // Every SQLite since 3.0 has the authorizer unless built without it.
        state.error =
          name === "sqlite3_set_authorizer"
            ? "bendo sqlite: libsqlite3 was built without the authorizer (SQLITE_OMIT_AUTHORIZATION)"
            : `bendo sqlite: libsqlite3 lacks ${name}; it is too old`;
        return false;
      }
    }
    throw new Error("bendo sqlite: bun:ffi could not load libsqlite3");
  }
  let total64;
  try {
    total64 = ffi.dlopen(found, spec("sqlite3_total_changes64", ["ptr"], "i64")).symbols
      .sqlite3_total_changes64;
  } catch {}
  if (s.sqlite3_threadsafe() === 0) {
    state.error = "bendo sqlite: libsqlite3 was built without thread support";
    return false;
  }
  // One authorizer and one progress handler serve every connection; the
  // user-data pointer SQLite passes back is the connection's slot.
  const conn_of = (slot) => state.conns[Number(slot) - 1];
  const authorize = new ffi.JSCallback(
    (slot, action) => {
      const conn = conn_of(slot);
      if (conn.guard && (action === BSQ_AUTH_TRANSACTION || action === BSQ_AUTH_SAVEPOINT)) {
        conn.refused = true;
        return BSQ_DENY;
      }
      return 0;
    },
    { args: ["ptr", "i32", "ptr", "ptr", "ptr", "ptr"], returns: "i32" },
  );
  const progress = new ffi.JSCallback(
    (slot) => {
      const conn = conn_of(slot);
      if (conn.stop !== 0 && performance.now() >= conn.stop) {
        conn.expired = true;
        return 1;
      }
      return 0;
    },
    { args: ["ptr"], returns: "i32" },
  );
  state.lib = {
    s,
    ffi,
    total64,
    authorize,
    progress,
    decoder: new TextDecoder("utf-8", { ignoreBOM: true }),
  };
  return true;
}

function bsq_failure(code, message) {
  return { $: CID(Fail), error: { $: CID(Tuple), fst: code >>> 0, snd: message } };
}

function bsq_list(xs) {
  let list = { $: CID(Nil) };
  for (let i = xs.length; i > 0; i -= 1) {
    list = { $: CID(Con), head: xs[i - 1], tail: list };
  }
  return list;
}

function bsq_text(lib, p) {
  return p === null || p === 0 ? null : String(new lib.ffi.CString(p));
}

function bsq_bytes(lib, p, n) {
  if (p === null || p === 0 || n === 0) {
    return new Uint8Array(0);
  }
  return new Uint8Array(lib.ffi.toArrayBuffer(p, 0, n)).slice();
}

// A NUL-terminated UTF-8 copy; lone surrogates become U+FFFD, as io_cstr
// writes them.
function bsq_cbuf(text) {
  return Buffer.from(text + "\0", "utf8");
}

// String(x) is the format sqlite.c's bsq_real writes, which also drops the
// sign of zero.
function bsq_real(x) {
  return Object.is(x, -0) ? "0" : String(x);
}

const BSQ_INT = /^-?(0|[1-9][0-9]*)$/;
const BSQ_NUMBER = /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/;

class BsqError {
  constructor(code, message) {
    this.code = code;
    this.message = message;
  }
}

function bsq_db_error(lib, db) {
  return new BsqError(lib.s.sqlite3_extended_errcode(db), String(lib.s.sqlite3_errmsg(db)));
}

// One payload: characters up to an unescaped ';'. Returns [text, next], or
// undefined when the payload has no end.
function bsq_payload(s, i) {
  let out = "";
  while (i < s.length) {
    let c = s[i++];
    if (c === ";") {
      return [out, i];
    }
    if (c === "\\") {
      if (i === s.length) {
        return undefined;
      }
      c = s[i++];
    }
    out += c;
  }
  return undefined;
}

function bsq_skip(s, i) {
  if (i >= s.length) {
    return 0;
  }
  if (s[i++] === "n") {
    return i;
  }
  const p = bsq_payload(s, i);
  return p === undefined ? 0 : p[1];
}

function bsq_named(name) {
  return name !== null && (name[0] === ":" || name[0] === "@" || name[0] === "$");
}

function bsq_check(lib, rc) {
  if (rc !== 0) {
    throw new BsqError(rc, String(lib.s.sqlite3_errstr(rc)));
  }
}

function bsq_bind_one(lib, st, at, tag, p) {
  const s = lib.s;
  switch (tag) {
    case "n":
      return bsq_check(lib, s.sqlite3_bind_null(st, at));
    case "i": {
      const v = BSQ_INT.test(p) && p !== "-0" ? BigInt(p) : undefined;
      if (v === undefined || v > 9223372036854775807n || v < -9223372036854775808n) {
        throw new BsqError(
          BSQ_MISMATCH,
          `parameter ${at}: an integer must be canonical decimal text in the signed 64-bit range`,
        );
      }
      return bsq_check(lib, s.sqlite3_bind_int64(st, at, v));
    }
    case "r":
      if (!BSQ_NUMBER.test(p)) {
        throw new BsqError(BSQ_MISMATCH, `parameter ${at}: a real must be a JSON number`);
      }
      return bsq_check(lib, s.sqlite3_bind_double(st, at, Number(p)));
    case "t": {
      const b = new TextEncoder().encode(p);
      if (b.length > BSQ_INT_MAX) {
        throw new BsqError(BSQ_TOOBIG, "string or blob too big");
      }
      // An empty buffer has no address, and NULL would bind NULL.
      const buf = b.length === 0 ? new Uint8Array(1) : b;
      return bsq_check(lib, s.sqlite3_bind_text(st, at, buf, b.length, -1n));
    }
    case "b": {
      // The payload is a string of code points, as the C side decodes them.
      const points = Array.from(p, (ch) => ch.codePointAt(0));
      const b = new Uint8Array(points.length);
      for (let i = 0; i < points.length; i += 1) {
        if (points[i] > 255) {
          throw new BsqError(BSQ_MISMATCH, `parameter ${at}: a blob byte must be below 256`);
        }
        b[i] = points[i];
      }
      if (b.length > BSQ_INT_MAX) {
        throw new BsqError(BSQ_TOOBIG, "string or blob too big");
      }
      return bsq_check(
        lib,
        b.length === 0
          ? s.sqlite3_bind_zeroblob(st, at, 0)
          : s.sqlite3_bind_blob(st, at, b, b.length, -1n),
      );
    }
    default:
      throw new BsqError(BSQ_MISUSE, "bendo sqlite: malformed parameters");
  }
}

function bsq_bind(lib, st, wire) {
  const s = lib.s;
  const count = s.sqlite3_bind_parameter_count(st);
  if (wire.length === 0 || (wire[0] !== "P" && wire[0] !== "N")) {
    throw new BsqError(BSQ_MISUSE, "bendo sqlite: malformed parameters");
  }
  const named = wire[0] === "N";
  if (!named) {
    let given = 0;
    for (let i = 1; i < wire.length; given += 1) {
      i = bsq_skip(wire, i);
      if (i === 0) {
        throw new BsqError(BSQ_MISUSE, "bendo sqlite: malformed parameters");
      }
    }
    if (given !== count) {
      throw new BsqError(BSQ_RANGE, `${given} parameters given, the statement has ${count}`);
    }
    for (let k = 1; k <= count; k += 1) {
      const name = bsq_text(lib, s.sqlite3_bind_parameter_name(st, k));
      if (bsq_named(name)) {
        throw new BsqError(
          BSQ_RANGE,
          `parameter ${k} is named ${name.slice(0, 150)}; bind named parameters with Sql.named`,
        );
      }
    }
  }
  const bound = new Uint8Array(count + 1);
  let at = 0;
  let i = 1;
  while (i < wire.length) {
    if (named) {
      const p = bsq_payload(wire, i);
      if (p === undefined || p[1] >= wire.length) {
        throw new BsqError(BSQ_MISUSE, "bendo sqlite: malformed parameters");
      }
      // sqlite.c reads the name as a C string, so a NUL ends it.
      const name = p[0].split("\0")[0];
      at = s.sqlite3_bind_parameter_index(st, bsq_cbuf(name));
      if (at === 0) {
        throw new BsqError(BSQ_RANGE, `no parameter named ${name.slice(0, 200)}`);
      }
      if (bound[at]) {
        throw new BsqError(BSQ_RANGE, `parameter ${name.slice(0, 200)} is bound twice`);
      }
      i = p[1];
    } else {
      at += 1;
    }
    const tag = wire[i++];
    if (tag === "n") {
      bsq_bind_one(lib, st, at, tag, "");
    } else {
      const p = bsq_payload(wire, i);
      if (p === undefined) {
        throw new BsqError(BSQ_MISUSE, "bendo sqlite: malformed parameters");
      }
      i = p[1];
      bsq_bind_one(lib, st, at, tag, p[0]);
    }
    bound[at] = 1;
  }
  for (let k = 1; named && k <= count; k += 1) {
    if (!bound[k]) {
      const name = bsq_text(lib, s.sqlite3_bind_parameter_name(st, k));
      throw new BsqError(
        BSQ_RANGE,
        name !== null
          ? `parameter ${name.slice(0, 200)} is not bound`
          : `parameter ${k} has no name; bind it with Sql.positional`,
      );
    }
  }
}

const BSQ_CONTROL_MSG =
  "bendo sqlite: a statement may not begin or end a transaction or savepoint; " +
  "use Sql.begin, Sql.commit and Sql.rollback";

// Compiles the caller's SQL with the authorizer's guard up, as sqlite.c's
// bsq_compile; returns the error to throw, if any.
function bsq_compile(lib, conn, sql, n, out, tail) {
  conn.guard = true;
  conn.refused = false;
  const rc = lib.s.sqlite3_prepare_v2(conn.db, sql, n, out, tail);
  conn.guard = false;
  if (rc === 0) {
    return undefined;
  }
  return conn.refused ? new BsqError(BSQ_MISUSE, BSQ_CONTROL_MSG) : bsq_db_error(lib, conn.db);
}

// Starts and stops the deadline of a statement's steps, as sqlite.c's
// bsq_clock_start and bsq_clock_stop.
function bsq_clock_start(conn) {
  conn.expired = false;
  conn.stop = conn.max_ms === 0 ? 0 : performance.now() + conn.max_ms;
}

function bsq_clock_stop(conn) {
  conn.stop = 0;
}

// A failed step, as sqlite.c's bsq_fail_step.
function bsq_step_error(lib, conn) {
  if (conn.expired && lib.s.sqlite3_extended_errcode(conn.db) === BSQ_INTERRUPT) {
    return new BsqError(
      BSQ_INTERRUPT,
      `bendo sqlite: the statement ran longer than ${conn.max_ms} ms`,
    );
  }
  return bsq_db_error(lib, conn.db);
}

// Exactly one statement, as sqlite.c's bsq_prepare_one.
function bsq_prepare_one(lib, conn, sql) {
  const s = lib.s;
  if (sql.includes("\0")) {
    throw new BsqError(BSQ_MISUSE, "bendo sqlite: SQL contains a NUL character");
  }
  const buf = bsq_cbuf(sql);
  const n = buf.length - 1;
  if (n > BSQ_INT_MAX) {
    throw new BsqError(BSQ_TOOBIG, "string or blob too big");
  }
  const base = lib.ffi.ptr(buf);
  const out = new BigUint64Array(1);
  const tail = new BigUint64Array(1);
  const failed = bsq_compile(lib, conn, base, n, out, tail);
  if (failed !== undefined) {
    throw failed;
  }
  const st = Number(out[0]);
  if (st === 0) {
    throw new BsqError(BSQ_MISUSE, "bendo sqlite: no SQL statement");
  }
  const used = Number(tail[0]) - base;
  const more = new BigUint64Array(1);
  const rest = bsq_compile(lib, conn, base + used, n - used, more, tail);
  if (rest !== undefined || more[0] !== 0n) {
    if (more[0] !== 0n) {
      s.sqlite3_finalize(Number(more[0]));
    }
    s.sqlite3_finalize(st);
    throw new BsqError(
      BSQ_MISUSE,
      "bendo sqlite: one statement per call; run scripts with Sql.exec",
    );
  }
  return st;
}

function bsq_total(lib, db) {
  return lib.total64 !== undefined
    ? BigInt(lib.total64(db))
    : BigInt(lib.s.sqlite3_total_changes(db));
}

// Counts n more bytes of the result against its budgets, as sqlite.c's
// bsq_budget; a text or blob cell also counts against the per-cell one.
function bsq_budget(j, n, cell) {
  if (cell && n > j.max_cell) {
    throw new BsqError(
      BSQ_TOOBIG,
      `bendo sqlite: a column value is larger than ${j.max_cell} bytes`,
    );
  }
  if (n > j.max_bytes - j.bytes) {
    throw new BsqError(BSQ_TOOBIG, `bendo sqlite: the result is larger than ${j.max_bytes} bytes`);
  }
  j.bytes += n;
}

function bsq_cell(lib, st, c, j) {
  const s = lib.s;
  switch (s.sqlite3_column_type(st, c)) {
    case 1: {
      const text = BigInt(s.sqlite3_column_int64(st, c)).toString();
      bsq_budget(j, text.length, false);
      return { $: CID(CellInteger), text };
    }
    case 2: {
      const text = bsq_real(s.sqlite3_column_double(st, c));
      bsq_budget(j, text.length, false);
      return { $: CID(CellReal), text };
    }
    case 3: {
      const p = s.sqlite3_column_text(st, c);
      const n = s.sqlite3_column_bytes(st, c);
      bsq_budget(j, p === null || p === 0 ? 0 : n, true);
      return { $: CID(CellText), value: lib.decoder.decode(bsq_bytes(lib, p, n)) };
    }
    case 4: {
      const p = s.sqlite3_column_blob(st, c);
      const n = s.sqlite3_column_bytes(st, c);
      bsq_budget(j, p === null || p === 0 ? 0 : n, true);
      return { $: CID(CellBlob), bytes: bsq_list(Array.from(bsq_bytes(lib, p, n))) };
    }
    default:
      return { $: CID(CellNull) };
  }
}

const BSQ_ROLLED_BACK =
  "bendo sqlite: the transaction was rolled back; roll it back and start again";

function bsq_before(lib, db, token) {
  if (token !== 0 && lib.s.sqlite3_get_autocommit(db) !== 0) {
    throw new BsqError(BSQ_ABORT_ROLLBACK, BSQ_ROLLED_BACK);
  }
}

// After a statement, as sqlite.c's bsq_after; failure is the first error.
function bsq_after(lib, db, token, failure) {
  const autocommit = lib.s.sqlite3_get_autocommit(db) !== 0;
  if (token === 0 && !autocommit) {
    bsq_exec_plain(lib, db, "ROLLBACK");
    return new BsqError(
      BSQ_MISUSE,
      "bendo sqlite: a statement may not begin a transaction; use Sql.begin",
    );
  }
  if (token !== 0 && autocommit && failure === undefined) {
    return new BsqError(
      BSQ_MISUSE,
      "bendo sqlite: a statement may not end a transaction; use Sql.commit or Sql.rollback",
    );
  }
  return failure;
}

function bsq_exec_plain(lib, db, sql) {
  return lib.s.sqlite3_exec(db, bsq_cbuf(sql), null, null, null);
}

function bsq_query(lib, conn, j) {
  const s = lib.s;
  const db = conn.db;
  bsq_before(lib, db, j.token);
  const own = j.index === 0;
  let st;
  if (own) {
    st = bsq_prepare_one(lib, conn, j.text1);
  } else {
    const rec = conn.stmts[j.index - 1];
    if (rec === undefined || rec.stmt === 0 || rec.gen !== j.sgen) {
      throw new BsqError(
        BSQ_MISUSE,
        "bendo sqlite: the statement is finalized or belongs to another connection",
      );
    }
    st = rec.stmt;
    s.sqlite3_reset(st);
    s.sqlite3_clear_bindings(st);
  }
  let failure;
  const columns = [];
  const rows = [];
  let changes = 0n;
  let rowid = 0n;
  try {
    bsq_bind(lib, st, j.text2);
    let ncols = 0;
    const before = bsq_total(lib, db);
    bsq_clock_start(conn);
    for (let first = true; ; first = false) {
      const rc = s.sqlite3_step(st);
      // After the first step: a step can recompile the statement after a
      // schema change, and change its columns.
      if (first && j.mode !== 0 && (rc === BSQ_ROW || rc === BSQ_DONE)) {
        ncols = s.sqlite3_column_count(st);
        for (let k = 0; k < ncols; k += 1) {
          columns.push(bsq_text(lib, s.sqlite3_column_name(st, k)) ?? "");
        }
      }
      if (rc === BSQ_ROW) {
        if (j.mode === 0) {
          continue;
        }
        if (j.mode === 1 && rows.length >= j.limit) {
          failure = new BsqError(
            BSQ_TOOBIG,
            `bendo sqlite: the query returned more than ${j.limit} rows`,
          );
          break;
        }
        const row = [];
        for (let k = 0; k < ncols; k += 1) {
          row.push(bsq_cell(lib, st, k, j));
        }
        rows.push(bsq_list(row));
        if (j.mode === 2) {
          break;
        }
      } else if (rc === BSQ_DONE) {
        break;
      } else {
        failure = bsq_step_error(lib, conn);
        break;
      }
    }
    changes = bsq_total(lib, db) - before;
    rowid = BigInt(s.sqlite3_last_insert_rowid(db));
  } catch (e) {
    if (!(e instanceof BsqError)) {
      throw e;
    }
    failure = e;
  }
  bsq_clock_stop(conn);
  if (own) {
    s.sqlite3_finalize(st);
  } else {
    s.sqlite3_reset(st);
    s.sqlite3_clear_bindings(st);
  }
  failure = bsq_after(lib, db, j.token, failure);
  if (failure !== undefined) {
    throw failure;
  }
  const count = changes < 0n ? 0 : changes > 0xffffffffffffn ? 0xffffffffffff : Number(changes);
  return {
    $: CID(Ran),
    columns: bsq_list(columns),
    rows: bsq_list(rows),
    changes: count,
    rowid: rowid.toString(),
  };
}

// A script, one statement at a time, as sqlite.c's bsq_exec.
function bsq_exec(lib, conn, j) {
  const s = lib.s;
  const db = conn.db;
  if (j.text1.includes("\0")) {
    throw new BsqError(BSQ_MISUSE, "bendo sqlite: SQL contains a NUL character");
  }
  const buf = bsq_cbuf(j.text1);
  const n = buf.length - 1;
  if (n > BSQ_INT_MAX) {
    throw new BsqError(BSQ_TOOBIG, "string or blob too big");
  }
  bsq_before(lib, db, j.token);
  const autocommit = s.sqlite3_get_autocommit(db);
  const base = lib.ffi.ptr(buf);
  const out = new BigUint64Array(1);
  const tail = new BigUint64Array(1);
  let failure;
  let at = 0;
  while (failure === undefined && at < n) {
    out[0] = 0n;
    tail[0] = 0n;
    failure = bsq_compile(lib, conn, base + at, n - at, out, tail);
    if (failure !== undefined) {
      break;
    }
    const st = Number(out[0]);
    const next = tail[0] === 0n ? at : Number(tail[0]) - base;
    if (st === 0) {
      // Whitespace, a comment or a lone ';'.
      if (next <= at) {
        break;
      }
      at = next;
      continue;
    }
    bsq_clock_start(conn);
    let rc = s.sqlite3_step(st);
    while (rc === BSQ_ROW) {
      rc = s.sqlite3_step(st);
    }
    bsq_clock_stop(conn);
    if (rc !== BSQ_DONE) {
      failure = bsq_step_error(lib, conn);
    }
    s.sqlite3_finalize(st);
    if (s.sqlite3_get_autocommit(db) !== autocommit) {
      break;
    }
    at = next;
  }
  failure = bsq_after(lib, db, j.token, failure);
  if (failure !== undefined) {
    throw failure;
  }
  return { $: CID(Finished) };
}

// Runs an admitted operation, as sqlite.c's bsq_call.
function bsq_call(lib, conn, j) {
  const s = lib.s;
  switch (j.op) {
    case 0: {
      const out = new BigUint64Array(1);
      const flags = (j.mode === 2 ? 0x1 : j.mode === 1 ? 0x2 : 0x2 | 0x4) | 0x10000;
      const rc = s.sqlite3_open_v2(bsq_cbuf(j.text1), out, flags, null);
      const db = Number(out[0]);
      if (rc !== 0) {
        if (db !== 0) {
          const e = bsq_db_error(lib, db);
          s.sqlite3_close_v2(db);
          throw e;
        }
        throw new BsqError(rc, String(s.sqlite3_errstr(rc)));
      }
      s.sqlite3_extended_result_codes(db, 1);
      s.sqlite3_busy_timeout(db, Math.min(j.limit, BSQ_INT_MAX));
      conn.max_ms = j.max_bytes;
      conn.guard = false;
      conn.stop = 0;
      s.sqlite3_set_authorizer(db, lib.authorize.ptr, j.slot);
      s.sqlite3_progress_handler(db, BSQ_PROGRESS_OPS, lib.progress.ptr, j.slot);
      conn.db = db;
      conn.state = "open";
      return { $: CID(Handle), first: j.slot, second: conn.gen };
    }
    case 1: {
      let failure;
      if (s.sqlite3_get_autocommit(conn.db) === 0) {
        bsq_exec_plain(lib, conn.db, "ROLLBACK");
      }
      for (const rec of conn.stmts) {
        if (rec.stmt !== 0) {
          s.sqlite3_finalize(rec.stmt);
        }
      }
      conn.stmts = [];
      if (s.sqlite3_close_v2(conn.db) !== 0) {
        failure = bsq_db_error(lib, conn.db);
      }
      conn.db = 0;
      if (failure !== undefined) {
        throw failure;
      }
      return { $: CID(Finished) };
    }
    case 2: {
      const st = bsq_prepare_one(lib, conn, j.text1);
      let at = conn.stmts.findIndex((rec) => rec.stmt === 0);
      if (at < 0) {
        at = conn.stmts.length;
        conn.stmts.push({ stmt: 0, gen: 0 });
      }
      const rec = conn.stmts[at];
      rec.stmt = st;
      rec.gen = (rec.gen + 1) >>> 0;
      return { $: CID(Handle), first: at + 1, second: rec.gen };
    }
    case 3: {
      const rec = j.index === 0 ? undefined : conn.stmts[j.index - 1];
      if (rec === undefined || rec.stmt === 0 || rec.gen !== j.sgen) {
        throw new BsqError(
          BSQ_MISUSE,
          "bendo sqlite: the statement is finalized or belongs to another connection",
        );
      }
      s.sqlite3_finalize(rec.stmt);
      rec.stmt = 0;
      return { $: CID(Finished) };
    }
    case 4:
      return bsq_query(lib, conn, j);
    case 5:
      return bsq_exec(lib, conn, j);
    case 6: {
      const sql =
        j.mode === 2 ? "BEGIN EXCLUSIVE" : j.mode === 1 ? "BEGIN IMMEDIATE" : "BEGIN DEFERRED";
      if (bsq_exec_plain(lib, conn.db, sql) !== 0) {
        throw bsq_db_error(lib, conn.db);
      }
      return { $: CID(Handle), first: j.token, second: 0 };
    }
    default: {
      const db = conn.db;
      if (j.mode === 1) {
        if (s.sqlite3_get_autocommit(db) !== 0) {
          throw new BsqError(BSQ_ABORT_ROLLBACK, BSQ_ROLLED_BACK);
        }
        if (bsq_exec_plain(lib, db, "COMMIT") !== 0) {
          const e = bsq_db_error(lib, db);
          if (s.sqlite3_get_autocommit(db) === 0) {
            bsq_exec_plain(lib, db, "ROLLBACK");
          }
          throw e;
        }
      } else if (s.sqlite3_get_autocommit(db) === 0 && bsq_exec_plain(lib, db, "ROLLBACK") !== 0) {
        throw bsq_db_error(lib, db);
      }
      return { $: CID(Finished) };
    }
  }
}

// The gate, as sqlite.c's bsq_gate. Nothing is in flight between effects
// here, so the in-flight count is always 0.
function bsq_gate(conn, j) {
  switch (j.op) {
    case 4:
    case 5:
      if (j.token === 0) {
        return conn.owner === 0 && conn.pending === 0 ? "go" : "hold";
      }
      return conn.owner === j.token ? "go" : "no";
    case 6:
      return conn.owner === 0 ? "go" : "hold";
    case 7:
      return j.token !== 0 && conn.owner === j.token ? "go" : "no";
    default:
      return "go";
  }
}

// Runs an admitted operation and settles the connection, as sqlite.c's
// bsq_pack.
function bsq_finish(state, conn, j) {
  let reply;
  let failure;
  try {
    reply = bsq_call(state.lib, conn, j);
  } catch (e) {
    if (!(e instanceof BsqError)) {
      throw e;
    }
    failure = e;
  }
  if (j.op === 0 && failure !== undefined) {
    conn.state = "free";
    conn.gen = (conn.gen + 1) >>> 0;
  } else if (j.op === 1) {
    conn.state = "free";
    conn.gen = (conn.gen + 1) >>> 0;
    conn.owner = 0;
  } else if ((j.op === 6 && failure !== undefined) || j.op === 7) {
    conn.owner = 0;
  }
  return failure !== undefined
    ? bsq_failure(failure.code, failure.message)
    : { $: CID(Done), value: reply };
}

function bsq_refuse(conn, j, code, message) {
  // A begin counted on a connection that has since closed counts nowhere:
  // open zeroes the count of the connection that reuses the slot.
  if (j.counted && conn.gen === j.gen) {
    conn.pending -= 1;
    j.counted = false;
  }
  return bsq_failure(code, message);
}

function bsq_try(state, j, k) {
  const conn = state.conns[j.slot - 1];
  if (conn.gen !== j.gen || conn.state !== "open") {
    return bsq_refuse(conn, j, BSQ_MISUSE, "bendo sqlite: the connection is closed");
  }
  const verdict = bsq_gate(conn, j);
  if (verdict === "no") {
    return bsq_refuse(conn, j, BSQ_MISUSE, "bendo sqlite: no open transaction for this handle");
  }
  if (verdict === "hold") {
    const now = performance.now();
    if (now >= j.deadline || typeof io_park_on !== "function") {
      return bsq_refuse(
        conn,
        j,
        BSQ_BUSY,
        "bendo sqlite: the connection is busy with another transaction",
      );
    }
    if (j.op === 6 && !j.counted) {
      j.counted = true;
      conn.pending += 1;
    }
    // A woken wait is dropped; more parks again itself when still held.
    io_park_on(
      undefined,
      false,
      k,
      () => bsq_try(state, j, k),
      Math.min(now + BSQ_POLL_MS, j.deadline),
    );
    return undefined;
  }
  if (j.counted) {
    j.counted = false;
    conn.pending -= 1;
  }
  if (j.op === 6) {
    conn.next_token = conn.next_token === 0xffffffff ? 1 : conn.next_token + 1;
    conn.owner = conn.next_token;
    j.token = conn.owner;
  }
  return bsq_finish(state, conn, j);
}

function bendo_sqlite_call(
  op,
  slot,
  gen,
  token,
  index,
  sgen,
  mode,
  limit,
  max_bytes,
  max_cell,
  text1,
  text2,
  k,
) {
  const state = bsq_state();
  const j = {
    op,
    slot,
    gen,
    token,
    index,
    sgen,
    mode,
    limit,
    max_bytes,
    max_cell,
    bytes: 0,
    text1,
    text2,
    counted: false,
    deadline: 0,
  };
  if (op > 7) {
    return bsq_failure(BSQ_MISUSE, "bendo sqlite: unknown operation");
  }
  if (!bsq_load(state)) {
    return bsq_failure(BSQ_CANTOPEN, state.error);
  }
  if (op === 0) {
    if (text1.includes("\0")) {
      return bsq_failure(BSQ_MISUSE, "bendo sqlite: the path contains a NUL character");
    }
    let at = state.conns.findIndex((c) => c.state === "free");
    if (at < 0) {
      at = state.conns.length;
      state.conns.push({
        gen: 0,
        state: "free",
        owner: 0,
        next_token: 0,
        pending: 0,
        busy_ms: 0,
        db: 0,
        stmts: [],
        max_ms: 0,
        guard: false,
        refused: false,
        expired: false,
        stop: 0,
      });
    }
    const conn = state.conns[at];
    conn.state = "opening";
    conn.owner = 0;
    conn.pending = 0;
    conn.busy_ms = limit;
    j.slot = at + 1;
    return bsq_finish(state, conn, j);
  }
  const conn = slot === 0 ? undefined : state.conns[slot - 1];
  if (conn === undefined || conn.gen !== gen || conn.state !== "open") {
    return bsq_failure(BSQ_MISUSE, "bendo sqlite: the connection is closed");
  }
  // Close, commit and rollback never time out, as in sqlite.c.
  j.deadline = op === 1 || op === 7 ? Infinity : performance.now() + conn.busy_ms;
  return bsq_try(state, j, k);
}

io_eff(CID(sqlite_call), bendo_sqlite_call);
