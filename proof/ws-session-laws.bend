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

# BND-52 review round 1.

law ws_session_abrupt_closing:
  {S.disconnected(S.WsClosing{}) == S.Action{S.WsDone{}, None{}, S.WsFinished{1006, ""}} : S.Action}

law ws_session_abrupt_done:
  {S.disconnected(S.WsDone{}) == S.Action{S.WsDone{}, None{}, S.WsSilent{}} : S.Action}

# In every phase: open and closing end with one 1006 notice and no frame; done
# produces neither. The connection feeds every drop through S.step.
law ws_session_abrupt_any:
  for +max: U32
  for +phase: S.Phase
  for +assembly: M.State
  {S.step(max, S.Session{phase, assembly}, S.Dropped{}) == S.Transition{assembly, Spec.dropped(phase)} : S.Transition}

# For every history of decoded frames, outbound commands, decoder errors and
# drops, the reducer the connection uses writes only pongs after its first
# close frame and delivers no message after it, and writes and delivers nothing
# after the finish notice. So it writes at most one close and finishes once.
law ws_session_trace_safe:
  for +max: U32
  for +events: List<&2, S.WsEvent>
  {Spec.watch(S.trace(max, events, S.opened()), False{}, False{}) == True{} : Bool}

# After any history, a valid ping (final, at most 125 bytes) gets exactly one
# identical pong unless the session is done (the peer's close, a failure or a
# drop), and changes nothing else.
law ws_session_trace_ping:
  for +max: U32
  for +events: List<&2, S.WsEvent>
  for +payload: List<&2, U32>
  for +small: {Nat.is_le(List.length(&2, U32, payload), 125n) == True{} : Bool}
  {S.step(max, S.settle(max, events, S.opened()), S.Inbound{F.Frame{True{}, F.OpPing{}, payload}}) == Spec.ping_reply(S.settle(max, events, S.opened()), payload) : S.Transition}

# A fragmented message whose pieces are interleaved with pings and pongs: the
# payloads concatenate in order, each ping gets its pong, and the final fragment
# delivers the whole message as the trace's only message notice. A data frame
# that takes the message past max fails with 1009, a control frame over 125
# bytes with 1002, and text that is not UTF-8 with 1007. After a failure every
# later frame is ignored. Spec.expect checks sizes on the concatenated bytes.
law ws_session_fragments:
  for +max: U32
  for +text: Bool
  for +first: List<&2, U32>
  for +pieces: List<&2, Spec.Piece>
  for +last: List<&2, U32>
  {S.trace(max, Spec.opening(text, first) <> Spec.tail_events(pieces, last), S.opened()) == Spec.expected(max, text, first, pieces, last) : List<&2, S.Action>}

law ws_session_single_message:
  for +max: U32
  for +text: Bool
  for +payload: List<&2, U32>
  {S.trace(max, [S.Inbound{F.Frame{True{}, Spec.data_op(text), payload}}], S.opened()) == [Spec.finale(max, text, payload)] : List<&2, S.Action>}

# Without its final fragment a message is never delivered, whatever its pieces.
law ws_session_incomplete:
  for +max: U32
  for +text: Bool
  for +first: List<&2, U32>
  for +pieces: List<&2, Spec.Piece>
  {Spec.messages(S.trace(max, Spec.opening(text, first) <> Spec.open_events(pieces), S.opened())) == 0n : Nat}

# The assembler fails exactly on the input errors Spec.fault classifies, with
# its code: 1002 for protocol errors, 1009 for an oversized message, 1007 for
# invalid UTF-8 text or close reason. It ignores frames once ended.
law ws_session_fault_classified:
  for +max: U32
  for +st: M.State
  for +f: F.Frame
  {Spec.failure_of(M.step(max, st, f)) == Spec.fault(max, st, f) : Maybe<&2, U32>}

# A classified error ends the session with that code and, while closing or
# done, writes no second close.
law ws_session_fault_closes:
  for +max: U32
  for +phase: S.Phase
  for +st: M.State
  for +f: F.Frame
  for +code: U32
  for +bad: {Spec.fault(max, st, f) == Some{code} : Maybe<&2, U32>}
  {S.step(max, S.Session{phase, st}, S.Inbound{f}) == S.Transition{M.Ended{}, Spec.failed_in(phase, code)} : S.Transition}

# A decoder rejection carries its own code (1002, or 1009 for a frame over the
# limit) and ends the session the same way.
law ws_session_rejected:
  for +max: U32
  for +phase: S.Phase
  for +st: M.State
  for +code: U32
  {S.step(max, S.Session{phase, st}, S.Rejected{code}) == S.Transition{st, Spec.failed_in(phase, code)} : S.Transition}

# Exactly which commands the send helpers admit into the mailbox. The octet
# conditions are what the frame encoder checks of every payload.
law ws_session_admit_text:
  for +max: U32
  for +text: String
  {S.admissible(max, S.SendText{text}) == Spec.text_ok(max, text) : Bool}

law ws_session_admit_binary:
  for +max: U32
  for +bytes: List<&2, U32>
  {S.admissible(max, S.SendBinary{bytes}) == Spec.binary_ok(max, bytes) : Bool}

law ws_session_admit_ping:
  for +max: U32
  for +bytes: List<&2, U32>
  {S.admissible(max, S.SendPing{bytes}) == Spec.ping_ok(bytes) : Bool}

law ws_session_admit_close:
  for +max: U32
  for +code: U32
  for +reason: String
  {S.admissible(max, S.SendClose{code, reason}) == Spec.close_ok(code, reason) : Bool}
