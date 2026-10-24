# JWT (HS256) bearer authentication. Reads "Authorization: Bearer <token>",
# verifies it against the wall clock and hands the claims to the continuation.
import Base
import ../app/context.bend as C
import ../http/response.bend as Response
import ../crypto/jwt.bend as Jwt
import ../data/json.bend as Json
import ../effects/clock.bend as Clock
import ./auth_common.bend as A
import ./jwt_config.bend as JC

def realm_param(realm: String) -> String:
  "Bearer realm=" ++ A.quoted(realm)

def invalid(realm: String, e: Jwt.Error) -> Response.Res:
  A.challenge(401, realm_param(realm) ++ ", error=\"invalid_token\", error_description=" ++ A.quoted(Jwt.error_text(e)))

def verified(-Vars: Data, c: C.Ctx<Vars>, next: Json.Json -> C.Ctx<Vars> -> IO(Response.Res), realm: String, result: Result<&2, &2, Jwt.Error, Json.Json>) -> IO(Response.Res):
  match result:
    case Fail{e}: IO.pure(Response.Res, invalid(realm, e))
    case Done{claims}: next(claims, c)

def timed(-Vars: Data, c: C.Ctx<Vars>, next: Json.Json -> C.Ctx<Vars> -> IO(Response.Res), config: JC.Config, token: String, now: Result<&1, &1, U32 & String, Nat>) -> IO(Response.Res):
  JC.Config{secret, leeway, realm} = config
  match now:
    case Fail{error}: IO.pure(Response.Res, Response.body(500, [], []))
    case Done{seconds}: verified(Vars, c, next, realm, Jwt.verify(secret, token, seconds, leeway))

def dispatch(-Vars: Data, c: C.Ctx<Vars>, next: Json.Json -> C.Ctx<Vars> -> IO(Response.Res), +config: JC.Config, supplied: A.Supplied) -> IO(Response.Res):
  JC.Config{s, l, +realm} = config
  match supplied:
    case A.Missing{}: IO.pure(Response.Res, A.challenge(401, realm_param(realm)))
    case A.Other{}: IO.pure(Response.Res, A.challenge(401, realm_param(realm) ++ ", error=\"invalid_request\""))
    case A.Given{token}:
      do IO<Response.Res>:
        now : Result<&1, &1, U32 & String, Nat> <- Clock.wall_seconds()
        timed(Vars, c, next, config, token, now)

# Verify and pass the claim set to next, so a typed app can store it in Vars.
def with_claims(-Vars: Data, config: JC.Config, +c: C.Ctx<Vars>, next: Json.Json -> C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  dispatch(Vars, c, next, config, A.supplied(C.request_header(Vars, c, "authorization"), "bearer"))

def middleware(-Vars: Data, config: JC.Config, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  with_claims(Vars, config, c, claims => ctx => next(ctx))
