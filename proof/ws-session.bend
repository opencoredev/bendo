import Base
import ./ws-session-laws.bend as L
import ../src/ws/session.bend as S
import ../src/ws/message.bend as M

def L.ws_session_ping(bytes): {==}
def L.ws_session_ping_while_closing(bytes): {==}
def L.ws_session_after_close_sent(command): {==}
def L.ws_session_peer_close(code, reason):
  match code:
    case None{}: {==}
    case Some{c}: {==}
def L.ws_session_close_once(message): {==}
def L.ws_session_close_ack(code, reason):
  match code:
    case None{}: {==}
    case Some{c}: {==}
def L.ws_session_abrupt(): {==}
def L.ws_session_done_no_send(command): {==}
def L.ws_session_begin_close(code, reason): {==}
def L.ws_session_failure(code): {==}
def L.ws_session_pong(bytes): {==}
def L.ws_session_receive_spec(phase, message):
  match phase message:
    case S.WsOpen{} M.TextMessage{t}: {==}
    case S.WsOpen{} M.BinaryMessage{b}: {==}
    case S.WsOpen{} M.PingMessage{b}: {==}
    case S.WsOpen{} M.PongMessage{b}: {==}
    case S.WsOpen{} M.CloseMessage{None{}, r}: {==}
    case S.WsOpen{} M.CloseMessage{Some{c}, r}: {==}
    case S.WsClosing{} M.CloseMessage{None{}, r}: {==}
    case S.WsClosing{} M.CloseMessage{Some{c}, r}: {==}
    case S.WsClosing{} M.TextMessage{x}: {==}
    case S.WsClosing{} M.BinaryMessage{x}: {==}
    case S.WsClosing{} M.PingMessage{x}: {==}
    case S.WsClosing{} M.PongMessage{x}: {==}
    case S.WsDone{} _: {==}
