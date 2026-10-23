# HTTP Basic authentication (RFC 7617) with UTF-8 credentials.
import Base
import ../app/context.bend as C
import ../http/response.bend as Response
import ../data/base64.bend as Base64
import ../data/utf8.bend as Utf8
import ./auth_common.bend as A

type Credential is Data:
  Credential{username: String, password: String}

# One 64-byte value per pair: SHA-256(username) ++ SHA-256(password).
def pair_digest(user: String, pass: String) -> List<&2, U32>:
  List.append(&2, U32, A.digest(user), A.digest(pass))

def digests(users: List<&2, Credential>) -> List<&2, List<&2, U32>>:
  match users:
    case Nil{}: []
    case Credential{u, p} <> t: pair_digest(u, p) <> digests(t)

def split_pair(parts: Maybe<&2, A.Cut>) -> Maybe<&2, Credential>:
  match parts:
    case None{}: None{}
    case Some{A.Cut{user, pass}}: Some{Credential{user, pass}}

# The user-id ends at the first colon; the password may contain colons.
def pair(text: Maybe<&2, String>) -> Maybe<&2, Credential>:
  match text:
    case None{}: None{}
    case Some{s}: split_pair(A.cut(s, ':'))

def octets(padded: Maybe<&2, List<&2, U32>>, +value: String) -> Maybe<&2, List<&2, U32>>:
  match padded:
    case Some{bytes}: Some{bytes}
    case None{}: Base64.decode(value, False{}, False{})

def text(bytes: Maybe<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match bytes:
    case None{}: None{}
    case Some{b}: Utf8.decode(b)

# Standard-alphabet base64, padded as clients send it; unpadded is accepted too.
def credential(+value: String) -> Maybe<&2, Credential>:
  pair(text(octets(Base64.decode(value, False{}, True{}), value)))

def accepted(users: List<&2, Credential>, given: Maybe<&2, Credential>) -> Bool:
  match given:
    case None{}: False{}
    case Some{Credential{u, p}}: A.any(pair_digest(u, p), digests(users))

def valid(users: List<&2, Credential>, supplied: A.Supplied) -> Bool:
  match supplied:
    case A.Given{value}: accepted(users, credential(value))
    case _: False{}

def denied(realm: String) -> Response.Res:
  A.challenge(401, "Basic realm=" ++ A.quoted(realm) ++ ", charset=\"UTF-8\"")

def checked(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), realm: String, ok: Bool) -> IO(Response.Res):
  match ok:
    case True{}: next(c)
    case False{}: IO.pure(Response.Res, denied(realm))

def middleware(-Vars: Data, realm: String, users: List<&2, Credential>, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  checked(Vars, c, next, realm, valid(users, A.supplied(C.request_header(Vars, c, "authorization"), "basic")))
