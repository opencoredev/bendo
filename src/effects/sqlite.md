# The SQLite effect, outside the proofs

`sqlite.bend`, `sqlite.c` and `sqlite.js` are the trusted shell under
[`src/sqlite.bend`](../sqlite.bend), the module apps import. The laws in
[`proof/sqlite-laws.bend`](../../proof/sqlite-laws.bend) cover the pure parts:
the parameter wire format, the mapping from columns to JSON, and the
transaction gate as a table. Everything on this page is trusted code that the
laws do not reach. [`tests/sqlite.test.ts`](../../tests/sqlite.test.ts) checks
it against a compiled server and compares the native and JS builds line by
line.

## Loading SQLite

The native build loads `libsqlite3.so.0` (then `libsqlite3.so`;
`libsqlite3.dylib` on macOS) with `dlopen` the first time a program opens a
database. Bend links native programs with only `-lpthread -lm` and has no way
to add a library, so linking at build time is not possible; `dlopen` also
means a program that never opens a database needs no SQLite at all, and the
build needs no headers. glibc 2.34 and later (Ubuntu 22.04 and later) have
`dlopen` in libc itself.

The JS build loads the same library through `bun:ffi` and makes the same calls
in the same order. `bun:sqlite` and `node:sqlite` were not used: both run
Bun's bundled SQLite, a different version from the system's, and neither
reports a statement's unused tail or its parameter names, so neither could
refuse a second statement or an unbound named parameter the way the native
build does.

On Ubuntu and Debian the library is the `libsqlite3-0` package. No `-dev`
package is needed. When the library is missing, the first open fails with code
14 and the message `bendo sqlite: libsqlite3 was not found (tried
libsqlite3.so.0, libsqlite3.so); install it, for example with apt-get install
libsqlite3-0`. A library built without thread support, or one older than
SQLite 3.7.14 (no `sqlite3_close_v2`), is refused with its own message.

The vendored amalgamation was considered and rejected: Bend splices an
effect's C file into every program that imports it, so 9 MB of SQLite source
would be compiled by clang on every build of every app that uses the effect.

## What each call does

Every operation runs on one of the runtime's IO helper threads, so a slow
query does not stop the event loop. Each connection has a mutex, held for the
whole operation, so one connection runs one statement at a time.

- `open` calls `sqlite3_open_v2` with `SQLITE_OPEN_FULLMUTEX`, turns on
  extended result codes and sets SQLite's busy timeout. The path is used as
  SQLite reads it: `:memory:` is a private in-memory database and `""` a
  temporary file. A path containing a NUL character is refused.
- `prepare` compiles exactly one statement. An empty statement, or anything
  but whitespace and comments after the first statement, is refused, so a
  second statement is never silently dropped. `exec` is the only call that
  runs several statements, and it takes no parameters.
- `run`, `all` and `get` reset the statement and clear its bindings, bind
  every parameter, step, and reset and clear it again on every path, including
  errors. A one-shot statement is finalized on every path. `get` stops
  stepping after the first row. `all` fails with code 18 (`SQLITE_TOOBIG`)
  past the connection's row cap instead of returning a truncated result.
- A statement's change count is the difference in
  `sqlite3_total_changes64` across it, so it counts rows changed by triggers
  and foreign-key actions and is 0 for a statement that changed nothing; it is
  never the stale count of an earlier statement. The rowid is
  `sqlite3_last_insert_rowid` after the statement, which SQLite does not reset
  for statements that insert nothing.
- `finalize` finalizes one prepared statement; using it afterwards fails.
- `close` waits for the connection's operations already in flight, rolls back
  an open transaction, finalizes every prepared statement and calls
  `sqlite3_close_v2`. Every copy of the connection fails afterwards with code
  21. A connection slot is reused only with a new generation number, so a
  stale handle never reaches another database.

## Bound parameters

Parameters cross from Bend as one string in the wire format of
[`src/data/sqlite.bend`](../data/sqlite.bend), which the laws prove reads back
value by value, with each value's type. The effect binds each value with
`sqlite3_bind_*`; no parameter is ever written into SQL text, so a parameter
cannot change the statement. The checks, identical in both builds:

- Positional parameters (`?` and `?NNN`) must number exactly as many as the
  statement's highest parameter index, and the statement may not contain a
  named parameter.
- Named parameters (`:name`, `@name`, `$name`, written with their prefix) must
  each name a parameter of the statement, at most once, and must bind every
  parameter the statement has.
- An integer must be canonical decimal text (no leading zeros, no `+`, no
  `-0`) in the signed 64-bit range. A real must be a JSON number; `1e999`
  binds as an infinity, as `strtod` reads it. A blob byte must be below 256.
  Text is bound as UTF-8; lone surrogates become U+FFFD on both builds.

## Values read back

| SQLite | `Sqlite.Value` | JSON row |
| --- | --- | --- |
| NULL | `SqlNull{}` | `null` |
| INTEGER | `SqlInteger{text}`, exact decimal, all 64 bits | number with the same digits |
| REAL | `SqlReal{text}`, the shortest decimal that reads back as the same double, in JavaScript's `Number.prototype.toString` form; `-0.0` reads back as `0` | number with the same text, or a `NotJson` failure for an infinity |
| TEXT | `SqlText{value}`, UTF-8 decoded as WHATWG does, invalid bytes as U+FFFD | string |
| BLOB | `SqlBlob{bytes}` | string of standard, padded base64 |

Bend's native `Nat` holds at most 2^48 - 1, so 64-bit integers stay decimal
text. `Sqlite.integer(n)` builds a parameter from a `Nat`; pass larger values
with `Sqlite.integer_text`.

## Transactions and concurrency

A Bendo server runs every request on one event loop in one process, and a
`Db` is copyable data, so many requests share one connection. A transaction
on a shared connection would swallow the other requests' statements, so the
effect gates the connection (the table is `Sqlite.gate`, stated in the laws):

- `begin` waits until no transaction is open and no operation is in flight,
  then opens one and returns a `Db` carrying its token.
- While it is open, statements through other copies of the connection wait,
  polling every millisecond, up to the connection's busy timeout (5 s by
  default), then fail with code 5 (`SQLITE_BUSY`). A statement carrying a
  token that is not the open one's, such as a copy kept after a commit, fails
  with code 21.
- `commit` and `rollback` wait for the transaction's in-flight statements and
  end it. A commit that fails rolls back, so a transaction is always over
  after either call.
- A statement may not begin or end a transaction itself (`BEGIN`, `COMMIT`,
  `ROLLBACK` or a top-level `SAVEPOINT` through `run` or `exec`): the effect
  rolls back what it began and fails with code 21. If SQLite rolls a
  transaction back by itself after an error, the transaction's next statement
  or commit fails with code 516 (`SQLITE_ABORT_ROLLBACK`).
- `Sqlite.transaction` commits when its body returns `Done` and rolls back
  when it returns `Fail`. A Bend handler cannot throw, so those are the only
  ways out. A handler timed out by `IO.within` keeps running (decision 9) and
  still reaches its commit or rollback. A raw `begin` without a matching end
  leaves the connection gated until it closes; prefer the helper.

With workers (`B.workers`, decision 0017), each worker process runs `main` and
opens its own connection. SQLite's file locks then arbitrate between
processes, and SQLite's busy timeout (the same `busy_ms`) makes a writer wait
for another process's lock instead of failing at once. `begin` uses `BEGIN
IMMEDIATE`, which takes the write lock up front, so two processes cannot
deadlock upgrading read locks. For many concurrent writers, put the database
in WAL mode once with `Sqlite.exec(db, "PRAGMA journal_mode=WAL")`. An
in-memory database is private to each worker.

The JS build runs each operation to completion on the loop, so nothing is in
flight between effects there; the gate's waiting and refusals are the same.

## Error codes

Failures are `Sqlite.SqlError{code, message}` with SQLite's extended result
code and message (`2067 UNIQUE constraint failed: users.email`), or one of
the effect's own, which reuse SQLite's codes and start with `bendo sqlite:`
unless noted:

| Code | When |
| --- | --- |
| 5 `SQLITE_BUSY` | A statement waited past the busy timeout for another transaction on the connection |
| 14 `SQLITE_CANTOPEN` | libsqlite3 could not be loaded, or is unusable |
| 18 `SQLITE_TOOBIG` | `all` passed the row cap |
| 20 `SQLITE_MISMATCH` | A parameter value is malformed (messages start `parameter N:`) |
| 21 `SQLITE_MISUSE` | Closed connection, finalized statement, ended transaction, SQL with a NUL, no statement, more than one statement, or a statement that begins or ends a transaction |
| 25 `SQLITE_RANGE` | Parameters do not match the statement (messages name the count or the parameter) |
| 516 `SQLITE_ABORT_ROLLBACK` | SQLite rolled the transaction back by itself |

## Publishing

The effect is part of the BendHub package like every other file in `src/`:
`bun run release --dry-run` stages it and `tests/release.test.ts` publishes
it to a stub hub. The `.c` and `.js` files travel with the `.bend` file that
imports them.
