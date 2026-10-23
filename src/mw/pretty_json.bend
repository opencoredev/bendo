import Base
import ../app/context.bend as C
import ../http/response.bend as Response
import ../http/request.bend as Request
import ../http/bytes.bend as Bytes
import ../data/json.bend as Json
import ./common.bend as Common

def rewritten(res: Response.Res, text: String) -> Response.Res:
  Response.Res{code, hs, body, representation} = res
  clean = C.without(C.without(C.without(C.without(C.without(hs, "etag"), "content-md5"), "digest"), "content-digest"), "repr-digest")
  Response.Res{code, clean, Response.utf8(text), None{}}

def written(res: Response.Res, result: Result<&2, &2, Json.Error, String>) -> Response.Res:
  match result:
    case Fail{error}: res
    case Done{text}: rewritten(res, text)

def parsed(res: Response.Res, result: Result<&2, &2, Json.Error, Json.Json>) -> Response.Res:
  match result:
    case Fail{error}: res
    case Done{value}: written(res, Json.write(value, True{}, False{}))

def parse_response(+res: Response.Res) -> Response.Res:
  Response.Res{code, hs, body, representation} = res
  parsed(res, Json.parse(body))

def transform(res: Response.Res, eligible: Bool) -> Response.Res:
  match eligible:
    case False{}: res
    case True{}: parse_response(res)

def first(parts: List<&2, String>) -> String:
  match parts:
    case Nil{}: ""
    case h <> t: h

def media(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}: False{}
    case Some{s}: String.eq(Bytes.fold(Bytes.ascii(Bytes.trim(Bytes.encode(first(String.split(s, ';')))))), "application/json")

def absent(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}: True{}
    case Some{s}: False{}

def response(+res: Response.Res) -> Response.Res:
  Response.Res{+code, hs, body, rep} = res
  transform(res, media(Common.response_header(res, "content-type")) && absent(Common.response_header(res, "content-encoding")) && absent(Common.response_header(res, "content-range")) && (code >= 200 : U32) && U32.is_ne(code, 204) && U32.is_ne(code, 205) && U32.is_ne(code, 206) && U32.is_ne(code, 304))

def enabled(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), query: Maybe<&2, String>) -> IO(Response.Res):
  match query:
    case None{}: next(c)
    case Some{value}:
      do IO<Response.Res>:
        res : Response.Res <- next(c)
        return response(res)

def middleware(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  enabled(Vars, c, next, C.query(Vars, c, "pretty"))
