# BND-84: every request-path string and octet helper runs as a tail loop, so
# 64 KiB inputs cannot overflow the JavaScript stack. Each law equates a
# rewritten helper with its earlier direct recursion (kept as *_spec), or a
# Text helper with the Base function it replaces. Loop laws state what an
# exposed accumulator means.
import Base
import ../src/http/text.bend as Text
import ../src/http/bytes.bend as Bytes
import ../src/http/parse.bend as Parse
import ../src/http/request.bend as Request
import ../src/http/media.bend as Media
import ../src/http/connection.bend as Connection
import ../src/app/errors.bend as Errors
import ../src/data/utf8.bend as Utf8
import ../src/http/origin.bend as Origin
import ../src/crypto/jwt.bend as Jwt
import ../src/net/ip.bend as Ip
import ../src/net/conn_info.bend as Conn
import ../src/http/conditional.bend as Conditional
import ../src/mw/auth_common.bend as Auth
import ../src/mw/bearer_auth.bend as Bearer
import ../src/mw/cors_policy.bend as CorsPolicy
import ../src/mw/cors_request.bend as CorsRequest
import ../src/mw/trailing_slash_policy.bend as TrailingSlash
import ../src/http/websocket.bend as WebSocket

law tail_text_split:
  for +s: String
  for +sep: Char
  {Text.split(s, sep) == String.split(s, sep) : List<&2, String>}

law tail_text_lower:
  for +s: String
  {Text.lower(s) == String.to_lower(s) : String}

law tail_text_lower_go:
  for +s: String
  for +acc: String
  {Text.lower_go(String.reverse(s), acc) == String.append(String.to_lower(s), acc) : String}

law tail_text_upper:
  for +s: String
  {Text.upper(s) == String.to_upper(s) : String}

law tail_text_upper_go:
  for +s: String
  for +acc: String
  {Text.upper_go(String.reverse(s), acc) == String.append(String.to_upper(s), acc) : String}

law tail_text_bytes_append:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  {Text.bytes_append(xs, ys) == List.append(&2, U32, xs, ys) : List<&2, U32>}

law tail_text_list_append:
  for -A: Data
  for +xs: List<&2, A>
  for +ys: List<&2, A>
  {Text.list_append(A, xs, ys) == List.append(&2, A, xs, ys) : List<&2, A>}

law tail_text_length:
  for -A: Data
  for +xs: List<&2, A>
  {Text.length(A, xs) == List.length(&2, A, xs) : Nat}

law tail_text_length_go:
  for -A: Data
  for +xs: List<&2, A>
  for +n: Nat
  {Text.length_go(A, xs, n) == Nat.add(List.length(&2, A, xs), n) : Nat}

law tail_text_join:
  for +xs: List<&2, String>
  for +sep: String
  {Text.join(xs, sep) == String.join(xs, sep) : String}

law tail_text_join_go:
  for +xs: List<&2, String>
  for +sep: String
  for +acc: String
  for +h: String
  {Text.join_go(xs, sep, String.append(acc, h)) == String.append(acc, String.join.go(xs, h, sep)) : String}

law tail_text_cut:
  for +s: String
  for +sep: Char
  {Text.cut(s, sep) == Text.cut_spec(s, sep) : Maybe<&2, Text.Cut>}

law tail_bytes_encode:
  for +s: String
  {Bytes.encode(s) == Bytes.encode_spec(s) : List<&2, U32>}

law tail_bytes_encode_go:
  for +s: String
  for +acc: List<&2, U32>
  {Bytes.encode_go(String.reverse(s), acc) == List.append(&2, U32, Bytes.encode_spec(s), acc) : List<&2, U32>}

law tail_bytes_ascii:
  for +xs: List<&2, U32>
  {Bytes.ascii(xs) == Bytes.ascii_spec(xs) : String}

law tail_bytes_ascii_go:
  for +xs: List<&2, U32>
  for +acc: String
  {Bytes.ascii_go(List.reverse(&2, U32, xs), acc) == String.append(Bytes.ascii_spec(xs), acc) : String}

law tail_bytes_token_tail:
  for +s: String
  {Bytes.token_tail(s) == Bytes.token_tail_spec(s) : Bool}

law tail_bytes_token_go:
  for +s: String
  for +acc: Bool
  {Bytes.token_go(s, acc) == acc && Bytes.token_tail_spec(s) : Bool}

law tail_bytes_value:
  for +xs: List<&2, U32>
  {Bytes.value(xs) == Bytes.value_spec(xs) : Bool}

law tail_bytes_value_go:
  for +xs: List<&2, U32>
  for +acc: Bool
  {Bytes.value_go(xs, acc) == acc && Bytes.value_spec(xs) : Bool}

law tail_bytes_fold:
  for +s: String
  {Bytes.fold(s) == String.to_lower(s) : String}

law tail_bytes_append:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  {Bytes.append(xs, ys) == List.append(&2, U32, xs, ys) : List<&2, U32>}

law tail_bytes_uri:
  for +s: String
  for +q: Bool
  {Bytes.uri(s, q) == Bytes.uri_spec(s, q) : Bool}

law tail_bytes_uri_go:
  for +s: String
  for +q: Bool
  for +acc: Bool
  {Bytes.uri_go(s, q, acc) == acc && Bytes.uri_spec(s, q) : Bool}

law tail_bytes_split_target:
  for +s: String
  {Bytes.split_target(s) == Bytes.split_target_spec(s) : String & Maybe<&2, String>}

law tail_parse_field:
  for +xs: List<&2, U32>
  {Parse.field(xs) == Parse.field_spec(xs) : Parse.Field}

law tail_request_lookup_folded:
  for +hs: List<&2, Request.Header>
  for +name: String
  {Request.lookup_folded(hs, name) == Request.lookup_folded_spec(hs, name) : List<&2, List<&2, U32>>}

law tail_media_before_params:
  for +s: String
  {Media.before_params(s) == Media.before_params_spec(s) : String}

law tail_media_before_params_go:
  for +s: String
  for +rev: String
  {Media.before_params_go(s, rev) == String.reverse.go(rev, Media.before_params_spec(s)) : String}

law tail_connection_tokens:
  for +xs: List<&2, String>
  for +wanted: String
  {Connection.tokens(xs, wanted) == Connection.tokens_spec(xs, wanted) : Bool}

law tail_connection_has_token:
  for +hs: List<&2, Request.Header>
  for +wanted: String
  {Connection.has_token(hs, wanted) == Connection.has_token_spec(hs, wanted) : Bool}

law tail_errors_parameters:
  for +xs: List<&2, String>
  {Errors.parameters(xs) == Errors.parameters_spec(xs) : Bool}

law tail_errors_accepts_json_tokens:
  for +xs: List<&2, String>
  {Errors.accepts_json_tokens(xs) == Errors.accepts_json_tokens_spec(xs) : Bool}

law tail_utf8_valid:
  for +s: String
  {Utf8.valid(s) == Utf8.valid_spec(s) : Bool}

law tail_origin_cut:
  for +s: String
  for +sep: Char
  {Origin.cut(s, sep) == Origin.cut_spec(s, sep) : Maybe<&2, Origin.Cut>}

law tail_origin_authority:
  for +s: String
  {Origin.authority(s) == Origin.authority_spec(s) : Origin.Cut}

law tail_origin_digits:
  for +s: String
  {Origin.digits(s) == Origin.digits_spec(s) : Bool}

law tail_origin_name_chars:
  for +s: String
  {Origin.name_chars(s) == Origin.name_chars_spec(s) : Bool}

law tail_origin_ipv6_chars:
  for +s: String
  {Origin.ipv6_chars(s) == Origin.ipv6_chars_spec(s) : Bool}

law tail_jwt_split:
  for +s: String
  {Jwt.split(s) == Jwt.split_spec(s) : Maybe<&2, Jwt.Cut>}

law tail_jwt_dotfree:
  for +s: String
  {Jwt.dotfree(s) == Jwt.dotfree_spec(s) : Bool}

law tail_jwt_dotfree_go:
  for +s: String
  for +acc: Bool
  {Jwt.dotfree_go(s, acc) == acc && Jwt.dotfree_spec(s) : Bool}

law tail_jwt_codes:
  for +s: String
  {Jwt.codes(s) == Jwt.codes_spec(s) : List<&2, U32>}

law tail_ip_split:
  for +xs: List<&2, U32>
  for +sep: U32
  {Ip.split(xs, sep) == Ip.split_spec(xs, sep) : List<&2, List<&2, U32>>}

law tail_ip_all_digits:
  for +xs: List<&2, U32>
  {Ip.all_digits(xs) == Ip.all_digits_spec(xs) : Bool}

law tail_ip_all_digits_go:
  for +xs: List<&2, U32>
  for +acc: Bool
  {Ip.all_digits_go(xs, acc) == acc && Ip.all_digits_spec(xs) : Bool}

law tail_ip_all_hex:
  for +xs: List<&2, U32>
  {Ip.all_hex(xs) == Ip.all_hex_spec(xs) : Bool}

law tail_ip_all_hex_go:
  for +xs: List<&2, U32>
  for +acc: Bool
  {Ip.all_hex_go(xs, acc) == acc && Ip.all_hex_spec(xs) : Bool}

law tail_ip_has:
  for +xs: List<&2, U32>
  for +c: U32
  {Ip.has(xs, c) == Ip.has_spec(xs, c) : Bool}

law tail_ip_has_go:
  for +xs: List<&2, U32>
  for +c: U32
  for +acc: Bool
  {Ip.has_go(xs, c, acc) == acc || Ip.has_spec(xs, c) : Bool}

law tail_ip_groups:
  for +parts: List<&2, List<&2, U32>>
  for +tail: Bool
  {Ip.groups(parts, tail) == Ip.groups_spec(parts, tail) : Maybe<&2, List<&2, U32>>}

law tail_ip_groups_go:
  for +parts: List<&2, List<&2, U32>>
  for +tail: Bool
  for +done: Maybe<&2, List<&2, U32>>
  {Ip.groups_go(parts, tail, done) == Ip.groups_finish(done, Ip.groups_spec(parts, tail)) : Maybe<&2, List<&2, U32>>}

law tail_ip_doubles:
  for +xs: List<&2, U32>
  {Ip.doubles(xs) == Ip.doubles_spec(xs) : List<&2, List<&2, U32>>}

law tail_conn_strip_lead:
  for +xs: List<&2, U32>
  {Conn.strip_lead(xs) == Conn.strip_lead_spec(xs) : List<&2, U32>}

law tail_conn_strip_trail:
  for +xs: List<&2, U32>
  {Conn.strip_trail(xs) == Conn.strip_trail_spec(xs) : List<&2, U32>}

law tail_conn_entry_texts:
  for +ps: List<&2, List<&2, U32>>
  {Conn.entry_texts(ps) == Conn.entry_texts_spec(ps) : List<&2, String>}

law tail_conn_entries:
  for +fs: List<&2, List<&2, U32>>
  {Conn.entries(fs) == Conn.entries_spec(fs) : List<&2, String>}

law tail_conn_walk_entries:
  for +xs: List<&2, String>
  for +trusted: List<&2, Ip.Cidr>
  for +c: Ip.Addr
  {Conn.walk_entries(xs, trusted, Conn.Going{c}) == Conn.walk(Conn.hops(xs, trusted), c) : Ip.Addr}

law tail_conditional_opaque:
  for +s: String
  for +acc: String
  {Conditional.opaque(s, acc) == Conditional.opaque_spec(s, acc) : Maybe<&2, String>}

law tail_conditional_segments:
  for +s: String
  for +q: Bool
  for +acc: String
  {Conditional.segments(s, q, acc) == Conditional.segments_spec(s, q, acc) : List<&2, String>}

law tail_conditional_segments_go:
  for +s: String
  for +q: Bool
  for +acc: String
  for +done: List<&2, String>
  {Conditional.segments_go(s, q, acc, done) == List.reverse.go(&2, String, done, Conditional.segments_spec(s, q, acc)) : List<&2, String>}

law tail_conditional_members:
  for +xs: List<&2, String>
  for +tag: Maybe<&2, String>
  {Conditional.members(xs, tag) == Conditional.members_spec(xs, tag) : Sigma<&2, &2, Bool, _ => Bool>}

law tail_auth_cut:
  for +s: String
  for +sep: Char
  {Auth.cut(s, sep) == Auth.cut_spec(s, sep) : Maybe<&2, Auth.Cut>}

law tail_auth_escape:
  for +s: String
  {Auth.escape(s) == Auth.escape_spec(s) : String}

law tail_auth_escape_go:
  for +s: String
  for +rev: String
  {Auth.escape_go(s, rev) == String.reverse.go(rev, Auth.escape_spec(s)) : String}

law tail_bearer_body:
  for +s: String
  {Bearer.body_go(s) == Bearer.body_spec(s) : Bool}

law tail_cors_tokens:
  for +xs: List<&2, String>
  {CorsPolicy.tokens(xs) == CorsPolicy.tokens_spec(xs) : List<&2, String>}

law tail_cors_request_texts:
  for +xs: List<&2, List<&2, U32>>
  {CorsRequest.texts(xs) == CorsRequest.texts_spec(xs) : List<&2, String>}

law tail_trailing_clean:
  for +s: String
  {TrailingSlash.clean(s) == TrailingSlash.clean_spec(s) : Bool}

law tail_trailing_trim_last:
  for +s: String
  {TrailingSlash.trim_last(s) == TrailingSlash.trim_last_spec(s) : Maybe<&2, String>}

law tail_trailing_final_slash:
  for +s: String
  {TrailingSlash.final_slash(s) == TrailingSlash.final_slash_spec(s) : Bool}

law tail_websocket_has_element:
  for +xs: List<&2, String>
  for +wanted: String
  {WebSocket.has_element(xs, wanted) == WebSocket.has_element_spec(xs, wanted) : Bool}

law tail_websocket_listed:
  for +xs: List<&2, List<&2, U32>>
  for +wanted: String
  {WebSocket.listed(xs, wanted) == WebSocket.listed_spec(xs, wanted) : Bool}

law tail_websocket_zeros:
  for +xs: List<&2, U32>
  {WebSocket.zeros(xs) == WebSocket.zeros_spec(xs) : Bool}

law tail_websocket_has_offer:
  for +xs: List<&2, String>
  for +p: String
  {WebSocket.has_offer(xs, p) == WebSocket.has_offer_spec(xs, p) : Bool}

law tail_websocket_offered_any:
  for +xs: List<&2, List<&2, U32>>
  for +p: String
  {WebSocket.offered_any(xs, p) == WebSocket.offered_any_spec(xs, p) : Bool}
