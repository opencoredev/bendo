# BND-47: the proxy forwards exactly the end-to-end fields, in both
# directions. ProxySpec (proof/proxy-headers-spec.bend) imports only Base and
# the Request.Header record: a field is clean unless its case-folded name is
# Connection, Keep-Alive, Proxy-Connection, TE, Trailer, Transfer-Encoding or
# Upgrade, or is an option named in any Connection field of the message
# (comma-separated, spaces and tabs trimmed, case-folded, whatever the case
# of the Connection field's own name).
import Base
import ../src/http/request.bend as Request
import ../src/http/proxy_headers.bend as ProxyHeaders
import ./proxy-headers-spec.bend as ProxySpec

# LAW: the forwarded list is exactly the clean fields of the original list,
# each unchanged and in its original order. Nothing clean is dropped and
# nothing is added or reordered.
law proxy_forward_spec:
  for +hs: List<&2, Request.Header>
  {ProxyHeaders.forward(hs) == ProxySpec.forward(hs) : List<&2, Request.Header>}

# LAW: no forwarded field is hop-by-hop or named by any Connection option of
# the original message.
law proxy_forward_clean:
  for +hs: List<&2, Request.Header>
  {ProxySpec.all_clean(ProxySpec.listed(hs), ProxyHeaders.forward(hs)) == True{} : Bool}
