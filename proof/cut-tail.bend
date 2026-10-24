# Text.cut equals its right-fold spec, and each module's first-separator
# split equals Text.cut_spec under its own Cut type (BND-84).
# This module deliberately does not import LAWS.
import Base
import ../src/http/text.bend as T
import ./text.bend as TP
import ../src/crypto/jwt.bend as J
import ../src/http/origin.bend as O
import ../src/mw/auth_common.bend as A

# Reading s right to left onto the suffix ys keeps the accumulator equal to
# the spec's answer for the suffix.
def cut_reverse(+s: String, +r: String, +ys: String, +sep: Char) -> {T.cut_go(String.reverse.go(s, r), sep, T.Folded{ys, T.cut_spec(ys, sep)}) == T.cut_go(r, sep, T.Folded{String.append(s, ys), T.cut_spec(String.append(s, ys), sep)}) : Maybe<&2, T.Cut>}:
  match s:
    case SNil{}:
      {==}
    case SCon{c, t}:
      cut_reverse(t, SCon{c, r}, ys, sep)

def cut_equiv(+s: String, +sep: Char) -> {T.cut(s, sep) == T.cut_spec(s, sep) : Maybe<&2, T.Cut>}:
  Equal.trans(Maybe<&2, T.Cut>, T.cut(s, sep), T.cut_spec(String.append(s, ""), sep), T.cut_spec(s, sep), cut_reverse(s, "", "", sep), Equal.cong(String, Maybe<&2, T.Cut>, x => T.cut_spec(x, sep), String.append(s, ""), s, TP.string_append_nil(s)))

# ---- J ----

def J_prepend(c: Char, r: Maybe<&2, T.Cut>) -> {J.prepend(c, J.from_text(r)) == J.from_text(T.cut_prepend(c, r)) : Maybe<&2, J.Cut>}:
  match r:
    case None{}:
      {==}
    case Some{T.Cut{a, b}}:
      {==}

def J_pick(+c: Char, +t: String, here: Bool, ih: {J.split_spec(t) == J.from_text(T.cut_spec(t, '.')) : Maybe<&2, J.Cut>}) -> {J.split_pick(c, t, J.split_spec(t), here) == J.from_text(T.cut_pick(c, t, T.cut_spec(t, '.'), here)) : Maybe<&2, J.Cut>}:
  match here:
    case True{}:
      {==}
    case False{}:
      %Equal.sym(Maybe<&2, J.Cut>, J.split_spec(t), J.from_text(T.cut_spec(t, '.')), ih) : {J.prepend(c, _) == J.from_text(T.cut_prepend(c, T.cut_spec(t, '.'))) : Maybe<&2, J.Cut>}
      J_prepend(c, T.cut_spec(t, '.'))

def J_spec_text(+s: String) -> {J.split_spec(s) == J.from_text(T.cut_spec(s, '.')) : Maybe<&2, J.Cut>}:
  match s:
    case SNil{}:
      {==}
    case SCon{c, t}:
      J_pick(c, t, Char.is_eq(c, '.'), J_spec_text(t))

def J_equiv(+s: String) -> {J.split(s) == J.split_spec(s) : Maybe<&2, J.Cut>}:
  %Equal.sym(Maybe<&2, T.Cut>, T.cut(s, '.'), T.cut_spec(s, '.'), cut_equiv(s, '.')) : {J.from_text(_) == J.split_spec(s) : Maybe<&2, J.Cut>}
  Equal.sym(Maybe<&2, J.Cut>, J.split_spec(s), J.from_text(T.cut_spec(s, '.')), J_spec_text(s))

# ---- O ----

def O_prepend(c: Char, r: Maybe<&2, T.Cut>) -> {O.cut_prepend(c, O.from_text(r)) == O.from_text(T.cut_prepend(c, r)) : Maybe<&2, O.Cut>}:
  match r:
    case None{}:
      {==}
    case Some{T.Cut{a, b}}:
      {==}

def O_pick(+c: Char, +t: String, +sep: Char, here: Bool, ih: {O.cut_spec(t, sep) == O.from_text(T.cut_spec(t, sep)) : Maybe<&2, O.Cut>}) -> {O.cut_pick(c, t, O.cut_spec(t, sep), here) == O.from_text(T.cut_pick(c, t, T.cut_spec(t, sep), here)) : Maybe<&2, O.Cut>}:
  match here:
    case True{}:
      {==}
    case False{}:
      %Equal.sym(Maybe<&2, O.Cut>, O.cut_spec(t, sep), O.from_text(T.cut_spec(t, sep)), ih) : {O.cut_prepend(c, _) == O.from_text(T.cut_prepend(c, T.cut_spec(t, sep))) : Maybe<&2, O.Cut>}
      O_prepend(c, T.cut_spec(t, sep))

def O_spec_text(+s: String, +sep: Char) -> {O.cut_spec(s, sep) == O.from_text(T.cut_spec(s, sep)) : Maybe<&2, O.Cut>}:
  match s:
    case SNil{}:
      {==}
    case SCon{c, t}:
      O_pick(c, t, sep, Char.is_eq(c, sep), O_spec_text(t, sep))

def O_equiv(+s: String, +sep: Char) -> {O.cut(s, sep) == O.cut_spec(s, sep) : Maybe<&2, O.Cut>}:
  %Equal.sym(Maybe<&2, T.Cut>, T.cut(s, sep), T.cut_spec(s, sep), cut_equiv(s, sep)) : {O.from_text(_) == O.cut_spec(s, sep) : Maybe<&2, O.Cut>}
  Equal.sym(Maybe<&2, O.Cut>, O.cut_spec(s, sep), O.from_text(T.cut_spec(s, sep)), O_spec_text(s, sep))

# ---- A ----

def A_prepend(c: Char, r: Maybe<&2, T.Cut>) -> {A.cut_prepend(c, A.from_text(r)) == A.from_text(T.cut_prepend(c, r)) : Maybe<&2, A.Cut>}:
  match r:
    case None{}:
      {==}
    case Some{T.Cut{a, b}}:
      {==}

def A_pick(+c: Char, +t: String, +sep: Char, here: Bool, ih: {A.cut_spec(t, sep) == A.from_text(T.cut_spec(t, sep)) : Maybe<&2, A.Cut>}) -> {A.cut_pick(c, t, A.cut_spec(t, sep), here) == A.from_text(T.cut_pick(c, t, T.cut_spec(t, sep), here)) : Maybe<&2, A.Cut>}:
  match here:
    case True{}:
      {==}
    case False{}:
      %Equal.sym(Maybe<&2, A.Cut>, A.cut_spec(t, sep), A.from_text(T.cut_spec(t, sep)), ih) : {A.cut_prepend(c, _) == A.from_text(T.cut_prepend(c, T.cut_spec(t, sep))) : Maybe<&2, A.Cut>}
      A_prepend(c, T.cut_spec(t, sep))

def A_spec_text(+s: String, +sep: Char) -> {A.cut_spec(s, sep) == A.from_text(T.cut_spec(s, sep)) : Maybe<&2, A.Cut>}:
  match s:
    case SNil{}:
      {==}
    case SCon{c, t}:
      A_pick(c, t, sep, Char.is_eq(c, sep), A_spec_text(t, sep))

def A_equiv(+s: String, +sep: Char) -> {A.cut(s, sep) == A.cut_spec(s, sep) : Maybe<&2, A.Cut>}:
  %Equal.sym(Maybe<&2, T.Cut>, T.cut(s, sep), T.cut_spec(s, sep), cut_equiv(s, sep)) : {A.from_text(_) == A.cut_spec(s, sep) : Maybe<&2, A.Cut>}
  Equal.sym(Maybe<&2, A.Cut>, A.cut_spec(s, sep), A.from_text(T.cut_spec(s, sep)), A_spec_text(s, sep))
