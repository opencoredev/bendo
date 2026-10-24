# BND-68: proofs that the hot-path rewrites equal their retained specs.
import Base
import ./hot-path-laws.bend as Laws
import ../src/data/utf8.bend as Utf8
import ./utf8.bend as UP
import ../src/http/bytes.bend as B

def Laws.hot_utf8_encode_char(c):
  Equal.sym(List<&2, U32>, Utf8.encode_char_spec(c), Utf8.encode_char(c), UP.encode_char_equiv(c))

# ---- BND-68: the branching token classifier equals the string search ----

def punct_step_14(+c: U32, hit: Bool) -> {B.tchar_punct_14(c, hit) == String.contains.if("", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      {==}

def punct_step_13(+c: U32, hit: Bool) -> {B.tchar_punct_13(c, hit) == String.contains.if("~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_14(c, U32.is_eq(126, c))

def punct_step_12(+c: U32, hit: Bool) -> {B.tchar_punct_12(c, hit) == String.contains.if("|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_13(c, U32.is_eq(124, c))

def punct_step_11(+c: U32, hit: Bool) -> {B.tchar_punct_11(c, hit) == String.contains.if("`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_12(c, U32.is_eq(96, c))

def punct_step_10(+c: U32, hit: Bool) -> {B.tchar_punct_10(c, hit) == String.contains.if("_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_11(c, U32.is_eq(95, c))

def punct_step_9(+c: U32, hit: Bool) -> {B.tchar_punct_9(c, hit) == String.contains.if("^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_10(c, U32.is_eq(94, c))

def punct_step_8(+c: U32, hit: Bool) -> {B.tchar_punct_8(c, hit) == String.contains.if(".^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, ".^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_9(c, U32.is_eq(46, c))

def punct_step_7(+c: U32, hit: Bool) -> {B.tchar_punct_7(c, hit) == String.contains.if("-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_8(c, U32.is_eq(45, c))

def punct_step_6(+c: U32, hit: Bool) -> {B.tchar_punct_6(c, hit) == String.contains.if("+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_7(c, U32.is_eq(43, c))

def punct_step_5(+c: U32, hit: Bool) -> {B.tchar_punct_5(c, hit) == String.contains.if("*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_6(c, U32.is_eq(42, c))

def punct_step_4(+c: U32, hit: Bool) -> {B.tchar_punct_4(c, hit) == String.contains.if("'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_5(c, U32.is_eq(39, c))

def punct_step_3(+c: U32, hit: Bool) -> {B.tchar_punct_3(c, hit) == String.contains.if("&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_4(c, U32.is_eq(38, c))

def punct_step_2(+c: U32, hit: Bool) -> {B.tchar_punct_2(c, hit) == String.contains.if("%&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "%&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_3(c, U32.is_eq(37, c))

def punct_step_1(+c: U32, hit: Bool) -> {B.tchar_punct_1(c, hit) == String.contains.if("$%&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "$%&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_2(c, U32.is_eq(36, c))

def punct_step_0(+c: U32, hit: Bool) -> {B.tchar_punct_0(c, hit) == String.contains.if("#$%&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "#$%&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_1(c, U32.is_eq(35, c))

def tchar_pick_spec(+c: U32, alnum: Bool) -> {B.tchar_pick(c, alnum) == alnum || String.contains("!#$%&'*+-.^_`|~", Char.show(Chr{c})) : Bool}:
  match alnum:
    case True{}:
      {==}
    case False{}:
      punct_step_0(c, U32.is_eq(33, c))

def tchar_equiv(+c: U32) -> {B.tchar(c) == B.tchar_spec(c) : Bool}:
  tchar_pick_spec(c, ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)))

def Laws.hot_bytes_tchar(c): tchar_equiv(c)
