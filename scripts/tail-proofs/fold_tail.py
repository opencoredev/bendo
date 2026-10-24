import os
import sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); from folds import module
H = '''# Right folds over request lists and text, run as tail loops over the
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
'''
SL = 'List<&2, String>'; BL = 'List<&2, List<&2, U32>>'; UL = 'List<&2, U32>'
def lst(name, mod, L, E, pat, res, base, step, extra=('', ''), spec=None, go=None, impl=None, rpat=None):
    return dict(name=name, list=L, elem=E, pat=pat, rpat=rpat or pat.replace('+', ''), res=res, base=base, step=step,
                extra_decl=extra[0], extra_args=extra[1],
                spec=spec or '%s.%s_spec' % (mod, name.split('_', 1)[1]), go=go or '%s.%s_go' % (mod, name.split('_', 1)[1]),
                impl=impl or '%s.%s' % (mod, name.split('_', 1)[1]))
def txt(name, mod, pat, step, spec=None, go=None, impl=None, rpat=None):
    d = lst(name, mod, 'String', None, pat, 'Bool', 'True{}', step, spec=spec, go=go, impl=impl, rpat=rpat)
    d['string'] = True
    return d
F = [
  lst('e_parameters', 'E', SL, 'String', 'x', 'Bool', 'True{}', "E.parameter(E.split(E.trim(x), '=')) && {acc}"),
  lst('e_accepts_json_tokens', 'E', SL, 'String', 'x', 'Bool', 'False{}', "E.media(E.split(Bytes.fold(x), ';')) || {acc}"),
  lst('cn_tokens', 'Cn', SL, 'String', 'x', 'Bool', 'False{}', "Cn.token_hit(x, wanted) || {acc}", ('+wanted: String', 'wanted')),
  lst('cn_has_token', 'Cn', 'List<&2, R.Header>', 'R.Header', 'R.Header{n, v}', 'Bool', 'False{}', "Cn.header_hit(n, v, wanted) || {acc}", ('+wanted: String', 'wanted')),
  lst('w_has_element', 'W', SL, 'String', 'x', 'Bool', 'False{}', "String.eq(Bytes.fold(W.element(x)), wanted) || {acc}", ('+wanted: String', 'wanted')),
  lst('w_listed', 'W', BL, UL, 'x', 'Bool', 'False{}', "W.has_element(T.split(Bytes.ascii(x), ','), wanted) || {acc}", ('+wanted: String', 'wanted')),
  lst('w_zeros', 'W', UL, 'U32', '+c', 'Bool', 'True{}', "U32.is_eq(c, 48) && {acc}"),
  lst('w_has_offer', 'W', SL, 'String', 'x', 'Bool', 'False{}', "String.eq(W.element(x), p) || {acc}", ('+p: String', 'p')),
  lst('w_offered_any', 'W', BL, UL, 'x', 'Bool', 'False{}', "W.has_offer(T.split(Bytes.ascii(x), ','), p) || {acc}", ('+p: String', 'p')),
  lst('cond_members', 'Cond', SL, 'String', 'x', 'Sigma<&2, &2, Bool, _ => Bool>', '(True{}, False{})', "Cond.combine_member(Cond.trim(x), tag, {acc})", ('+tag: Maybe<&2, String>', 'tag')),
  lst('cp_tokens', 'Cp', SL, 'String', 'x', SL, '[]', "Cp.kept_token(Bytes.fold(String.trim(x)), {acc}, Bytes.token(Bytes.fold(String.trim(x))))"),
  lst('cr_texts', 'Cr', BL, UL, 'x', SL, '[]', "Cr.text(Utf8.decode(x)) <> {acc}"),
  txt('o_digits', 'O', 'c', "O.digit(c) && {acc}"),
  txt('o_name_chars', 'O', 'c', "O.name_char(c) && {acc}"),
  txt('o_ipv6_chars', 'O', 'c', "O.ipv6_char(c) && {acc}"),
  txt('be_body', 'Be', 'Chr{+c}', "Be.token_char(c) && {acc}", spec='Be.body_spec', go='Be.body_fold', impl='Be.body_go'),
  txt('ts_clean', 'Ts', 'c', "Bool.not(Ts.unsafe_char(c)) && {acc}"),
]
print(module(H, F))
