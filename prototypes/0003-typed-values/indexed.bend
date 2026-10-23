import Base

type Shape is Data:
  SchemaText{}
  SchemaFlag{}
  SchemaPair{left: Shape, right: Shape}

type Fields<-A: Data, -B: Data> is Data:
  Fields{left: A, right: B}

def Value(s: Shape) -> Data:
  match s:
    case SchemaText{}:
      String
    case SchemaFlag{}:
      Bool
    case SchemaPair{a, b}:
      Fields<Value(a), Value(b)>

def example() -> Value(SchemaPair{SchemaText{}, SchemaFlag{}}):
  Fields{"typed", False{}}

def title_of(todo: Value(SchemaPair{SchemaText{}, SchemaFlag{}})) -> String:
  Fields{title, done} = todo
  title

def main() -> IO(Unit):
  IO.print(title_of(example()))
