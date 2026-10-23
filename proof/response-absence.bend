# Filtered application headers cannot supply a Content-Length wire line.
import Base
import ../LAWS.bend as Laws
import ../src/http/bytes.bend as B
import ../src/http/request.bend as R
import ../src/http/write_response.bend as W
import ./equality.bend as E
import ./tokens.bend as Tokens
import ./line.bend as Line
import ./response-lines.bend as Lines
import ./scanner.bend as Scanner
import ./support.bend as Support

def starts_head(+a: U32, +b: U32, +s: String, +p: String, same: Bool, eq: {Char.is_eq(Chr{a}, Chr{b}) == same : Bool}, yes: {String.starts_with.go.if(p, s, same) == True{} : Bool}) -> {a == b : U32}:
  match same:
    case False{}:
      E.absurd({a == b : U32}, E.false_true(yes))
    case True{}:
      Laws.u32_eq_sound(a, b, eq)

def starts_tail(+s: String, +p: String, same: Bool, yes: {String.starts_with.go.if(p, s, same) == True{} : Bool}) -> {String.starts_with(s, p) == True{} : Bool}:
  match same:
    case False{}:
      E.absurd({String.starts_with(s, p) == True{} : Bool}, E.false_true(yes))
    case True{}:
      yes

# A colon terminates a token, so a delimited prefix identifies the whole name.
def token_delimited_sound(+s: String, +p: String, +tail: String, +sv: {B.token_tail(s) == True{} : Bool}, +pv: {B.token_tail(p) == True{} : Bool}, +yes: {String.starts_with(s ++ ":" ++ tail, p ++ ":") == True{} : Bool}) -> {s == p : String}:
  match s p:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{Chr{c}, pt}:
      eq = starts_head(58, c, tail, pt ++ ":", Char.is_eq(':', Chr{c}), {==}, yes)
      bad = Equal.trans(Bool, False{}, B.tchar(c), True{}, Equal.cong(U32, Bool, x => B.tchar(x), 58, c, eq), Laws.and_left(B.tchar(c), B.token_tail(pt), pv))
      E.absurd({SNil{} == SCon{Chr{c}, pt} : String}, E.false_true(bad))
    case SCon{Chr{c}, st} SNil{}:
      eq = starts_head(c, 58, st ++ ":" ++ tail, "", Char.is_eq(Chr{c}, ':'), {==}, yes)
      bad = Equal.trans(Bool, False{}, B.tchar(c), True{}, Equal.cong(U32, Bool, x => B.tchar(x), 58, c, Equal.sym(U32, c, 58, eq)), Laws.and_left(B.tchar(c), B.token_tail(st), sv))
      E.absurd({SCon{Chr{c}, st} == SNil{} : String}, E.false_true(bad))
    case SCon{Chr{a}, st} SCon{Chr{b}, pt}:
      head = starts_head(a, b, st ++ ":" ++ tail, pt ++ ":", Char.is_eq(Chr{a}, Chr{b}), {==}, yes)
      rest = token_delimited_sound(st, pt, tail, Laws.and_right(B.tchar(a), B.token_tail(st), sv), Laws.and_right(B.tchar(b), B.token_tail(pt), pv), starts_tail(st ++ ":" ++ tail, pt ++ ":", Char.is_eq(Chr{a}, Chr{b}), yes))
      Equal.trans(String, SCon{Chr{a}, st}, SCon{Chr{b}, st}, SCon{Chr{b}, pt}, Equal.cong(U32, String, c => SCon{Chr{c}, st}, a, b, head), Equal.cong(String, String, t => SCon{Chr{b}, t}, st, pt, rest))

def header_token(+n: String, +v: List<&2, U32>, +valid: {R.header_valid(R.Header{n, v}) == True{} : Bool}) -> {B.token_tail(n) == True{} : Bool}:
  a = Laws.and_left(B.token(n) && String.eq(n, B.fold(n)) && B.value(v) && R.value_start(v), R.value_start(List.reverse(&2, U32, v)), valid)
  b = Laws.and_left(B.token(n) && String.eq(n, B.fold(n)) && B.value(v), R.value_start(v), a)
  c = Laws.and_left(B.token(n) && String.eq(n, B.fold(n)), B.value(v), b)
  Laws.token_tail_valid(n, Laws.and_left(B.token(n), String.eq(n, B.fold(n)), c))

def retained_not_length(+n: String, +v: List<&2, U32>, +tail: String, +valid: {R.header_valid(R.Header{n, v}) == True{} : Bool}, +keep: {W.user_header(R.Header{n, v}) == True{} : Bool}, here: Bool, eq: {String.starts_with(n ++ ": " ++ B.ascii(v) ++ tail, "content-length:") == here : Bool}) -> {here == False{} : Bool}:
  match here:
    case False{}:
      {==}
    case True{}:
      same = token_delimited_sound(n, "content-length", " " ++ B.ascii(v) ++ tail, header_token(n, v, valid), {==}, eq)
      excluded = Tokens.or_false_left(String.eq(n, "content-length"), String.eq(n, "transfer-encoding"), Tokens.not_true_false(String.eq(n, "content-length") || String.eq(n, "transfer-encoding"), keep))
      bad = Equal.trans(Bool, False{}, String.eq(n, "content-length"), True{}, Equal.sym(Bool, String.eq(n, "content-length"), False{}, excluded), Equal.cong(String, Bool, s => String.eq(s, "content-length"), n, "content-length", same))
      E.absurd({True{} == False{} : Bool}, E.false_true(bad))

def header_absent(+h: R.Header, +tail: String, +valid: {R.header_valid(h) == True{} : Bool}, keep: {W.user_header(h) == True{} : Bool}, absent: {String.contains(tail, "\r\ncontent-length:") == False{} : Bool}) -> {String.contains("\r\n" ++ W.header_text(h) ++ tail, "\r\ncontent-length:") == False{} : Bool}:
  match h:
    case R.Header{n, v}:
      no_start = Equal.trans(Bool, String.starts_with(W.header_text(R.Header{n, v}) ++ tail, "content-length:"), String.starts_with(n ++ ": " ++ B.ascii(v) ++ tail, "content-length:"), False{}, Equal.cong(String, Bool, s => String.starts_with(s, "content-length:"), (n ++ ": " ++ B.ascii(v)) ++ tail, n ++ ((": " ++ B.ascii(v)) ++ tail), Line.string_assoc(n, ": " ++ B.ascii(v), tail)), retained_not_length(n, v, tail, valid, keep, String.starts_with(n ++ ": " ++ B.ascii(v) ++ tail, "content-length:"), {==}))
      %Equal.sym(Bool, String.starts_with(W.header_text(R.Header{n, v}) ++ tail, "content-length:"), False{}, no_start) : {String.contains.if("\n" ++ W.header_text(R.Header{n, v}) ++ tail, "\r\ncontent-length:", _) == False{} : Bool}
      Equal.trans(Bool, String.contains(W.header_text(R.Header{n, v}) ++ tail, "\r\ncontent-length:"), String.contains(tail, "\r\ncontent-length:"), False{}, Lines.clear_scan(W.header_text(R.Header{n, v}), tail, "\ncontent-length:", Lines.header_clear(R.Header{n, v}, Laws.header_scannable_valid(R.Header{n, v}, valid))), absent)

def filtered_absent_step(+h: R.Header, +rest: List<&2, R.Header>, +valid: {R.header_valid(h) == True{} : Bool}, keep: Bool, eq: {W.user_header(h) == keep : Bool}, absent: {String.contains(W.headers_text(rest), "\r\ncontent-length:") == False{} : Bool}) -> {String.contains(W.headers_text(List.filter.put(R.Header, h, rest, keep)), "\r\ncontent-length:") == False{} : Bool}:
  match keep:
    case False{}:
      absent
    case True{}:
      header_absent(h, W.headers_text(rest), valid, eq, absent)

def filtered_headers_absent(+hs: List<&2, R.Header>, valid: {R.headers_valid(hs) == True{} : Bool}) -> {String.contains(W.headers_text(W.headers(hs)), "\r\ncontent-length:") == False{} : Bool}:
  match hs:
    case Nil{}:
      {==}
    case h <> t:
      +ok = valid
      filtered_absent_step(h, W.headers(t), Laws.and_left(R.header_valid(h), R.headers_valid(t), ok), W.user_header(h), {==}, filtered_headers_absent(t, Laws.and_right(R.header_valid(h), R.headers_valid(t), ok)))
