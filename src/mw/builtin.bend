import Base
import ../app/context.bend as C
import ../http/response.bend as Response
import ./logger.bend as Logger
import ./request_id.bend as RequestId
import ./server_timing.bend as Timing
import ./powered_by.bend as PoweredBy
import ./pretty_json.bend as Pretty

type Builtin is Data:
  Logger{}
  RequestId{}
  ServerTiming{}
  PoweredBy{name: String}
  PrettyJson{}

def dispatch(-Vars: Data, id: Builtin, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  match id:
    case Logger{}: Logger.middleware(Vars, c, next)
    case RequestId{}: RequestId.middleware(Vars, c, next)
    case ServerTiming{}: Timing.middleware(Vars, c, next)
    case PoweredBy{name}: PoweredBy.middleware(Vars, name, c, next)
    case PrettyJson{}: Pretty.middleware(Vars, c, next)
