import Base

# An already-parsed JSON tree, not HTTP text or bytes.
type JsonValue is Data:
  JsonString{value: String}
  JsonBool{value: Bool}
  JsonNumber{value: String}
  JsonNull{}
  JsonArray{}
  JsonObject{fields: List<&2, JsonField>}

type JsonField is Data:
  JsonField{name: String, value: JsonValue}

type DecodeMode is Data:
  BodyMode{}
  QueryMode{}
  ResponseMode{}

def choose(value: JsonValue, rest: Maybe<&2, JsonValue>, found: Bool) -> Maybe<&2, JsonValue>:
  match found:
    case True{}:
      Some{value}
    case False{}:
      rest

def lookup(fields: List<&2, JsonField>, +name: String) -> Maybe<&2, JsonValue>:
  match fields:
    case Nil{}:
      None{}
    case JsonField{key, value} <> rest:
      choose(value, lookup(rest, name), String.eq(key, name))

def read_string(value: Maybe<&2, JsonValue>) -> Result<&2, &2, String, String>:
  match value:
    case Some{JsonString{text}}:
      Done{text}
    case _:
      Fail{"expected string"}

def read_optional_string(value: Maybe<&2, JsonValue>) -> Result<&2, &2, String, Maybe<&2, String>>:
  match value:
    case None{}:
      Done{None{}}
    case Some{JsonString{text}}:
      Done{Some{text}}
    case _:
      Fail{"expected optional string"}

def query_flag(text: String) -> Result<&2, &2, String, Bool>:
  match text:
    case "true":
      Done{True{}}
    case "1":
      Done{True{}}
    case "false":
      Done{False{}}
    case "0":
      Done{False{}}
    case _:
      Fail{"expected query boolean"}

def string_flag(text: String, mode: DecodeMode) -> Result<&2, &2, String, Bool>:
  match mode:
    case QueryMode{}:
      query_flag(text)
    case _:
      Fail{"expected boolean"}

def missing_flag(mode: DecodeMode) -> Result<&2, &2, String, Bool>:
  match mode:
    case ResponseMode{}:
      Fail{"expected response boolean"}
    case _:
      Done{False{}}

def read_flag(value: Maybe<&2, JsonValue>, mode: DecodeMode) -> Result<&2, &2, String, Bool>:
  match value:
    case None{}:
      missing_flag(mode)
    case Some{JsonBool{flag}}:
      Done{flag}
    case Some{JsonString{text}}:
      string_flag(text, mode)
    case _:
      Fail{"expected boolean"}

def require_known(known: Bool) -> Result<&2, &2, String, Unit>:
  match known:
    case True{}:
      Done{Unit{}}
    case False{}:
      Fail{"unknown field"}
