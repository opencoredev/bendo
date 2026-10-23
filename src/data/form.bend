# Unified body decoder. The original Urlencoded.parse_body API stays intact.
import Base
import ./multipart.bend as Multipart
import ./urlencoded.bend as Url

def fields_go(xs: List<&2, Url.Entry>, rev: List<&2, Multipart.Part>) -> List<&2, Multipart.Part>:
  match xs:
    case Nil{}:
      List.reverse(&2, Multipart.Part, rev)
    case Url.Entry{k, v} <> t:
      fields_go(t, Multipart.Field{k, v} <> rev)

def url_result(r: Result<&2, &2, Url.Error, List<&2, Url.Entry>>) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>:
  match r:
    case Fail{e}:
      Fail{Multipart.Urlencoded{e}}
    case Done{xs}:
      Done{fields_go(xs, [])}

def dispatch(media: List<&2, String>, +ct: String, body: List<&2, U32>, limits: Multipart.Limits) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>:
  match media:
    case "multipart/form-data" <> ps:
      Multipart.parse_with_limits(ct, body, limits)
    case _:
      url_result(Url.parse_body(ct, body))

def folded_media(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case m <> ps:
      Url.lower(String.trim(m)) <> ps

def parse_body_with_limits(+content_type: String, body: List<&2, U32>, limits: Multipart.Limits) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>:
  dispatch(folded_media(Url.media_scan(content_type, Url.MediaScan{False{}, False{}, "", []})), content_type, body, limits)

def parse_body(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>:
  parse_body_with_limits(content_type, body, Multipart.defaults())
