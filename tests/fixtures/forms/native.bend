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

# BND-100: strings holding a Char that is not a Unicode scalar value.
def nonscalar(k: U32) -> String:
  +s = {SCon{'a', SCon{Chr{k}, "b"}} : String}
  decoded(F.decode(s)) ++ "|" ++ decoded(F.decode_form(s)) ++ "|" ++ parsed(F.parse_pairs(s)) ++ "|" ++ F.encode(s) ++ "|" ++ Maybe.default(&2, String, U.decode(U.encode(s)), "utf8-error")

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
    case exe <> "nonscalar" <> Nil{}:
      nonscalar(55296) ++ "\n" ++ nonscalar(57343) ++ "\n" ++ nonscalar(1114112) ++ "\n" ++ nonscalar(2097152) ++ "\n" ++ nonscalar(4294967295)
    case _:
      "bad-args"

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(run(args))
