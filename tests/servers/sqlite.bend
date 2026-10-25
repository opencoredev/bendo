# A compiled server doing CRUD over HTTP on SQLite (BND-38). The database
# path comes from BENDO_SQLITE_DB.
import Base
import ../../src/main.bend as B
import ../../src/sqlite.bend as Sql
import ../../src/data/json.bend as J
import ../../src/data/schema.bend as S
import ../../src/data/hex.bend as Hex
import ../../src/router/methods.bend as Methods

type Env is Data:
  Env{db: Sql.Db, insert: Sql.Stmt}

type Tag is Data:
  CreateUser{}
  ListUsers{}
  ReadUser{}
  UpdateUser{}
  DeleteUser{}
  Search{}
  FindText{}
  FindInteger{}
  PutValue{}
  ReadValue{}
  Transfer{}
  Accounts{}
  Mismatch{}
  SlowTransaction{}

def schema_sql() -> String:
  "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE);
   CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, v);
   CREATE TABLE IF NOT EXISTS accounts (name TEXT PRIMARY KEY, balance INTEGER NOT NULL CHECK (balance >= 0));
   INSERT OR IGNORE INTO accounts VALUES ('alice', 100), ('bob', 0);"

def user_schema() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"id", S.IntegerSchema{Some{"1"}, None{}}, S.Required{}},
    S.Field{"name", S.StringSchema{0n, None{}, None{}, S.Plain{}}, S.Required{}},
    S.Field{"email", S.NullableSchema{S.StringSchema{0n, None{}, None{}, S.Plain{}}}, S.Required{}}
  ], S.Strict{}}

# The users table read with the wrong schema: name must be an integer.
def wrong_schema() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"id", S.IntegerSchema{None{}, None{}}, S.Required{}},
    S.Field{"name", S.IntegerSchema{None{}, None{}}, S.Required{}},
    S.Field{"email", S.NullableSchema{S.StringSchema{0n, None{}, None{}, S.Plain{}}}, S.Required{}}
  ], S.Strict{}}

def error_json(+e: Sql.Error) -> J.Json:
  J.JObject{[J.Field{"code", J.JNumber{U32.show(Sql.code(e))}}, J.Field{"message", J.JString{Sql.message(e)}}]}

def failure_status(+c: B.Ctx, +e: Sql.Error, constraint: Bool) -> B.Res:
  match constraint:
    case True{}: B.json(B.status(c, 409), error_json(e))
    case False{}: B.json(B.status(c, 400), error_json(e))

def failure(+c: B.Ctx, +e: Sql.Error) -> B.Res:
  failure_status(c, e, Sql.is_constraint(e))

def changes_json(ch: Sql.Changes) -> J.Json:
  match ch:
    case Sql.Changes{n, rowid}: J.JObject{[J.Field{"changes", J.JNumber{Nat.show(n)}}, J.Field{"rowid", J.JNumber{rowid}}]}

def changed(+c: B.Ctx, r: Result<&2, &2, Sql.Error, Sql.Changes>) -> B.Res:
  match r:
    case Fail{e}: failure(c, e)
    case Done{ch}: B.json(c, changes_json(ch))

# 404 when the statement changed nothing.
def touched(+c: B.Ctx, r: Result<&2, &2, Sql.Error, Sql.Changes>) -> B.Res:
  match r:
    case Fail{e}: failure(c, e)
    case Done{Sql.Changes{0n, rowid}}: B.text(B.status(c, 404), "no such user")
    case Done{ch}: B.json(c, changes_json(ch))

def json_list(+c: B.Ctx, r: Result<&2, &2, Sql.Error, List<&2, J.Json>>) -> B.Res:
  match r:
    case Fail{e}: B.json(B.status(c, 500), error_json(e))
    case Done{xs}: B.json(c, J.JArray{xs})

def listed(+c: B.Ctx, r: Result<&2, &2, Sql.Error, Sql.Rows>) -> B.Res:
  match r:
    case Fail{e}: failure(c, e)
    case Done{rows}: json_list(c, Sql.rows_json(rows))

def first_json(+c: B.Ctx, r: Result<&2, &2, Sql.Error, List<&2, J.Json>>) -> B.Res:
  match r:
    case Fail{e}: B.json(B.status(c, 500), error_json(e))
    case Done{Nil{}}: B.text(B.status(c, 404), "no such key")
    case Done{x <> t}: B.json(c, x)

def first_listed(+c: B.Ctx, r: Result<&2, &2, Sql.Error, Sql.Rows>) -> B.Res:
  match r:
    case Fail{e}: failure(c, e)
    case Done{rows}: first_json(c, Sql.rows_json(rows))

def decoded_user(+c: B.Ctx, r: Result<&2, &2, Sql.Error, S.Value>) -> B.Res:
  match r:
    case Fail{e}: B.json(B.status(c, 500), error_json(e))
    case Done{v}: B.json(c, S.to_json(v))

def read_user(+c: B.Ctx, r: Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>>) -> B.Res:
  match r:
    case Fail{e}: failure(c, e)
    case Done{None{}}: B.text(B.status(c, 404), "no such user")
    case Done{Some{row}}: decoded_user(c, Sql.decode_row(user_schema(), row))

def mismatch_result(+c: B.Ctx, r: Result<&2, &2, Sql.Error, List<&2, S.Value>>) -> B.Res:
  match r:
    case Fail{Sql.RowError{n, es}}: B.json(B.status(c, 500), J.JObject{[J.Field{"row", J.JNumber{Nat.show(n)}}, J.Field{"errors", S.errors_json(es)}]})
    case Fail{e}: B.json(B.status(c, 500), error_json(e))
    case Done{vs}: B.text(c, "decoded")

def mismatched(+c: B.Ctx, r: Result<&2, &2, Sql.Error, Sql.Rows>) -> B.Res:
  match r:
    case Fail{e}: failure(c, e)
    case Done{rows}: mismatch_result(c, Sql.decode_rows(wrong_schema(), rows))

def or_null(m: Maybe<&2, String>) -> Sql.Value:
  match m:
    case None{}: Sql.null()
    case Some{s}: Sql.text(s)

def blob_of(m: Maybe<&2, List<&2, U32>>) -> Sql.Value:
  match m:
    case None{}: Sql.text("bad hex")
    case Some{xs}: Sql.blob(xs)

def typed_pick(+value: String, int: Bool, real: Bool, null: Bool, blob: Bool) -> Sql.Value:
  match int real null blob:
    case True{} _ _ _: Sql.integer_text(value)
    case False{} True{} _ _: Sql.real(value)
    case False{} False{} True{} _: Sql.null()
    case False{} False{} False{} True{}: blob_of(Hex.decode(value))
    case False{} False{} False{} False{}: Sql.text(value)

def typed(+kind: String, +value: String) -> Sql.Value:
  typed_pick(value, String.eq(kind, "int"), String.eq(kind, "real"), String.eq(kind, "null"), String.eq(kind, "blob"))

def arg(+c: B.Ctx, name: String) -> String:
  Maybe.default(&2, String, B.query(c, name), "")

def path_id(+c: B.Ctx) -> String:
  Maybe.default(&2, String, B.param(c, "id"), "")

# The body of a transfer: debit, optionally fail, credit.
def unit_of(r: Result<&2, &2, Sql.Error, Sql.Changes>) -> Result<&2, &2, Sql.Error, Unit>:
  match r:
    case Fail{e}: Fail{e}
    case Done{ch}: Done{Unit{}}

def credit(+to: String, +amount: String, +fail: String, +tx: Sql.Db, abort: Bool, constraint: Bool) -> IO(Result<&2, &2, Sql.Error, Unit>):
  match abort constraint:
    case True{} _: IO.pure(Result<&2, &2, Sql.Error, Unit>, Fail{Sql.abort("transfer aborted")})
    case False{} True{}:
      do IO<Result<&2, &2, Sql.Error, Unit>>:
        r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "INSERT INTO accounts VALUES (?, 0)", Sql.positional([Sql.text(to)]))
        return unit_of(r)
    case False{} False{}:
      do IO<Result<&2, &2, Sql.Error, Unit>>:
        r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "UPDATE accounts SET balance = balance + ? WHERE name = ?", Sql.positional([Sql.integer_text(amount), Sql.text(to)]))
        return unit_of(r)

def after_debit(+to: String, +amount: String, +fail: String, +tx: Sql.Db, d: Result<&2, &2, Sql.Error, Sql.Changes>) -> IO(Result<&2, &2, Sql.Error, Unit>):
  match d:
    case Fail{e}: IO.pure(Result<&2, &2, Sql.Error, Unit>, Fail{e})
    case Done{ch}: credit(to, amount, fail, tx, String.eq(fail, "abort"), String.eq(fail, "constraint"))

def debit_credit(+from: String, +to: String, +amount: String, +fail: String, +tx: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Unit>):
  do IO<Result<&2, &2, Sql.Error, Unit>>:
    d : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "UPDATE accounts SET balance = balance - ? WHERE name = ?", Sql.positional([Sql.integer_text(amount), Sql.text(from)]))
    after_debit(to, amount, fail, tx, d)

def transferred(+c: B.Ctx, r: Result<&2, &2, Sql.Error, Unit>) -> B.Res:
  match r:
    case Fail{Sql.Abort{m}}: B.text(B.status(c, 422), m)
    case Fail{e}: failure(c, e)
    case Done{u}: B.text(c, "ok")

# Holds a transaction open for ms milliseconds after its write.
def slow_body(+ms: U32, +tx: Sql.Db) -> IO(Result<&2, &2, Sql.Error, Unit>):
  do IO<Result<&2, &2, Sql.Error, Unit>>:
    r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(tx, "UPDATE accounts SET balance = balance + 1000 WHERE name = 'bob'", Sql.none())
    IO.sleep(ms)
    return unit_of(r)

def respond(tag: Tag, +c: B.Ctx, env: Env) -> IO(B.Res):
  match tag env:
    case CreateUser{} Env{+db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run_stmt(db, insert, Sql.positional([Sql.text(arg(c, "name")), or_null(B.query(c, "email"))]))
        return changed(c, r)
    case ListUsers{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT id, name, email FROM users ORDER BY id", Sql.none())
        return listed(c, r)
    case ReadUser{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Maybe<&2, Sql.Row>> <- Sql.get(db, "SELECT id, name, email FROM users WHERE id = ?", Sql.positional([Sql.integer_text(path_id(c))]))
        return read_user(c, r)
    case UpdateUser{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "UPDATE users SET name = :name WHERE id = :id", Sql.named([Sql.bind(":name", Sql.text(arg(c, "name"))), Sql.bind(":id", Sql.integer_text(path_id(c)))]))
        return touched(c, r)
    case DeleteUser{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "DELETE FROM users WHERE id = ?", Sql.positional([Sql.integer_text(path_id(c))]))
        return touched(c, r)
    case Search{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT id, name FROM users WHERE name = :name ORDER BY id", Sql.named([Sql.bind(":name", Sql.text(arg(c, "name")))]))
        return listed(c, r)
    case FindText{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT id, name FROM users WHERE id = ?", Sql.positional([Sql.text(arg(c, "id"))]))
        return listed(c, r)
    case FindInteger{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT id, name FROM users WHERE id = ?", Sql.positional([Sql.integer_text(arg(c, "id"))]))
        return listed(c, r)
    case PutValue{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Changes> <- Sql.run(db, "INSERT OR REPLACE INTO kv (key, v) VALUES (?, ?)", Sql.positional([Sql.text(arg(c, "key")), typed(arg(c, "kind"), arg(c, "value"))]))
        return changed(c, r)
    case ReadValue{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT key, typeof(v) AS type, v FROM kv WHERE key = ?", Sql.positional([Sql.text(path_id(c))]))
        return first_listed(c, r)
    case Transfer{} Env{db, insert}:
      do IO<B.Res>:
        +from : String = arg(c, "from")
        +to : String = arg(c, "to")
        +amount : String = arg(c, "amount")
        +fail : String = arg(c, "fail")
        r : Result<&2, &2, Sql.Error, Unit> <- Sql.transaction(Unit, db, tx => debit_credit(from, to, amount, fail, tx))
        return transferred(c, r)
    case Accounts{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT name, balance FROM accounts ORDER BY name", Sql.none())
        return listed(c, r)
    case Mismatch{} Env{db, insert}:
      do IO<B.Res>:
        r : Result<&2, &2, Sql.Error, Sql.Rows> <- Sql.all(db, "SELECT id, name, email FROM users ORDER BY id", Sql.none())
        return mismatched(c, r)
    case SlowTransaction{} Env{db, insert}:
      do IO<B.Res>:
        +ms : U32 = Maybe.default(&2, U32, U32.read(arg(c, "ms")), 300)
        r : Result<&2, &2, Sql.Error, Unit> <- Sql.transaction(Unit, db, tx => slow_body(ms, tx))
        return transferred(c, r)

def dispatch(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  respond(tag, c, env)

def ready(env: Env, result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "bad sqlite routes")
    case Done{table}: B.serve(~Tag, ~Env, ~dispatch, table, env, B.config())

def routes() -> Result<&2, &2, Methods.BuildError, B.Routes(Tag)>:
  B.routes(Tag, [
    B.post(Tag, "/users", CreateUser{}), B.get(Tag, "/users", ListUsers{}),
    B.get(Tag, "/users/:id", ReadUser{}), B.put(Tag, "/users/:id", UpdateUser{}),
    B.delete(Tag, "/users/:id", DeleteUser{}), B.get(Tag, "/search", Search{}),
    B.get(Tag, "/find-text", FindText{}), B.get(Tag, "/find-integer", FindInteger{}),
    B.post(Tag, "/kv", PutValue{}), B.get(Tag, "/kv/:id", ReadValue{}),
    B.post(Tag, "/transfer", Transfer{}), B.get(Tag, "/accounts", Accounts{}),
    B.get(Tag, "/mismatch", Mismatch{}), B.post(Tag, "/slow", SlowTransaction{})
  ])

def started(+db: Sql.Db, r: Result<&2, &2, Sql.Error, Sql.Stmt>) -> IO(Unit):
  match r:
    case Fail{e}: IO.die(Unit, 1, Sql.message(e))
    case Done{insert}: ready(Env{db, insert}, routes())

def with_schema(+db: Sql.Db, r: Result<&2, &2, Sql.Error, Unit>) -> IO(Unit):
  match r:
    case Fail{e}: IO.die(Unit, 1, Sql.message(e))
    case Done{u}:
      do IO<Unit>:
        p : Result<&2, &2, Sql.Error, Sql.Stmt> <- Sql.prepare(db, "INSERT INTO users (name, email) VALUES (?, ?)")
        started(db, p)

def opened(r: Result<&2, &2, Sql.Error, Sql.Db>) -> IO(Unit):
  match r:
    case Fail{e}: IO.die(Unit, 1, Sql.message(e))
    case Done{+db}:
      do IO<Unit>:
        s : Result<&2, &2, Sql.Error, Unit> <- Sql.exec(db, schema_sql())
        with_schema(db, s)

def main() -> IO(Unit):
  do IO<Unit>:
    path : String <- IO.try(String, IO.get_env("BENDO_SQLITE_DB"))
    r : Result<&2, &2, Sql.Error, Sql.Db> <- Sql.open(path)
    opened(r)
