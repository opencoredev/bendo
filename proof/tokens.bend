# Token splitting lemmas. No scanner or parser assumptions.
import Base
import ../LAWS.bend as Laws
import ./support.bend as Support
import ./equality.bend as E
import ../src/http/bytes.bend as B
import ./bytes-tail.bend as BT
import ../src/http/request.bend as R

def tchar_space_case(+c: U32, ok: {B.tchar(c) == True{} : Bool}, same: Bool, e: {U32.is_eq(c, 32) == same : Bool}) -> {same == False{} : Bool}:
  match same:
    case False{}:
      {==}
    case True{}:
      eq = Laws.u32_eq_sound(c, 32, e)
      bad = Equal.trans(Bool, False{}, B.tchar(c), True{}, Equal.cong(U32, Bool, x => B.tchar(x), 32, c, Equal.sym(U32, c, 32, eq)), ok)
      E.absurd({True{} == False{} : Bool}, E.false_true(bad))

def Laws.tchar_not_space(c, ok):
  tchar_space_case(c, ok, U32.is_eq(c, 32), {==})

# Induction runs on the direct-recursion spec; the law converts at the boundary.
def split_token_tail_spec(+s: String, +rest: String, +ok: {B.token_tail_spec(s) == True{} : Bool}) -> {String.split(s ++ " " ++ rest, ' ') == s <> String.split(rest, ' ') : List<&2, String>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      e1 = Laws.tchar_not_space(c, Laws.and_left(B.tchar(c), B.token_tail_spec(t), ok))
      e2 = split_token_tail_spec(t, rest, Laws.and_right(B.tchar(c), B.token_tail_spec(t), ok))
      Equal.trans(List<&2, String>, String.split.fin(Chr{c}, String.split(t ++ " " ++ rest, ' '), Char.is_eq(Chr{c}, ' ')), String.split.fin(Chr{c}, String.split(t ++ " " ++ rest, ' '), False{}), SCon{Chr{c}, t} <> String.split(rest, ' '), Equal.cong(Bool, List<&2, String>, same => String.split.fin(Chr{c}, String.split(t ++ " " ++ rest, ' '), same), Char.is_eq(Chr{c}, ' '), False{}, e1), Equal.cong(List<&2, String>, List<&2, String>, parts => String.split.push(Chr{c}, parts), String.split(t ++ " " ++ rest, ' '), t <> String.split(rest, ' '), e2))

def Laws.split_token_tail(s, rest, ok):
  split_token_tail_spec(s, rest, Equal.trans(Bool, B.token_tail_spec(s), B.token_tail(s), True{}, Equal.sym(Bool, B.token_tail(s), B.token_tail_spec(s), BT.token_tail_equiv(s)), ok))

def Laws.method_text_token(method, ok):
  match method:
    case R.Get{}:
      {==}
    case R.Head{}:
      {==}
    case R.Post{}:
      {==}
    case R.Put{}:
      {==}
    case R.Delete{}:
      {==}
    case R.Connect{}:
      {==}
    case R.Options{}:
      {==}
    case R.Trace{}:
      {==}
    case R.Patch{}:
      {==}
    case R.Extension{s}:
      Laws.and_left(B.token(s), Bool.not(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT") || String.eq(s, "OPTIONS") || String.eq(s, "TRACE") || String.eq(s, "PATCH")), ok)

def Laws.token_tail_valid(s, ok):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      Equal.trans(Bool, B.token_tail(SCon{Chr{c}, t}), B.tchar(c) && B.token_tail(t), True{}, Equal.trans(Bool, B.token_tail(SCon{Chr{c}, t}), B.tchar(c) && B.token_tail_spec(t), B.tchar(c) && B.token_tail(t), BT.token_tail_equiv(SCon{Chr{c}, t}), Equal.cong(Bool, Bool, x => B.tchar(c) && x, B.token_tail_spec(t), B.token_tail(t), Equal.sym(Bool, B.token_tail(t), B.token_tail_spec(t), BT.token_tail_equiv(t)))), ok)

def Laws.split_method(method, rest, ok):
  Laws.split_token_tail(R.method_text(method), rest, Laws.token_tail_valid(R.method_text(method), Laws.method_text_token(method, ok)))

# A false disjunction has a false left operand.
def or_false_left(a: Bool, b: Bool, e: {a || b == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      E.absurd({True{} == False{} : Bool}, E.false_true(Equal.sym(Bool, True{}, False{}, e)))

# A false disjunction has a false right operand.
def or_false_right(a: Bool, b: Bool, e: {a || b == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case False{}:
      e
    case True{}:
      E.absurd({b == False{} : Bool}, E.false_true(Equal.sym(Bool, True{}, False{}, e)))

def not_true_false(b: Bool, e: {Bool.not(b) == True{} : Bool}) -> {b == False{} : Bool}:
  match b:
    case False{}:
      {==}
    case True{}:
      E.absurd({True{} == False{} : Bool}, E.false_true(e))

# Canonical extension tokens cannot alias a standard method.
def Laws.method_recover(m, ok):
  match m:
    case R.Get{}:
      {==}
    case R.Head{}:
      {==}
    case R.Post{}:
      {==}
    case R.Put{}:
      {==}
    case R.Delete{}:
      {==}
    case R.Connect{}:
      {==}
    case R.Options{}:
      {==}
    case R.Trace{}:
      {==}
    case R.Patch{}:
      {==}
    case R.Extension{s}:
      +no = not_true_false(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT") || String.eq(s, "OPTIONS") || String.eq(s, "TRACE") || String.eq(s, "PATCH"), Laws.and_right(B.token(s), Bool.not(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT") || String.eq(s, "OPTIONS") || String.eq(s, "TRACE") || String.eq(s, "PATCH")), ok))
      e8 = or_false_right(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT") || String.eq(s, "OPTIONS") || String.eq(s, "TRACE"), String.eq(s, "PATCH"), no)
      +no = or_false_left(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT") || String.eq(s, "OPTIONS") || String.eq(s, "TRACE"), String.eq(s, "PATCH"), no)
      e7 = or_false_right(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT") || String.eq(s, "OPTIONS"), String.eq(s, "TRACE"), no)
      +no = or_false_left(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT") || String.eq(s, "OPTIONS"), String.eq(s, "TRACE"), no)
      e6 = or_false_right(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT"), String.eq(s, "OPTIONS"), no)
      +no = or_false_left(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT"), String.eq(s, "OPTIONS"), no)
      e5 = or_false_right(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE"), String.eq(s, "CONNECT"), no)
      +no = or_false_left(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE"), String.eq(s, "CONNECT"), no)
      e4 = or_false_right(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT"), String.eq(s, "DELETE"), no)
      +no = or_false_left(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT"), String.eq(s, "DELETE"), no)
      e3 = or_false_right(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST"), String.eq(s, "PUT"), no)
      +no = or_false_left(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST"), String.eq(s, "PUT"), no)
      e2 = or_false_right(String.eq(s, "GET") || String.eq(s, "HEAD"), String.eq(s, "POST"), no)
      +no = or_false_left(String.eq(s, "GET") || String.eq(s, "HEAD"), String.eq(s, "POST"), no)
      e1 = or_false_right(String.eq(s, "GET"), String.eq(s, "HEAD"), no)
      +no = or_false_left(String.eq(s, "GET"), String.eq(s, "HEAD"), no)
      e0 = no
      %Equal.sym(Bool, String.eq(s, "GET"), False{}, e0) : {R.method_get(s, _) == R.Extension{s} : R.Method}
      %Equal.sym(Bool, String.eq(s, "HEAD"), False{}, e1) : {R.method_head(s, _) == R.Extension{s} : R.Method}
      %Equal.sym(Bool, String.eq(s, "POST"), False{}, e2) : {R.method_post(s, _) == R.Extension{s} : R.Method}
      %Equal.sym(Bool, String.eq(s, "PUT"), False{}, e3) : {R.method_put(s, _) == R.Extension{s} : R.Method}
      %Equal.sym(Bool, String.eq(s, "DELETE"), False{}, e4) : {R.method_delete(s, _) == R.Extension{s} : R.Method}
      %Equal.sym(Bool, String.eq(s, "CONNECT"), False{}, e5) : {R.method_connect(s, _) == R.Extension{s} : R.Method}
      %Equal.sym(Bool, String.eq(s, "OPTIONS"), False{}, e6) : {R.method_options(s, _) == R.Extension{s} : R.Method}
      %Equal.sym(Bool, String.eq(s, "TRACE"), False{}, e7) : {R.method_trace(s, _) == R.Extension{s} : R.Method}
      %Equal.sym(Bool, String.eq(s, "PATCH"), False{}, e8) : {R.method_patch(s, _) == R.Extension{s} : R.Method}
      {==}
