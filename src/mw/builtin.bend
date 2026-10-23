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

type Builtin is Data:
  Logger{}
  RequestId{}
  ServerTiming{}
  PoweredBy{name: String}
  PrettyJson{}
  BasicAuth{realm: String, users: List<&2, Basic.Credential>}
  BearerAuth{realm: String, tokens: List<&2, String>}
  Jwt{config: JwtAuth.Config}
  Csrf{origins: List<&2, String>}

def dispatch(-Vars: Data, id: Builtin, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  match id:
    case Logger{}: Logger.middleware(Vars, c, next)
    case RequestId{}: RequestId.middleware(Vars, c, next)
    case ServerTiming{}: Timing.middleware(Vars, c, next)
    case PoweredBy{name}: PoweredBy.middleware(Vars, name, c, next)
    case PrettyJson{}: Pretty.middleware(Vars, c, next)
    case BasicAuth{realm, users}: Basic.middleware(Vars, realm, users, c, next)
    case BearerAuth{realm, tokens}: Bearer.middleware(Vars, realm, tokens, c, next)
    case Jwt{config}: JwtAuth.middleware(Vars, config, c, next)
    case Csrf{origins}: Csrf.middleware(Vars, origins, c, next)
