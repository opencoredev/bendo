# Startup configuration, including enforced connection limits.
import Base
import ../router/router.bend as Router

# Development answers a response that breaks its route's response schema
# with a 500; Production logs it to stderr and sends it unchanged (BND-36).
type Mode is Data:
  Development{}
  Production{}

type Config is Data:
  Config{
    host: String,
    port: U32,
    body_limit: U32,
    header_limit: U32,
    idle_timeout_ms: U32,
    head_timeout_ms: U32,
    body_timeout_ms: U32,
    write_timeout_ms: U32,
    max_requests: U32,
    keep_alive: Bool,
    router: Router.RouterKind,
    mode: Mode,
    workers: U32
  }

# host: 127.0.0.1 (IPv4 literal); bound by BND-12.
# port: 8787; valid $PORT overrides at startup (BND-12).
# body_limit: 1048576 bytes (1 MiB, decision 0002); enforced by BND-8.
# header_limit: 65536 bytes; BND-11 returns 431 above this limit.
# idle_timeout_ms: 5000 ms between requests; enforced by BND-11.
# head_timeout_ms: 10000 ms to read the request head; enforced by BND-11.
# body_timeout_ms: 30000 ms to read the body; enforced by BND-11.
# write_timeout_ms: 30000 ms; a buffered response, parser reply or 100 Continue
#   whose client accepts no bytes for a whole window this long is abandoned
#   and its connection closed (BND-106, decision 0009).
# max_requests: 100 requests per connection; enforced by BND-11.
# keep_alive: True; enables HTTP/1.1 connection reuse.
# router: Trie, proven equal to Spec (BND-17); B.serve resolves methods with it.
# mode: Development; $BENDO_ENV=production selects Production at startup (BND-36).
# workers: 1 process; 0 is one per CPU, and a valid $BENDO_WORKERS overrides it.
#   Workers share no memory, so stores and rate limits are per worker (BND-69,
#   decision 0017).
def defaults() -> Config:
  Config{"127.0.0.1", 8787, 1048576, 65536, 5000, 10000, 30000, 30000, 100, True{}, Router.default_kind(), Development{}, 1}

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

def body_limit(config: Config) -> U32:
  Config{host, port, limit, headers, idle, head, body, write, max, keep, router, mode, workers} = config
  limit

def write_timeout(config: Config) -> U32:
  Config{host, port, limit, headers, idle, head, body, write, max, keep, router, mode, workers} = config
  write

def with_mode(config: Config, mode: Mode) -> Config:
  Config{host, port, limit, headers, idle, head, body, write, max, keep, router, old, workers} = config
  Config{host, port, limit, headers, idle, head, body, write, max, keep, router, mode, workers}

# $BENDO_ENV=production selects Production; anything else keeps the config's mode.
def mode_env(value: Result<&1, &1, U32 & String, String>, fallback: Mode) -> Mode:
  match value:
    case Done{"production"}: Production{}
    case _: fallback

def with_workers(config: Config, workers: U32) -> Config:
  Config{host, port, limit, headers, idle, head, body, write, max, keep, router, mode, old} = config
  Config{host, port, limit, headers, idle, head, body, write, max, keep, router, mode, workers}

def workers_read(parsed: Maybe<&2, U32>, fallback: U32) -> U32:
  match parsed:
    case None{}: fallback
    case Some{+count}:
      port_range(count, fallback, (count <= 256 : U32))

def workers_decimal(text: String, fallback: U32, valid: Bool) -> U32:
  match valid:
    case False{}: fallback
    case True{}: workers_read(U32.read(text), fallback)

# $BENDO_WORKERS: decimal 0 to 256 overrides the config; anything else keeps it.
def workers_env(value: Result<&1, &1, U32 & String, String>, fallback: U32) -> U32:
  match value:
    case Fail{error}: fallback
    case Done{text}:
      +s = text
      workers_decimal(s, fallback, decimal(s))
