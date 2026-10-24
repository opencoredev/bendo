import Base
import ../../src/main.bend as B
import ../../src/app/store.bend as Store
import ../../src/app/store_actor.bend as StoreActor
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
  Env{counter: B.Store(U32), todos: B.Store(List<&2, Todo>), dead: B.Store(U32), silent: B.Store(U32), full: B.Store(U32), late: B.Store(U32), gate: Chan(Unit)}

type Tag is Data:
  ReadCounter{}
  AddCounter{}
  SetCounter{}
  ReadTodos{}
  Put{}
  ResetTodos{}
  HandlerError{}
  Dead{}
  Silent{}
  Full{}
  Late{}
  Release{}
  ReadLate{}
  Budget{}
  ClosedReply{}

def number(+c: B.Ctx, result: Result<&2, &2, Store.Error, U32>) -> B.Res:
  match result:
    case Done{n}: B.text(c, U32.show(n))
    case Fail{Store.Unavailable{}}: B.text(B.status(c, 503), "unavailable")
    case Fail{Store.TimedOut{}}: B.text(B.status(c, 503), "timed out")

def unit_result(c: B.Ctx, result: Result<&2, &2, Store.Error, Unit>) -> B.Res:
  match result:
    case Done{u}: B.text(c, "set")
    case Fail{e}: B.text(B.status(c, 503), "unavailable")

def todo_text(todos: List<&2, Todo>) -> List<&2, String>:
  match todos:
    case Nil{}: []
    case Todo{id, title} <> tail:
      (U32.show(id) ++ ":" ++ title) <> todo_text(tail)

def todos_result(c: B.Ctx, result: Result<&2, &2, Store.Error, List<&2, Todo>>) -> B.Res:
  match result:
    case Done{todos}: B.text(c, String.join(todo_text(todos), "|"))
    case Fail{e}: B.text(B.status(c, 503), "unavailable")

def finish_unanswered(got: Maybe<&1, Store.Message<U32>>, close_reply: Bool) -> IO(Unit):
  match got close_reply:
    case Some{Store.Get{channel}} True{}: Chan.close(U32, channel)
    case _ _: IO.pure(Unit, Unit{})

def budget_result(c: B.Ctx, result: Result<&2, &2, Store.Error, U32>, elapsed: Nat) -> B.Res:
  match result:
    case Fail{Store.TimedOut{}}: B.text(c, Nat.show(elapsed))
    case _: B.text(B.status(c, 500), "expected timeout")

# Fault injection: accept a queued get after delay, then never answer (or close).
def unanswered(+requests: Chan(Store.Message<U32>), delay: U32, close_reply: Bool) -> IO(Unit):
  do IO<Unit>:
    IO.sleep(delay)
    got : Maybe<&1, Store.Message<U32>> <- Chan.recv(Store.Message<U32>, requests)
    finish_unanswered(got, close_reply)

def todo_count(c: B.Ctx, result: Result<&2, &2, Store.Error, List<&2, Todo>>) -> B.Res:
  match result:
    case Done{todos}: B.text(c, Nat.show(List.length(&2, Todo, todos)))
    case Fail{e}: B.text(B.status(c, 503), "unavailable")

def respond(tag: Tag, +c: B.Ctx, env: Env) -> IO(B.Res):
  match tag env:
    case ReadCounter{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_get(U32, counter)
        return number(c, r)
    case AddCounter{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_update(U32, counter, increment)
        return number(c, r)
    case SetCounter{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, Unit> <- B.store_set(U32, counter, Maybe.default(&2, U32, U32.read(Maybe.default(&2, String, B.query(c, "n"), "0")), 0))
        return unit_result(c, r)
    case ReadTodos{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, List<&2, Todo>> <- B.store_get(List<&2, Todo>, todos)
        return todos_result(c, r)
    case Put{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        title : String = Maybe.default(&2, String, B.query(c, "title"), "first")
        r : Result<&2, &2, Store.Error, List<&2, Todo>> <- B.store_update(List<&2, Todo>, todos, state => put_todo(state, 1, title))
        return todo_count(c, r)
    case ResetTodos{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, Unit> <- B.store_set(List<&2, Todo>, todos, [])
        return unit_result(c, r)
    case HandlerError{} Env{counter, todos, dead, silent, full, late, gate}:
      # A real failed response after a successful state mutation.
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_update(U32, counter, increment)
        return B.text(B.status(c, 500), "handler failed")
    case Dead{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_get(U32, dead)
        return number(c, r)
    case Silent{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_get(U32, silent)
        return number(c, r)
    case Full{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_get(U32, full)
        return number(c, r)
    case Late{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_update(U32, late, increment)
        return number(c, r)
    case Release{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        Store.reply(Unit, gate, Unit{})
        return B.text(c, "released")
    case ReadLate{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_get(U32, late)
        return number(c, r)

    case Budget{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        +requests : Chan(Store.Message<U32>) <- Chan.new(Store.Message<U32>, 0)
        IO.spawn(Unit, unanswered(requests, 1000, False{}))
        begin : Nat <- IO.now()
        r : Result<&2, &2, Store.Error, U32> <- Store.get(U32, Store.Store{requests, 1500})
        end : Nat <- IO.now()
        return budget_result(c, r, Nat.sub(end, begin))
    case ClosedReply{} Env{counter, todos, dead, silent, full, late, gate}:
      do IO<B.Res>:
        +requests : Chan(Store.Message<U32>) <- Chan.new(Store.Message<U32>, 0)
        IO.spawn(Unit, unanswered(requests, 0, True{}))
        r : Result<&2, &2, Store.Error, U32> <- Store.get(U32, Store.Store{requests, 100})
        return number(c, r)

def dispatch(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  respond(tag, c, env)

def ready(env: Env, result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "bad store routes")
    case Done{table}: B.serve(~Tag, ~Env, ~dispatch, table, env, B.config())

def gated(gate: Chan(Unit), requests: Chan(Store.Message<U32>)) -> IO(Unit):
  do IO<Unit>:
    open : Maybe<&1, Unit> <- Chan.recv(Unit, gate)
    StoreActor.actor(U32, requests, 0, Store.Receive{})

def main() -> IO(Unit):
  do IO<Unit>:
    counter : B.Store(U32) <- B.store(U32, 0)
    todos : B.Store(List<&2, Todo>) <- B.store(List<&2, Todo>, [])
    +dead : Chan(Store.Message<U32>) <- Chan.new(Store.Message<U32>, 1)
    Chan.close(Store.Message<U32>, dead)
    silent : Chan(Store.Message<U32>) <- Chan.new(Store.Message<U32>, 1)
    full : Chan(Store.Message<U32>) <- Chan.new(Store.Message<U32>, 0)
    +late : Chan(Store.Message<U32>) <- Chan.new(Store.Message<U32>, 128)
    +gate : Chan(Unit) <- Chan.new(Unit, 1)
    IO.spawn(Unit, gated(gate, late))
    ready(Env{counter, todos, Store.Store{dead, 100}, Store.Store{silent, 100}, Store.Store{full, 100}, Store.Store{late, 100}, gate}, B.routes(Tag, [
      B.get(Tag, "/counter", ReadCounter{}), B.post(Tag, "/counter", AddCounter{}), B.put(Tag, "/counter", SetCounter{}),
      B.get(Tag, "/todos", ReadTodos{}), B.post(Tag, "/todos", Put{}), B.delete(Tag, "/todos", ResetTodos{}),
      B.get(Tag, "/error", HandlerError{}), B.get(Tag, "/dead", Dead{}), B.get(Tag, "/silent", Silent{}),
      B.get(Tag, "/full", Full{}), B.post(Tag, "/late", Late{}), B.post(Tag, "/release", Release{}), B.get(Tag, "/late", ReadLate{}), B.get(Tag, "/budget", Budget{}), B.get(Tag, "/closed-reply", ClosedReply{})
    ]))
