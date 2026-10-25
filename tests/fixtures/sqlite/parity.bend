# Runs the same SQLite operations in the native and JS builds and prints one
# line per result, so tests/sqlite.test.ts can compare the two (BND-38).
# The first argument is a scratch directory for file databases, or --open to
# only open an in-memory database and print the result.
import Base
import ../../../src/sqlite.bend as Sql
import ../../../src/data/sqlite.bend as D
import ../../../src/data/json.bend as J
import ../../../src/data/schema.bend as S
import ../../../src/data/hex.bend as Hex

def value_text(v: D.Value) -> String:
  match v:
    case D.SqlNull{}: "null"
    case D.SqlInteger{t}: "i:" ++ t
    case D.SqlReal{t}: "r:" ++ t
    case D.SqlText{s}: "t:" ++ s
    case D.SqlBlob{xs}: "b:" ++ Hex.encode(xs)

def row_text(vs: List<&2, D.Value>) -> String:
  match vs:
    case Nil{}: ""
    case v <> Nil{}: value_text(v)
    case v <> t: value_text(v) ++ "|" ++ row_text(t)

def rows_text(rs: List<&2, List<&2, D.Value>>) -> String:
  match rs:
    case Nil{}: ""
    case r <> t: " [" ++ row_text(r) ++ "]" ++ rows_text(t)

def error_text(e: Sql.Error) -> String:
  match e:
    case Sql.SqlError{c, m}: "error " ++ U32.show(c) ++ " " ++ m
    case Sql.RowError{n, es}: "row error " ++ Nat.show(n) ++ " " ++ Result.default(&2, &2, J.Error, String, J.stringify(S.errors_json(es)), "?")
    case Sql.NotJson{n, c}: "not json " ++ Nat.show(n) ++ " " ++ c
    case Sql.Abort{m}: "abort " ++ m

def rows(r: Result<&2, &2, Sql.Error, Sql.Rows>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{Sql.Rows{cols, rs, Sql.Changes{n, rowid}}}: "rows " ++ String.join(cols, ",") ++ rows_text(rs) ++ " changes " ++ Nat.show(n)

def changes(r: Result<&2, &2, Sql.Error, Sql.Changes>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{Sql.Changes{n, rowid}}: "changes " ++ Nat.show(n) ++ " rowid " ++ rowid

def unit(r: Result<&2, &2, Sql.Error, Unit>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{u}: "ok"

def got(r: Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{None{}}: "none"
    case Done{Some{Sql.Row{cols, vs}}}: "row " ++ String.join(cols, ",") ++ " [" ++ row_text(vs) ++ "]"

def jsons(r: Result<&2, &2, Sql.Error, List<&2, J.Json>>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{xs}: Result.default(&2, &2, J.Error, String, J.stringify(J.JArray{xs}), "?")

def as_json(r: Result<&2, &2, Sql.Error, Sql.Rows>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{rs}: jsons(Sql.rows_json(rs))

def decoded(r: Result<&2, &2, Sql.Error, List<&2, S.Value>>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{vs}: "decoded " ++ Nat.show(List.length(&2, S.Value, vs))

def schema() -> S.Schema:
  S.ObjectSchema{[S.Field{"n", S.StringSchema{0n, None{}, None{}, S.Plain{}}, S.Required{}}], S.Strict{}}

def stmt_or_die(r: Result<&2, &2, Sql.Error, Sql.Stmt>) -> IO(Sql.Stmt):
  match r:
    case Fail{e}: IO.die(Sql.Stmt, 1, error_text(e))
    case Done{s}: IO.pure(Sql.Stmt, s)

def db_or_die(r: Result<&2, &2, Sql.Error, Sql.Db>) -> IO(Sql.Db):
  match r:
    case Fail{e}: IO.die(Sql.Db, 1, error_text(e))
    case Done{db}: IO.pure(Sql.Db, db)

def say(+label: String, line: String) -> IO(Unit):
  IO.print(label ++ ": " ++ line)

def p(vs: List<&2, D.Value>) -> Sql.Params: Sql.positional(vs)

def n(bs: List<&2, D.Binding>) -> Sql.Params: Sql.named(bs)

def values(+db: Sql.Db) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(db, "CREATE TABLE t (id INTEGER PRIMARY KEY, i, r, s, b); CREATE TABLE u (name TEXT UNIQUE)")
    say("schema", unit(a))
    b : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "INSERT INTO t (i, r, s, b) VALUES (?, ?, ?, ?)", p([Sql.integer_text("9223372036854775807"), Sql.real("0.1"), Sql.text("h\u{e9}llo \u{1F389} a;b\\c'd"), Sql.blob([0, 255, 59, 92, 10])]))
    say("insert max", changes(b))
    c : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "INSERT INTO t (i, r, s, b) VALUES (?, ?, ?, ?)", p([Sql.integer_text("-9223372036854775808"), Sql.real("-1.5e300"), Sql.text(""), Sql.blob([])]))
    say("insert min", changes(c))
    d : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "INSERT INTO t (i, r, s, b) VALUES (?, ?, ?, ?)", p([Sql.null(), Sql.null(), Sql.null(), Sql.null()]))
    say("insert nulls", changes(d))
    e : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT id, i, r, s, b, typeof(b) FROM t ORDER BY id", Sql.none())
    say("select", rows(e))
    f : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT id, i, r, s, b FROM t ORDER BY id", Sql.none())
    say("json", as_json(f))
    g : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 2.0, 1e308 * 10, -0.0, 0.1, 123456789012345680000.0, 1e21, 5e-7, 1e-7, 0.000001, 1234.5678, 3e-310, -1e21, 1.0 / 3, 100.0", Sql.none())
    say("reals", rows(g))
    h : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?, ?, ?, ?, ?", p([Sql.real("1e999"), Sql.real("-0"), Sql.real("2.5E-3"), Sql.integer(Nat.mul(65535n, 65535n)), Sql.integer_text("9000000000000000000")]))
    say("bound reals", rows(h))
    i : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 1e999 AS big", Sql.none())
    say("not json", as_json(i))

def injection(+db: Sql.Db) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "INSERT INTO t (s) VALUES (?)", p([Sql.text("'; DROP TABLE t; --")]))
    say("inject insert", changes(a))
    b : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT s FROM t WHERE s = ?", p([Sql.text("'; DROP TABLE t; --")]))
    say("inject read", rows(b))
    c : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT count(*) FROM t WHERE id = ?", p([Sql.text("1 OR 1=1")]))
    say("inject text", rows(c))
    d : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT count(*) FROM t WHERE id = ?", p([Sql.integer_text("1 OR 1=1")]))
    say("inject integer", rows(d))
    e : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT count(*) FROM t", Sql.none())
    say("table survives", rows(e))

def errors(+db: Sql.Db) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "INSERT INTO u VALUES (?)", p([Sql.text("x")]))
    say("unique first", changes(a))
    b : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "INSERT INTO u VALUES (?)", p([Sql.text("x")]))
    say("unique second", changes(b))
    c : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?, ?", p([Sql.integer(1n)]))
    say("too few", rows(c))
    d : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?", p([Sql.integer(1n), Sql.integer(2n), Sql.null()]))
    say("too many", rows(d))
    e : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT :a, :b, :a", n([Sql.bind(":a", Sql.integer(1n)), Sql.bind(":b", Sql.text("two"))]))
    say("named", rows(e))
    f : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT :a, :b", n([Sql.bind(":a", Sql.integer(1n))]))
    say("named missing", rows(f))
    g : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT :a", n([Sql.bind(":a", Sql.integer(1n)), Sql.bind(":zz", Sql.integer(2n))]))
    say("named unknown", rows(g))
    h : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT :a", n([Sql.bind(":a", Sql.integer(1n)), Sql.bind(":a", Sql.integer(2n))]))
    say("named twice", rows(h))
    i : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT :a", p([Sql.integer(1n)]))
    say("positional on named", rows(i))
    j : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?", n([Sql.bind("?1", Sql.integer(1n))]))
    say("named on anonymous", rows(j))
    k : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?2, ?1", p([Sql.text("one"), Sql.text("two")]))
    say("numbered", rows(k))
    l : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?", p([Sql.integer_text("9223372036854775808")]))
    say("int overflow", rows(l))
    m : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?", p([Sql.integer_text("007")]))
    say("int leading zero", rows(m))
    o : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?", p([Sql.integer_text("-0")]))
    say("int minus zero", rows(o))
    q : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?", p([Sql.real("NaN")]))
    say("real nan", rows(q))
    r : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT ?", p([Sql.blob([1, 256])]))
    say("blob byte", rows(r))
    s : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 1; SELECT 2", Sql.none())
    say("two statements", rows(s))
    t : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 1; -- done", Sql.none())
    say("trailing comment", rows(t))
    u : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "  -- nothing", Sql.none())
    say("no statement", rows(u))
    v : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELEC 1", Sql.none())
    say("syntax", rows(v))
    w : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "BEGIN", Sql.none())
    say("sql begin", changes(w))
    x : Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>> <- Sql.get(db, "SELECT * FROM u WHERE name = ?", p([Sql.text("nobody")]))
    say("get none", got(x))
    y : Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>> <- Sql.get(db, "SELECT name, length(name) AS len FROM u", Sql.none())
    say("get some", got(y))
    z : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(db, "CREATE TABLE z (a); BOGUS")
    say("exec error", unit(z))
    aa : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT name AS n FROM u", Sql.none())
    say("decode ok", decoded(Result.bind(&2, &2, Sql.Error, Sql.Rows, List<&2, S.Value>, aa, rs => Sql.decode_rows(schema(), rs))))
    bb : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 1 AS n", Sql.none())
    say("decode mismatch", decoded(Result.bind(&2, &2, Sql.Error, Sql.Rows, List<&2, S.Value>, bb, rs => Sql.decode_rows(schema(), rs))))

def insert_then_abort(+tx: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Unit>):
  do IO<Result<&2, &2, Sql.Error, Unit>>:
    r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "INSERT INTO u VALUES ('rolled back')", Sql.none())
    return Fail{Sql.abort("stop")}

def insert_then_fail(+tx: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Unit>):
  do IO<Result<&2, &2, Sql.Error, Unit>>:
    r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "INSERT INTO u VALUES ('also rolled back')", Sql.none())
    s : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "INSERT INTO u VALUES ('x')", Sql.none())
    return Result.bind(&2, &2, Sql.Error, Sql.Changes, Unit, s, ch => Done{Unit{}})

def insert_kept(+tx: Sql.Db) -> IO(Result<&2, &2, Sql.Error, String>):
  do IO<Result<&2, &2, Sql.Error, String>>:
    r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "INSERT INTO u VALUES ('kept')", Sql.none())
    return Done{changes(r)}

def kept(r: Result<&2, &2, Sql.Error, String>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{s}: "committed " ++ s

def transactions(+db: Sql.Db) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Unit> <- Sql.transaction(Unit, db, tx => insert_then_abort(tx))
    say("tx abort", unit(a))
    b : Result<&2, &2, Sql.Error, Unit> <- Sql.transaction(Unit, db, tx => insert_then_fail(tx))
    say("tx constraint", unit(b))
    c : Result<&2, &2, Sql.Error, String> <- Sql.transaction(String, db, tx => insert_kept(tx))
    say("tx commit", kept(c))
    d : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT name FROM u ORDER BY name", Sql.none())
    say("after tx", rows(d))
    e : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.begin(db)
    +tx : Sql.Db <- db_or_die(e)
    f : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "INSERT INTO u VALUES ('manual')", Sql.none())
    say("manual insert", changes(f))
    g : Result<&2, &2, Sql.Error, Unit> <- Sql.rollback(tx)
    say("manual rollback", unit(g))
    h : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "INSERT INTO u VALUES ('stale')", Sql.none())
    say("stale tx", changes(h))
    i : Result<&2, &2, Sql.Error, Unit> <- Sql.commit(tx)
    say("stale commit", unit(i))
    j : Result<&2, &2, Sql.Error, Unit> <- Sql.commit(db)
    say("commit without tx", unit(j))
    k : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.begin(db)
    +tx2 : Sql.Db <- db_or_die(k)
    l : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx2, "COMMIT", Sql.none())
    say("sql commit", changes(l))
    m : Result<&2, &2, Sql.Error, Unit> <- Sql.rollback(tx2)
    say("rollback after sql commit", unit(m))

def stmt_text(r: Result<&2, &2, Sql.Error, Sql.Stmt>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{s}: "prepared"

def statements(+db: Sql.Db) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Stmt> <- Sql.prepare(db, "INSERT INTO u VALUES (?)")
    +st : Sql.Stmt <- stmt_or_die(a)
    b : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run_stmt(db, st, p([Sql.text("p1")]))
    say("stmt 1", changes(b))
    c : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run_stmt(db, st, p([Sql.text("p2")]))
    say("stmt 2", changes(c))
    d : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run_stmt(db, st, p([Sql.text("p1")]))
    say("stmt dup", changes(d))
    e : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run_stmt(db, st, p([]))
    say("stmt missing", changes(e))
    f : Result<&2, &2, Sql.Error, Sql.Stmt> <- Sql.prepare(db, "SELECT name FROM u WHERE name LIKE ? ORDER BY name")
    +q : Sql.Stmt <- stmt_or_die(f)
    g : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all_stmt(db, q, p([Sql.text("p%")]))
    say("stmt select", rows(g))
    h : Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>> <- Sql.get_stmt(db, q, p([Sql.text("k%")]))
    say("stmt get", got(h))
    i : Result<&2, &2, Sql.Error, Unit> <- Sql.finalize(st)
    say("finalize", unit(i))
    j : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run_stmt(db, st, p([Sql.text("p3")]))
    say("finalized use", changes(j))
    k : Result<&2, &2, Sql.Error, Unit> <- Sql.finalize(st)
    say("finalize twice", unit(k))
    l : Result<&2, &2, Sql.Error, Sql.Stmt> <- Sql.prepare(db, "SELECT 1; SELECT 2")
    say("prepare two", stmt_text(l))

# Fixes from review round 1 (BND-38). Each section prints what a bug changed.

# A transaction-control statement is refused before it runs, in a statement
# and anywhere in a script, so nothing it would commit is committed.
def control(+db: Sql.Db) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(db, "CREATE TABLE c (x)")
    say("control schema", unit(a))
    b : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.begin(db)
    +tx : Sql.Db <- db_or_die(b)
    c : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "INSERT INTO c VALUES ('in tx')", Sql.none())
    say("control insert", changes(c))
    d : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "COMMIT", Sql.none())
    say("tx sql commit", changes(d))
    e : Result<&2, &2, Sql.Error, Unit> <- Sql.rollback(tx)
    say("rollback after refused commit", unit(e))
    f : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT count(*) FROM c", Sql.none())
    say("rows after refused commit", rows(f))
    g : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.begin(db)
    +tx2 : Sql.Db <- db_or_die(g)
    h : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(tx2, "INSERT INTO c VALUES ('script'); COMMIT; BEGIN")
    say("tx script commit", unit(h))
    i : Result<&2, &2, Sql.Error, Unit> <- Sql.rollback(tx2)
    say("rollback after script", unit(i))
    j : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT count(*) FROM c", Sql.none())
    say("rows after script", rows(j))
    k : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(db, "BEGIN; INSERT INTO c VALUES ('own transaction'); COMMIT")
    say("script with its own transaction", unit(k))
    l : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT count(*) FROM c", Sql.none())
    say("rows after own transaction", rows(l))
    m : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "  /* note */ -- line\n  savepoint s", Sql.none())
    say("savepoint", changes(m))
    n : Result<&2, &2, Sql.Error, Sql.Stmt> <- Sql.prepare(db, "end")
    say("prepare end", stmt_text(n))
    o : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 'BEGIN' AS begin_text", Sql.none())
    say("keyword in a value", rows(o))

def began_text(r: Result<&2, &2, Sql.Error, Sql.Db>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{d}: "began"

def waiting_begin(db: Sql.Db) -> IO(String):
  do IO<String>:
    r : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.begin(db)
    return began_text(r)

# A begin still waiting when its connection closes must not touch the
# connection that reuses the slot.
def reopen(+busy: Sql.Options) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open_with(":memory:", busy)
    +db : Sql.Db <- db_or_die(a)
    b : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.begin(db)
    say("first begin", began_text(b))
    ch : Chan(String) <- IO.fork(String, waiting_begin(db))
    IO.sleep(30)
    c : Result<&2, &2, Sql.Error, Unit> <- Sql.close(db)
    say("close with a begin waiting", unit(c))
    d : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open_with(":memory:", busy)
    +db2 : Sql.Db <- db_or_die(d)
    w : String <- IO.join(String, ch)
    say("waiting begin", w)
    e : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db2, "SELECT 1", Sql.none())
    say("reopened slot", rows(e))
    f : Result<&2, &2, Sql.Error, Unit> <- Sql.close(db2)
    say("reopened close", unit(f))

def slow(tx: Sql.Db) -> IO(String):
  do IO<String>:
    r : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(tx, "WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c WHERE x < 3000000) SELECT count(*) FROM c", Sql.none())
    return rows(r)

# Commit waits for the transaction's statement in flight, past the busy
# timeout, and the connection is free afterwards.
def inflight(+busy: Sql.Options) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open_with(":memory:", busy)
    +db : Sql.Db <- db_or_die(a)
    b : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.begin(db)
    +tx : Sql.Db <- db_or_die(b)
    ch : Chan(String) <- IO.fork(String, slow(tx))
    IO.sleep(10)
    c : Result<&2, &2, Sql.Error, Unit> <- Sql.commit(tx)
    say("commit with a statement in flight", unit(c))
    s : String <- IO.join(String, ch)
    say("statement in flight", s)
    d : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 1", Sql.none())
    say("after commit", rows(d))
    e : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.begin(db)
    +tx2 : Sql.Db <- db_or_die(e)
    ch2 : Chan(String) <- IO.fork(String, slow(tx2))
    IO.sleep(10)
    f : Result<&2, &2, Sql.Error, Unit> <- Sql.rollback(tx2)
    say("rollback with a statement in flight", unit(f))
    s2 : String <- IO.join(String, ch2)
    say("statement in flight", s2)
    g : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 1", Sql.none())
    say("after rollback", rows(g))
    h : Result<&2, &2, Sql.Error, Unit> <- Sql.close(db)
    say("inflight close", unit(h))

# A prepared statement that SQLite recompiles after a schema change reports
# its new columns.
def reprepare(+db: Sql.Db) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(db, "CREATE TABLE m (a); INSERT INTO m VALUES (1)")
    say("reprepare schema", unit(a))
    b : Result<&2, &2, Sql.Error, Sql.Stmt> <- Sql.prepare(db, "SELECT * FROM m")
    +st : Sql.Stmt <- stmt_or_die(b)
    c : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all_stmt(db, st, p([]))
    say("before alter", rows(c))
    d : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(db, "ALTER TABLE m ADD COLUMN b DEFAULT 2")
    say("alter", unit(d))
    e : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all_stmt(db, st, p([]))
    say("after alter", rows(e))
    f : Result<&2, &2, Sql.Error, Sql.Stmt> <- Sql.prepare(db, "SELECT * FROM m WHERE a = 0")
    +empty : Sql.Stmt <- stmt_or_die(f)
    g : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(db, "ALTER TABLE m ADD COLUMN c DEFAULT 3")
    say("alter again", unit(g))
    h : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all_stmt(db, empty, p([]))
    say("no rows after alter", rows(h))

# A result past its byte budget, or a text or blob cell past the per-cell
# one, fails with code 18 instead of being copied.
def budgets(+caps: Sql.Options) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open_with(":memory:", caps)
    +db : Sql.Db <- db_or_die(a)
    b : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 'abcde', 1234567", Sql.none())
    say("at both caps", rows(b))
    c : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 'abcdefg'", Sql.none())
    say("text past the cell cap", rows(c))
    d : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT zeroblob(7)", Sql.none())
    say("blob past the cell cap", rows(d))
    e : Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>> <- Sql.get(db, "SELECT 'abcdefg'", Sql.none())
    say("get past the cell cap", got(e))
    f : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 'abcd' UNION ALL SELECT 'efgh' UNION ALL SELECT 'ijkl' UNION ALL SELECT 'm'", Sql.none())
    say("rows past the result cap", rows(f))
    g : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 'abcd', 'efgh', 'ijkl'", Sql.none())
    say("rows at the result cap", rows(g))
    h : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "SELECT 'abcdefghijklmnop'", Sql.none())
    say("run drops rows", changes(h))
    i : Result<&2, &2, Sql.Error, Unit> <- Sql.close(db)
    say("budgets close", unit(i))

# Reading rows fails with the first bad row, numbered from 0.
def row_order(+db: Sql.Db) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 'a' AS n UNION ALL SELECT 2 UNION ALL SELECT 1e999", Sql.none())
    say("json row index", as_json(a))
    b : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 'a' AS n UNION ALL SELECT 2 UNION ALL SELECT 1e999", Sql.none())
    say("decode row index", decoded(Result.bind(&2, &2, Sql.Error, Sql.Rows, List<&2, S.Value>, b, rs => Sql.decode_rows(schema(), rs))))

def hardening(+db: Sql.Db) -> IO(Unit):
  do IO<Unit>:
    control(db)
    reprepare(db)
    row_order(db)
    reopen(Sql.Options{Sql.ReadWriteCreate{}, 300, 10, 1000, 1000})
    inflight(Sql.Options{Sql.ReadWriteCreate{}, 50, 10, 1000, 1000})
    budgets(Sql.Options{Sql.ReadWriteCreate{}, 100, 10, 12, 6})

def opened(r: Result<&2, &2, Sql.Error, Sql.Db>) -> String:
  match r:
    case Fail{e}: error_text(e)
    case Done{db}: "opened"

def limits(+dir: String) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open_with(":memory:", Sql.Options{Sql.ReadWriteCreate{}, 100, 2, 1000, 1000})
    +db : Sql.Db <- db_or_die(a)
    b : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 1 UNION ALL SELECT 2", Sql.none())
    say("two rows", rows(b))
    c : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3", Sql.none())
    say("three rows", rows(c))
    d : Result<&2, &2, Sql.Error, Unit> <- Sql.close(db)
    say("close", unit(d))
    e : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT 1", Sql.none())
    say("closed use", rows(e))
    f : Result<&2, &2, Sql.Error, Unit> <- Sql.close(db)
    say("close twice", unit(f))
    g : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open_with(dir ++ "/missing.db", Sql.Options{Sql.ReadOnly{}, 100, 10, 1000, 1000})
    say("open missing", opened(g))
    h : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open(dir ++ "/file.db")
    +fdb : Sql.Db <- db_or_die(h)
    i : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(fdb, "CREATE TABLE IF NOT EXISTS f (a)")
    say("file schema", unit(i))
    j : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open_with(dir ++ "/file.db", Sql.Options{Sql.ReadOnly{}, 100, 10, 1000, 1000})
    +ro : Sql.Db <- db_or_die(j)
    k : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(ro, "INSERT INTO f VALUES (1)", Sql.none())
    say("read-only write", changes(k))
    l : Result<&2, &2, Sql.Error, Unit> <- Sql.close(ro)
    m : Result<&2, &2, Sql.Error, Unit> <- Sql.close(fdb)
    say("closed files", unit(m))

def everything(+dir: String) -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open(":memory:")
    +db : Sql.Db <- db_or_die(a)
    values(db)
    injection(db)
    errors(db)
    transactions(db)
    statements(db)
    limits(dir)
    hardening(db)

def only_open() -> IO(Unit):
  do IO<Unit>:
    a : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open(":memory:")
    say("open", opened(a))

def pick(+dir: String, open: Bool) -> IO(Unit):
  match open:
    case True{}: only_open()
    case False{}: everything(dir)

def run(args: List<String>) -> IO(Unit):
  match args:
    case program <> +dir <> rest: pick(dir, String.eq(dir, "--open"))
    case _: IO.die(Unit, 2, "usage: parity DIR | parity --open")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
