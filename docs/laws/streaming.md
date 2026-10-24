# Streaming, WebSocket and static file laws

These laws cover chunked bodies and streamed responses, Server-Sent Events,
the WebSocket handshake, frames, sessions and publish/subscribe, and static
file paths. See the [laws index](README.md) for how to read an entry.

## Chunked bodies and streams

A streamed response is sent with chunked encoding, or with a fixed
`Content-Length` when the stream knows its length. These laws say the bytes on
the wire decode back to exactly what the producer wrote, a length-framed stream
can neither overrun nor fall short of its length, and the decoder stops at the
end of the body so a pipelined request after it is untouched. They cover
finite streams; longer and aborted streams have socket tests instead. See
[stream a response](../streaming.md) and
[decision 0005](../decisions/0005-framing.md).

- `chunked_roundtrip`: for any list of chunks whose total length is within the limit, decoding the chunked encoding followed by any suffix gives back the concatenated chunks, no trailers, and the suffix untouched. Empty chunks are allowed and are omitted on the wire.
- `stream_roundtrip`: the same for the bytes the stream writer actually sends, chunk by chunk.
- `stream_empty_chunk`: writing an empty chunk sends nothing.
- `stream_chunk_tail`: each single-chunk write is the canonical chunk encoding, so the writes compose to the sequence above.
- `stream_rfc_roundtrip`: those bytes also satisfy an independent RFC 9112 section 7.1 chunked grammar (lowercase hex sizes, no extensions or trailers) and parse back to the chunks and the suffix. The limit here bounds the total payload, not the runtime's chunk size.
- `stream_rfc_last_chunk`: the first last-chunk ends the body; a suffix that looks like more chunks is left untouched.
- `stream_sized_fields`: a stream with a known length `n` is framed with exactly `content-length: n` and no `transfer-encoding`, replacing any the app set.
- `stream_sized_body`: for every chunk partition and every `n`, the writes of a sized stream (the model the transport follows chunk by chunk) are the concatenated chunks when they total exactly `n` bytes, and an abort otherwise.
- `stream_sized_exact`: that test is the byte count, stated with the standard list length.
- `stream_head_matches_get`: a HEAD response for a known-length stream with a body-bearing status has the same head as the GET, `Content-Length` included; only the body is dropped.
- `stream_http10_needs_length`: HTTP/1.0 has no chunked encoding, so it accepts a stream exactly when the stream knows its length.

## Server-Sent Events

The event-stream writer is checked against an independent parser written from
the WHATWG HTML event-stream algorithm (`proof/sse-spec.bend`). These laws say
a browser observes exactly the events the app sent, and that no frame can
inject extra events: unsafe frames are refused whole, not stripped or escaped.
See [send Server-Sent Events](../sse.md).

- `sse_roundtrip`: for every list of admissible frames, the parser reports, per message, its retry value as a number, then one event with its type, its data (each CR, LF and CRLF read as one LF) and the last event id in force. Comments report nothing. Admissible means every field is UTF-8 of Unicode scalar values, with no CR or LF in an event name, id or comment and no NUL in an id.
- `sse_encode_rejects_unsafe`: the encoder sends exactly the admissible frames, unchanged, and refuses every other frame.
- `sse_sent_frame_exact`: whatever bytes the encoder sends for one frame parse as exactly that frame's observations and nothing else.
- `sse_heartbeat_ignored`: a heartbeat comment at any line start, even in the middle of an event, leaves the parser state and every later observation unchanged.
- `sse_text_utf8`: every string of Unicode scalar values, as Bendo encodes it, passes the admissibility check, so admissibility excludes no text.
- `sse_retry_decimal`, `sse_retry_value`: a retry value is written as ASCII digits whose base-ten value is the number sent.

## WebSocket handshake

The opening handshake is a pure decision on the request, then a 101 response.
These laws compare the decision with `proof/websocket-spec.bend` and fix the
exact responses. The decision law covers canonical requests with lowercase
header names, and it shares `Origin.canonical` with the implementation; the
origin parser has its own laws on the [middleware page](middleware.md#origins).
See [accept a WebSocket upgrade](../websocket.md).

- `websocket_decision_spec`: for every configuration and request, the decision equals the specification: 400 unless the request is an HTTP/1.1 GET with no `Transfer-Encoding`, at most one zero `Content-Length`, a `websocket` Upgrade, an `upgrade` Connection token and exactly one key that is canonical base64 of 16 bytes; then 400 for a missing or repeated version and 426 for one other than 13; then 403 when a listed origin policy does not list the request's origin; otherwise accept, with the first configured subprotocol the client offered.
- `websocket_accept_spec`: `Sec-WebSocket-Accept` is the padded base64 of the SHA-1 of the key followed by the RFC 6455 GUID, for every key. SHA-1 itself rests on the test vectors.
- `websocket_accept_rfc`: the worked example from RFC 6455 section 1.3 gives `s3pPLMBiTxaQ9kYGzzhZRbK+xOo=`.
- `websocket_response_success`: an accepted handshake answers 101 with exactly the RFC fields, and a `sec-websocket-protocol` field exactly when a subprotocol was chosen.
- `websocket_response_version`: a 426 names version 13.
- `websocket_response_refuse_400`, `websocket_response_refuse_403`: 400 and 403 refusals are empty; the context layer adds error bodies.
- `websocket_rebuilt_framing`: whatever response middleware produced, the rebuilt 101 has no body and neither `Content-Length` nor `Transfer-Encoding`, in any case.
- `websocket_rebuilt_response`: every middleware header survives unchanged, in order with duplicates, except handshake fields, framing fields and the internal marker; the computed handshake fields come first.

## WebSocket frames

These laws cover the frame encoder and the whole-buffer decoder (`F.decode`)
against RFC 6455 sections 5.1 to 5.5 (`proof/ws-frame-spec.bend`). The
connection decodes incrementally with `F.start` and `F.resume`, through
`F.next`; `F.feed` is its read loop for one frame, folded over the chunks its
reads return.
The incremental laws tie that loop to one decode of the concatenated bytes, so
the decoder laws also cover the bytes a live connection reads in pieces. See
[WebSocket frames and messages](../websocket-frames.md).

- `ws_mask_spec`: masking is the RFC 6455 section 5.3 rule, for every key and payload.
- `ws_mask_involution`: masking twice with the same key restores any payload.
- `ws_encode_valid`: the encoder's validity check equals the specification's transport-level well-formedness. Close payload contents are checked on receipt, by the session.
- `ws_encode_accepts`, `ws_encode_refuses`: the encoder sends exactly the valid frames and refuses every other one.
- `ws_encode_bytes`: an encoding is, byte for byte, FIN and opcode, the mask bit and 7-bit length, the shortest big-endian extended length, the key, then the payload, masked when keyed.
- `ws_encode_minimal`: every encoding uses the shortest length form.
- `ws_length_threshold_exact`, `ws_length_exact`: below any U32 cap, the 16-bit length threshold is the numeric one and converting the length to U32 loses nothing.
- `ws_roundtrip_masked`: a server decodes every valid masked client frame back to the frame and key, and leaves the following bytes untouched.
- `ws_roundtrip_plain`: a client does the same for every valid unmasked server frame.
- `ws_decode_sound`: whatever the decoder accepts, from any bytes, re-encodes to exactly the bytes it consumed, so non-minimal lengths, reserved bits and similar tricks cannot pass.
- `ws_decode_valid`: every accepted frame is one the peer may send under the receiver's size cap, masked exactly when the peer is a client.
- `ws_decode_incremental`: from any decoder state, with no frame started or any frame in progress, and for every split of the input into chunks, the connection's read loop ends with exactly what one decode of all the bytes gives: the same frame, key and remaining bytes, the same rejection code, or the same payload progress, mask position included.
- `ws_decode_chunks`: so a fresh connection reading any split of a buffer settles on exactly `F.decode` of the whole buffer, the decoder `ws_decode_sound` and `ws_decode_valid` describe.

## WebSocket sessions

The session reducer takes decoded frames, app commands, decoder errors and
drops, and decides which frames to write and which notices (message, finish)
to deliver. These laws check it against `proof/ws-session-spec.bend`. Together
they say pings get exactly one identical pong, fragmented messages arrive
whole and in order, each protocol error closes with its code, at most one close
frame is written, and the app is told the session finished at most once (a
history of only pings, for example, has no finish notice yet). See
[run WebSocket handlers](../websocket-sessions.md).

Whole-history laws:

- `ws_session_trace_safe`: for every history of events, the reducer writes only pongs after its first close frame, delivers no message after it, and writes and delivers nothing after the finish notice. So it writes at most one close and delivers at most one finish notice.
- `ws_session_trace_strict`: the same, and the action that writes the first close delivers no message either, because the connection writes that close before delivering the action's notice.
- `ws_session_trace_ping`: after any history, a valid ping (final, at most 125 bytes) gets exactly one identical pong unless the session is done, and changes nothing else.
- `ws_session_trace_close`, `ws_session_close_empty`: after any history, a valid close from the peer ends message assembly, even mid-message; while open it writes one close echoing the code and reason, while closing it writes nothing, and either way it delivers the finish notice with that code (1005 for an empty payload). Once done it is ignored.
- `ws_session_close_interrupts`: a valid close after the first fragment of a message drops that message, ends assembly and is echoed.
- `ws_session_fragments`: a fragmented message interleaved with pings and pongs concatenates its pieces in order, answers each ping, and delivers the whole message on its final fragment as the only message notice. A message over the size limit fails with 1009, a control frame over 125 bytes with 1002, invalid UTF-8 text with 1007, and every frame after a failure is ignored.
- `ws_session_fragments_end`: after such a message the session is open and ready for the next one, or done if the message failed.
- `ws_session_single_message`, `ws_session_single_message_end`: the same two facts for a message in one frame.
- `ws_session_message_ready`: a single data frame that fits, and is UTF-8 if text, delivers its message and leaves the session ready.
- `ws_session_incomplete`: a message without its final fragment is never delivered.

Single-step laws, by phase (open, closing after Bendo sent a close, done):

- `ws_session_receive_spec`: handling any message in any phase equals the specification.
- `ws_session_ping`, `ws_session_ping_while_closing`: a ping while open or closing answers one pong with the same payload and delivers nothing.
- `ws_session_pong`: a pong while open does nothing.
- `ws_session_peer_close`: a peer close while open echoes the close, finishes with its code (1005 when absent) and reason, and ends the session.
- `ws_session_close_ack`: a peer close while closing finishes without writing another close.
- `ws_session_close_once`: once done, every incoming message is ignored.
- `ws_session_begin_close`: an app close while open writes one close frame and moves to closing.
- `ws_session_after_close_sent`, `ws_session_done_no_send`: after Bendo's close, and once done, app commands write nothing.
- `ws_session_failure`: a failure while open writes a close with its code and finishes with that code.
- `ws_session_abrupt`, `ws_session_abrupt_closing`, `ws_session_abrupt_done`: a dropped connection while open or closing finishes once with 1006 and writes nothing; once done it changes nothing.
- `ws_session_abrupt_any`: every drop, in every phase, goes through the same step and behaves as those three laws say.

Errors and the send helpers:

- `ws_session_fault_classified`: message assembly fails exactly on the errors the specification classifies, with its code: 1002 for protocol errors, 1009 for an oversized message, 1007 for invalid UTF-8 text or close reason.
- `ws_session_failure_ends`, `ws_session_ended_absorbs`: every failure leaves assembly ended, and ended assembly absorbs every frame.
- `ws_session_fault_closes`: a classified error ends the session with its code and, while closing or done, writes no second close.
- `ws_session_start_rejects`, `ws_session_resume_rejects`: the frame decoder only ever rejects with 1002 or 1009, whether it starts a frame or resumes one.
- `ws_session_rejected`: a decoder rejection ends the session with its code, the same way.
- `ws_session_admit_text`, `ws_session_admit_binary`, `ws_session_admit_ping`, `ws_session_admit_close`: the send helpers admit exactly the commands whose payloads the frame encoder accepts.

## WebSocket publish and subscribe

The topic registry is a list of subscription records (topic, connection ID,
mailbox), the next connection ID to hand out, and the IDs of connections that
joined and have not closed. One store actor owns it. These laws check its
membership against an independent model in `proof/ws-topics-spec.bend`, pin
each operation's effect on whole records, and prove that every registry the
shell can reach is well-formed: no pair is recorded twice, every record
belongs to an active connection, and every active ID was already handed out.
Together they say a publication selects each subscribed connection exactly
once as a target, minus the sender, a closed connection can never subscribe
again, and a close's release revokes the connection's ID even when its join
timed out, whatever other connections did in between. Delivery is not proven:
a copy for a full mailbox or an oversized message is dropped. That the release
reaches the hub is a property of the IO shell, not a law: it waits for room in
a full hub queue instead of giving up (BND-98), and an integration test holds
the queue full to check it. See
[publish and subscribe](../websocket-pubsub.md) and
[decision 0018](../decisions/0018-websocket-pubsub.md).

Membership:

- `ws_topics_subscribe_member`, `ws_topics_unsubscribe_leaves`, `ws_topics_remove_leaves`: after subscribing a connection to a topic it is a member; after unsubscribing it from that topic, or removing it, it is not.
- `ws_topics_subscribe_independent`, `ws_topics_unsubscribe_independent`: changing one connection's membership in one topic leaves every other topic's members, in order, unchanged.
- `ws_topics_registry_spec`: over any history of subscribes, unsubscribes and removals, membership matches the model: a connection is in a topic when the last operation naming that pair, or removing the connection, was a subscribe.
- `ws_topics_members_records`: a connection is a member of a topic exactly when some record pairs them.

Publication:

- `ws_topics_publish_targets`: a publication to a topic targets exactly its members, minus the sender when one is given.
- `ws_topics_publish_once`: over any history, a publication selects each connection as a target once if the model says it is a member and it is not the sender, and otherwise never.
- `ws_topics_targets_records`: a publication selects exactly the topic's complete records, minus the sender's, in registry order, so each copy goes to the mailbox stored for that connection.
- `ws_topics_publish_once_wf`, `ws_topics_history_once`: in a well-formed registry, and so after every runtime history, a publication selects each connection exactly once if a record pairs it with the topic and it is not the sender, and otherwise never.

Records:

- `ws_topics_subscribe_record`, `ws_topics_subscribe_target`: subscribing stores the new mailbox and replaces every earlier record for that pair; the other records keep their order.
- `ws_topics_unsubscribe_record`: unsubscribing drops exactly the records for that pair.
- `ws_topics_subscribe_records_independent`, `ws_topics_unsubscribe_records_independent`: every other topic's records, mailboxes included, are unchanged.
- `ws_topics_remove_record`, `ws_topics_remove_next`, `ws_topics_remove_revokes`: removing a connection keeps exactly the other connections' records in order, keeps the next ID, and revokes the removed ID.

Active connections and IDs:

- `ws_topics_admit_active`, `ws_topics_admit_inactive`: the shell's subscribe records the subscription for an active connection and changes nothing for one that closed or never joined.
- `ws_topics_late_subscribe`: a subscribe that arrives after the close cleanup changes nothing, so a kept handle cannot re-register a closed connection.
- `ws_topics_join_next`, `ws_topics_join_id`, `ws_topics_join_subs`, `ws_topics_join_live`: a join hands out the next ID, increments the counter, keeps every record and adds only the new ID to the active set.
- `ws_topics_join_positive`, `ws_topics_join_fresh_live`, `ws_topics_join_fresh_subs`: in a well-formed registry the new ID is not 0 and differs from every active and every subscribed ID.

Joins that time out:

A join can time out after the actor queued it, and still commit. Each
connection joins under its own random token, and its close releases by
token, so the close revokes whatever ID the token got.

- `ws_topics_claim_registry`, `ws_topics_claim_records`: a claim is a join on the registry and records the new ID under the token.
- `ws_topics_change_keeps_claims`: every registry change keeps every claim.
- `ws_topics_release_revokes`, `ws_topics_release_leaves`, `ws_topics_release_unclaims`: a release revokes every ID claimed under its token, removes it from every topic, and forgets those claims.
- `ws_topics_late_join_released`: a claim followed by any registry changes and then a release of the same token leaves the claimed ID inactive.
- `ws_topics_claim_others`, `ws_topics_release_others`: a claim or release under one token keeps every other token's claimed IDs, in order, so one connection's join or close cannot drop another connection's claim.
- `ws_topics_history_release_revokes`, `ws_topics_history_release_leaves`: a claim, then any ledger history (registry changes, prunes, other tokens' claims and releases, even earlier claims and releases of the same token), then a release of that token leaves the ID the claim got inactive and in no topic.

Pruning:

A publication removes the subscribers it found closed. It also forgets their
claims, so the ledger shrinks back even when a closed connection's own release
never arrives.

- `ws_topics_prune_registry`, `ws_topics_prune_claims`, `ws_topics_prune_unclaims`: a prune changes the registry exactly as `T.remove_all` does, keeps exactly the claims whose ID it did not prune, in order, and leaves no token claiming a pruned ID.

Well-formedness:

- `ws_topics_wf_empty`, `ws_topics_wf_join`, `ws_topics_wf_admit`, `ws_topics_wf_unsubscribe`, `ws_topics_wf_remove`, `ws_topics_wf_remove_all`, `ws_topics_wf_claim`, `ws_topics_wf_release`, `ws_topics_wf_prune`: the empty registry is well-formed, and every operation the shell uses preserves it.
- `ws_topics_history_wf`, `ws_topics_ledger_history_wf`: so every registry reachable through any history of joins, subscribes, unsubscribes, closes and prunes is well-formed, including histories of claims, releases and ledger prunes.

## Static files

`B.serve_static` turns a request path into a file under a root directory. These
laws say no request path escapes the root or reaches a dotfile, and that
ordinary paths resolve as expected. The open itself is a C effect that walks
the resolved segments without following symlinks; that part is covered by
integration tests. See [static files](../static.md).

- `static_path_confined`: every resolution is refused or is a relative path made only of in-root segments.
- `static_path_no_dotfiles`: no resolved segment starts with `.`, so files such as `.env` and directories such as `.git` are never served.
- `static_path_segments`: each resolved segment is the decoding of exactly one raw segment, in order, with an empty final segment replaced by the index name; no decoded segment contains `/`.
- `static_path_target`: the path handed to the open effect is the root, `/`, then the resolved path, and nothing is opened for a refused path.
- `static_path_complete`: servable segments (nonempty printable ASCII without space, `%`, `/` or `\`, not starting with `.`) written as `/first/rest...` resolve to those segments joined by `/`, so the resolver is not trivially refusing everything.
- `static_path_index`: servable segments followed by a trailing slash resolve to those segments plus the index name, when the index name is itself servable.
