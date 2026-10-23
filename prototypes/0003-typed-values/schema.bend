import Base

type Scalar is Data:
  StringField{}
  BooleanField{}

type Presence is Data:
  RequiredField{}
  OptionalField{}
  DefaultFalse{}

type Field is Data:
  Field{name: String, scalar: Scalar, presence: Presence}

type ObjectSchema is Data:
  ObjectSchema{name: String, fields: List<&2, Field>}

def todo_schema() -> ObjectSchema:
  ObjectSchema{"Todo", [
    Field{"title", StringField{}, RequiredField{}},
    Field{"done", BooleanField{}, DefaultFalse{}},
    Field{"due", StringField{}, OptionalField{}},
  ]}

type HandlerTag is Data:
  CreateTodo{}

type Route is Data:
  Route{method: String, path: String, tag: HandlerTag, schema: ObjectSchema}

def routes() -> List<&2, Route>:
  [Route{"POST", "/todos", CreateTodo{}, todo_schema()}]
