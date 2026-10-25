# SQLite for Bendo apps (BND-38): open a database, run statements with bound
# parameters, read rows as JSON or through schemas, and use transactions.
# Opt-in: only a program that imports this module compiles the effect, and
# only one that opens a database loads libsqlite3. See docs/sqlite.md and
# src/effects/sqlite.md, which says what the effect does outside the proofs.
import Base
import ./effects/sqlite.bend as E
import ./data/sqlite.bend as D
import ./data/json.bend as J
import ./data/schema.bend as S

def Value() -> Data: D.Value
def Binding() -> Data: D.Binding

# A connection. Copy it freely: every copy names the same connection, and
# closing it makes every copy fail. Inside a transaction, the Db that begin
# returns carries the transaction's token, and statements run through it run
# in the transaction. max_rows caps what Sqlite.all returns.
type Db is Data:
  Db{slot: U32, gen: U32, token: U32, max_rows: U32}

# A prepared statement on one connection, reusable until finalized.
type Stmt is Data:
  Stmt{slot: U32, gen: U32, index: U32, sgen: U32}

type Params is Data:
  Positional{values: List<&2, D.Value>}
  Named{bindings: List<&2, D.Binding>}

type Mode is Data:
  ReadWriteCreate{}
  ReadWrite{}
  ReadOnly{}

type Begin is Data:
  Deferred{}
  Immediate{}
  Exclusive{}

type Options is Data:
  Options{mode: Mode, busy_ms: U32, max_rows: U32}

# SqlError carries SQLite's extended result code and message, or one of the
# effect's own (src/effects/sqlite.md lists them). RowError and NotJson come
# from reading rows; row counts from 0. Abort is yours: return it from a
# transaction body to roll the transaction back.
type Error is Data:
  SqlError{code: U32, message: String}
  RowError{row: Nat, errors: List<&2, S.Error>}
  NotJson{row: Nat, column: String}
  Abort{message: String}

# Rows the statement inserted, updated or deleted, triggers and foreign-key
# actions included, and the connection's last insert rowid as decimal text.
type Changes is Data:
  Changes{changes: Nat, rowid: String}

type Row is Data:
  Row{columns: List<&2, String>, values: List<&2, D.Value>}

type Rows is Data:
  Rows{columns: List<&2, String>, rows: List<&2, List<&2, D.Value>>, changes: Changes}

# ------------------------------------------------------------------ Values

def null() -> D.Value: D.SqlNull{}
def integer(n: Nat) -> D.Value: D.SqlInteger{Nat.show(n)}
def integer_text(text: String) -> D.Value: D.SqlInteger{text}
def real(text: String) -> D.Value: D.SqlReal{text}
def text(s: String) -> D.Value: D.SqlText{s}
def blob(bytes: List<&2, U32>) -> D.Value: D.SqlBlob{bytes}

def none() -> Params: Positional{[]}
def positional(values: List<&2, D.Value>) -> Params: Positional{values}
def named(bindings: List<&2, D.Binding>) -> Params: Named{bindings}
def bind(name: String, v: D.Value) -> D.Binding: D.Binding{name, v}

def options() -> Options:
  Options{ReadWriteCreate{}, 5000, 100000}

def abort(message: String) -> Error: Abort{message}

# SQLite's extended result code, or 0 for an error that is not SQLite's.
def code(e: Error) -> U32:
  match e:
    case SqlError{c, m}: c
    case RowError{n, es}: 0
    case NotJson{n, c}: 0
    case Abort{m}: 0

def message(e: Error) -> String:
  match e:
    case SqlError{c, m}: m
    case RowError{n, es}: "row " ++ Nat.show(n) ++ " does not match the schema"
    case NotJson{n, c}: "row " ++ Nat.show(n) ++ ", column " ++ c ++ ": not a JSON number"
    case Abort{m}: m

def primary(e: Error) -> U32:
  (code(e) .&. 255 : U32)

def is_constraint(e: Error) -> Bool:
  U32.is_eq(primary(e), 19)

def is_busy(e: Error) -> Bool:
  U32.is_eq(primary(e), 5)

# ------------------------------------------------------------------ Replies

def Raw() -> Type:
  Result<&1, &1, U32 & String, E.Reply>

def unexpected(-A: Data) -> Result<&2, &2, Error, A>:
  Fail{SqlError{21, "bendo sqlite: unexpected reply"}}

def cell(c: E.Cell) -> D.Value:
  match c:
    case E.CellNull{}: D.SqlNull{}
    case E.CellInteger{t}: D.SqlInteger{t}
    case E.CellReal{t}: D.SqlReal{t}
    case E.CellText{s}: D.SqlText{s}
    case E.CellBlob{xs}: D.SqlBlob{xs}

# A row has at most a few thousand columns, so direct recursion is safe.
def cells(cs: List<&2, E.Cell>) -> List<&2, D.Value>:
  match cs:
    case Nil{}: []
    case c <> t: cell(c) <> cells(t)

def rows_go(rs: List<&2, List<&2, E.Cell>>, rev: List<&2, List<&2, D.Value>>) -> List<&2, List<&2, D.Value>>:
  match rs:
    case Nil{}: List.reverse(&2, List<&2, D.Value>, rev)
    case r <> t: rows_go(t, cells(r) <> rev)

def opened(max_rows: U32, r: Raw()) -> Result<&2, &2, Error, Db>:
  match r:
    case Fail{(c, m)}: Fail{SqlError{c, m}}
    case Done{E.Handle{slot, gen}}: Done{Db{slot, gen, 0, max_rows}}
    case Done{_}: unexpected(Db)

def finished(r: Raw()) -> Result<&2, &2, Error, Unit>:
  match r:
    case Fail{(c, m)}: Fail{SqlError{c, m}}
    case Done{E.Finished{}}: Done{Unit{}}
    case Done{_}: unexpected(Unit)

def prepared(slot: U32, gen: U32, r: Raw()) -> Result<&2, &2, Error, Stmt>:
  match r:
    case Fail{(c, m)}: Fail{SqlError{c, m}}
    case Done{E.Handle{index, sgen}}: Done{Stmt{slot, gen, index, sgen}}
    case Done{_}: unexpected(Stmt)

def began(slot: U32, gen: U32, max_rows: U32, r: Raw()) -> Result<&2, &2, Error, Db>:
  match r:
    case Fail{(c, m)}: Fail{SqlError{c, m}}
    case Done{E.Handle{token, zero}}: Done{Db{slot, gen, token, max_rows}}
    case Done{_}: unexpected(Db)

def ran(r: Raw()) -> Result<&2, &2, Error, Rows>:
  match r:
    case Fail{(c, m)}: Fail{SqlError{c, m}}
    case Done{E.Ran{cols, rs, n, rowid}}: Done{Rows{cols, rows_go(rs, []), Changes{n, rowid}}}
    case Done{_}: unexpected(Rows)

def changes_of(r: Result<&2, &2, Error, Rows>) -> Result<&2, &2, Error, Changes>:
  match r:
    case Fail{e}: Fail{e}
    case Done{Rows{cols, rs, ch}}: Done{ch}

def first_row(cols: List<&2, String>, rs: List<&2, List<&2, D.Value>>) -> Maybe<&2, Row>:
  match rs:
    case Nil{}: None{}
    case r <> t: Some{Row{cols, r}}

def row_of(r: Result<&2, &2, Error, Rows>) -> Result<&2, &2, Error, Maybe<&2, Row>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{Rows{cols, rs, ch}}: Done{first_row(cols, rs)}

def wire(p: Params) -> String:
  match p:
    case Positional{vs}: D.positional(vs)
    case Named{bs}: D.named(bs)

def mode_code(m: Mode) -> U32:
  match m:
    case ReadWriteCreate{}: 0
    case ReadWrite{}: 1
    case ReadOnly{}: 2

def kind_code(k: Begin) -> U32:
  match k:
    case Deferred{}: 0
    case Immediate{}: 1
    case Exclusive{}: 2

# ------------------------------------------------------------------ Connections

# Opens path (":memory:" for a private in-memory database) with a busy
# timeout and a row cap.
def open_with(path: String, o: Options) -> IO(Result<&2, &2, Error, Db>):
  match o:
    case Options{mode, busy_ms, +max_rows}:
      do IO<Result<&2, &2, Error, Db>>:
        r : Raw() <- E.sqlite_call(0, 0, 0, 0, 0, 0, mode_code(mode), busy_ms, path, "")
        return opened(max_rows, r)

def open(path: String) -> IO(Result<&2, &2, Error, Db>):
  open_with(path, options())

# Rolls back an open transaction, finalizes every prepared statement and
# closes the connection, once operations already started have finished.
def close(db: Db) -> IO(Result<&2, &2, Error, Unit>):
  match db:
    case Db{slot, gen, token, max_rows}:
      do IO<Result<&2, &2, Error, Unit>>:
        r : Raw() <- E.sqlite_call(1, slot, gen, 0, 0, 0, 0, 0, "", "")
        return finished(r)

# Runs a script of statements with no parameters, such as a schema.
def exec(db: Db, script: String) -> IO(Result<&2, &2, Error, Unit>):
  match db:
    case Db{slot, gen, token, max_rows}:
      do IO<Result<&2, &2, Error, Unit>>:
        r : Raw() <- E.sqlite_call(5, slot, gen, token, 0, 0, 0, 0, script, "")
        return finished(r)

def query(db: Db, index: U32, sgen: U32, mode: U32, sql: String, params: Params) -> IO(Result<&2, &2, Error, Rows>):
  match db:
    case Db{slot, gen, token, max_rows}:
      do IO<Result<&2, &2, Error, Rows>>:
        r : Raw() <- E.sqlite_call(4, slot, gen, token, index, sgen, mode, max_rows, sql, wire(params))
        return ran(r)

# One statement with bound parameters; the result rows are dropped.
def run(db: Db, sql: String, params: Params) -> IO(Result<&2, &2, Error, Changes>):
  do IO<Result<&2, &2, Error, Changes>>:
    r : Result<&2, &2, Error, Rows> <- query(db, 0, 0, 0, sql, params)
    return changes_of(r)

# Every row, failing past the connection's max_rows.
def all(db: Db, sql: String, params: Params) -> IO(Result<&2, &2, Error, Rows>):
  query(db, 0, 0, 1, sql, params)

# The first row, if any; the statement stops after it.
def get(db: Db, sql: String, params: Params) -> IO(Result<&2, &2, Error, Maybe<&2, Row>>):
  do IO<Result<&2, &2, Error, Maybe<&2, Row>>>:
    r : Result<&2, &2, Error, Rows> <- query(db, 0, 0, 2, sql, params)
    return row_of(r)

# ------------------------------------------------------------------ Statements

def prepare(db: Db, sql: String) -> IO(Result<&2, &2, Error, Stmt>):
  match db:
    case Db{+slot, +gen, token, max_rows}:
      do IO<Result<&2, &2, Error, Stmt>>:
        r : Raw() <- E.sqlite_call(2, slot, gen, 0, 0, 0, 0, 0, sql, "")
        return prepared(slot, gen, r)

def finalize(stmt: Stmt) -> IO(Result<&2, &2, Error, Unit>):
  match stmt:
    case Stmt{slot, gen, index, sgen}:
      do IO<Result<&2, &2, Error, Unit>>:
        r : Raw() <- E.sqlite_call(3, slot, gen, 0, index, sgen, 0, 0, "", "")
        return finished(r)

# Whether db is the connection stmt was prepared on.
def owns(db: Db, +slot: U32, +gen: U32) -> Bool:
  match db:
    case Db{a, g, t, m}: U32.is_eq(a, slot) && U32.is_eq(g, gen)

def stmt_query(db: Db, ok: Bool, index: U32, sgen: U32, mode: U32, params: Params) -> IO(Result<&2, &2, Error, Rows>):
  match ok:
    case True{}: query(db, index, sgen, mode, "", params)
    case False{}: IO.pure(Result<&2, &2, Error, Rows>, Fail{SqlError{21, "bendo sqlite: the statement is finalized or belongs to another connection"}})

# A prepared statement runs on the connection, and in the transaction, of db,
# which must be the connection it was prepared on.
def query_stmt(+db: Db, stmt: Stmt, mode: U32, params: Params) -> IO(Result<&2, &2, Error, Rows>):
  match stmt:
    case Stmt{+slot, +gen, index, sgen}: stmt_query(db, owns(db, slot, gen), index, sgen, mode, params)

def run_stmt(db: Db, stmt: Stmt, params: Params) -> IO(Result<&2, &2, Error, Changes>):
  do IO<Result<&2, &2, Error, Changes>>:
    r : Result<&2, &2, Error, Rows> <- query_stmt(db, stmt, 0, params)
    return changes_of(r)

def all_stmt(db: Db, stmt: Stmt, params: Params) -> IO(Result<&2, &2, Error, Rows>):
  query_stmt(db, stmt, 1, params)

def get_stmt(db: Db, stmt: Stmt, params: Params) -> IO(Result<&2, &2, Error, Maybe<&2, Row>>):
  do IO<Result<&2, &2, Error, Maybe<&2, Row>>>:
    r : Result<&2, &2, Error, Rows> <- query_stmt(db, stmt, 2, params)
    return row_of(r)

# ------------------------------------------------------------------ Transactions

# Begins a transaction and returns the Db to run its statements through.
# Statements through other copies of the connection wait until it ends, up
# to the busy timeout.
def begin_with(db: Db, kind: Begin) -> IO(Result<&2, &2, Error, Db>):
  match db:
    case Db{+slot, +gen, token, +max_rows}:
      do IO<Result<&2, &2, Error, Db>>:
        r : Raw() <- E.sqlite_call(6, slot, gen, 0, 0, 0, kind_code(kind), 0, "", "")
        return began(slot, gen, max_rows, r)

# BEGIN IMMEDIATE: takes the write lock at once, so a second process cannot
# make the commit fail with SQLITE_BUSY halfway.
def begin(db: Db) -> IO(Result<&2, &2, Error, Db>):
  begin_with(db, Immediate{})

def finish(tx: Db, mode: U32) -> IO(Result<&2, &2, Error, Unit>):
  match tx:
    case Db{slot, gen, token, max_rows}:
      do IO<Result<&2, &2, Error, Unit>>:
        r : Raw() <- E.sqlite_call(7, slot, gen, token, 0, 0, mode, 0, "", "")
        return finished(r)

# A commit that fails rolls the transaction back; either way it is over.
def commit(tx: Db) -> IO(Result<&2, &2, Error, Unit>):
  finish(tx, 1)

def rollback(tx: Db) -> IO(Result<&2, &2, Error, Unit>):
  finish(tx, 0)

def committed(-A: Data, c: Result<&2, &2, Error, Unit>, x: A) -> Result<&2, &2, Error, A>:
  match c:
    case Fail{e}: Fail{e}
    case Done{u}: Done{x}

def settle(-A: Data, +tx: Db, out: Result<&2, &2, Error, A>) -> IO(Result<&2, &2, Error, A>):
  match out:
    case Fail{e}:
      do IO<Result<&2, &2, Error, A>>:
        r : Result<&2, &2, Error, Unit> <- rollback(tx)
        return Fail{e}
    case Done{x}:
      do IO<Result<&2, &2, Error, A>>:
        c : Result<&2, &2, Error, Unit> <- commit(tx)
        return committed(A, c, x)

def started(-A: Data, body: Db -> IO(Result<&2, &2, Error, A>), r: Result<&2, &2, Error, Db>) -> IO(Result<&2, &2, Error, A>):
  match r:
    case Fail{e}: IO.pure(Result<&2, &2, Error, A>, Fail{e})
    case Done{+tx}:
      do IO<Result<&2, &2, Error, A>>:
        out : Result<&2, &2, Error, A> <- body(tx)
        settle(A, tx, out)

# Runs body in a transaction: commits when it returns Done, rolls back when
# it returns Fail (Sqlite.abort for your own reasons) and returns that error.
def transaction(-A: Data, db: Db, body: Db -> IO(Result<&2, &2, Error, A>)) -> IO(Result<&2, &2, Error, A>):
  do IO<Result<&2, &2, Error, A>>:
    r : Result<&2, &2, Error, Db> <- begin(db)
    started(A, body, r)

# ------------------------------------------------------------------ Reading rows

def json_or_fail(n: Nat, r: Result<&2, &2, String, J.Json>) -> Result<&2, &2, Error, J.Json>:
  match r:
    case Fail{c}: Fail{NotJson{n, c}}
    case Done{j}: Done{j}

# A row as a JSON object keyed by column name (Sqlite.Value docs give the
# mapping). Fails when a real has no JSON form.
def row_json(row: Row) -> Result<&2, &2, Error, J.Json>:
  match row:
    case Row{cols, vs}: json_or_fail(0n, D.row_json(cols, vs))

def push_json_row(rev: List<&2, J.Json>, r: Result<&2, &2, Error, J.Json>) -> Result<&2, &2, Error, List<&2, J.Json>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{j}: Done{j <> rev}

def push_json(acc: Result<&2, &2, Error, List<&2, J.Json>>, +n: Nat, +cols: List<&2, String>, vs: List<&2, D.Value>) -> Result<&2, &2, Error, List<&2, J.Json>>:
  match acc:
    case Fail{e}: Fail{e}
    case Done{rev}: push_json_row(rev, json_or_fail(n, D.row_json(cols, vs)))

def flip_json(r: Result<&2, &2, Error, List<&2, J.Json>>) -> Result<&2, &2, Error, List<&2, J.Json>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{rev}: Done{List.reverse(&2, J.Json, rev)}

def rows_json_go(rs: List<&2, List<&2, D.Value>>, +cols: List<&2, String>, +n: Nat, acc: Result<&2, &2, Error, List<&2, J.Json>>) -> Result<&2, &2, Error, List<&2, J.Json>>:
  match rs:
    case Nil{}: flip_json(acc)
    case vs <> t: rows_json_go(t, cols, 1n+n, push_json(acc, n, cols, vs))

def rows_json(rows: Rows) -> Result<&2, &2, Error, List<&2, J.Json>>:
  match rows:
    case Rows{cols, rs, ch}: rows_json_go(rs, cols, 0n, Done{[]})

def decoded(n: Nat, r: Result<&2, &2, List<&2, S.Error>, S.Value>) -> Result<&2, &2, Error, S.Value>:
  match r:
    case Fail{es}: Fail{RowError{n, es}}
    case Done{v}: Done{v}

def decode_json(+schema: S.Schema, n: Nat, r: Result<&2, &2, Error, J.Json>) -> Result<&2, &2, Error, S.Value>:
  match r:
    case Fail{e}: Fail{e}
    case Done{j}: decoded(n, S.decode(schema, j))

# A row decoded through an object schema, as route validation decodes a
# JSON body.
def decode_row(+schema: S.Schema, row: Row) -> Result<&2, &2, Error, S.Value>:
  decode_json(schema, 0n, row_json(row))

def push_value(rev: List<&2, S.Value>, r: Result<&2, &2, Error, S.Value>) -> Result<&2, &2, Error, List<&2, S.Value>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{v}: Done{v <> rev}

def push_decoded(acc: Result<&2, &2, Error, List<&2, S.Value>>, +schema: S.Schema, +n: Nat, +cols: List<&2, String>, vs: List<&2, D.Value>) -> Result<&2, &2, Error, List<&2, S.Value>>:
  match acc:
    case Fail{e}: Fail{e}
    case Done{rev}: push_value(rev, decode_json(schema, n, json_or_fail(n, D.row_json(cols, vs))))

def flip_values(r: Result<&2, &2, Error, List<&2, S.Value>>) -> Result<&2, &2, Error, List<&2, S.Value>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{rev}: Done{List.reverse(&2, S.Value, rev)}

def decode_go(rs: List<&2, List<&2, D.Value>>, +schema: S.Schema, +cols: List<&2, String>, +n: Nat, acc: Result<&2, &2, Error, List<&2, S.Value>>) -> Result<&2, &2, Error, List<&2, S.Value>>:
  match rs:
    case Nil{}: flip_values(acc)
    case vs <> t: decode_go(t, schema, cols, 1n+n, push_decoded(acc, schema, n, cols, vs))

# Every row decoded through schema; fails with the first row that does not
# match (RowError) or has no JSON form (NotJson).
def decode_rows(+schema: S.Schema, rows: Rows) -> Result<&2, &2, Error, List<&2, S.Value>>:
  match rows:
    case Rows{cols, rs, ch}: decode_go(rs, schema, cols, 0n, Done{[]})
