import Base
import ../../src/serve.bend as Serve
import ../../src/data/form.bend as Form
import ../../src/data/multipart.bend as M
import ../../src/data/urlencoded.bend as Url
import ../../src/http/request.bend as R
import ../../src/http/bytes.bend as Bytes
import ../../src/http/response.bend as Response
import ../../src/http/write_response.bend as Write
import ../../src/crypto/sha256.bend as Sha
import ../../src/data/hex.bend as Crypto

def summary(p: M.Part) -> String:
  match p:
    case M.Field{n, v}:
      "field\t" ++ Url.encode(n) ++ "\t" ++ Url.encode(v) ++ "\n"
    case M.File{n, f, ct, +xs}:
      "file\t" ++ Url.encode(n) ++ "\t" ++ Url.encode(f) ++ "\t" ++ Url.encode(ct) ++ "\t" ++ Nat.show(Response.length(xs)) ++ "\t" ++ Crypto.encode(Sha.hash(xs)) ++ "\n"

def summaries(xs: List<&2, M.Part>, rev: String) -> String:
  match xs:
    case Nil{}:
      String.reverse(rev)
    case p <> t:
      summaries(t, String.reverse.go(summary(p), rev))

def result(r: Result<&2, &2, M.Error, List<&2, M.Part>>) -> List<&2, U32>:
  match r:
    case Fail{e}:
      Write.write(R.Post{}, Response.text(M.error_status(e), "rejected"))
    case Done{xs}:
      Write.write(R.Post{}, Response.text(200, summaries(xs, "")))

def limits(path: String) -> M.Limits:
  match path:
    case "/file":
      M.Limits{8, 4194304, 128, 8192}
    case "/total":
      M.Limits{3145728, 256, 128, 8192}
    case _:
      M.Limits{3145728, 4194304, 128, 8192}

def content_type(xs: List<&2, List<&2, U32>>) -> String:
  match xs:
    case h <> Nil{}:
      Bytes.ascii(h)
    case _:
      ""

def app(req: R.Req, body: List<&2, U32>) -> List<&2, U32>:
  R.Req{m, p, q, v, hs} = req
  result(Form.parse_body_with_limits(content_type(R.lookup(hs, "content-type")), body, limits(p)))

def main() -> IO(Unit):
  Serve.serve_config(~app, Serve.Config{8789, 5242880})
