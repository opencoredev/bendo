import Base
import ../app/observability.bend as Obs
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as Response
import ./common.bend as Common
import ../http/request_id.bend as RequestId

def suffix(id: Maybe<&2, String>) -> String:
  match id:
    case None{}: ""
    case Some{value}: " id=" ++ value

def safe_suffix(value: String, safe: Bool) -> String:
  match safe:
    case True{}: " id=" ++ value
    case False{}: ""

def chosen(response_id: Maybe<&2, String>, context_id: Maybe<&2, String>) -> String:
  match response_id:
    case None{}: suffix(context_id)
    case Some{+value}: safe_suffix(value, RequestId.valid_go(value, 200n, False{}))

def line(-Vars: Data, +c: C.Ctx<Vars>, +res: Response.Res, elapsed: Nat) -> String:
  Response.Res{status, hs, body, rep} = res
  Request.method_text(C.method(Vars, c)) ++ " " ++ C.path(Vars, c) ++ " " ++ U32.show(status) ++ " " ++ Nat.show(elapsed) ++ "ms" ++ chosen(Common.response_header(res, "x-request-id"), C.request_id(Vars, c))

def recorded(+channel: Chan(List<&2, Obs.Access>), entry: Obs.Access, got: Maybe<&1, List<&2, Obs.Access>>) -> IO(Unit):
  match got:
    case None{}: IO.pure(Unit, Unit{})
    case Some{entries}:
      do IO<Unit>:
        sent : Result<&1, &1, List<&2, Obs.Access>, Unit> <- Chan.send(List<&2, Obs.Access>, channel, List.append(&2, Obs.Access, entries, [entry]))
        return Unit{}

def retain(-Vars: Data, +c: C.Ctx<Vars>, +res: Response.Res, elapsed: Nat, channel: Maybe<&2, Chan(List<&2, Obs.Access>)>) -> IO(Unit):
  match channel:
    case None{}: IO.print_err(line(Vars, c, res, elapsed))
    case Some{+ch}:
      do IO<Unit>:
        got : Maybe<&1, List<&2, Obs.Access>> <- Chan.recv(List<&2, Obs.Access>, ch)
        recorded(ch, Obs.Access{Request.method_text(C.method(Vars, c)) ++ " " ++ C.path(Vars, c), elapsed, C.request_id(Vars, c)}, got)

def emit(entries: List<&2, Obs.Access>, +res: Response.Res) -> IO(Unit):
  match entries:
    case Nil{}: IO.pure(Unit, Unit{})
    case Obs.Access{prefix, elapsed, fallback} <> tail:
      Response.Res{status, hs, body, rep} = res
      do IO<Unit>:
        IO.print_err(prefix ++ " " ++ U32.show(status) ++ " " ++ Nat.show(elapsed) ++ "ms" ++ chosen(Common.response_header(res, "x-request-id"), fallback))
        emit(tail, res)

def collected(got: Maybe<&1, List<&2, Obs.Access>>, res: Response.Res) -> IO(Unit):
  match got:
    case None{}: IO.pure(Unit, Unit{})
    case Some{entries}: emit(entries, res)

def flush(channel: Maybe<&2, Chan(List<&2, Obs.Access>)>, res: Response.Res) -> IO(Unit):
  match channel:
    case None{}: IO.pure(Unit, Unit{})
    case Some{+ch}:
      do IO<Unit>:
        got : Maybe<&1, List<&2, Obs.Access>> <- Chan.recv(List<&2, Obs.Access>, ch)
        Chan.close(List<&2, Obs.Access>, ch)
        collected(got, res)

def middleware(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    before : Nat <- IO.now()
    raw : Response.Res <- next(c)
    after : Nat <- IO.now()
    +res : Response.Res = C.finalize(raw)
    retain(Vars, c, res, Nat.sub(after, before), Obs.access(C.observation(Vars, c)))
    return res
