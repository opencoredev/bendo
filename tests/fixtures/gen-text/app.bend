import Base
import ../../../src/main.bend as B
import ../../../src/serve-schemas.bend as BS
import ../../../src/router/methods.bend as Methods
import ../../../src/data/schema.bend as S
import ../../../src/data/json.bend as J
import ../../../src/app/context.bend as C
import ../../../src/data/urlencoded.bend as Q
import ../../../src/data/utf8.bend as Utf8
import ../../../src/http/request.bend as R
import ../../../src/router/pattern.bend as P

type Tag is Data:
  TextRoute{}

def choice() -> S.Schema:
  S.UnionSchema{[S.IntegerSchema{None{}, None{}}, S.BooleanSchema{}, S.LiteralSchema{J.JString{"word"}}]}

def enumeration() -> S.Schema:
  S.EnumSchema{[J.JNumber{"1"}, J.JBool{True{}}, J.JNull{}, J.JString{"one"}]}

def params() -> S.Schema:
  S.ObjectSchema{[S.Field{"id", choice(), S.Required{}}], S.Strict{}}

def query() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"choice", choice(), S.Required{}},
    S.Field{"enum", enumeration(), S.Required{}},
    S.Field{"literal", S.LiteralSchema{J.JString{"yes"}}, S.Required{}},
    S.Field{"integer", S.IntegerSchema{None{}, None{}}, S.Required{}},
    S.Field{"number", S.NumberSchema{None{}, None{}}, S.Required{}},
    S.Field{"boolean", S.BooleanSchema{}, S.Required{}},
    S.Field{"nullable", S.NullableSchema{S.IntegerSchema{None{}, None{}}}, S.Optional{}},
    S.Field{"tags", S.ArraySchema{choice(), 0n, None{}}, S.Optional{}},
    S.Field{"ids", S.ArraySchema{S.IntegerSchema{None{}, None{}}, 0n, None{}}, S.Required{}},
    S.Field{"limits", S.ArraySchema{S.IntegerSchema{None{}, None{}}, 0n, None{}}, S.Default{J.JArray{[J.JNumber{"7"}]}}},
    S.Field{"numeric-enum", S.EnumSchema{[J.JNumber{"1"}]}, S.Optional{}},
    S.Field{"numeric-literal", S.LiteralSchema{J.JNumber{"1"}}, S.Optional{}},
    S.Field{"boolean-literal", S.LiteralSchema{J.JBool{True{}}}, S.Optional{}},
    S.Field{"numeric-union", S.UnionSchema{[S.IntegerSchema{None{}, None{}}, S.BooleanSchema{}]}, S.Optional{}},
  ], S.Strict{}}

def headers() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"x-choice", choice(), S.Required{}},
    S.Field{"x-enum", enumeration(), S.Required{}},
    S.Field{"x-literal", S.LiteralSchema{J.JString{"yes"}}, S.Required{}},
  ], S.Strip{}}

def query_json(pairs: List<&2, Q.Entry>) -> List<&2, J.Field>:
  match pairs:
    case Nil{}: []
    case Q.Entry{k, v} <> tail: J.Field{k, J.JString{v}} <> query_json(tail)

def params_json(pairs: P.Params) -> List<&2, J.Field>:
  match pairs:
    case Nil{}: []
    case P.Param{k, v} <> tail: J.Field{k, J.JString{v}} <> params_json(tail)

def header_value(key: String, value: Maybe<&2, String>, rest: List<&2, J.Field>) -> List<&2, J.Field>:
  match value:
    case Some{v}: J.Field{key, J.JString{v}} <> rest
    case None{}: rest

def headers_json(pairs: List<&2, R.Header>) -> List<&2, J.Field>:
  match pairs:
    case Nil{}: []
    case R.Header{k, v} <> tail: header_value(k, Utf8.decode(v), headers_json(tail))

def decoded(ctx: B.Ctx, p: Result<&2, &2, S.Errors(), S.Value>, q: Result<&2, &2, S.Errors(), S.Value>, h: Result<&2, &2, S.Errors(), S.Value>) -> IO(B.Res):
  match p q h:
    case Done{pv} Done{qv} Done{hv}: IO.pure(B.Res, B.json(ctx, J.JObject{[J.Field{"params", S.to_json(pv)}, J.Field{"query", S.to_json(qv)}, J.Field{"headers", S.to_json(hv)}]}))
    case _ _ _: IO.pure(B.Res, B.text(B.status(ctx, 422), "decode failed"))

# Until BND-36 attaches route validation, run the production decoder here.
# The manifest and HTTP handler share the exact same schema definitions.
def dispatch_ctx(ctx: B.Ctx, original: B.Ctx) -> IO(B.Res):
  C.Ctx{r, ps, body, pairs, code, hs, vars, observation} = ctx
  R.Req{method, path, query_string, version, request_headers} = r
  decoded(original, S.decode_from(S.TextSource{}, params(), J.JObject{params_json(ps)}), S.decode_from(S.TextSource{}, query(), J.JObject{query_json(pairs)}), S.decode_from(S.TextSource{}, headers(), J.JObject{headers_json(request_headers)}))

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  +c = ctx
  dispatch_ctx(c, c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      BS.serve_schemas(~Tag, ~Unit, ~dispatch, table, [BS.route_schemas(Some{params()}, Some{query()}, Some{headers()}, None{}, None{})], Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid gen-text fixture")

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/text/:id", TextRoute{})]))
