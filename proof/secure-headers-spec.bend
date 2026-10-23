# BND-40: the default security headers, listed literally.
import Base
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes
import ./response-policy-spec.bend as RS

# Hono 4's secureHeaders defaults, in its order.
def defaults() -> List<&2, Request.Header>:
  [
    Request.Header{"cross-origin-resource-policy", Bytes.encode("same-origin")},
    Request.Header{"cross-origin-opener-policy", Bytes.encode("same-origin")},
    Request.Header{"origin-agent-cluster", Bytes.encode("?1")},
    Request.Header{"referrer-policy", Bytes.encode("no-referrer")},
    Request.Header{"strict-transport-security", Bytes.encode("max-age=15552000; includeSubDomains")},
    Request.Header{"x-content-type-options", Bytes.encode("nosniff")},
    Request.Header{"x-dns-prefetch-control", Bytes.encode("off")},
    Request.Header{"x-download-options", Bytes.encode("noopen")},
    Request.Header{"x-frame-options", Bytes.encode("SAMEORIGIN")},
    Request.Header{"x-permitted-cross-domain-policies", Bytes.encode("none")},
    Request.Header{"x-xss-protection", Bytes.encode("0")}
  ]

# The names a secured response may carry only from the defaults, plus
# X-Powered-By, which it never carries.
def replaced() -> List<&2, String>:
  ["cross-origin-resource-policy", "cross-origin-opener-policy", "origin-agent-cluster", "referrer-policy", "strict-transport-security", "x-content-type-options", "x-dns-prefetch-control", "x-download-options", "x-frame-options", "x-permitted-cross-domain-policies", "x-xss-protection", "x-powered-by"]

# Status, body, representation and every unrelated field stay as they were,
# in order and byte for byte; every copy of a default field or of
# X-Powered-By, in any case, is gone; the eleven defaults follow once each.
def secured(res: Response.Res) -> Response.Res:
  match res:
    case Response.Res{s, hs, b, rep}: Response.Res{s, List.append(&2, Request.Header, RS.unrelated(hs, replaced()), defaults()), b, rep}
