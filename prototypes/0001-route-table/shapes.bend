import Base

# Affine routes: the closed template expression constructs a fresh list per call.
type FnRoute is Type:
  FnRoute{path: String, handler: U32 -> U32}

def list_pick(hit: Bool, h: U32 -> U32, rest: U32 -> U32, nonce: U32) -> U32:
  match hit:
    case True{}:
      h(nonce)
    case False{}:
      rest(nonce)

def list_walk(xs: List<FnRoute>, +path: String, nonce: U32) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{FnRoute{p, h}, t}:
      list_pick(String.eq(p, path), h, n => list_walk(t, path, n), nonce)

def template_list(~routes: List<FnRoute>, path: String, nonce: U32) -> U32:
  list_walk(routes, path, nonce)

type Route is Data:
  Route{path: String, tag: U32}

def data_walk(xs: List<&2, Route>, +path: String) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{Route{p, tag}, t}:
      # Pass the continuation affinely; it is never stored in the route table.
      list_pick(String.eq(p, path), n => tag, n => data_walk(t, path), 0)

def chain_pick(~handler: U32 -> U32, ~next: String -> U32 -> U32,
               hit: Bool, path: String, nonce: U32) -> U32:
  match hit:
    case True{}:
      handler(nonce)
    case False{}:
      next(path, nonce)

def chain(~handler: U32 -> U32, ~next: String -> U32 -> U32,
          pattern: String, +path: String, nonce: U32) -> U32:
  chain_pick(~handler, ~next, String.eq(pattern, path), path, nonce)

def missing(path: String, nonce: U32) -> U32:
  0
