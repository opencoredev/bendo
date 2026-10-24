# The todo list as pure state. The server keeps one State in a B.Store and
# changes it only through these functions, each passed to B.store_update, so
# every change is one atomic step of the store's actor. Each step records the
# todo it touched in `last`, so the handler can answer from the same step
# without a second read that another request could interleave with.
import Base
import ../../src/data/json.bend as J

type Todo is Data:
  Todo{id: U32, title: String, done: Bool}

type State is Data:
  State{next: U32, items: List<&2, Todo>, last: Maybe<&2, Todo>}

# A PATCH: each field the request left out stays as it was.
type Change is Data:
  Change{title: Maybe<&2, String>, done: Maybe<&2, Bool>}

type Show is Data:
  All{}
  Active{}
  Finished{}

# The list starts with three todos, newest first, so the app has something to show.
def seed() -> State:
  State{4, [
    Todo{3, "Try the Bendo todo example", False{}},
    Todo{2, "Read the Bend guide", False{}},
    Todo{1, "Install Bend", True{}}
  ], None{}}

def show_of(text: String) -> Show:
  match text:
    case "active": Active{}
    case "done": Finished{}
    case _: All{}

def keeps(show: Show, done: Bool) -> Bool:
  match show:
    case All{}: True{}
    case Active{}: Bool.not(done)
    case Finished{}: done

def keep(+todo: Todo, rest: List<&2, Todo>, kept: Bool) -> List<&2, Todo>:
  match kept:
    case True{}: todo <> rest
    case False{}: rest

def filter(items: List<&2, Todo>, +show: Show) -> List<&2, Todo>:
  match items:
    case Nil{}: []
    case Todo{id, title, +done} <> tail: keep(Todo{id, title, done}, filter(tail, show), keeps(show, done))

def done_count(items: List<&2, Todo>, acc: Nat) -> Nat:
  match items:
    case Nil{}: acc
    case Todo{id, title, True{}} <> tail: done_count(tail, 1n+acc)
    case Todo{id, title, False{}} <> tail: done_count(tail, acc)

def find(items: List<&2, Todo>, +id: U32) -> Maybe<&2, Todo>:
  match items:
    case Nil{}: None{}
    case Todo{+key, title, done} <> tail: Bool.pick(Maybe<&2, Todo>, U32.is_eq(key, id), Some{Todo{key, title, done}}, find(tail, id))

# New todos go first.
def create(title: String, done: Bool, state: State) -> State:
  match state:
    case State{+next, items, last}:
      +todo = {Todo{next, title, done} : Todo}
      State{(next + 1 : U32), todo <> items, Some{todo}}

def changed(change: Change, todo: Todo) -> Todo:
  match change todo:
    case Change{title, done} Todo{id, old_title, old_done}:
      Todo{id, Maybe.default(&2, String, title, old_title), Maybe.default(&2, Bool, done, old_done)}

def patch_items(items: List<&2, Todo>, +id: U32, +change: Change) -> List<&2, Todo>:
  match items:
    case Nil{}: []
    case Todo{+key, +title, +done} <> tail:
      Bool.pick(Todo, U32.is_eq(key, id), changed(change, Todo{key, title, done}), Todo{key, title, done}) <> patch_items(tail, id, change)

# `last` is the changed todo, or None when no todo has the ID.
def update(+id: U32, +change: Change, state: State) -> State:
  match state:
    case State{next, items, last}:
      +patched = patch_items(items, id, change)
      State{next, patched, find(patched, id)}

def without(items: List<&2, Todo>, +id: U32) -> List<&2, Todo>:
  match items:
    case Nil{}: []
    case Todo{+key, title, done} <> tail:
      keep(Todo{key, title, done}, without(tail, id), Bool.not(U32.is_eq(key, id)))

# `last` is the removed todo, or None when no todo had the ID.
def remove(+id: U32, state: State) -> State:
  match state:
    case State{next, +items, last}:
      State{next, without(items, id), find(items, id)}

def todo_json(todo: Todo) -> J.Json:
  match todo:
    case Todo{id, title, done}:
      J.JObject{[J.Field{"id", J.JNumber{U32.show(id)}}, J.Field{"title", J.JString{title}}, J.Field{"done", J.JBool{done}}]}

def todos_json(items: List<&2, Todo>) -> List<&2, J.Json>:
  match items:
    case Nil{}: []
    case t <> tail: todo_json(t) <> todos_json(tail)

def count_json(n: Nat) -> J.Json:
  J.JNumber{Nat.show(n)}

# GET /api/todos: the kept todos and the counts for every filter.
def list_json(+items: List<&2, Todo>, show: Show) -> J.Json:
  +all = List.length(&2, Todo, items)
  +finished = done_count(items, 0n)
  J.JObject{[
    J.Field{"todos", J.JArray{todos_json(filter(items, show))}},
    J.Field{"counts", J.JObject{[
      J.Field{"all", count_json(all)},
      J.Field{"active", count_json(Nat.sub(all, finished))},
      J.Field{"done", count_json(finished)}
    ]}}
  ]}
