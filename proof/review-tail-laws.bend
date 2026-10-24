# BND-84 review: unrestricted equivalence to the retained recursive definitions.
import Base
import ../src/http/write.bend as W
import ../src/crypto/jwt.bend as J
import ../src/mw/method_override.bend as M
import ../src/data/multipart.bend as Multipart
import ../src/data/utf8.bend as Utf8
import ../src/http/proxy_headers.bend as H
import ../src/http/upstream.bend as U
import ../src/http/request.bend as R
import ../src/http/bytes.bend as Bytes
import ../src/http/text.bend as T

law review_j_nonzero:
  for +xs: String
  {J.nonzero(xs) == J.nonzero_spec(xs) : Bool}

law review_m_texts:
  for +xs: List<&2, List<&2, U32>>
  {M.texts(xs) == M.texts_spec(xs) : List<&2, String>}

law review_m_field_values:
  for +xs: List<&2, Multipart.Part>
  for +name: String
  {M.field_values(xs, name) == M.field_values_spec(xs, name) : List<&2, String>}

law review_h_named:
  for +xs: List<&2, String>
  for +name: String
  {H.named(name, xs) == H.named_spec(name, xs) : Bool}

law review_u_named:
  for +xs: List<&2, String>
  for +name: String
  {U.named(name, xs) == U.named_spec(name, xs) : Bool}

law review_h_strip_trail:
  for +xs: List<&2, U32>
  {H.strip_trail(xs) == H.strip_trail_spec(xs) : List<&2, U32>}

law review_h_commas:
  for +xs: List<&2, U32>
  {H.commas(xs) == H.commas_spec(xs) : List<&2, List<&2, U32>>}

law review_h_token_names:
  for +xs: List<&2, List<&2, U32>>
  {H.token_names(xs) == H.token_names_spec(xs) : List<&2, String>}

law review_h_listed:
  for +xs: List<&2, R.Header>
  {H.listed(xs) == H.listed_spec(xs) : List<&2, String>}

law review_h_keep_all:
  for +xs: List<&2, R.Header>
  for +tokens: List<&2, String>
  {H.keep_all(tokens, xs) == H.keep_all_spec(tokens, xs) : List<&2, R.Header>}

law review_u_without:
  for +xs: List<&2, R.Header>
  for +names: List<&2, String>
  {U.without(names, xs) == U.without_spec(names, xs) : List<&2, R.Header>}

law review_u_ascii_values:
  for +xs: List<&2, List<&2, U32>>
  {U.ascii_values(xs) == U.ascii_values_spec(xs) : List<&2, String>}

law review_u_quote_chars:
  for +xs: String
  {U.quote_chars(xs) == U.quote_chars_spec(xs) : String}

law review_u_sane_all:
  for +xs: List<&2, R.Header>
  {U.sane_all(xs) == U.sane_all_spec(xs) : List<&2, R.Header>}

law review_u_lengths:
  for +xs: List<&2, List<&2, U32>>
  {U.lengths(xs) == U.lengths_spec(xs) : List<&2, Maybe<&2, U32>>}

law review_u_same_length:
  for +xs: List<&2, Maybe<&2, U32>>
  for +n: U32
  {U.same_length(n, xs) == U.same_length_spec(n, xs) : Bool}

law review_u_all_values:
  for +xs: List<&2, List<&2, U32>>
  {U.all_values(xs) == U.all_values_spec(xs) : List<&2, Maybe<&2, U32>>}

law review_u_coding:
  for +xs: List<&2, List<&2, U32>>
  {U.coding(xs) == U.coding_spec(xs) : List<&2, String>}

law review_h_strip_lead:
  for +xs: List<&2, U32>
  {H.strip_lead(xs) == H.strip_lead_spec(xs) : List<&2, U32>}

law review_h_listed_pick:
  for +v: List<&2, U32>
  for +rest: List<&2, String>
  for +on: Bool
  {H.listed_pick(v, rest, on) == H.listed_pick_spec(v, rest, on) : List<&2, String>}

law review_u_chain:
  for +xs: List<&2, String>
  for +mine: Maybe<&2, String>
  {U.chain(xs, mine) == U.chain_spec(xs, mine) : Maybe<&2, String>}

law review_text_concat:
  for -A: Data
  for +xs: List<&2, List<&2, A>>
  {T.concat(A, xs) == List.concat(&2, A, xs) : List<&2, A>}

law review_write_headers:
  for +xs: List<&2, R.Header>
  {W.headers(xs) == W.headers_spec(xs) : List<&2, U32>}

law review_text_take:
  for +s: String
  for +n: Nat
  {T.take(s, n) == String.take(s, n) : String}

law review_j_zeros:
  for +n: Nat
  {J.zeros(n) == J.zeros_spec(n) : String}
