# SQLite

`bendo/sqlite.bend`, imported as `Sql`, is an opt-in module: an app that does
not import it does not compile or load SQLite. [SQLite](../../sqlite.md)
explains how the pieces fit, and
[the effect's notes](../../../src/effects/sqlite.md) give the error codes and
what the effect does outside the proofs. Every call that touches the database
returns `IO(Result<&2, &2, Sql.Error, A>)`.

Examples on this page are one Bend program and share this setup:

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/sqlite.bend as Sql
import ./bendo/data/json.bend as J
import ./bendo/data/schema.bend as S

def user_schema() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"id", S.IntegerSchema{None{}, None{}}, S.Required{}},
    S.Field{"name", S.StringSchema{0n, None{}, None{}, S.Plain{}}, S.Required{}}
  ], S.Strict{}}
```

## Types

### `Sql.Db`

```bend signature
type Db is Data:
  Db{slot: U32, gen: U32, token: U32, max_rows: U32, max_bytes: U32, max_cell: U32}
```

A connection. It is copyable `Data`: keep it in your app's `env`, and every
copy names the same connection. The `Db` that `Sql.begin` returns also
carries its transaction's token, so statements run through it run in the
transaction. It also carries the result caps from `Sql.Options`. The fields
are internal.

```bend
type Env is Data:
  Env{db: Sql.Db}
```

### `Sql.Stmt`

```bend signature
type Stmt is Data:
  Stmt{slot: U32, gen: U32, index: U32, sgen: U32}
```

A prepared statement, reusable on the connection it was prepared on until
`Sql.finalize` or `Sql.close`. The fields are internal.

```bend
type Prepared is Data:
  Prepared{db: Sql.Db, insert: Sql.Stmt}
```

### `Sql.Value`

```bend signature
def Value() -> Data

type Value is Data:
  SqlNull{}
  SqlInteger{text: String}
  SqlReal{text: String}
  SqlText{value: String}
  SqlBlob{bytes: List<&2, U32>}
```

A value to bind or a column value read back. An integer is decimal text in
the signed 64-bit range and a real is a JSON number's text, so neither loses
digits. Build one with `Sql.null`, `Sql.integer`, `Sql.integer_text`,
`Sql.real`, `Sql.text` or `Sql.blob`.

```bend
def ex_values() -> List<&2, Sql.Value>:
  [Sql.null(), Sql.integer(42n), Sql.text("ann")]
```

### `Sql.Binding`

```bend signature
def Binding() -> Data
```

One named parameter, made by `Sql.bind`.

```bend
def ex_binding() -> Sql.Binding:
  Sql.bind(":name", Sql.text("ann"))
```

### `Sql.Params`

```bend signature
type Params is Data:
  Positional{values: List<&2, Value>}
  Named{bindings: List<&2, Binding>}
```

A statement's bound parameters. Build them with `Sql.positional`,
`Sql.named` or `Sql.none`.

```bend
def ex_params() -> Sql.Params:
  Sql.positional([Sql.text("ann")])
```

### `Sql.Options`, `Sql.Mode`

```bend signature
type Options is Data:
  Options{mode: Mode, busy_ms: U32, max_rows: U32, max_bytes: U32, max_cell: U32, max_ms: U32}

type Mode is Data:
  ReadWriteCreate{}
  ReadWrite{}
  ReadOnly{}
```

How `Sql.open_with` opens a database. `busy_ms` is how long a statement waits
for another transaction on the connection, or another process's lock, before
failing with code 5. `max_rows` is the most rows `Sql.all` returns.
`max_bytes` is the most bytes of cell data one result of `Sql.all` or
`Sql.get` holds, counting text and blob bytes and the digits of numbers, and
`max_cell` the most bytes of one text or blob value in it. A result past any
cap fails with code 18 instead of being cut short. `max_ms` is the most
milliseconds one statement may run before it is interrupted and fails with
code 9; 0 turns that bound off.

```bend
def ex_read_only() -> Sql.Options:
  Sql.Options{Sql.ReadOnly{}, 1000, 500, 1048576, 65536, 5000}

def ex_mode() -> Sql.Mode:
  Sql.ReadWrite{}
```

### `Sql.Begin`

```bend signature
type Begin is Data:
  Deferred{}
  Immediate{}
  Exclusive{}
```

The kind of transaction `Sql.begin_with` starts: SQLite's `BEGIN DEFERRED`,
`BEGIN IMMEDIATE` or `BEGIN EXCLUSIVE`.

```bend
def ex_kind() -> Sql.Begin:
  Sql.Deferred{}
```

### `Sql.Error`

```bend signature
type Error is Data:
  SqlError{code: U32, message: String}
  RowError{row: Nat, errors: List<&2, S.Error>}
  NotJson{row: Nat, column: String}
  Abort{message: String}
```

Why a call failed. `SqlError` carries SQLite's extended result code and
message, or one of the effect's own codes. `RowError` is a row that does not
match its schema and `NotJson` a real with no JSON form; `row` counts from 0.
`Abort` is yours, returned from a transaction body to roll it back.

```bend
def ex_describe(e: Sql.Error) -> String:
  match e:
    case Sql.SqlError{code, message}: U32.show(code) ++ " " ++ message
    case Sql.RowError{row, errors}: "row " ++ Nat.show(row) ++ " does not match"
    case Sql.NotJson{row, column}: "column " ++ column ++ " is not JSON"
    case Sql.Abort{message}: message
```

### `Sql.Changes`

```bend signature
type Changes is Data:
  Changes{changes: Nat, rowid: String}
```

What a statement changed: the rows it inserted, updated or deleted (rows
changed by triggers and foreign-key actions included), and the connection's
last insert rowid as decimal text.

```bend
def ex_rowid(ch: Sql.Changes) -> String:
  match ch:
    case Sql.Changes{n, rowid}: rowid
```

### `Sql.Row`, `Sql.Rows`

```bend signature
type Row is Data:
  Row{columns: List<&2, String>, values: List<&2, Value>}

type Rows is Data:
  Rows{columns: List<&2, String>, rows: List<&2, List<&2, Value>>, changes: Changes}
```

One row with its column names, and a statement's rows with the column names
and its `Sql.Changes`.

```bend
def ex_count(r: Sql.Rows) -> Nat:
  match r:
    case Sql.Rows{cols, rows, ch}: List.length(&2, List<&2, Sql.Value>, rows)

def ex_columns(r: Sql.Row) -> List<&2, String>:
  match r:
    case Sql.Row{cols, vs}: cols
```

## Connections

### `Sql.open`

```bend signature
def open(path: String) -> IO(Result<&2, &2, Error, Db>)
```

Opens or creates the database file at `path` with `Sql.options()`.
`":memory:"` is a private in-memory database. The first open loads
libsqlite3; when it is missing, the call fails with code 14 and says which
package to install.

```bend
def ex_open() -> IO(Result<&2, &2, Sql.Error, Sql.Db>):
  Sql.open("app.db")
```

### `Sql.open_with`

```bend signature
def open_with(path: String, o: Options) -> IO(Result<&2, &2, Error, Db>)
```

Opens a database with a mode, busy timeout, result caps and statement
deadline.

```bend
def ex_open_with() -> IO(Result<&2, &2, Sql.Error, Sql.Db>):
  Sql.open_with("app.db", Sql.Options{Sql.ReadWrite{}, 2000, 1000, 8388608, 1048576, 10000})
```

### `Sql.options`

```bend signature
def options() -> Options
```

The defaults: read, write and create, a 5000 ms busy timeout, and at most
100000 rows, 64 MiB of cell data and 16 MiB in one text or blob value per
result, and 30000 ms per statement.

```bend
def ex_options() -> Sql.Options:
  Sql.options()
```

### `Sql.close`

```bend signature
def close(db: Db) -> IO(Result<&2, &2, Error, Unit>)
```

Waits for the connection's operations in flight, rolls back an open
transaction, finalizes every statement prepared on it and closes it. Every
copy of the `Db` fails with code 21 afterwards.

```bend
def ex_close(db: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Unit>):
  Sql.close(db)
```

### `Sql.exec`

```bend signature
def exec(db: Db, script: String) -> IO(Result<&2, &2, Error, Unit>)
```

Runs a script of statements with no parameters, such as a schema or a
pragma, one statement at a time. A statement that begins or ends a
transaction or savepoint fails with code 21 before it runs; the statements
before it have run. Run a script atomically inside `Sql.transaction`.

```bend
def ex_schema(db: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Unit>):
  Sql.exec(db, "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
```

## Statements

### `Sql.run`

```bend signature
def run(db: Db, sql: String, params: Params) -> IO(Result<&2, &2, Error, Changes>)
```

Runs one statement with bound parameters and drops any rows. A second
statement in `sql`, or one that begins or ends a transaction or savepoint,
fails with code 21; use `Sql.exec` for scripts and `Sql.begin` for
transactions.

```bend
def ex_insert(db: Sql.Db, name: String) -> IO(Result<&2, &2, Sql.Error, Sql.Changes>):
  Sql.run(db, "INSERT INTO users (name) VALUES (?)", Sql.positional([Sql.text(name)]))
```

### `Sql.all`

```bend signature
def all(db: Db, sql: String, params: Params) -> IO(Result<&2, &2, Error, Rows>)
```

Runs one statement and returns every row. More rows than the connection's
`max_rows`, or more data than its `max_bytes` or `max_cell`, fail with code
18 instead of being cut short.

```bend
def ex_all(db: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Sql.Rows>):
  Sql.all(db, "SELECT id, name FROM users ORDER BY id", Sql.none())
```

### `Sql.get`

```bend signature
def get(db: Db, sql: String, params: Params) -> IO(Result<&2, &2, Error, Maybe<&2, Row>>)
```

Runs one statement and returns its first row, if any; the statement stops
after it.

```bend
def ex_get(db: Sql.Db, id: String) -> IO(Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>>):
  Sql.get(db, "SELECT id, name FROM users WHERE id = ?", Sql.positional([Sql.integer_text(id)]))
```

### `Sql.prepare`

```bend signature
def prepare(db: Db, sql: String) -> IO(Result<&2, &2, Error, Stmt>)
```

Compiles one statement for reuse. Prepare at startup and keep the
`Sql.Stmt` in `env`.

```bend
def ex_prepare(db: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Sql.Stmt>):
  Sql.prepare(db, "INSERT INTO users (name) VALUES (?)")
```

### `Sql.run_stmt`, `Sql.all_stmt`, `Sql.get_stmt`

```bend signature
def run_stmt(db: Db, stmt: Stmt, params: Params) -> IO(Result<&2, &2, Error, Changes>)
def all_stmt(db: Db, stmt: Stmt, params: Params) -> IO(Result<&2, &2, Error, Rows>)
def get_stmt(db: Db, stmt: Stmt, params: Params) -> IO(Result<&2, &2, Error, Maybe<&2, Row>>)
```

`Sql.run`, `Sql.all` and `Sql.get` for a prepared statement. `db` must be the
connection it was prepared on, or the `Db` of a transaction on it; another
connection fails with code 21.

```bend
def ex_run_stmt(db: Sql.Db, insert: Sql.Stmt) -> IO(Result<&2, &2, Sql.Error, Sql.Changes>):
  Sql.run_stmt(db, insert, Sql.positional([Sql.text("ann")]))

def ex_all_stmt(db: Sql.Db, list: Sql.Stmt) -> IO(Result<&2, &2, Sql.Error, Sql.Rows>):
  Sql.all_stmt(db, list, Sql.none())

def ex_get_stmt(db: Sql.Db, find: Sql.Stmt) -> IO(Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>>):
  Sql.get_stmt(db, find, Sql.positional([Sql.integer(1n)]))
```

### `Sql.finalize`

```bend signature
def finalize(stmt: Stmt) -> IO(Result<&2, &2, Error, Unit>)
```

Releases a prepared statement. Using it afterwards fails with code 21.

```bend
def ex_finalize(stmt: Sql.Stmt) -> IO(Result<&2, &2, Sql.Error, Unit>):
  Sql.finalize(stmt)
```

## Parameters

### `Sql.positional`

```bend signature
def positional(values: List<&2, Value>) -> Params
```

Binds `?` and `?NNN` parameters in order. The list must have exactly as many
values as the statement's highest parameter index, and the statement may not
have named parameters.

```bend
def ex_positional() -> Sql.Params:
  Sql.positional([Sql.text("ann"), Sql.null()])
```

### `Sql.named`, `Sql.bind`

```bend signature
def named(bindings: List<&2, Binding>) -> Params
def bind(name: String, v: Value) -> Binding
```

Binds `:name`, `@name` and `$name` parameters. Write each name with its
prefix, as in the SQL. Every parameter must be bound exactly once.

```bend
def ex_named(id: String) -> Sql.Params:
  Sql.named([Sql.bind(":id", Sql.integer_text(id)), Sql.bind(":name", Sql.text("ann"))])
```

### `Sql.none`

```bend signature
def none() -> Params
```

No parameters.

```bend
def ex_none() -> Sql.Params:
  Sql.none()
```

### `Sql.null`, `Sql.integer`, `Sql.integer_text`, `Sql.real`, `Sql.text`, `Sql.blob`

```bend signature
def null() -> Value
def integer(n: Nat) -> Value
def integer_text(text: String) -> Value
def real(text: String) -> Value
def text(s: String) -> Value
def blob(bytes: List<&2, U32>) -> Value
```

Values to bind. `Sql.integer` takes a `Nat`, which the native build holds up
to 2^48 - 1; `Sql.integer_text` takes any signed 64-bit integer as canonical
decimal text. `Sql.real` takes a JSON number. A blob byte must be below 256.
A malformed value fails with code 20 before the statement runs.

```bend
def ex_all_values() -> List<&2, Sql.Value>:
  [Sql.null(), Sql.integer(7n), Sql.integer_text("-9223372036854775808"), Sql.real("0.1"), Sql.text("ann"), Sql.blob([0, 255])]
```

## Transactions

### `Sql.begin`, `Sql.begin_with`

```bend signature
def begin(db: Db) -> IO(Result<&2, &2, Error, Db>)
def begin_with(db: Db, kind: Begin) -> IO(Result<&2, &2, Error, Db>)
```

Begins a transaction, `BEGIN IMMEDIATE` for `Sql.begin`, and returns the `Db`
to run its statements through. Statements through other copies of the
connection wait until it ends, up to the busy timeout.

```bend
def ex_begin(db: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Sql.Db>):
  Sql.begin(db)

def ex_begin_deferred(db: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Sql.Db>):
  Sql.begin_with(db, Sql.Deferred{})
```

### `Sql.commit`, `Sql.rollback`

```bend signature
def commit(tx: Db) -> IO(Result<&2, &2, Error, Unit>)
def rollback(tx: Db) -> IO(Result<&2, &2, Error, Unit>)
```

End the transaction `tx` belongs to. Each waits, without a limit, for the
transaction's statements already running, and a commit that fails rolls
back, so the transaction is over after either call whatever it returns;
using `tx` again fails with code 21.

```bend
def ex_commit(tx: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Unit>):
  Sql.commit(tx)

def ex_rollback(tx: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Unit>):
  Sql.rollback(tx)
```

### `Sql.transaction`

```bend signature
def transaction(-A: Data, db: Db, body: Db -> IO(Result<&2, &2, Error, A>)) -> IO(Result<&2, &2, Error, A>)
```

Begins a transaction and runs `body` with its `Db`. Commits and returns the
result when `body` returns `Done`; rolls back and returns the error when it
returns `Fail`. When the commit fails, it returns that error and the
transaction has been rolled back.

```bend
def ex_body(+tx: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Sql.Changes>):
  Sql.run(tx, "INSERT INTO users (name) VALUES ('in a transaction')", Sql.none())

def ex_transaction(db: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Sql.Changes>):
  Sql.transaction(Sql.Changes, db, tx => ex_body(tx))
```

### `Sql.abort`

```bend signature
def abort(message: String) -> Error
```

The error to return from a transaction body to roll it back for your own
reasons.

```bend
def ex_abort() -> Result<&2, &2, Sql.Error, Unit>:
  Fail{Sql.abort("insufficient funds")}
```

## Reading rows

### `Sql.rows_json`, `Sql.row_json`

```bend signature
def rows_json(rows: Rows) -> Result<&2, &2, Error, List<&2, J.Json>>
def row_json(row: Row) -> Result<&2, &2, Error, J.Json>
```

Rows as JSON objects keyed by column name, in order. NULL is `null`,
integers and reals are numbers with the same digits, text is a string and a
blob the string of its standard base64. The first row with a real that has
no JSON form fails with `Sql.NotJson{row, column}`, `row` counting from 0.

```bend
def ex_rows_json(rows: Sql.Rows) -> Result<&2, &2, Sql.Error, J.Json>:
  Result.bind(&2, &2, Sql.Error, List<&2, J.Json>, J.Json, Sql.rows_json(rows), xs => Done{J.JArray{xs}})

def ex_row_json(row: Sql.Row) -> Result<&2, &2, Sql.Error, J.Json>:
  Sql.row_json(row)
```

### `Sql.decode_rows`, `Sql.decode_row`

```bend signature
def decode_rows(schema: S.Schema, rows: Rows) -> Result<&2, &2, Error, List<&2, S.Value>>
def decode_row(schema: S.Schema, row: Row) -> Result<&2, &2, Error, S.Value>
```

Rows converted as `Sql.rows_json` converts them, then decoded through a
schema, as route validation decodes a JSON body, one by one in order. The
first row that fails decides the error: `Sql.NotJson` when it has no JSON
form, or `Sql.RowError{row, errors}` when it does not match.

```bend
def ex_decode_rows(rows: Sql.Rows) -> Result<&2, &2, Sql.Error, List<&2, S.Value>>:
  Sql.decode_rows(user_schema(), rows)

def ex_decode_row(row: Sql.Row) -> Result<&2, &2, Sql.Error, S.Value>:
  Sql.decode_row(user_schema(), row)
```

## Errors

### `Sql.code`, `Sql.message`, `Sql.primary`

```bend signature
def code(e: Error) -> U32
def message(e: Error) -> String
def primary(e: Error) -> U32
```

SQLite's extended result code (0 for an error that is not SQLite's), a
message for any error, and the primary code, the extended code's low byte.

```bend
def ex_code(+e: Sql.Error) -> String:
  U32.show(Sql.code(e)) ++ " (" ++ U32.show(Sql.primary(e)) ++ "): " ++ Sql.message(e)
```

### `Sql.is_constraint`, `Sql.is_busy`

```bend signature
def is_constraint(e: Error) -> Bool
def is_busy(e: Error) -> Bool
```

Whether the error is a constraint violation (primary code 19) or a lock that
outlasted the busy timeout (primary code 5).

```bend
def ex_status(+e: Sql.Error) -> U32:
  Bool.pick(U32, Sql.is_constraint(e), 409, Bool.pick(U32, Sql.is_busy(e), 503, 500))
```
