# Right folds over request lists and text, run as tail loops over the
# reversed input, equal their recursive specs (BND-84). Generated from one
# template: onto is the spec's fold onto any accumulator.
# This module deliberately does not import LAWS.
import Base
import ../src/http/bytes.bend as Bytes
import ../src/http/text.bend as T
import ../src/http/request.bend as R
import ../src/data/utf8.bend as Utf8
import ../src/app/errors.bend as E
import ../src/http/connection.bend as Cn
import ../src/http/websocket.bend as W
import ../src/http/conditional.bend as Cond
import ../src/mw/cors_policy.bend as Cp
import ../src/mw/cors_request.bend as Cr
import ../src/http/origin.bend as O
import ../src/mw/bearer_auth.bend as Be
import ../src/mw/trailing_slash_policy.bend as Ts

def e_parameters_onto(+xs: List<&2, String>, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      E.parameter(E.split(E.trim(x), '=')) && e_parameters_onto(t, acc)

def e_parameters_onto_base(+xs: List<&2, String>) -> {e_parameters_onto(xs, True{}) == E.parameters_spec(xs) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(Bool, Bool, folded => E.parameter(E.split(E.trim(x), '=')) && folded, e_parameters_onto(t, True{}), E.parameters_spec(t), e_parameters_onto_base(t))

def e_parameters_reverse(+xs: List<&2, String>, +r: List<&2, String>, +acc: Bool) -> {E.parameters_go(List.reverse.go(&2, String, xs, r), acc) == E.parameters_go(r, e_parameters_onto(xs, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      e_parameters_reverse(t, x <> r, acc)

def e_parameters_equiv(+xs: List<&2, String>) -> {E.parameters(xs) == E.parameters_spec(xs) : Bool}:
  Equal.trans(Bool, E.parameters(xs), e_parameters_onto(xs, True{}), E.parameters_spec(xs), e_parameters_reverse(xs, [], True{}), e_parameters_onto_base(xs))

def e_accepts_json_tokens_onto(+xs: List<&2, String>, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      E.media(E.split(Bytes.fold(x), ';')) || e_accepts_json_tokens_onto(t, acc)

def e_accepts_json_tokens_onto_base(+xs: List<&2, String>) -> {e_accepts_json_tokens_onto(xs, False{}) == E.accepts_json_tokens_spec(xs) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(Bool, Bool, folded => E.media(E.split(Bytes.fold(x), ';')) || folded, e_accepts_json_tokens_onto(t, False{}), E.accepts_json_tokens_spec(t), e_accepts_json_tokens_onto_base(t))

def e_accepts_json_tokens_reverse(+xs: List<&2, String>, +r: List<&2, String>, +acc: Bool) -> {E.accepts_json_tokens_go(List.reverse.go(&2, String, xs, r), acc) == E.accepts_json_tokens_go(r, e_accepts_json_tokens_onto(xs, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      e_accepts_json_tokens_reverse(t, x <> r, acc)

def e_accepts_json_tokens_equiv(+xs: List<&2, String>) -> {E.accepts_json_tokens(xs) == E.accepts_json_tokens_spec(xs) : Bool}:
  Equal.trans(Bool, E.accepts_json_tokens(xs), e_accepts_json_tokens_onto(xs, False{}), E.accepts_json_tokens_spec(xs), e_accepts_json_tokens_reverse(xs, [], False{}), e_accepts_json_tokens_onto_base(xs))

def cn_tokens_onto(+xs: List<&2, String>, +wanted: String, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      Cn.token_hit(x, wanted) || cn_tokens_onto(t, wanted, acc)

def cn_tokens_onto_base(+xs: List<&2, String>, +wanted: String) -> {cn_tokens_onto(xs, wanted, False{}) == Cn.tokens_spec(xs, wanted) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(Bool, Bool, folded => Cn.token_hit(x, wanted) || folded, cn_tokens_onto(t, wanted, False{}), Cn.tokens_spec(t, wanted), cn_tokens_onto_base(t, wanted))

def cn_tokens_reverse(+xs: List<&2, String>, +r: List<&2, String>, +wanted: String, +acc: Bool) -> {Cn.tokens_go(List.reverse.go(&2, String, xs, r), wanted, acc) == Cn.tokens_go(r, wanted, cn_tokens_onto(xs, wanted, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      cn_tokens_reverse(t, x <> r, wanted, acc)

def cn_tokens_equiv(+xs: List<&2, String>, +wanted: String) -> {Cn.tokens(xs, wanted) == Cn.tokens_spec(xs, wanted) : Bool}:
  Equal.trans(Bool, Cn.tokens(xs, wanted), cn_tokens_onto(xs, wanted, False{}), Cn.tokens_spec(xs, wanted), cn_tokens_reverse(xs, [], wanted, False{}), cn_tokens_onto_base(xs, wanted))

def cn_has_token_onto(+xs: List<&2, R.Header>, +wanted: String, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case R.Header{n, v} <> t:
      Cn.header_hit(n, v, wanted) || cn_has_token_onto(t, wanted, acc)

def cn_has_token_onto_base(+xs: List<&2, R.Header>, +wanted: String) -> {cn_has_token_onto(xs, wanted, False{}) == Cn.has_token_spec(xs, wanted) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case R.Header{n, v} <> t:
      Equal.cong(Bool, Bool, folded => Cn.header_hit(n, v, wanted) || folded, cn_has_token_onto(t, wanted, False{}), Cn.has_token_spec(t, wanted), cn_has_token_onto_base(t, wanted))

def cn_has_token_reverse(+xs: List<&2, R.Header>, +r: List<&2, R.Header>, +wanted: String, +acc: Bool) -> {Cn.has_token_go(List.reverse.go(&2, R.Header, xs, r), wanted, acc) == Cn.has_token_go(r, wanted, cn_has_token_onto(xs, wanted, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case R.Header{n, v} <> t:
      cn_has_token_reverse(t, R.Header{n, v} <> r, wanted, acc)

def cn_has_token_equiv(+xs: List<&2, R.Header>, +wanted: String) -> {Cn.has_token(xs, wanted) == Cn.has_token_spec(xs, wanted) : Bool}:
  Equal.trans(Bool, Cn.has_token(xs, wanted), cn_has_token_onto(xs, wanted, False{}), Cn.has_token_spec(xs, wanted), cn_has_token_reverse(xs, [], wanted, False{}), cn_has_token_onto_base(xs, wanted))

def w_has_element_onto(+xs: List<&2, String>, +wanted: String, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      String.eq(Bytes.fold(W.element(x)), wanted) || w_has_element_onto(t, wanted, acc)

def w_has_element_onto_base(+xs: List<&2, String>, +wanted: String) -> {w_has_element_onto(xs, wanted, False{}) == W.has_element_spec(xs, wanted) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(Bool, Bool, folded => String.eq(Bytes.fold(W.element(x)), wanted) || folded, w_has_element_onto(t, wanted, False{}), W.has_element_spec(t, wanted), w_has_element_onto_base(t, wanted))

def w_has_element_reverse(+xs: List<&2, String>, +r: List<&2, String>, +wanted: String, +acc: Bool) -> {W.has_element_go(List.reverse.go(&2, String, xs, r), wanted, acc) == W.has_element_go(r, wanted, w_has_element_onto(xs, wanted, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      w_has_element_reverse(t, x <> r, wanted, acc)

def w_has_element_equiv(+xs: List<&2, String>, +wanted: String) -> {W.has_element(xs, wanted) == W.has_element_spec(xs, wanted) : Bool}:
  Equal.trans(Bool, W.has_element(xs, wanted), w_has_element_onto(xs, wanted, False{}), W.has_element_spec(xs, wanted), w_has_element_reverse(xs, [], wanted, False{}), w_has_element_onto_base(xs, wanted))

def w_listed_onto(+xs: List<&2, List<&2, U32>>, +wanted: String, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      W.has_element(T.split(Bytes.ascii(x), ','), wanted) || w_listed_onto(t, wanted, acc)

def w_listed_onto_base(+xs: List<&2, List<&2, U32>>, +wanted: String) -> {w_listed_onto(xs, wanted, False{}) == W.listed_spec(xs, wanted) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(Bool, Bool, folded => W.has_element(T.split(Bytes.ascii(x), ','), wanted) || folded, w_listed_onto(t, wanted, False{}), W.listed_spec(t, wanted), w_listed_onto_base(t, wanted))

def w_listed_reverse(+xs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +wanted: String, +acc: Bool) -> {W.listed_go(List.reverse.go(&2, List<&2, U32>, xs, r), wanted, acc) == W.listed_go(r, wanted, w_listed_onto(xs, wanted, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      w_listed_reverse(t, x <> r, wanted, acc)

def w_listed_equiv(+xs: List<&2, List<&2, U32>>, +wanted: String) -> {W.listed(xs, wanted) == W.listed_spec(xs, wanted) : Bool}:
  Equal.trans(Bool, W.listed(xs, wanted), w_listed_onto(xs, wanted, False{}), W.listed_spec(xs, wanted), w_listed_reverse(xs, [], wanted, False{}), w_listed_onto_base(xs, wanted))

def w_zeros_onto(+xs: List<&2, U32>, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case +c <> t:
      U32.is_eq(c, 48) && w_zeros_onto(t, acc)

def w_zeros_onto_base(+xs: List<&2, U32>) -> {w_zeros_onto(xs, True{}) == W.zeros_spec(xs) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +c <> t:
      Equal.cong(Bool, Bool, folded => U32.is_eq(c, 48) && folded, w_zeros_onto(t, True{}), W.zeros_spec(t), w_zeros_onto_base(t))

def w_zeros_reverse(+xs: List<&2, U32>, +r: List<&2, U32>, +acc: Bool) -> {W.zeros_go(List.reverse.go(&2, U32, xs, r), acc) == W.zeros_go(r, w_zeros_onto(xs, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +c <> t:
      w_zeros_reverse(t, c <> r, acc)

def w_zeros_equiv(+xs: List<&2, U32>) -> {W.zeros(xs) == W.zeros_spec(xs) : Bool}:
  Equal.trans(Bool, W.zeros(xs), w_zeros_onto(xs, True{}), W.zeros_spec(xs), w_zeros_reverse(xs, [], True{}), w_zeros_onto_base(xs))

def w_has_offer_onto(+xs: List<&2, String>, +p: String, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      String.eq(W.element(x), p) || w_has_offer_onto(t, p, acc)

def w_has_offer_onto_base(+xs: List<&2, String>, +p: String) -> {w_has_offer_onto(xs, p, False{}) == W.has_offer_spec(xs, p) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(Bool, Bool, folded => String.eq(W.element(x), p) || folded, w_has_offer_onto(t, p, False{}), W.has_offer_spec(t, p), w_has_offer_onto_base(t, p))

def w_has_offer_reverse(+xs: List<&2, String>, +r: List<&2, String>, +p: String, +acc: Bool) -> {W.has_offer_go(List.reverse.go(&2, String, xs, r), p, acc) == W.has_offer_go(r, p, w_has_offer_onto(xs, p, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      w_has_offer_reverse(t, x <> r, p, acc)

def w_has_offer_equiv(+xs: List<&2, String>, +p: String) -> {W.has_offer(xs, p) == W.has_offer_spec(xs, p) : Bool}:
  Equal.trans(Bool, W.has_offer(xs, p), w_has_offer_onto(xs, p, False{}), W.has_offer_spec(xs, p), w_has_offer_reverse(xs, [], p, False{}), w_has_offer_onto_base(xs, p))

def w_offered_any_onto(+xs: List<&2, List<&2, U32>>, +p: String, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      W.has_offer(T.split(Bytes.ascii(x), ','), p) || w_offered_any_onto(t, p, acc)

def w_offered_any_onto_base(+xs: List<&2, List<&2, U32>>, +p: String) -> {w_offered_any_onto(xs, p, False{}) == W.offered_any_spec(xs, p) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(Bool, Bool, folded => W.has_offer(T.split(Bytes.ascii(x), ','), p) || folded, w_offered_any_onto(t, p, False{}), W.offered_any_spec(t, p), w_offered_any_onto_base(t, p))

def w_offered_any_reverse(+xs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +p: String, +acc: Bool) -> {W.offered_any_go(List.reverse.go(&2, List<&2, U32>, xs, r), p, acc) == W.offered_any_go(r, p, w_offered_any_onto(xs, p, acc)) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      w_offered_any_reverse(t, x <> r, p, acc)

def w_offered_any_equiv(+xs: List<&2, List<&2, U32>>, +p: String) -> {W.offered_any(xs, p) == W.offered_any_spec(xs, p) : Bool}:
  Equal.trans(Bool, W.offered_any(xs, p), w_offered_any_onto(xs, p, False{}), W.offered_any_spec(xs, p), w_offered_any_reverse(xs, [], p, False{}), w_offered_any_onto_base(xs, p))

def cond_members_onto(+xs: List<&2, String>, +tag: Maybe<&2, String>, acc: Sigma<&2, &2, Bool, _ => Bool>) -> Sigma<&2, &2, Bool, _ => Bool>:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      Cond.combine_member(Cond.trim(x), tag, cond_members_onto(t, tag, acc))

def cond_members_onto_base(+xs: List<&2, String>, +tag: Maybe<&2, String>) -> {cond_members_onto(xs, tag, (True{}, False{})) == Cond.members_spec(xs, tag) : Sigma<&2, &2, Bool, _ => Bool>}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(Sigma<&2, &2, Bool, _ => Bool>, Sigma<&2, &2, Bool, _ => Bool>, folded => Cond.combine_member(Cond.trim(x), tag, folded), cond_members_onto(t, tag, (True{}, False{})), Cond.members_spec(t, tag), cond_members_onto_base(t, tag))

def cond_members_reverse(+xs: List<&2, String>, +r: List<&2, String>, +tag: Maybe<&2, String>, +acc: Sigma<&2, &2, Bool, _ => Bool>) -> {Cond.members_go(List.reverse.go(&2, String, xs, r), tag, acc) == Cond.members_go(r, tag, cond_members_onto(xs, tag, acc)) : Sigma<&2, &2, Bool, _ => Bool>}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      cond_members_reverse(t, x <> r, tag, acc)

def cond_members_equiv(+xs: List<&2, String>, +tag: Maybe<&2, String>) -> {Cond.members(xs, tag) == Cond.members_spec(xs, tag) : Sigma<&2, &2, Bool, _ => Bool>}:
  Equal.trans(Sigma<&2, &2, Bool, _ => Bool>, Cond.members(xs, tag), cond_members_onto(xs, tag, (True{}, False{})), Cond.members_spec(xs, tag), cond_members_reverse(xs, [], tag, (True{}, False{})), cond_members_onto_base(xs, tag))

def cp_tokens_onto(+xs: List<&2, String>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      Cp.kept_token(Bytes.fold(String.trim(x)), cp_tokens_onto(t, acc), Bytes.token(Bytes.fold(String.trim(x))))

def cp_tokens_onto_base(+xs: List<&2, String>) -> {cp_tokens_onto(xs, []) == Cp.tokens_spec(xs) : List<&2, String>}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(List<&2, String>, List<&2, String>, folded => Cp.kept_token(Bytes.fold(String.trim(x)), folded, Bytes.token(Bytes.fold(String.trim(x)))), cp_tokens_onto(t, []), Cp.tokens_spec(t), cp_tokens_onto_base(t))

def cp_tokens_reverse(+xs: List<&2, String>, +r: List<&2, String>, +acc: List<&2, String>) -> {Cp.tokens_go(List.reverse.go(&2, String, xs, r), acc) == Cp.tokens_go(r, cp_tokens_onto(xs, acc)) : List<&2, String>}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      cp_tokens_reverse(t, x <> r, acc)

def cp_tokens_equiv(+xs: List<&2, String>) -> {Cp.tokens(xs) == Cp.tokens_spec(xs) : List<&2, String>}:
  Equal.trans(List<&2, String>, Cp.tokens(xs), cp_tokens_onto(xs, []), Cp.tokens_spec(xs), cp_tokens_reverse(xs, [], []), cp_tokens_onto_base(xs))

def cr_texts_onto(+xs: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      Cr.text(Utf8.decode(x)) <> cr_texts_onto(t, acc)

def cr_texts_onto_base(+xs: List<&2, List<&2, U32>>) -> {cr_texts_onto(xs, []) == Cr.texts_spec(xs) : List<&2, String>}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      Equal.cong(List<&2, String>, List<&2, String>, folded => Cr.text(Utf8.decode(x)) <> folded, cr_texts_onto(t, []), Cr.texts_spec(t), cr_texts_onto_base(t))

def cr_texts_reverse(+xs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +acc: List<&2, String>) -> {Cr.texts_go(List.reverse.go(&2, List<&2, U32>, xs, r), acc) == Cr.texts_go(r, cr_texts_onto(xs, acc)) : List<&2, String>}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      cr_texts_reverse(t, x <> r, acc)

def cr_texts_equiv(+xs: List<&2, List<&2, U32>>) -> {Cr.texts(xs) == Cr.texts_spec(xs) : List<&2, String>}:
  Equal.trans(List<&2, String>, Cr.texts(xs), cr_texts_onto(xs, []), Cr.texts_spec(xs), cr_texts_reverse(xs, [], []), cr_texts_onto_base(xs))

def o_digits_onto(+xs: String, acc: Bool) -> Bool:
  match xs:
    case SNil{}:
      acc
    case SCon{c, t}:
      O.digit(c) && o_digits_onto(t, acc)

def o_digits_onto_base(+xs: String) -> {o_digits_onto(xs, True{}) == O.digits_spec(xs) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{c, t}:
      Equal.cong(Bool, Bool, folded => O.digit(c) && folded, o_digits_onto(t, True{}), O.digits_spec(t), o_digits_onto_base(t))

def o_digits_reverse(+xs: String, +r: String, +acc: Bool) -> {O.digits_go(String.reverse.go(xs, r), acc) == O.digits_go(r, o_digits_onto(xs, acc)) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{c, t}:
      o_digits_reverse(t, SCon{c, r}, acc)

def o_digits_equiv(+xs: String) -> {O.digits(xs) == O.digits_spec(xs) : Bool}:
  Equal.trans(Bool, O.digits(xs), o_digits_onto(xs, True{}), O.digits_spec(xs), o_digits_reverse(xs, "", True{}), o_digits_onto_base(xs))

def o_name_chars_onto(+xs: String, acc: Bool) -> Bool:
  match xs:
    case SNil{}:
      acc
    case SCon{c, t}:
      O.name_char(c) && o_name_chars_onto(t, acc)

def o_name_chars_onto_base(+xs: String) -> {o_name_chars_onto(xs, True{}) == O.name_chars_spec(xs) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{c, t}:
      Equal.cong(Bool, Bool, folded => O.name_char(c) && folded, o_name_chars_onto(t, True{}), O.name_chars_spec(t), o_name_chars_onto_base(t))

def o_name_chars_reverse(+xs: String, +r: String, +acc: Bool) -> {O.name_chars_go(String.reverse.go(xs, r), acc) == O.name_chars_go(r, o_name_chars_onto(xs, acc)) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{c, t}:
      o_name_chars_reverse(t, SCon{c, r}, acc)

def o_name_chars_equiv(+xs: String) -> {O.name_chars(xs) == O.name_chars_spec(xs) : Bool}:
  Equal.trans(Bool, O.name_chars(xs), o_name_chars_onto(xs, True{}), O.name_chars_spec(xs), o_name_chars_reverse(xs, "", True{}), o_name_chars_onto_base(xs))

def o_ipv6_chars_onto(+xs: String, acc: Bool) -> Bool:
  match xs:
    case SNil{}:
      acc
    case SCon{c, t}:
      O.ipv6_char(c) && o_ipv6_chars_onto(t, acc)

def o_ipv6_chars_onto_base(+xs: String) -> {o_ipv6_chars_onto(xs, True{}) == O.ipv6_chars_spec(xs) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{c, t}:
      Equal.cong(Bool, Bool, folded => O.ipv6_char(c) && folded, o_ipv6_chars_onto(t, True{}), O.ipv6_chars_spec(t), o_ipv6_chars_onto_base(t))

def o_ipv6_chars_reverse(+xs: String, +r: String, +acc: Bool) -> {O.ipv6_chars_go(String.reverse.go(xs, r), acc) == O.ipv6_chars_go(r, o_ipv6_chars_onto(xs, acc)) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{c, t}:
      o_ipv6_chars_reverse(t, SCon{c, r}, acc)

def o_ipv6_chars_equiv(+xs: String) -> {O.ipv6_chars(xs) == O.ipv6_chars_spec(xs) : Bool}:
  Equal.trans(Bool, O.ipv6_chars(xs), o_ipv6_chars_onto(xs, True{}), O.ipv6_chars_spec(xs), o_ipv6_chars_reverse(xs, "", True{}), o_ipv6_chars_onto_base(xs))

def be_body_onto(+xs: String, acc: Bool) -> Bool:
  match xs:
    case SNil{}:
      acc
    case SCon{Chr{+c}, t}:
      Be.token_char(c) && be_body_onto(t, acc)

def be_body_onto_base(+xs: String) -> {be_body_onto(xs, True{}) == Be.body_spec(xs) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      Equal.cong(Bool, Bool, folded => Be.token_char(c) && folded, be_body_onto(t, True{}), Be.body_spec(t), be_body_onto_base(t))

def be_body_reverse(+xs: String, +r: String, +acc: Bool) -> {Be.body_fold(String.reverse.go(xs, r), acc) == Be.body_fold(r, be_body_onto(xs, acc)) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      be_body_reverse(t, SCon{Chr{c}, r}, acc)

def be_body_equiv(+xs: String) -> {Be.body_go(xs) == Be.body_spec(xs) : Bool}:
  Equal.trans(Bool, Be.body_go(xs), be_body_onto(xs, True{}), Be.body_spec(xs), be_body_reverse(xs, "", True{}), be_body_onto_base(xs))

def ts_clean_onto(+xs: String, acc: Bool) -> Bool:
  match xs:
    case SNil{}:
      acc
    case SCon{c, t}:
      Bool.not(Ts.unsafe_char(c)) && ts_clean_onto(t, acc)

def ts_clean_onto_base(+xs: String) -> {ts_clean_onto(xs, True{}) == Ts.clean_spec(xs) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{c, t}:
      Equal.cong(Bool, Bool, folded => Bool.not(Ts.unsafe_char(c)) && folded, ts_clean_onto(t, True{}), Ts.clean_spec(t), ts_clean_onto_base(t))

def ts_clean_reverse(+xs: String, +r: String, +acc: Bool) -> {Ts.clean_go(String.reverse.go(xs, r), acc) == Ts.clean_go(r, ts_clean_onto(xs, acc)) : Bool}:
  match xs:
    case SNil{}:
      {==}
    case SCon{c, t}:
      ts_clean_reverse(t, SCon{c, r}, acc)

def ts_clean_equiv(+xs: String) -> {Ts.clean(xs) == Ts.clean_spec(xs) : Bool}:
  Equal.trans(Bool, Ts.clean(xs), ts_clean_onto(xs, True{}), Ts.clean_spec(xs), ts_clean_reverse(xs, "", True{}), ts_clean_onto_base(xs))
