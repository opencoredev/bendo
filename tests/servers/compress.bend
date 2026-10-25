# BND-46 fixture: response compression. /z/* uses the defaults, /low/* a
# 100-octet threshold, /tiny/* a 2048-octet limit, and /etagged/* runs
# B.etag outside the compression.
import Base
import ../../src/main.bend as B
import ../../src/compress.bend as Z
import ../../src/http/response.bend as Response
import ../../src/http/stream_types.bend as StreamTypes
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Json{}
  Html{}
  Size{}
  Png{}
  Svg{}
  Encoded{}
  Strong{}
  Weak{}
  NoContent{}
  Partial{}
  NoTransform{}
  Varied{}
  Stream{}
  Random{}
  Zip{config: Z.Config}
  Builtin{id: B.Builtin}

def json_text() -> String:
  "{\"items\":[" ++ String.repeat("{\"id\":1,\"name\":\"bendo\",\"done\":false,\"tags\":[\"a\",\"b\"]},", 300n) ++ "{\"id\":0}]}"

def html_text() -> String:
  "<!doctype html><html><body>" ++ String.repeat("<p>Hello from Bendo, compressed on the way out.</p>\n", 300n) ++ "</body></html>"

def octets(n: Nat) -> List<&2, U32>:
  Response.utf8(String.repeat("x", n))

def size(q: Maybe<&2, String>) -> Nat:
  match q:
    case None{}: 0n
    case Some{s}: Maybe.default(&2, Nat, Nat.read(s), 0n)

# Octets that zlib cannot shrink: a linear congruential sequence.
def noise(n: Nat, +x: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n: acc
    case 1n+k: noise(k, (x * 1103515245 + 12345 : U32), ((x / 65536) % 256 : U32) <> acc)

def stream_step(state: Nat) -> IO(StreamTypes.Step<Nat>):
  match state:
    case 0n: IO.pure(StreamTypes.Step<Nat>, StreamTypes.End{0n})
    case 1n+n: IO.pure(StreamTypes.Step<Nat>, StreamTypes.Chunk{Response.utf8(String.repeat("stream ", 400n)), n})

def stream_cleanup(state: Nat) -> IO(Unit):
  IO.pure(Unit, Unit{})

def handle(tag: Tag, +c: B.Ctx) -> IO(B.Res):
  match tag:
    case Json{}: IO.pure(B.Res, B.body(c, Response.utf8(json_text()), Some{"application/json"}))
    case Html{}: IO.pure(B.Res, B.html(c, html_text()))
    case Size{}: IO.pure(B.Res, B.text(c, String.repeat("a", size(B.query(c, "n")))))
    case Png{}: IO.pure(B.Res, B.body(c, octets(4096n), Some{"image/png"}))
    case Svg{}: IO.pure(B.Res, B.body(c, Response.utf8("<svg xmlns=\"http://www.w3.org/2000/svg\">" ++ String.repeat("<rect width=\"1\" height=\"1\"/>", 200n) ++ "</svg>"), Some{"image/svg+xml"}))
    case Encoded{}: IO.pure(B.Res, B.body(B.header(c, "content-encoding", "br"), octets(4096n), Some{"text/plain"}))
    case Strong{}: IO.pure(B.Res, B.html(B.header(c, "etag", "\"v1\""), html_text()))
    case Weak{}: IO.pure(B.Res, B.html(B.header(c, "etag", "W/\"v1\""), html_text()))
    case NoContent{}: IO.pure(B.Res, B.body(B.status(c, 204), [], None{}))
    case Partial{}: IO.pure(B.Res, B.text(B.header(B.status(c, 206), "content-range", "bytes 0-4095/8192"), String.repeat("p", 4096n)))
    case NoTransform{}: IO.pure(B.Res, B.html(B.header(c, "cache-control", "public, No-Transform"), html_text()))
    case Varied{}: IO.pure(B.Res, B.html(B.header(c, "vary", "Origin"), html_text()))
    case Stream{}: B.stream(~Unit, ~Nat, ~stream_step, ~stream_cleanup, c, 3n, B.stream_config())
    case Random{}: IO.pure(B.Res, B.body(c, noise(4096n, 7, []), Some{"text/plain"}))
    case _: IO.pure(B.Res, B.text(c, "?"))

def handler(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  handle(tag, c)

def middleware(tag: Tag, c: B.Ctx, env: Unit, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Zip{config}: Z.compress(Unit, config, c, next)
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case _: next(c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "invalid compress routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.use_path(Tag, "/z/*", Zip{Z.defaults()}),
    B.use_path(Tag, "/low/*", Zip{Z.threshold(Z.defaults(), 100)}),
    B.use_path(Tag, "/tiny/*", Zip{Z.limit(Z.defaults(), 2048)}),
    B.use_path(Tag, "/fast/*", Zip{Z.level(Z.defaults(), 0)}),
    B.use_path(Tag, "/etagged/*", Builtin{B.etag()}),
    B.use_path(Tag, "/etagged/*", Zip{Z.defaults()}),
    B.get(Tag, "/z/json", Json{}),
    B.get(Tag, "/z/html", Html{}),
    B.get(Tag, "/z/size", Size{}),
    B.get(Tag, "/z/png", Png{}),
    B.get(Tag, "/z/svg", Svg{}),
    B.get(Tag, "/z/encoded", Encoded{}),
    B.get(Tag, "/z/strong", Strong{}),
    B.get(Tag, "/z/weak", Weak{}),
    B.get(Tag, "/z/nocontent", NoContent{}),
    B.get(Tag, "/z/partial", Partial{}),
    B.get(Tag, "/z/notransform", NoTransform{}),
    B.get(Tag, "/z/varied", Varied{}),
    B.get(Tag, "/z/stream", Stream{}),
    B.get(Tag, "/z/random", Random{}),
    B.get(Tag, "/low/size", Size{}),
    B.get(Tag, "/tiny/size", Size{}),
    B.get(Tag, "/fast/html", Html{}),
    B.get(Tag, "/etagged/html", Html{}),
    B.get(Tag, "/plain/html", Html{})
  ]))
