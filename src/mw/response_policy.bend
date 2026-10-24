# Request-specific response policy, retained until lifecycle finalization.
import Base
import ../http/request.bend as Request
import ../http/response.bend as Response
import ./response_fields.bend as Fields
import ./vary.bend as Vary
import ../http/stream_marker.bend as Marker

type Policy is Data:
  Policy{remove: List<&2, String>, fields: List<&2, Request.Header>, vary: List<&2, String>}

def stripped(names: List<&2, String>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match names:
    case Nil{}: hs
    case n <> t: stripped(t, Fields.without(hs, n))

def varied(hs: List<&2, Request.Header>, names: List<&2, String>) -> List<&2, Request.Header>:
  match names:
    case Nil{}: hs
    case n <> t: Vary.add(hs, n <> t)

def apply(policy: Policy, res: Response.Res) -> Response.Res:
  Policy{remove, fields, vary} = policy
  Response.Res{s, hs, b, rep} = res
  Response.Res{s, varied(List.append(&2, Request.Header, stripped(remove, hs), fields), vary), b, rep}

# Policies are retained in actual application order: middleware unwind, then
# sequential lifecycle response hooks. Later applications win.
def all(policies: List<&2, Policy>, res: Response.Res) -> Response.Res:
  match policies:
    case Nil{}: res
    case p <> t: all(t, apply(p, res))

# Invalid custom fields still fail the response, but cannot erase independent
# valid policies or observability from the resulting 500.
def safe(policy: Policy) -> Policy:
  Policy{remove, fields, vary} = policy
  Policy{remove, List.filter(~Request.Header, ~Request.header_valid, fields), vary}

def safe_all(policies: List<&2, Policy>, res: Response.Res) -> Response.Res:
  match policies:
    case Nil{}: res
    case p <> t: safe_all(t, apply(safe(p), res))

def checked(policies: List<&2, Policy>, res: Response.Res, valid: Bool) -> Response.Res:
  match valid:
    case True{}: res
    case False{}: Marker.reserved(Response.body(500, [], []), safe_all(policies, Response.body(500, [], [])))

# Finalization applies retained policies before response validation, which then
# checks the result; policies still may not change how transport delivers it:
# the stream marker and status stay as they were (Marker.reserved), and a
# policy failure's 500 carries no marker (law finalized_policies_keep_delivery).
def finalized(+policies: List<&2, Policy>, +res: Response.Res) -> Response.Res:
  +decorated = Marker.reserved(res, all(policies, res))
  checked(policies, decorated, Response.valid(decorated))
