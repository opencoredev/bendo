# BND-36: finalization checks a buffered response as transport will send it.
# Retained policies (CORS, secure headers) run first, so their final fields,
# the media type included, are what the response schema sees. The finalizers
# that run after the check only stamp the Server-Timing and X-Request-ID
# fields (laws finalization_sends_checked_response, finalizers_only_stamp).
import Base
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes
import ../http/stream_marker.bend as Marker
import ../mw/response_policy.bend as Policy
import ../data/schema-prepared.bend as SP
import ./config.bend as Config
import ./validate.bend as V

def judged(mode: Config.Mode, delivery: V.Delivery, answer: V.Answer) -> V.Action:
  match answer:
    case V.Inspected{check}: V.policy(mode, delivery, check)
    case _: V.Send{}

# What validation does with `res`, the response after retained policies.
def action(~validator: V.Job -> V.Answer, mode: Config.Mode, claim: Marker.Claim, schema: Maybe<&2, SP.Checked>, res: Response.Res) -> V.Action:
  Response.Res{+code, +hs, body, rep} = res
  judged(mode, V.delivery(claim, code, hs), validator(V.ResponseJob{schema, code, hs, body}))

# The response finalization sends: the one it checked, or for a replacement,
# the replacement under the same retained policies.
def answered(policies: List<&2, Policy.Policy>, res: Response.Res, action: V.Action, replacement: Response.Res) -> Response.Res:
  match action:
    case V.Replace{}: Policy.finalized(policies, replacement)
    case V.Send{}: res
    case V.Report{errors}: res

# The fields the post-check finalizers own.
def stamp(+name: String) -> Bool:
  String.eq(name, "x-request-id") || String.eq(name, "server-timing")

def unstamped_field(h: Request.Header, tail: List<&2, Request.Header>, stamped: Bool) -> List<&2, Request.Header>:
  match stamped:
    case True{}: tail
    case False{}: h <> tail

def unstamped_fields(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+k, v} <> t: unstamped_field(Request.Header{k, v}, unstamped_fields(t), stamp(Bytes.fold(k)))

# A response without its Server-Timing and X-Request-ID fields.
def unstamped(res: Response.Res) -> Response.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{code, unstamped_fields(hs), body, rep}
