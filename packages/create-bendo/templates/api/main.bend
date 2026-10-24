# A Bendo API. Routes carry schemas: the server checks every request against
# them, and `bendo gen` turns them into TypeScript types for bendo/client.
import Base
import ./bendo/main.bend as B
import ./bendo/validated.bend as V
import ./bendo/data/schema.bend as S
import ./bendo/data/json.bend as J

type Tag is Data:
  Home{}
  Hello{}
  Echo{}

def text_of(value: Maybe<&2, S.Value>) -> String:
  match value:
    case Some{S.VString{s}}: s
    case _: ""

def hello(+c: B.Ctx) -> B.Res:
  B.json(c, J.JObject{[J.Field{"message", J.JString{"Hello, " ++ text_of(B.field(B.valid_params(c), "name")) ++ "!"}}]})

# Validation already decoded the body, so the message is there.
def echo(+c: B.Ctx) -> B.Res:
  B.json(c, J.JObject{[J.Field{"message", J.JString{text_of(B.field(B.valid_body(c), "message"))}}]})

def respond(tag: Tag, +c: B.Ctx) -> B.Res:
  match tag:
    case Home{}: B.text(c, "Hello from Bendo!")
    case Hello{}: hello(c)
    case Echo{}: echo(c)

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, respond(tag, c))

def text(min: Nat, max: Nat) -> S.Schema:
  S.StringSchema{min, Some{max}, None{}, S.Plain{}}

def message() -> S.Schema:
  S.ObjectSchema{[S.Field{"message", text(1n, 200n), S.Required{}}], S.Strict{}}

def name_params() -> S.Schema:
  S.ObjectSchema{[S.Field{"name", text(1n, 40n), S.Required{}}], S.Strict{}}

def routes() -> List<&2, B.Registration(Tag)>:
  [
    B.get(Tag, "/", Home{}),
    B.with_schemas(Tag, B.get(Tag, "/hello/:name", Hello{}), B.schemas([B.params_schema(name_params()), B.response_schema(message())])),
    B.with_schemas(Tag, B.post(Tag, "/echo", Echo{}), B.schemas([B.body_schema(message()), B.response_schema(message())])),
  ]

def ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}: V.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}: IO.die(Unit, 1, "invalid routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, routes()))
