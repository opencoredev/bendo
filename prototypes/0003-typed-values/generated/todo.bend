# Generated from schema.bend by generate.js. Do not edit.
import Base
import ./value.bend as V

type Todo is Data:
  Todo{title: String, done: Bool, due: Maybe<&2, String>}

def known(+name: String) -> Bool:
  String.eq(name, "title") || String.eq(name, "done") || String.eq(name, "due")

def known_fields(fields: List<&2, V.JsonField>) -> Bool:
  match fields:
    case Nil{}:
      True{}
    case V.JsonField{name, value} <> rest:
      known(name) && known_fields(rest)

def decode_object(+fields: List<&2, V.JsonField>, +mode: V.DecodeMode) -> Result<&2, &2, String, Todo>:
  do Result<&2, &2, String, Todo>:
    _ : Unit <- V.require_known(known_fields(fields))
    title : String <- V.read_string(V.lookup(fields, "title"))
    done : Bool <- V.read_flag(V.lookup(fields, "done"), mode)
    due : Maybe<&2, String> <- V.read_optional_string(V.lookup(fields, "due"))
    return Todo{title, done, due}

def decode(value: V.JsonValue, mode: V.DecodeMode) -> Result<&2, &2, String, Todo>:
  match value:
    case V.JsonObject{fields}:
      decode_object(fields, mode)
    case _:
      Fail{"expected object"}
