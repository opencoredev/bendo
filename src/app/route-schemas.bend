# Per-route schemas for the manifest (BND-37) and route validation (BND-36).
# An app passes one RouteSchemas per route registration, in registration
# order: the order of B.routes' table and of the manifest. See docs/manifest.md.
import Base
import ../data/schema.bend as S

type RouteSchemas is Data:
  RouteSchemas{params: Maybe<&2, S.Schema>, query: Maybe<&2, S.Schema>, headers: Maybe<&2, S.Schema>, body: Maybe<&2, S.Schema>, response: Maybe<&2, S.Schema>}

# A route without schemas.
def none() -> RouteSchemas:
  RouteSchemas{None{}, None{}, None{}, None{}, None{}}

def blame(ok: Bool, name: String, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match ok:
    case True{}: rest
    case False{}: Some{name}

def slot(name: String, s: Maybe<&2, S.Schema>, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match s:
    case None{}: rest
    case Some{+x}: blame(S.valid(x), name, rest)

# The first slot, in field order, whose schema is invalid.
def invalid_slot(x: RouteSchemas) -> Maybe<&2, String>:
  match x:
    case RouteSchemas{p, q, h, b, r}: slot("params", p, slot("query", q, slot("headers", h, slot("body", b, slot("response", r, None{})))))

# A slot's name with its schema, for the slots a route sets.
type Named is Data:
  Named{slot: String, schema: S.Schema}

def present(name: String, s: Maybe<&2, S.Schema>, rest: List<&2, Named>) -> List<&2, Named>:
  match s:
    case None{}: rest
    case Some{x}: Named{name, x} <> rest

def slots(x: RouteSchemas) -> List<&2, Named>:
  match x:
    case RouteSchemas{p, q, h, b, r}: present("params", p, present("query", q, present("headers", h, present("body", b, present("response", r, [])))))
