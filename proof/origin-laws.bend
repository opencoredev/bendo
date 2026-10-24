# BND-85: the origin parser equals the independent origin specification
# (proof/origin-spec.bend) for every input, and a serialized origin keeps
# scheme, host and effective port apart.
import Base
import ../src/http/origin.bend as Origin
import ./origin-spec.bend as OriginSpec

# The serialized origin of every Origin header value is the specification's.
law origin_canonical_spec:
  for +s: String
  {Origin.canonical(s) == OriginSpec.canonical(s) : Maybe<&2, String>}

# The same for every URL (Referer values and configured origins).
law origin_of_url_spec:
  for +s: String
  {Origin.of_url(s) == OriginSpec.of_url(s) : Maybe<&2, String>}

# The same for every scheme and Host value.
law origin_of_host_spec:
  for +scheme: String
  for +host: String
  {Origin.of_host(scheme, host) == OriginSpec.of_host(scheme, host) : Maybe<&2, String>}

# No collapse: reading a serialized origin gives back exactly the scheme,
# host and port (None for the default) it was parsed into. So two inputs
# serialize alike only when all three agree: "http" and "https", or ":8443"
# and the default port, stay distinct, while ":443" on https is the default.
law origin_read_back:
  for +s: String
  for +url: Bool
  {OriginSpec.read_back(OriginSpec.serialized(OriginSpec.parse(s, url))) == OriginSpec.parse(s, url) : Maybe<&2, OriginSpec.Origin>}

# Hosts from the BND-85 report. Invalid IPv6 text is no origin.
law origin_rejects_invalid_ipv6:
  {Origin.canonical("https://[:::]") == None{} : Maybe<&2, String>}

law origin_rejects_ipv6_word:
  {Origin.canonical("https://[abc]") == None{} : Maybe<&2, String>}

# A configured host a browser would rewrite is rejected, and the form the
# browser sends is accepted unchanged.
law origin_rejects_ipv4_shorthand:
  {Origin.of_url("http://127.1") == None{} : Maybe<&2, String>}

law origin_keeps_ipv4_quad:
  {Origin.canonical("http://127.0.0.1") == Some{"http://127.0.0.1"} : Maybe<&2, String>}

law origin_rejects_uncompressed_ipv6:
  {Origin.of_url("https://[0::1]") == None{} : Maybe<&2, String>}

law origin_keeps_compressed_ipv6:
  {Origin.canonical("https://[::1]") == Some{"https://[::1]"} : Maybe<&2, String>}

# The report's exact text: the port does not rescue an invalid host.
law origin_rejects_invalid_ipv6_port:
  {Origin.canonical("https://[:::]:443") == None{} : Maybe<&2, String>}

# The default port is dropped; another port and the scheme are kept.
law origin_default_port:
  {Origin.canonical("https://a:443") == Some{"https://a"} : Maybe<&2, String>}

law origin_keeps_other_port:
  {Origin.canonical("https://a:8443") == Some{"https://a:8443"} : Maybe<&2, String>}

law origin_keeps_scheme:
  {Origin.canonical("http://a:443") == Some{"http://a:443"} : Maybe<&2, String>}
