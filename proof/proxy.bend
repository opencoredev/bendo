# BND-47: proofs of the proxy header laws.
import Base
import ./proxy-laws.bend as Laws
import ./proxy-headers.bend as Headers

def Laws.proxy_forward_spec(hs): Headers.forward_spec(hs)
def Laws.proxy_forward_clean(hs): Headers.forward_clean(hs)
