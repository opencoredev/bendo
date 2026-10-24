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
import ../src/http/upstream.bend as Upstream
import ./upstream-host-spec.bend as UpstreamSpec

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

# BND-93: the host and port of an upstream URL. UpstreamSpec
# (proof/upstream-host-spec.bend) states the grammar on top of BND-85's
# origin specification: a bracketed RFC 5952 IPv6 address that embeds no IPv4
# address, or a dotted-quad IPv4 address or DNS name with RFC 1123 labels,
# then optionally ':' and a port of one to five digits from 1 to 65535. It
# splits the authority at every ']' or ':' where the parser cuts at the first.

# LAW: the parser accepts exactly the authorities the grammar accepts, and
# reads the same host and port from each.
law proxy_upstream_authority_spec:
  for +s: String
  {Upstream.read_authority(s) == UpstreamSpec.authority(s) : Maybe<&2, Upstream.Endpoint>}

# LAW: the Host value sent upstream (IPv6 in brackets, the port as written
# when the URL has one) parses back to exactly the endpoint it came from.
law proxy_upstream_host_round_trip:
  for +s: String
  {UpstreamSpec.reread(Upstream.read_authority(s)) == Upstream.read_authority(s) : Maybe<&2, Upstream.Endpoint>}

# Examples. A bracketed IPv6 upstream keeps its brackets in Host.
law proxy_upstream_ipv6_url:
  {Upstream.parse_url("http://[::1]:8080/api/") == Some{Upstream.Upstream{"::1", 8080, "[::1]:8080", "/api"}} : Maybe<&2, Upstream.Upstream>}

law proxy_upstream_name_url:
  {Upstream.parse_url("HTTP://Api.Internal") == Some{Upstream.Upstream{"api.internal", 80, "api.internal", ""}} : Maybe<&2, Upstream.Upstream>}

# Text a resolver would rewrite or that breaks a label rule is refused.
law proxy_upstream_rejects_ipv4_shorthand:
  {Upstream.read_authority("127.1") == None{} : Maybe<&2, Upstream.Endpoint>}

law proxy_upstream_rejects_noncanonical_ipv6:
  {Upstream.read_authority("[0::1]") == None{} : Maybe<&2, Upstream.Endpoint>}

# An IPv6 address that carries an IPv4 one, mapped or compatible, is refused:
# a dual-stack socket would dial the IPv4 address.
law proxy_upstream_rejects_ipv4_mapped:
  {Upstream.read_authority("[::ffff:c000:201]") == None{} : Maybe<&2, Upstream.Endpoint>}

law proxy_upstream_rejects_ipv4_compatible:
  {Upstream.read_authority("[::c000:201]") == None{} : Maybe<&2, Upstream.Endpoint>}

law proxy_upstream_rejects_empty_label:
  {Upstream.read_authority("a..b") == None{} : Maybe<&2, Upstream.Endpoint>}

law proxy_upstream_rejects_trailing_dot:
  {Upstream.read_authority("a.example.") == None{} : Maybe<&2, Upstream.Endpoint>}

law proxy_upstream_rejects_hyphen_edge:
  {Upstream.read_authority("-a.example") == None{} : Maybe<&2, Upstream.Endpoint>}

law proxy_upstream_rejects_trailing_hyphen:
  {Upstream.read_authority("a-.example") == None{} : Maybe<&2, Upstream.Endpoint>}

law proxy_upstream_rejects_port_zero:
  {Upstream.read_authority("a.example:0") == None{} : Maybe<&2, Upstream.Endpoint>}

# Leading zeros in a port are allowed and kept as written.
law proxy_upstream_keeps_port_digits:
  {Upstream.read_authority("a.example:080") == Some{Upstream.Endpoint{Upstream.HostName{"a.example"}, Some{"080"}}} : Maybe<&2, Upstream.Endpoint>}
