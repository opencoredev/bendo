import Base
import ../../src/main.bend as B
import ../../src/app/store.bend as Store
import ../../src/router/methods.bend as Methods

def increment(count: U32) -> U32:
  (count + 1 : U32)

type Todo is Data:
  Todo{id: U32, title: String}

def keep(todo: Todo, rest: List<&2, Todo>, same: Bool) -> List<&2, Todo>:
  match same:
    case True{}: rest
    case False{}: todo <> rest

def without(todos: List<&2, Todo>, +id: U32) -> List<&2, Todo>:
  match todos:
    case Nil{}: []
    case Todo{+key, title} <> tail:
      keep(Todo{key, title}, without(tail, id), U32.is_eq(key, id))

def put_todo(todos: List<&2, Todo>, +id: U32, title: String) -> List<&2, Todo>:
  Todo{id, title} <> without(todos, id)

type Env is Data:
  Env{counter: B.Store(U32), todos: B.Store(List<&2, Todo>)}

type Tag is Data:
  ReadCounter{}
  AddCounter{}
  ReadTodos{}
  Put{}

def number(+c: B.Ctx, result: Result<&2, &2, Store.Error, U32>) -> B.Res:
  match result:
    case Done{n}: B.text(c, U32.show(n))
    case Fail{Store.Unavailable{}}: B.text(B.status(c, 503), "unavailable")
    case Fail{Store.TimedOut{}}: B.text(B.status(c, 503), "timed out")

def todo_text(todos: List<&2, Todo>) -> List<&2, String>:
  match todos:
    case Nil{}: []
    case Todo{id, title} <> tail:
      (U32.show(id) ++ ":" ++ title) <> todo_text(tail)

def todos_result(c: B.Ctx, result: Result<&2, &2, Store.Error, List<&2, Todo>>) -> B.Res:
  match result:
    case Done{todos}: B.text(c, String.join(todo_text(todos), "|"))
    case Fail{e}: B.text(B.status(c, 503), "unavailable")

def todo_count(c: B.Ctx, result: Result<&2, &2, Store.Error, List<&2, Todo>>) -> B.Res:
  match result:
    case Done{todos}: B.text(c, Nat.show(List.length(&2, Todo, todos)))
    case Fail{e}: B.text(B.status(c, 503), "unavailable")

def respond(tag: Tag, +c: B.Ctx, env: Env) -> IO(B.Res):
  match tag env:
    case ReadCounter{} Env{counter, todos}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_get(U32, counter)
        return number(c, r)
    case AddCounter{} Env{counter, todos}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_update(U32, counter, increment)
        return number(c, r)
    case ReadTodos{} Env{counter, todos}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, List<&2, Todo>> <- B.store_get(List<&2, Todo>, todos)
        return todos_result(c, r)
    case Put{} Env{counter, todos}:
      do IO<B.Res>:
        title : String = Maybe.default(&2, String, B.query(c, "title"), "first")
        r : Result<&2, &2, Store.Error, List<&2, Todo>> <- B.store_update(List<&2, Todo>, todos, state => put_todo(state, 1, title))
        return todo_count(c, r)

def dispatch(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  respond(tag, c, env)

def ready(env: Env, result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "bad store routes")
    case Done{table}: B.serve(~Tag, ~Env, ~dispatch, table, env, B.config())

def main() -> IO(Unit):
  do IO<Unit>:
    counter : B.Store(U32) <- B.store(U32, 0)
    todos : B.Store(List<&2, Todo>) <- B.store(List<&2, Todo>, [])
    ready(Env{counter, todos}, B.routes(Tag, [
      B.get(Tag, "/counter", ReadCounter{}), B.post(Tag, "/counter", AddCounter{}),
      B.get(Tag, "/todos", ReadTodos{}), B.post(Tag, "/todos", Put{})
    ]))
