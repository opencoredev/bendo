# (name, params "for" list, statement, proof expression)
S='String'; UL='List<&2, U32>'; SL='List<&2, String>'; BL='List<&2, List<&2, U32>>'; HL='List<&2, Request.Header>'
L = [
 # Text: stack-safe replacements for Base
 ("text_split", [("s",S),("sep","Char")], "{Text.split(s, sep) == String.split(s, sep) : %s}" % SL, "TP.split_equiv(s, sep)"),
 ("text_lower", [("s",S)], "{Text.lower(s) == String.to_lower(s) : String}", "TP.lower_equiv(s)"),
 ("text_lower_go", [("s",S),("acc",S)], "{Text.lower_go(String.reverse(s), acc) == String.append(String.to_lower(s), acc) : String}", "TP.lower_go_equiv(s, acc)"),
 ("text_upper", [("s",S)], "{Text.upper(s) == String.to_upper(s) : String}", "TP.upper_equiv(s)"),
 ("text_upper_go", [("s",S),("acc",S)], "{Text.upper_go(String.reverse(s), acc) == String.append(String.to_upper(s), acc) : String}", "TP.upper_go_equiv(s, acc)"),
 ("text_bytes_append", [("xs",UL),("ys",UL)], "{Text.bytes_append(xs, ys) == List.append(&2, U32, xs, ys) : %s}" % UL, "TP.bytes_append_equiv(xs, ys)"),
 ("text_list_append", [("-A","Data"),("xs","List<&2, A>"),("ys","List<&2, A>")], "{Text.list_append(A, xs, ys) == List.append(&2, A, xs, ys) : List<&2, A>}", "CT.list_append_equiv(A, xs, ys)"),
 ("text_length", [("-A","Data"),("xs","List<&2, A>")], "{Text.length(A, xs) == List.length(&2, A, xs) : Nat}", "MT.length_equiv(A, xs)"),
 ("text_length_go", [("-A","Data"),("xs","List<&2, A>"),("n","Nat")], "{Text.length_go(A, xs, n) == Nat.add(List.length(&2, A, xs), n) : Nat}", "MT.length_go_equiv(A, xs, n)"),
 ("text_join", [("xs",SL),("sep",S)], "{Text.join(xs, sep) == String.join(xs, sep) : String}", "MT.join_equiv(xs, sep)"),
 ("text_join_go", [("xs",SL),("sep",S),("acc",S),("h",S)], "{Text.join_go(xs, sep, String.append(acc, h)) == String.append(acc, String.join.go(xs, h, sep)) : String}", "MT.join_go_equiv(xs, sep, acc, h)"),
 ("text_cut", [("s",S),("sep","Char")], "{Text.cut(s, sep) == Text.cut_spec(s, sep) : Maybe<&2, Text.Cut>}", "Cut.cut_equiv(s, sep)"),
 # Bytes
 ("bytes_encode", [("s",S)], "{Bytes.encode(s) == Bytes.encode_spec(s) : %s}" % UL, "BT.encode_equiv(s)"),
 ("bytes_encode_go", [("s",S),("acc",UL)], "{Bytes.encode_go(String.reverse(s), acc) == List.append(&2, U32, Bytes.encode_spec(s), acc) : %s}" % UL, "BT.encode_go_equiv(s, acc)"),
 ("bytes_ascii", [("xs",UL)], "{Bytes.ascii(xs) == Bytes.ascii_spec(xs) : String}", "BT.ascii_equiv(xs)"),
 ("bytes_ascii_go", [("xs",UL),("acc",S)], "{Bytes.ascii_go(List.reverse(&2, U32, xs), acc) == String.append(Bytes.ascii_spec(xs), acc) : String}", "BT.ascii_go_equiv(xs, acc)"),
 ("bytes_token_tail", [("s",S)], "{Bytes.token_tail(s) == Bytes.token_tail_spec(s) : Bool}", "BT.token_tail_equiv(s)"),
 ("bytes_token_go", [("s",S),("acc","Bool")], "{Bytes.token_go(s, acc) == acc && Bytes.token_tail_spec(s) : Bool}", "BT.token_go_equiv(s, acc)"),
 ("bytes_value", [("xs",UL)], "{Bytes.value(xs) == Bytes.value_spec(xs) : Bool}", "BT.value_equiv(xs)"),
 ("bytes_value_go", [("xs",UL),("acc","Bool")], "{Bytes.value_go(xs, acc) == acc && Bytes.value_spec(xs) : Bool}", "BT.value_go_equiv(xs, acc)"),
 ("bytes_fold", [("s",S)], "{Bytes.fold(s) == String.to_lower(s) : String}", "BT.fold_equiv(s)"),
 ("bytes_append", [("xs",UL),("ys",UL)], "{Bytes.append(xs, ys) == List.append(&2, U32, xs, ys) : %s}" % UL, "BT.append_equiv(xs, ys)"),
 ("bytes_uri", [("s",S),("q","Bool")], "{Bytes.uri(s, q) == Bytes.uri_spec(s, q) : Bool}", "BT.uri_equiv(s, q)"),
 ("bytes_uri_go", [("s",S),("q","Bool"),("acc","Bool")], "{Bytes.uri_go(s, q, acc) == acc && Bytes.uri_spec(s, q) : Bool}", "BT.uri_go_equiv(s, q, acc)"),
 ("bytes_split_target", [("s",S)], "{Bytes.split_target(s) == Bytes.split_target_spec(s) : String & Maybe<&2, String>}", "BT.split_target_equiv(s)"),
 # Request head
 ("parse_field", [("xs",UL)], "{Parse.field(xs) == Parse.field_spec(xs) : Parse.Field}", "PT.field_equiv(xs)"),
 ("request_lookup_folded", [("hs",HL),("name",S)], "{Request.lookup_folded(hs, name) == Request.lookup_folded_spec(hs, name) : %s}" % BL, "PT.lookup_equiv(hs, name)"),
 ("media_before_params", [("s",S)], "{Media.before_params(s) == Media.before_params_spec(s) : String}", "MT.before_params_equiv(s)"),
 ("media_before_params_go", [("s",S),("rev",S)], "{Media.before_params_go(s, rev) == String.reverse.go(rev, Media.before_params_spec(s)) : String}", "MT.before_params_go_equiv(s, rev)"),
 ("connection_tokens", [("xs",SL),("wanted",S)], "{Connection.tokens(xs, wanted) == Connection.tokens_spec(xs, wanted) : Bool}", "FT.cn_tokens_equiv(xs, wanted)"),
 ("connection_has_token", [("hs",HL),("wanted",S)], "{Connection.has_token(hs, wanted) == Connection.has_token_spec(hs, wanted) : Bool}", "FT.cn_has_token_equiv(hs, wanted)"),
 ("errors_parameters", [("xs",SL)], "{Errors.parameters(xs) == Errors.parameters_spec(xs) : Bool}", "FT.e_parameters_equiv(xs)"),
 ("errors_accepts_json_tokens", [("xs",SL)], "{Errors.accepts_json_tokens(xs) == Errors.accepts_json_tokens_spec(xs) : Bool}", "FT.e_accepts_json_tokens_equiv(xs)"),
 ("utf8_valid", [("s",S)], "{Utf8.valid(s) == Utf8.valid_spec(s) : Bool}", "U8.valid_equiv(s)"),
 # Origin
 ("origin_cut", [("s",S),("sep","Char")], "{Origin.cut(s, sep) == Origin.cut_spec(s, sep) : Maybe<&2, Origin.Cut>}", "Cut.O_equiv(s, sep)"),
 ("origin_authority", [("s",S)], "{Origin.authority(s) == Origin.authority_spec(s) : Origin.Cut}", "MT.authority_equiv(s)"),
 ("origin_digits", [("s",S)], "{Origin.digits(s) == Origin.digits_spec(s) : Bool}", "FT.o_digits_equiv(s)"),
 ("origin_name_chars", [("s",S)], "{Origin.name_chars(s) == Origin.name_chars_spec(s) : Bool}", "FT.o_name_chars_equiv(s)"),
 ("origin_ipv6_chars", [("s",S)], "{Origin.ipv6_chars(s) == Origin.ipv6_chars_spec(s) : Bool}", "FT.o_ipv6_chars_equiv(s)"),
 # JWT
 ("jwt_split", [("s",S)], "{Jwt.split(s) == Jwt.split_spec(s) : Maybe<&2, Jwt.Cut>}", "Cut.J_equiv(s)"),
 ("jwt_dotfree", [("s",S)], "{Jwt.dotfree(s) == Jwt.dotfree_spec(s) : Bool}", "JwtProof.dotfree_equiv(s)"),
 ("jwt_dotfree_go", [("s",S),("acc","Bool")], "{Jwt.dotfree_go(s, acc) == acc && Jwt.dotfree_spec(s) : Bool}", "JwtProof.dotfree_go_equiv(s, acc)"),
 ("jwt_codes", [("s",S)], "{Jwt.codes(s) == Jwt.codes_spec(s) : %s}" % UL, "JwtProof.codes_equiv(s)"),
 # Ip and client address
 ("ip_split", [("xs",UL),("sep","U32")], "{Ip.split(xs, sep) == Ip.split_spec(xs, sep) : %s}" % BL, "CT.split_equiv(xs, sep)"),
 ("ip_all_digits", [("xs",UL)], "{Ip.all_digits(xs) == Ip.all_digits_spec(xs) : Bool}", "MT.all_digits_equiv(xs)"),
 ("ip_all_digits_go", [("xs",UL),("acc","Bool")], "{Ip.all_digits_go(xs, acc) == acc && Ip.all_digits_spec(xs) : Bool}", "MT.all_digits_go_equiv(xs, acc)"),
 ("ip_all_hex", [("xs",UL)], "{Ip.all_hex(xs) == Ip.all_hex_spec(xs) : Bool}", "MT.all_hex_equiv(xs)"),
 ("ip_all_hex_go", [("xs",UL),("acc","Bool")], "{Ip.all_hex_go(xs, acc) == acc && Ip.all_hex_spec(xs) : Bool}", "MT.all_hex_go_equiv(xs, acc)"),
 ("ip_has", [("xs",UL),("c","U32")], "{Ip.has(xs, c) == Ip.has_spec(xs, c) : Bool}", "MT.has_equiv(xs, c)"),
 ("ip_has_go", [("xs",UL),("c","U32"),("acc","Bool")], "{Ip.has_go(xs, c, acc) == acc || Ip.has_spec(xs, c) : Bool}", "MT.has_go_equiv(xs, c, acc)"),
 ("ip_groups", [("parts",BL),("tail","Bool")], "{Ip.groups(parts, tail) == Ip.groups_spec(parts, tail) : Maybe<&2, List<&2, U32>>}", "MT.groups_equiv(parts, tail)"),
 ("ip_groups_go", [("parts",BL),("tail","Bool"),("done","Maybe<&2, List<&2, U32>>")], "{Ip.groups_go(parts, tail, done) == Ip.groups_finish(done, Ip.groups_spec(parts, tail)) : Maybe<&2, List<&2, U32>>}", "MT.groups_go_equiv(parts, tail, done)"),
 ("ip_doubles", [("xs",UL)], "{Ip.doubles(xs) == Ip.doubles_spec(xs) : %s}" % BL, "MT.doubles_equiv(xs)"),
 ("conn_strip_lead", [("xs",UL)], "{Conn.strip_lead(xs) == Conn.strip_lead_spec(xs) : %s}" % UL, "CT.strip_lead_equiv(xs)"),
 ("conn_strip_trail", [("xs",UL)], "{Conn.strip_trail(xs) == Conn.strip_trail_spec(xs) : %s}" % UL, "CT.strip_trail_equiv(xs)"),
 ("conn_entry_texts", [("ps",BL)], "{Conn.entry_texts(ps) == Conn.entry_texts_spec(ps) : %s}" % SL, "CT.entry_texts_equiv(ps)"),
 ("conn_entries", [("fs",BL)], "{Conn.entries(fs) == Conn.entries_spec(fs) : %s}" % SL, "CT.entries_equiv(fs)"),
 ("conn_walk_entries", [("xs",SL),("trusted","List<&2, Ip.Cidr>"),("c","Ip.Addr")], "{Conn.walk_entries(xs, trusted, Conn.Going{c}) == Conn.walk(Conn.hops(xs, trusted), c) : Ip.Addr}", "CT.walk_equiv(xs, trusted, c)"),
 # Conditional requests
 ("conditional_opaque", [("s",S),("acc",S)], "{Conditional.opaque(s, acc) == Conditional.opaque_spec(s, acc) : Maybe<&2, String>}", "MT.opaque_equiv(s, acc)"),
 ("conditional_segments", [("s",S),("q","Bool"),("acc",S)], "{Conditional.segments(s, q, acc) == Conditional.segments_spec(s, q, acc) : %s}" % SL, "MT.segments_equiv(s, q, acc)"),
 ("conditional_segments_go", [("s",S),("q","Bool"),("acc",S),("done",SL)], "{Conditional.segments_go(s, q, acc, done) == List.reverse.go(&2, String, done, Conditional.segments_spec(s, q, acc)) : %s}" % SL, "MT.segments_go_equiv(s, q, acc, done)"),
 ("conditional_members", [("xs",SL),("tag","Maybe<&2, String>")], "{Conditional.members(xs, tag) == Conditional.members_spec(xs, tag) : Sigma<&2, &2, Bool, _ => Bool>}", "FT.cond_members_equiv(xs, tag)"),
 # Middleware
 ("auth_cut", [("s",S),("sep","Char")], "{Auth.cut(s, sep) == Auth.cut_spec(s, sep) : Maybe<&2, Auth.Cut>}", "Cut.A_equiv(s, sep)"),
 ("auth_escape", [("s",S)], "{Auth.escape(s) == Auth.escape_spec(s) : String}", "MT.escape_equiv(s)"),
 ("auth_escape_go", [("s",S),("rev",S)], "{Auth.escape_go(s, rev) == String.reverse.go(rev, Auth.escape_spec(s)) : String}", "MT.escape_go_equiv(s, rev)"),
 ("bearer_body", [("s",S)], "{Bearer.body_go(s) == Bearer.body_spec(s) : Bool}", "FT.be_body_equiv(s)"),
 ("cors_tokens", [("xs",SL)], "{CorsPolicy.tokens(xs) == CorsPolicy.tokens_spec(xs) : %s}" % SL, "FT.cp_tokens_equiv(xs)"),
 ("cors_request_texts", [("xs",BL)], "{CorsRequest.texts(xs) == CorsRequest.texts_spec(xs) : %s}" % SL, "FT.cr_texts_equiv(xs)"),
 ("trailing_clean", [("s",S)], "{TrailingSlash.clean(s) == TrailingSlash.clean_spec(s) : Bool}", "FT.ts_clean_equiv(s)"),
 ("trailing_trim_last", [("s",S)], "{TrailingSlash.trim_last(s) == TrailingSlash.trim_last_spec(s) : Maybe<&2, String>}", "MT.trim_last_equiv(s)"),
 ("trailing_final_slash", [("s",S)], "{TrailingSlash.final_slash(s) == TrailingSlash.final_slash_spec(s) : Bool}", "MT.final_slash_equiv(s)"),
 # WebSocket handshake
 ("websocket_has_element", [("xs",SL),("wanted",S)], "{WebSocket.has_element(xs, wanted) == WebSocket.has_element_spec(xs, wanted) : Bool}", "FT.w_has_element_equiv(xs, wanted)"),
 ("websocket_listed", [("xs",BL),("wanted",S)], "{WebSocket.listed(xs, wanted) == WebSocket.listed_spec(xs, wanted) : Bool}", "FT.w_listed_equiv(xs, wanted)"),
 ("websocket_zeros", [("xs",UL)], "{WebSocket.zeros(xs) == WebSocket.zeros_spec(xs) : Bool}", "FT.w_zeros_equiv(xs)"),
 ("websocket_has_offer", [("xs",SL),("p",S)], "{WebSocket.has_offer(xs, p) == WebSocket.has_offer_spec(xs, p) : Bool}", "FT.w_has_offer_equiv(xs, p)"),
 ("websocket_offered_any", [("xs",BL),("p",S)], "{WebSocket.offered_any(xs, p) == WebSocket.offered_any_spec(xs, p) : Bool}", "FT.w_offered_any_equiv(xs, p)"),
]
laws = ['''# BND-84: every request-path string and octet helper runs as a tail loop, so
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
''']
proofs = ['''# BND-84: proofs of proof/tail-laws.bend, from the equivalence modules.
import Base
import ./tail-laws.bend as Laws
import ./text.bend as TP
import ./bytes-tail.bend as BT
import ./parse-tail.bend as PT
import ./cut-tail.bend as Cut
import ./conn-tail.bend as CT
import ./fold-tail.bend as FT
import ./misc-tail.bend as MT
import ./utf8.bend as U8
import ./jwt.bend as JwtProof
''']
for name, params, stmt, pf in L:
    lines = ["law tail_%s:" % name]
    for v, t in params:
        lines.append("  for %s: %s" % (v if v.startswith('-') else '+' + v, t))
    lines.append("  " + stmt)
    laws.append("\n".join(lines) + "\n")
    args = ", ".join(v.lstrip('-') for v, t in params)
    proofs.append("def Laws.tail_%s(%s):\n  %s\n" % (name, args, pf))
open('proof/tail-laws.bend', 'w').write("\n".join(laws))
open('proof/tail.bend', 'w').write("\n".join(proofs))
print(len(L))
