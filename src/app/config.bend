# Startup configuration, including enforced connection limits.
import Base
import ../router/router.bend as Router

type Config is Data:
  Config{
    host: String,
    port: U32,
    body_limit: U32,
    header_limit: U32,
    idle_timeout_ms: U32,
    head_timeout_ms: U32,
    body_timeout_ms: U32,
    max_requests: U32,
    keep_alive: Bool,
    router: Router.RouterKind
  }

# host: 127.0.0.1 (IPv4 literal); bound by BND-12.
# port: 8787; valid $PORT overrides at startup (BND-12).
# body_limit: 1048576 bytes (1 MiB, decision 0002); enforced by BND-8.
# header_limit: 65536 bytes; BND-11 returns 431 above this limit.
# idle_timeout_ms: 5000 ms between requests; enforced by BND-11.
# head_timeout_ms: 10000 ms to read the request head; enforced by BND-11.
# body_timeout_ms: 30000 ms to read the body; enforced by BND-11.
# max_requests: 100 requests per connection; enforced by BND-11.
# keep_alive: True; enables HTTP/1.1 connection reuse.
# router: Spec; reference method resolution until BND-17 integrates Trie.
def defaults() -> Config:
  Config{"127.0.0.1", 8787, 1048576, 65536, 5000, 10000, 30000, 100, True{}, Router.Spec{}}

# Validate decimal syntax before Base U32.read, which only checks arithmetic.
def digits(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+n}, tail}:
      (n >= 48 : U32) && (n <= 57 : U32) && digits(tail)

def decimal(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+n}, tail}:
      (n >= 48 : U32) && (n <= 57 : U32) && digits(tail)

def port_range(+port: U32, fallback: U32, valid: Bool) -> U32:
  match valid:
    case True{}: port
    case False{}: fallback

def port_read(parsed: Maybe<&2, U32>, fallback: U32) -> U32:
  match parsed:
    case None{}: fallback
    case Some{+port}:
      port_range(port, fallback, (port >= 1 : U32) && (port <= 65535 : U32))

def port_decimal(text: String, fallback: U32, valid: Bool) -> U32:
  match valid:
    case False{}: fallback
    case True{}: port_read(U32.read(text), fallback)

def port(text: String, fallback: U32) -> U32:
  +s = text
  port_decimal(s, fallback, decimal(s))

def port_env(value: Result<&1, &1, U32 & String, String>, fallback: U32) -> U32:
  match value:
    case Fail{error}: fallback
    case Done{text}: port(text, fallback)
