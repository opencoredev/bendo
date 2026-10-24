# BND-84: proofs of proof/tail-laws.bend, from the equivalence modules.
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

def Laws.tail_text_split(s, sep):
  TP.split_equiv(s, sep)

def Laws.tail_text_lower(s):
  TP.lower_equiv(s)

def Laws.tail_text_lower_go(s, acc):
  TP.lower_go_equiv(s, acc)

def Laws.tail_text_upper(s):
  TP.upper_equiv(s)

def Laws.tail_text_upper_go(s, acc):
  TP.upper_go_equiv(s, acc)

def Laws.tail_text_bytes_append(xs, ys):
  TP.bytes_append_equiv(xs, ys)

def Laws.tail_text_list_append(A, xs, ys):
  CT.list_append_equiv(A, xs, ys)

def Laws.tail_text_length(A, xs):
  MT.length_equiv(A, xs)

def Laws.tail_text_length_go(A, xs, n):
  MT.length_go_equiv(A, xs, n)

def Laws.tail_text_join(xs, sep):
  MT.join_equiv(xs, sep)

def Laws.tail_text_join_go(xs, sep, acc, h):
  MT.join_go_equiv(xs, sep, acc, h)

def Laws.tail_text_cut(s, sep):
  Cut.cut_equiv(s, sep)

def Laws.tail_bytes_encode(s):
  BT.encode_equiv(s)

def Laws.tail_bytes_encode_go(s, acc):
  BT.encode_go_equiv(s, acc)

def Laws.tail_bytes_ascii(xs):
  BT.ascii_equiv(xs)

def Laws.tail_bytes_ascii_go(xs, acc):
  BT.ascii_go_equiv(xs, acc)

def Laws.tail_bytes_token_tail(s):
  BT.token_tail_equiv(s)

def Laws.tail_bytes_token_go(s, acc):
  BT.token_go_equiv(s, acc)

def Laws.tail_bytes_value(xs):
  BT.value_equiv(xs)

def Laws.tail_bytes_value_go(xs, acc):
  BT.value_go_equiv(xs, acc)

def Laws.tail_bytes_fold(s):
  BT.fold_equiv(s)

def Laws.tail_bytes_append(xs, ys):
  BT.append_equiv(xs, ys)

def Laws.tail_bytes_uri(s, q):
  BT.uri_equiv(s, q)

def Laws.tail_bytes_uri_go(s, q, acc):
  BT.uri_go_equiv(s, q, acc)

def Laws.tail_bytes_split_target(s):
  BT.split_target_equiv(s)

def Laws.tail_parse_field(xs):
  PT.field_equiv(xs)

def Laws.tail_request_lookup_folded(hs, name):
  PT.lookup_equiv(hs, name)

def Laws.tail_media_before_params(s):
  MT.before_params_equiv(s)

def Laws.tail_media_before_params_go(s, rev):
  MT.before_params_go_equiv(s, rev)

def Laws.tail_connection_tokens(xs, wanted):
  FT.cn_tokens_equiv(xs, wanted)

def Laws.tail_connection_has_token(hs, wanted):
  FT.cn_has_token_equiv(hs, wanted)

def Laws.tail_errors_parameters(xs):
  FT.e_parameters_equiv(xs)

def Laws.tail_errors_accepts_json_tokens(xs):
  FT.e_accepts_json_tokens_equiv(xs)

def Laws.tail_utf8_valid(s):
  U8.valid_equiv(s)

def Laws.tail_origin_cut(s, sep):
  Cut.O_equiv(s, sep)

def Laws.tail_origin_authority(s):
  MT.authority_equiv(s)

def Laws.tail_origin_digits(s):
  FT.o_digits_equiv(s)

def Laws.tail_origin_name_chars(s):
  FT.o_name_chars_equiv(s)

def Laws.tail_origin_ipv6_chars(s):
  FT.o_ipv6_chars_equiv(s)

def Laws.tail_jwt_split(s):
  Cut.J_equiv(s)

def Laws.tail_jwt_dotfree(s):
  JwtProof.dotfree_equiv(s)

def Laws.tail_jwt_dotfree_go(s, acc):
  JwtProof.dotfree_go_equiv(s, acc)

def Laws.tail_jwt_codes(s):
  JwtProof.codes_equiv(s)

def Laws.tail_ip_split(xs, sep):
  CT.split_equiv(xs, sep)

def Laws.tail_ip_all_digits(xs):
  MT.all_digits_equiv(xs)

def Laws.tail_ip_all_digits_go(xs, acc):
  MT.all_digits_go_equiv(xs, acc)

def Laws.tail_ip_all_hex(xs):
  MT.all_hex_equiv(xs)

def Laws.tail_ip_all_hex_go(xs, acc):
  MT.all_hex_go_equiv(xs, acc)

def Laws.tail_ip_has(xs, c):
  MT.has_equiv(xs, c)

def Laws.tail_ip_has_go(xs, c, acc):
  MT.has_go_equiv(xs, c, acc)

def Laws.tail_ip_groups(parts, tail):
  MT.groups_equiv(parts, tail)

def Laws.tail_ip_groups_go(parts, tail, done):
  MT.groups_go_equiv(parts, tail, done)

def Laws.tail_ip_doubles(xs):
  MT.doubles_equiv(xs)

def Laws.tail_conn_strip_lead(xs):
  CT.strip_lead_equiv(xs)

def Laws.tail_conn_strip_trail(xs):
  CT.strip_trail_equiv(xs)

def Laws.tail_conn_entry_texts(ps):
  CT.entry_texts_equiv(ps)

def Laws.tail_conn_entries(fs):
  CT.entries_equiv(fs)

def Laws.tail_conn_walk_entries(xs, trusted, c):
  CT.walk_equiv(xs, trusted, c)

def Laws.tail_conditional_opaque(s, acc):
  MT.opaque_equiv(s, acc)

def Laws.tail_conditional_segments(s, q, acc):
  MT.segments_equiv(s, q, acc)

def Laws.tail_conditional_segments_go(s, q, acc, done):
  MT.segments_go_equiv(s, q, acc, done)

def Laws.tail_conditional_members(xs, tag):
  FT.cond_members_equiv(xs, tag)

def Laws.tail_auth_cut(s, sep):
  Cut.A_equiv(s, sep)

def Laws.tail_auth_escape(s):
  MT.escape_equiv(s)

def Laws.tail_auth_escape_go(s, rev):
  MT.escape_go_equiv(s, rev)

def Laws.tail_bearer_body(s):
  FT.be_body_equiv(s)

def Laws.tail_cors_tokens(xs):
  FT.cp_tokens_equiv(xs)

def Laws.tail_cors_request_texts(xs):
  FT.cr_texts_equiv(xs)

def Laws.tail_trailing_clean(s):
  FT.ts_clean_equiv(s)

def Laws.tail_trailing_trim_last(s):
  MT.trim_last_equiv(s)

def Laws.tail_trailing_final_slash(s):
  MT.final_slash_equiv(s)

def Laws.tail_websocket_has_element(xs, wanted):
  FT.w_has_element_equiv(xs, wanted)

def Laws.tail_websocket_listed(xs, wanted):
  FT.w_listed_equiv(xs, wanted)

def Laws.tail_websocket_zeros(xs):
  FT.w_zeros_equiv(xs)

def Laws.tail_websocket_has_offer(xs, p):
  FT.w_has_offer_equiv(xs, p)

def Laws.tail_websocket_offered_any(xs, p):
  FT.w_offered_any_equiv(xs, p)
