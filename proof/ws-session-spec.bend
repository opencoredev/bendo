# Independent RFC session table: writes, delivery, terminal notification.
import Base
import ../src/ws/session.bend as S
import ../src/ws/frame.bend as F
import ../src/ws/message.bend as M
import ../src/data/utf8.bend as Utf8

def code(c: Maybe<&2, U32>) -> U32:
  match c:
    case None{}: 1005
    case Some{x}: x

def payload(c: Maybe<&2, U32>, reason: String) -> List<&2, U32>:
  match c:
    case None{}: []
    case Some{+x}: U32.shrn(x, 8n) <> U32.and(x, 255) <> Utf8.encode(reason)

def receive(p: S.Phase, m: M.Message) -> S.Action:
  match p m:
    case S.WsOpen{} M.TextMessage{t}: S.Action{S.WsOpen{}, None{}, S.WsMessage{M.TextMessage{t}}}
    case S.WsOpen{} M.BinaryMessage{b}: S.Action{S.WsOpen{}, None{}, S.WsMessage{M.BinaryMessage{b}}}
    case S.WsOpen{} M.PingMessage{b}: S.Action{S.WsOpen{}, Some{F.Frame{True{}, F.OpPong{}, b}}, S.WsSilent{}}
    case S.WsOpen{} M.PongMessage{b}: S.Action{S.WsOpen{}, None{}, S.WsSilent{}}
    case S.WsOpen{} M.CloseMessage{+c, +r}: S.Action{S.WsDone{}, Some{F.Frame{True{}, F.OpClose{}, payload(c, r)}}, S.WsFinished{code(c), r}}
    case S.WsClosing{} M.CloseMessage{c, r}: S.Action{S.WsDone{}, None{}, S.WsFinished{code(c), r}}
    case S.WsClosing{} M.PingMessage{b}: S.Action{S.WsClosing{}, Some{F.Frame{True{}, F.OpPong{}, b}}, S.WsSilent{}}
    case S.WsClosing{} _: S.Action{S.WsClosing{}, None{}, S.WsSilent{}}
    case S.WsDone{} _: S.Action{S.WsDone{}, None{}, S.WsSilent{}}
