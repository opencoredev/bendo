import Base
import ./schema.bend as S
import ./todo.bend as T
import ./value.bend as V

def due_text(due: Maybe<&2, String>) -> String:
  match due:
    case None{}:
      "none"
    case Some{text}:
      text

# This handler receives a named, statically checked Bend record.
def create_todo(todo: T.Todo) -> String:
  T.Todo{title, done, due} = todo
  "ok:" ++ title ++ ":" ++ Bool.show(done) ++ ":" ++ due_text(due)

def decoded(result: Result<&2, &2, String, T.Todo>) -> String:
  match result:
    case Fail{message}:
      "error:" ++ message
    case Done{todo}:
      create_todo(todo)

def dispatch(tag: S.HandlerTag, value: V.JsonValue, mode: V.DecodeMode) -> String:
  match tag:
    case S.CreateTodo{}:
      decoded(T.decode(value, mode))
