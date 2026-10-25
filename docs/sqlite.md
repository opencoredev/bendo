# SQLite

`bendo/sqlite.bend` gives a Bendo app a SQLite database: open a connection,
run statements with bound parameters, read rows as JSON or through a schema,
and group statements in transactions. It is opt-in. An app that does not
import it compiles and links exactly as before, and only a program that opens
a database loads SQLite. The complete compiled example is
[`tests/servers/sqlite.bend`](../tests/servers/sqlite.bend), a CRUD server
over HTTP.

The machine that runs the app needs SQLite's shared library. On Ubuntu and
Debian that is the `libsqlite3-0` package, already present on most systems;
no `-dev` package is needed to build. The native and JavaScript builds load
the same library and behave the same way.
[What the effect does outside the proofs](../src/effects/sqlite.md) has the
details, including every error code.

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/sqlite.bend as Sql
```

## Open a database at startup

Open the connection in `main`, before serving, and keep it in your app's
`env`. A `Sql.Db` is copyable data: every request gets a copy that names the
same connection.

```bend
type Env is Data:
  Env{db: Sql.Db}

def opened(r: Result<&2, &2, Sql.Error, Sql.Db>) -> IO(Unit):
  match r:
    case Fail{e}: IO.die(Unit, 1, Sql.message(e))
    case Done{+db}:
      do IO<Unit>:
        s : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(db, "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE)")
        serve_with(db, s)
```

`Sql.open(path)` opens or creates a file; `":memory:"` is a private in-memory
database. `Sql.open_with(path, options)` sets the mode, the busy timeout,
the result caps and the statement deadline:

| `Sql.Options` field | `Sql.options()` | Meaning |
| --- | --- | --- |
| `mode` | `Sql.ReadWriteCreate{}` | Or `Sql.ReadWrite{}` (the file must exist) or `Sql.ReadOnly{}`. |
| `busy_ms` | 5000 | How long a statement waits for a lock held by another transaction or process before failing with code 5. |
| `max_rows` | 100000 | The most rows `Sql.all` returns; one more fails with code 18 instead of truncating. |
| `max_bytes` | 67108864 (64 MiB) | The most bytes of cell data one result of `Sql.all` or `Sql.get` holds: text and blob bytes and the digits of numbers. More fails with code 18. |
| `max_cell` | 16777216 (16 MiB) | The most bytes of one text or blob value in such a result. More fails with code 18. |
| `max_ms` | 30000 | The most milliseconds one statement may run. A statement still running then is interrupted and fails with code 9. 0 turns the bound off. |

The caps bound what one call copies out of SQLite. Bend holds a string as a
list of characters, so a result takes many times its byte size in memory;
lower the caps for an app whose rows are large or whose memory is small.
`max_ms` bounds what the caps cannot: a statement that runs a long time
before returning a row, or that returns none, such as an unbounded recursive
query.

`Sql.exec(db, script)` runs several statements with no parameters, such as a
schema, one after another. Everything else runs one statement per call. `Sql.close(db)` rolls
back an open transaction, finalizes the connection's prepared statements and
closes it; every copy of the `Db` fails afterwards.

## Run statements with bound parameters

`Sql.run(db, sql, params)` runs one statement and returns `Sql.Changes`: the
rows it inserted, updated or deleted, and the last insert rowid.
`Sql.all` returns every row, and `Sql.get` the first row, if any.

```bend
def create(+db: Sql.Db, name: String, email: String) -> IO(Result<&2, &2, Sql.Error, Sql.Changes>):
  Sql.run(db, "INSERT INTO users (name, email) VALUES (?, ?)", Sql.positional([Sql.text(name), Sql.text(email)]))

def rename(+db: Sql.Db, id: String, name: String) -> IO(Result<&2, &2, Sql.Error, Sql.Changes>):
  Sql.run(db, "UPDATE users SET name = :name WHERE id = :id", Sql.named([Sql.bind(":name", Sql.text(name)), Sql.bind(":id", Sql.integer_text(id))]))
```

Parameters are always bound, never pasted into the SQL, so a value such as
`'; DROP TABLE users; --` is stored and compared as plain text. There is no
helper that builds SQL from strings. Bind with `Sql.positional` for `?` and
`?NNN`, or with `Sql.named` and `Sql.bind(":name", value)` (a `Sql.Binding`)
for `:name`, `@name` and `$name`; both build a `Sql.Params`. Every parameter must be bound exactly once: a missing,
extra or unknown parameter fails with code 25 instead of binding NULL.
`Sql.none()` binds nothing.

Each parameter is a `Sql.Value`:

| Value | Binds |
| --- | --- |
| `Sql.null()` | NULL |
| `Sql.integer(n)` | a `Nat` as an INTEGER |
| `Sql.integer_text(t)` | a signed 64-bit integer written in decimal, such as a path capture |
| `Sql.real(t)` | a REAL written as a JSON number |
| `Sql.text(s)` | TEXT |
| `Sql.blob(bytes)` | a BLOB, one byte per list element |

A malformed value, such as `Sql.integer_text("1 OR 1=1")`, fails with code 20
before the statement runs.

## Read rows

`Sql.all` returns `Sql.Rows`: the column names, each row's values and the
statement's `Sql.Changes`. `Sql.get` returns one `Sql.Row`.
`Sql.rows_json(rows)` turns each row into a JSON object keyed by column name,
and `Sql.row_json(row)` does it for one row. NULL becomes `null`, integers
and reals become numbers with every digit (64-bit integers included), text
becomes a string and a blob a base64 string. A real with no JSON form, an
infinity, fails with `Sql.NotJson{row, column}`.

```bend
def listed(+c: B.Ctx, r: Result<&2, &2, Sql.Error, Sql.Rows>) -> B.Res:
  match r:
    case Fail{e}: B.text(B.status(c, 500), Sql.message(e))
    case Done{rows}: json_list(c, Sql.rows_json(rows))
```

`Sql.decode_rows(schema, rows)` and `Sql.decode_row(schema, row)` decode rows
through a schema, the same decoder that validates request bodies. A row that
does not match fails with `Sql.RowError{row, errors}`, which names the row and
carries the schema errors.

```bend
def read_user(+c: B.Ctx, r: Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>>) -> B.Res:
  match r:
    case Fail{e}: B.text(B.status(c, 500), Sql.message(e))
    case Done{None{}}: B.text(B.status(c, 404), "no such user")
    case Done{Some{row}}: decoded_user(c, Sql.decode_row(user_schema(), row))
```

## Prepare a statement once

`Sql.prepare(db, sql)` compiles a statement for reuse; `Sql.run_stmt`,
`Sql.all_stmt` and `Sql.get_stmt` run it with new parameters, and
`Sql.finalize` releases it. Prepare at startup and keep the `Sql.Stmt` in
`env` next to the connection. Closing the connection finalizes every
statement prepared on it.

## Transactions

`Sql.transaction(A, db, body)` begins a transaction, runs `body` with a `Db`
that runs statements inside it, and commits when `body` returns `Done`. When
`body` returns `Fail` it rolls back and returns that error. Return
`Fail{Sql.abort("reason")}` to roll back for your own reasons.

```bend
def debit_credit(+from: String, +to: String, +amount: String, +tx: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Unit>):
  do IO<Result<&2, &2, Sql.Error, Unit>>:
    d : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "UPDATE accounts SET balance = balance - ? WHERE name = ?", Sql.positional([Sql.integer_text(amount), Sql.text(from)]))
    after_debit(to, amount, tx, d)

# In a handler:
#   r <- Sql.transaction(Unit, db, tx => debit_credit(from, to, amount, tx))
```

Statements through other copies of the connection, from other requests, wait
until the transaction ends, so they never run inside it by accident. They
fail with code 5 if it stays open past the busy timeout. `Sql.begin`,
`Sql.commit` and `Sql.rollback` are the manual form. `Sql.commit` and
`Sql.rollback` always end the transaction, whatever they return: each waits
for the transaction's statements still running, and a commit that fails
rolls back. Each of those statements stops at `max_ms`, so the wait is
bounded too; with `max_ms` set to 0 it is not. A write interrupted at
`max_ms` inside a transaction makes SQLite roll the transaction back; the
next statement or commit then fails with code 516 and `Sql.rollback`
finishes it. Transactions begin with `BEGIN IMMEDIATE`;
`Sql.begin_with(db, Sql.Deferred{})` takes another `Sql.Begin` kind.

Only those calls change the transaction state. A statement that begins or
ends a transaction or savepoint (`BEGIN`, `COMMIT`, `END`, `ROLLBACK`,
`SAVEPOINT`, `RELEASE`, with or without whitespace, comments, empty
statements or a byte order mark before it) fails with code 21 before it runs,
through `Sql.run`,
`Sql.all`, `Sql.get`, `Sql.prepare` or anywhere in an `Sql.exec` script, in
or out of a transaction. To run a script atomically, run it inside
`Sql.transaction`. Savepoints are not supported.

## Errors

Every call returns `Result<&2, &2, Sql.Error, A>`. `Sql.SqlError{code,
message}` carries SQLite's extended result code and message, for example
`2067 UNIQUE constraint failed: users.email`. `Sql.code(e)`,
`Sql.message(e)`, `Sql.primary(e)`, `Sql.is_constraint(e)` and
`Sql.is_busy(e)` read it. `Sql.RowError`, `Sql.NotJson` and `Sql.Abort` come
from reading rows and from your transaction bodies.

```bend
def failure(+c: B.Ctx, +e: Sql.Error, constraint: Bool) -> B.Res:
  match constraint:
    case True{}: B.text(B.status(c, 409), Sql.message(e))
    case False{}: B.text(B.status(c, 400), Sql.message(e))
```

## Workers and concurrency

One connection runs one statement at a time, on a helper thread, so a slow
query does not stop other requests from being served. With
[workers](workers.md), each worker process opens its own connection in
`main`, and SQLite's file locks and busy timeout share the database between
them. For many concurrent writers, switch the file to WAL mode once:
`Sql.exec(db, "PRAGMA journal_mode=WAL")`. An in-memory database is private
to each worker.

## What is proven

The laws in [Data](laws/data.md#sqlite) prove that every bound value reaches
the effect as itself, with its type, that columns map to JSON without losing
digits, that a row converts to exactly its values or fails, that
`Sql.rows_json` and `Sql.decode_rows` read rows in order and fail with the
first bad row, and that the transaction gate keeps other statements out of
an open transaction. The effect's C and JavaScript code is trusted and covered by
`tests/sqlite.test.ts`, which also checks that both builds give the same
answers.
