import Base
import ../src/ws/session.bend as S
import ../src/ws/frame.bend as F
import ../src/ws/message.bend as M
import ./ws-session-spec.bend as Spec

# One action contains at most one frame. Every ping in an open session emits
# exactly one pong with its unchanged payload, and no application notification.
law ws_session_ping:
  for +bytes: List<&2, U32>
  {S.incoming(S.WsOpen{}, M.PingMessage{bytes}) == S.Action{S.WsOpen{}, Some{F.Frame{True{}, F.OpPong{}, bytes}}, S.WsSilent{}} : S.Action}

law ws_session_ping_while_closing:
  for +bytes: List<&2, U32>
  {S.incoming(S.WsClosing{}, M.PingMessage{bytes}) == S.Action{S.WsClosing{}, Some{F.Frame{True{}, F.OpPong{}, bytes}}, S.WsSilent{}} : S.Action}

law ws_session_after_close_sent:
  for command: S.Command
  {S.outgoing(S.WsClosing{}, command) == S.Action{S.WsClosing{}, None{}, S.WsSilent{}} : S.Action}

law ws_session_peer_close:
  for +code: Maybe<&2, U32>
  for +reason: String
  {S.incoming(S.WsOpen{}, M.CloseMessage{code, reason}) == S.Action{S.WsDone{}, Some{F.Frame{True{}, F.OpClose{}, Spec.payload(code, reason)}}, S.WsFinished{Spec.code(code), reason}} : S.Action}

law ws_session_close_once:
  for message: M.Message
  {S.incoming(S.WsDone{}, message) == S.Action{S.WsDone{}, None{}, S.WsSilent{}} : S.Action}

law ws_session_close_ack:
  for +code: Maybe<&2, U32>
  for +reason: String
  {S.incoming(S.WsClosing{}, M.CloseMessage{code, reason}) == S.Action{S.WsDone{}, None{}, S.WsFinished{Spec.code(code), reason}} : S.Action}

law ws_session_abrupt:
  {S.disconnected(S.WsOpen{}) == S.Action{S.WsDone{}, None{}, S.WsFinished{1006, ""}} : S.Action}

law ws_session_receive_spec:
  for +phase: S.Phase
  for +message: M.Message
  {S.incoming(phase, message) == Spec.receive(phase, message) : S.Action}

law ws_session_done_no_send:
  for command: S.Command
  {S.outgoing(S.WsDone{}, command) == S.Action{S.WsDone{}, None{}, S.WsSilent{}} : S.Action}

law ws_session_begin_close:
  for +code: U32
  for +reason: String
  {S.outgoing(S.WsOpen{}, S.SendClose{code, reason}) == S.Action{S.WsClosing{}, Some{F.Frame{True{}, F.OpClose{}, Spec.payload(Some{code}, reason)}}, S.WsSilent{}} : S.Action}

law ws_session_failure:
  for +code: U32
  {S.failure(S.WsOpen{}, code) == S.Action{S.WsDone{}, Some{F.Frame{True{}, F.OpClose{}, Spec.payload(Some{code}, "")}}, S.WsFinished{code, ""}} : S.Action}

law ws_session_pong:
  for bytes: List<&2, U32>
  {S.incoming(S.WsOpen{}, M.PongMessage{bytes}) == S.Action{S.WsOpen{}, None{}, S.WsSilent{}} : S.Action}
