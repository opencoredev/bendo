# BND-40: the default security policy equals the literal specification.
import Base
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/mw/response_policy.bend as Policy
import ../src/mw/secure_headers.bend as Secure
import ./response-policy-spec.bend as RS
import ./response-policy.bend as RP
import ./secure-headers-spec.bend as Spec

def defaults(+res: Response.Res) -> {Policy.apply(Secure.policy(Secure.defaults()), res) == Spec.secured(res) : Response.Res}:
  match res:
    case Response.Res{+s, +hs, +b, +rep}:
      %RP.stripped(Spec.replaced(), hs) : {Response.Res{s, List.append(&2, Request.Header, Policy.stripped(Spec.replaced(), hs), Spec.defaults()), b, rep} == Response.Res{s, List.append(&2, Request.Header, _, Spec.defaults()), b, rep} : Response.Res}
      {==}
