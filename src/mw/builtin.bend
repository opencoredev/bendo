import Base
import ../app/context.bend as C
import ../http/response.bend as Response
import ./logger.bend as Logger
import ./request_id.bend as RequestId
import ./server_timing.bend as Timing
import ./powered_by.bend as PoweredBy
import ./pretty_json.bend as Pretty
import ./basic_auth.bend as Basic
import ./bearer_auth.bend as Bearer
import ./jwt.bend as JwtAuth
import ./csrf.bend as Csrf
import ./csrf_policy.bend as CsrfPolicy
import ./cors.bend as Cors
import ./cors_policy.bend as CorsPolicy
import ./secure_headers.bend as Secure
import ./response_policy.bend as ResponsePolicy
import ./method_override.bend as Override
import ./method_override_policy.bend as OverridePolicy
import ./trailing_slash.bend as Trailing
import ./ip_restriction.bend as IpRestriction

import ./body_limit.bend as BodyLimit
import ./timeout.bend as Timeout
import ./etag.bend as ETag
import ./cache.bend as Cache

type Builtin is Data:
  BodyLimit{bytes: U32}
  Timeout{milliseconds: U32}
  ETag{}
  CacheControl{policy: Cache.Policy}
  Logger{}
  RequestId{}
  ServerTiming{}
  PoweredBy{name: String}
  PrettyJson{}
  BasicAuth{realm: String, users: List<&2, Basic.Credential>}
  BearerAuth{realm: String, tokens: List<&2, String>}
  Jwt{config: JwtAuth.Config}
  Csrf{policy: CsrfPolicy.Policy}
  Cors{config: CorsPolicy.Config}
  SecureHeaders{config: Secure.Config}
  # Secure.policy(config), computed once at registration.
  SecurePrepared{policy: ResponsePolicy.Policy}
  MethodOverride{config: OverridePolicy.Config}
  TrailingSlash{config: Trailing.Config}
  IpRestriction{policy: IpRestriction.Policy}

def dispatch(-Vars: Data, id: Builtin, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  match id:
    case BodyLimit{bytes}: BodyLimit.middleware(Vars, bytes, c, next)
    case Timeout{ms}: Timeout.middleware(Vars, ms, c, next)
    case ETag{}: ETag.middleware(Vars, c, next)
    case CacheControl{policy}: Cache.middleware(Vars, policy, c, next)
    case Logger{}: Logger.middleware(Vars, c, next)
    case RequestId{}: RequestId.middleware(Vars, c, next)
    case ServerTiming{}: Timing.middleware(Vars, c, next)
    case PoweredBy{name}: PoweredBy.middleware(Vars, name, c, next)
    case PrettyJson{}: Pretty.middleware(Vars, c, next)
    case BasicAuth{realm, users}: Basic.middleware(Vars, realm, users, c, next)
    case BearerAuth{realm, tokens}: Bearer.middleware(Vars, realm, tokens, c, next)
    case Jwt{config}: JwtAuth.middleware(Vars, config, c, next)
    case Csrf{policy}: Csrf.middleware(Vars, policy, c, next)
    case Cors{config}: Cors.middleware(Vars, config, c, next)
    case SecureHeaders{config}: Secure.middleware(Vars, config, c, next)
    case SecurePrepared{policy}: Secure.prepared(Vars, policy, c, next)
    case MethodOverride{config}: Override.middleware(Vars, config, c, next)
    case TrailingSlash{config}: Trailing.middleware(Vars, config, c, next)
    case IpRestriction{policy}: IpRestriction.middleware(Vars, policy, c, next)

# A pure selector for transport admission; all other built-ins have no limit.
def body_limit(id: Builtin) -> Maybe<&2, U32>:
  match id:
    case BodyLimit{n}: Some{n}
    case _: None{}
