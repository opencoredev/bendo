# Bearer token authentication (RFC 6750 section 2.1 and 3).
import Base
import ../app/context.bend as C
import ../http/response.bend as Response
import ./auth_common.bend as A

def token_char(+c: U32) -> Bool:
  ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || ((c >= 48 : U32) && (c <= 57 : U32)) || U32.is_eq(c, 45) || U32.is_eq(c, 46) || U32.is_eq(c, 95) || U32.is_eq(c, 126) || U32.is_eq(c, 43) || U32.is_eq(c, 47)

def body_spec(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, t}: token_char(c) && body_spec(t)

# body_spec as a tail loop over the reversed text (BND-84).
def body_fold(rev: String, acc: Bool) -> Bool:
  match rev:
    case SNil{}: acc
    case SCon{Chr{+c}, r}: body_fold(r, token_char(c) && acc)

def body_go(s: String) -> Bool:
  body_fold(String.reverse(s), True{})

# Scans the reversed token: trailing '=' first, then at least one token char.
def b64token_split(s: String) -> Bool:
  match s:
    case SCon{'=', t}: b64token_split(t)
    case SNil{}: False{}
    case _: body_go(s)

# b64token = 1*( ALPHA / DIGIT / "-" / "." / "_" / "~" / "+" / "/" ) *"="
def b64token(s: String) -> Bool:
  b64token_split(String.reverse(s))

def digests(tokens: List<&2, String>) -> List<&2, List<&2, U32>>:
  match tokens:
    case Nil{}: []
    case t <> rest: A.digest(t) <> digests(rest)

def realm_param(realm: String) -> String:
  "Bearer realm=" ++ A.quoted(realm)

def matched(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), realm: String, ok: Bool) -> IO(Response.Res):
  match ok:
    case True{}: next(c)
    case False{}: IO.pure(Response.Res, A.challenge(401, realm_param(realm) ++ ", error=\"invalid_token\""))

def formed(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), realm: String, tokens: List<&2, String>, +token: String, ok: Bool) -> IO(Response.Res):
  match ok:
    case True{}: matched(Vars, c, next, realm, A.any(A.digest(token), digests(tokens)))
    case False{}: IO.pure(Response.Res, A.challenge(400, realm_param(realm) ++ ", error=\"invalid_request\""))

def dispatch(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), realm: String, tokens: List<&2, String>, supplied: A.Supplied) -> IO(Response.Res):
  match supplied:
    case A.Missing{}: IO.pure(Response.Res, A.challenge(401, realm_param(realm)))
    case A.Other{}: IO.pure(Response.Res, A.challenge(400, realm_param(realm) ++ ", error=\"invalid_request\""))
    case A.Given{+token}: formed(Vars, c, next, realm, tokens, token, b64token(token))

# Missing credentials: 401 with a bare challenge. Another scheme or a token
# outside b64token syntax: 400 invalid_request. Unknown token: 401 invalid_token.
def middleware(-Vars: Data, realm: String, tokens: List<&2, String>, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  dispatch(Vars, c, next, realm, tokens, A.supplied(C.request_header(Vars, c, "authorization"), "bearer"))
