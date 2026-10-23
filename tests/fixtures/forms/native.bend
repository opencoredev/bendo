import Base
import ../../../src/data/urlencoded.bend as F
import ../../../src/data/utf8.bend as U

# A native consumer of the same public functions exercised by the .mjs tests.
def decoded(r: Result<&2, &2, F.Error, String>) -> String:
  match r:
    case Done{s}:
      s
    case Fail{e}:
      "decode-error"

def parsed(r: Result<&2, &2, F.Error, List<&2, F.Entry>>) -> String:
  match r:
    case Done{pairs}:
      F.serialize(pairs)
    case Fail{F.UnsupportedCharset{}}:
      "unsupported-charset"
    case Fail{F.UnsupportedMediaType{}}:
      "unsupported-media-type"
    case Fail{e}:
      "parse-error"

def run(args: List<String>) -> String:
  match args:
    case exe <> "body" <> ct <> body <> Nil{}:
      parsed(F.parse_body(ct, U.encode(body)))
    case exe <> "pairs" <> text <> Nil{}:
      parsed(F.parse_pairs(text))
    case exe <> "component" <> text <> Nil{}:
      decoded(F.decode(F.encode(text)))
    case exe <> "form" <> text <> Nil{}:
      decoded(F.decode_form(F.encode_form(text)))
    case exe <> "utf8" <> text <> Nil{}:
      Maybe.default(&2, String, U.decode(U.encode(text)), "utf8-error")
    case _:
      "bad-args"

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(run(args))
