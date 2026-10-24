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

# Register intent before entering next, so an enclosing deadline cannot erase
# the access entry. The mailbox serializes registration, completion and flush.
def registered(+channel: Chan(List<&2, Obs.Access>), prefix: String, before: Nat, fallback: Maybe<&2, String>, got: Maybe<&1, List<&2, Obs.Access>>) -> IO(Nat):
  match got:
    case None{}: IO.pure(Nat, 0n)
    case Some{+entries}:
      do IO<Nat>:
        +index : Nat = List.length(&2, Obs.Access, entries)
        sent : Result<&1, &1, List<&2, Obs.Access>, Unit> <- Chan.send(List<&2, Obs.Access>, channel, List.append(&2, Obs.Access, entries, [Obs.Access{index, prefix, before, None{}, fallback}]))
        return index

def register(-Vars: Data, +c: C.Ctx<Vars>, before: Nat, channel: Maybe<&2, Chan(List<&2, Obs.Access>)>) -> IO(Nat):
  match channel:
    case None{}: IO.pure(Nat, 0n)
    case Some{+ch}:
      do IO<Nat>:
        got : Maybe<&1, List<&2, Obs.Access>> <- Chan.recv(List<&2, Obs.Access>, ch)
        registered(ch, Request.method_text(C.method(Vars, c)) ++ " " ++ C.path(Vars, c), before, C.request_id(Vars, c), got)

def completed_entry(entry: Obs.Access, elapsed: Nat, same: Bool) -> Obs.Access:
  match entry same:
    case Obs.Access{index, prefix, before, old, fallback} False{}: Obs.Access{index, prefix, before, old, fallback}
    case Obs.Access{index, prefix, before, old, fallback} True{}: Obs.Access{index, prefix, before, Some{elapsed}, fallback}

def completed(entries: List<&2, Obs.Access>, +index: Nat, +elapsed: Nat) -> List<&2, Obs.Access>:
  match entries:
    case Nil{}: []
    case Obs.Access{+i, prefix, before, old, fallback} <> tail:
      completed_entry(Obs.Access{i, prefix, before, old, fallback}, elapsed, Nat.is_eq(i, index)) <> completed(tail, index, elapsed)

def recorded(+channel: Chan(List<&2, Obs.Access>), index: Nat, elapsed: Nat, got: Maybe<&1, List<&2, Obs.Access>>) -> IO(Unit):
  match got:
    case None{}: IO.pure(Unit, Unit{})
    case Some{entries}:
      do IO<Unit>:
        sent : Result<&1, &1, List<&2, Obs.Access>, Unit> <- Chan.send(List<&2, Obs.Access>, channel, completed(entries, index, elapsed))
        return Unit{}

def retain(-Vars: Data, +c: C.Ctx<Vars>, +res: Response.Res, index: Nat, elapsed: Nat, channel: Maybe<&2, Chan(List<&2, Obs.Access>)>) -> IO(Unit):
  match channel:
    case None{}: IO.print_err(line(Vars, c, res, elapsed))
    case Some{+ch}:
      do IO<Unit>:
        got : Maybe<&1, List<&2, Obs.Access>> <- Chan.recv(List<&2, Obs.Access>, ch)
        recorded(ch, index, elapsed, got)

# Completed onion layers keep their duration. Pending layers measure from
# registration until transport finalization; late completion cannot log again.
def duration(elapsed: Maybe<&2, Nat>, before: Nat, now: Nat) -> Nat:
  match elapsed:
    case None{}: Nat.sub(now, before)
    case Some{ms}: ms

def emit(entries: List<&2, Obs.Access>, +res: Response.Res, +now: Nat) -> IO(Unit):
  match entries:
    case Nil{}: IO.pure(Unit, Unit{})
    case Obs.Access{index, prefix, before, elapsed, fallback} <> tail:
      Response.Res{status, hs, body, rep} = res
      do IO<Unit>:
        IO.print_err(prefix ++ " " ++ U32.show(status) ++ " " ++ Nat.show(duration(elapsed, before, now)) ++ "ms" ++ chosen(Common.response_header(res, "x-request-id"), fallback))
        emit(tail, res, now)

def collected(got: Maybe<&1, List<&2, Obs.Access>>, res: Response.Res, now: Nat) -> IO(Unit):
  match got:
    case None{}: IO.pure(Unit, Unit{})
    case Some{entries}: emit(entries, res, now)

def flush(channel: Maybe<&2, Chan(List<&2, Obs.Access>)>, res: Response.Res) -> IO(Unit):
  match channel:
    case None{}: IO.pure(Unit, Unit{})
    case Some{+ch}:
      do IO<Unit>:
        got : Maybe<&1, List<&2, Obs.Access>> <- Chan.recv(List<&2, Obs.Access>, ch)
        now : Nat <- IO.now()
        Chan.close(List<&2, Obs.Access>, ch)
        collected(got, res, now)

def middleware(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    +before : Nat <- IO.now()
    index : Nat <- register(Vars, c, before, Obs.access(C.observation(Vars, c)))
    raw : Response.Res <- next(c)
    after : Nat <- IO.now()
    +res : Response.Res = C.finalize(raw)
    retain(Vars, c, res, index, Nat.sub(after, before), Obs.access(C.observation(Vars, c)))
    return res
