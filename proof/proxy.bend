# BND-47: proofs of the proxy header laws. BND-93: the upstream host laws.
import Base
import ./proxy-laws.bend as Laws
import ./proxy-headers.bend as Headers
import ./upstream-host.bend as Host

def Laws.proxy_forward_spec(hs): Headers.forward_spec(hs)
def Laws.proxy_forward_clean(hs): Headers.forward_clean(hs)
def Laws.proxy_upstream_authority_spec(s): Host.authority_same(s)
def Laws.proxy_upstream_host_round_trip(s): Host.round_trip(s)
def Laws.proxy_upstream_ipv6_url(): {==}
def Laws.proxy_upstream_name_url(): {==}
def Laws.proxy_upstream_rejects_ipv4_shorthand(): {==}
def Laws.proxy_upstream_rejects_noncanonical_ipv6(): {==}
def Laws.proxy_upstream_rejects_ipv4_mapped(): {==}
def Laws.proxy_upstream_rejects_ipv4_compatible(): {==}
def Laws.proxy_upstream_rejects_empty_label(): {==}
def Laws.proxy_upstream_rejects_trailing_dot(): {==}
def Laws.proxy_upstream_rejects_hyphen_edge(): {==}
def Laws.proxy_upstream_rejects_trailing_hyphen(): {==}
def Laws.proxy_upstream_rejects_port_zero(): {==}
def Laws.proxy_upstream_keeps_port_digits(): {==}
