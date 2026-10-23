import Base
import ../src/data/base64.bend as B
import ../src/data/utf8.bend as U
import ../src/crypto/octets.bend as O
import ./utf8.bend as UP
import ./crypto-support.bend as S

def alphabet(+w: Word(6n), +url: Bool) -> {B.value(B.symbol(w, url), url) == Some{w} : Maybe<&2, Word(6n)>}:
  match w:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      match url:
        case False{}:
          {==}
        case True{}:
          {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      match url:
        case False{}:
          {==}
        case True{}:
          {==}

def encode_acc(+xs: List<&2, U32>, +url: Bool, +padded: Bool, +rev: String) -> {B.encode_go(xs, url, padded, rev) == String.reverse.go(rev, B.encode_spec(xs, url, padded)) : String}:
  match xs:
    case Nil{}:
      {==}
    case U32{+a} <> Nil{}:
      S.reverse_last(B.one(U.low(8n, 24n, a), url, padded), rev)
    case U32{+a} <> U32{+b} <> Nil{}:
      S.reverse_last(B.two(U.low(8n, 24n, a), U.low(8n, 24n, b), url, padded), rev)
    case U32{+a} <> U32{+b} <> U32{+c} <> +t:
      +block = B.three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url)
      %Equal.sym(String, B.encode_go(t, url, padded, String.reverse(block) ++ rev), String.reverse.go(String.reverse(block) ++ rev, B.encode_spec(t, url, padded)), encode_acc(t, url, padded, String.reverse(block) ++ rev)) : {_ == String.reverse.go(rev, block ++ B.encode_spec(t, url, padded)) : String}
      S.reverse_block(block, rev, B.encode_spec(t, url, padded))

def symbols1(+a: Word(6n), +b: Word(6n), +url: Bool, +rev: List<&2, U32>, +ok: Bool) -> {B.decode1(B.value(B.symbol(a, url), url), B.value(B.symbol(b, url), url), Some{rev}, ok) == B.decode1(Some{a}, Some{b}, Some{rev}, ok) : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(a, url), url), Some{a}, alphabet(a, url)) : {B.decode1(_, B.value(B.symbol(b, url), url), Some{rev}, ok) == B.decode1(Some{a}, Some{b}, Some{rev}, ok) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(b, url), url), Some{b}, alphabet(b, url)) : {B.decode1(Some{a}, _, Some{rev}, ok) == B.decode1(Some{a}, Some{b}, Some{rev}, ok) : Maybe<&2, List<&2, U32>>}
  {==}

def symbols2(+a: Word(6n), +b: Word(6n), +c: Word(6n), +url: Bool, +rev: List<&2, U32>, +ok: Bool) -> {B.decode2(B.value(B.symbol(a, url), url), B.value(B.symbol(b, url), url), B.value(B.symbol(c, url), url), Some{rev}, ok) == B.decode2(Some{a}, Some{b}, Some{c}, Some{rev}, ok) : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(a, url), url), Some{a}, alphabet(a, url)) : {B.decode2(_, B.value(B.symbol(b, url), url), B.value(B.symbol(c, url), url), Some{rev}, ok) == B.decode2(Some{a}, Some{b}, Some{c}, Some{rev}, ok) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(b, url), url), Some{b}, alphabet(b, url)) : {B.decode2(Some{a}, _, B.value(B.symbol(c, url), url), Some{rev}, ok) == B.decode2(Some{a}, Some{b}, Some{c}, Some{rev}, ok) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(c, url), url), Some{c}, alphabet(c, url)) : {B.decode2(Some{a}, Some{b}, _, Some{rev}, ok) == B.decode2(Some{a}, Some{b}, Some{c}, Some{rev}, ok) : Maybe<&2, List<&2, U32>>}
  {==}

def symbols3(+a: Word(6n), +b: Word(6n), +c: Word(6n), +d: Word(6n), +url: Bool, +rev: List<&2, U32>) -> {B.decode3(B.value(B.symbol(a, url), url), B.value(B.symbol(b, url), url), B.value(B.symbol(c, url), url), B.value(B.symbol(d, url), url), Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(a, url), url), Some{a}, alphabet(a, url)) : {B.decode3(_, B.value(B.symbol(b, url), url), B.value(B.symbol(c, url), url), B.value(B.symbol(d, url), url), Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(b, url), url), Some{b}, alphabet(b, url)) : {B.decode3(Some{a}, _, B.value(B.symbol(c, url), url), B.value(B.symbol(d, url), url), Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(c, url), url), Some{c}, alphabet(c, url)) : {B.decode3(Some{a}, Some{b}, _, B.value(B.symbol(d, url), url), Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(d, url), url), Some{d}, alphabet(d, url)) : {B.decode3(Some{a}, Some{b}, Some{c}, _, Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}
  {==}

def quartet_symbols(+a: Word(6n), +b: Word(6n), +c: Word(6n), +d: Word(6n), +url: Bool, +padded: Bool, +terminal: Bool, +rev: List<&2, U32>) -> {B.quartet(B.symbol(a, url), B.symbol(b, url), B.symbol(c, url), B.symbol(d, url), url, padded, terminal, Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(c, url), url), Some{c}, alphabet(c, url)) : {B.quartet_values(_, B.value(B.symbol(d, url), url), B.value(B.symbol(a, url), url), B.value(B.symbol(b, url), url), padded && terminal && Char.is_eq(B.symbol(c, url), '='), padded && terminal && Char.is_eq(B.symbol(d, url), '='), Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(d, url), url), Some{d}, alphabet(d, url)) : {B.quartet_values(Some{c}, _, B.value(B.symbol(a, url), url), B.value(B.symbol(b, url), url), padded && terminal && Char.is_eq(B.symbol(c, url), '='), padded && terminal && Char.is_eq(B.symbol(d, url), '='), Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(a, url), url), Some{a}, alphabet(a, url)) : {B.quartet_values(Some{c}, Some{d}, _, B.value(B.symbol(b, url), url), padded && terminal && Char.is_eq(B.symbol(c, url), '='), padded && terminal && Char.is_eq(B.symbol(d, url), '='), Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(b, url), url), Some{b}, alphabet(b, url)) : {B.quartet_values(Some{c}, Some{d}, Some{a}, _, padded && terminal && Char.is_eq(B.symbol(c, url), '='), padded && terminal && Char.is_eq(B.symbol(d, url), '='), Some{rev}) == B.decode3(Some{a}, Some{b}, Some{c}, Some{d}, Some{rev}) : Maybe<&2, List<&2, U32>>}
  {==}
def tail1(+a: Word(6n), +b: Word(6n), +url: Bool, +rev: List<&2, U32>) -> {B.quartet(B.symbol(a, url), B.symbol(b, url), '=', '=', url, True{}, True{}, Some{rev}) == B.decode1(Some{a}, Some{b}, Some{rev}, True{}) : Maybe<&2, List<&2, U32>>}:
  symbols1(a, b, url, rev, True{})

def tail2(+a: Word(6n), +b: Word(6n), +c: Word(6n), +url: Bool, +rev: List<&2, U32>) -> {B.quartet(B.symbol(a, url), B.symbol(b, url), B.symbol(c, url), '=', url, True{}, True{}, Some{rev}) == B.decode2(Some{a}, Some{b}, Some{c}, Some{rev}, True{}) : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(c, url), url), Some{c}, alphabet(c, url)) : {B.quartet_values(_, None{}, B.value(B.symbol(a, url), url), B.value(B.symbol(b, url), url), Char.is_eq(B.symbol(c, url), '='), True{}, Some{rev}) == B.decode2(Some{a}, Some{b}, Some{c}, Some{rev}, True{}) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(a, url), url), Some{a}, alphabet(a, url)) : {B.decode2(_, B.value(B.symbol(b, url), url), Some{c}, Some{rev}, True{}) == B.decode2(Some{a}, Some{b}, Some{c}, Some{rev}, True{}) : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(B.symbol(b, url), url), Some{b}, alphabet(b, url)) : {B.decode2(Some{a}, _, Some{c}, Some{rev}, True{}) == B.decode2(Some{a}, Some{b}, Some{c}, Some{rev}, True{}) : Maybe<&2, List<&2, U32>>}
  {==}

def word1(+a: Word(8n), +url: Bool, padded: Bool, +rev: List<&2, U32>) -> {B.decode_go(B.one(a, url, padded), url, padded, Some{rev}) == Some{List.reverse.go(&2, U32, rev, [B.octet(a)])} : Maybe<&2, List<&2, U32>>}:
  match a:
    case WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WCon{a6, WCon{a7, WNil{}}}}}}}}}:
      match padded:
        case True{}:
          %Equal.sym(Maybe<&2, List<&2, U32>>, B.quartet(B.symbol(U.high(2n, 6n, a), url), B.symbol(U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url), '=', '=', url, True{}, True{}, Some{rev}), B.decode1(Some{U.high(2n, 6n, a)}, Some{U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a))}, Some{rev}, True{}), tail1(U.high(2n, 6n, a), U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url, rev)) : {B.finish(_) == Some{List.reverse.go(&2, U32, rev, [B.octet(a)])} : Maybe<&2, List<&2, U32>>}
          {==}
        case False{}:
          %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode1(B.value(B.symbol(U.high(2n, 6n, a), url), url), B.value(B.symbol(U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url), url), Some{rev}, True{}), B.decode1(Some{U.high(2n, 6n, a)}, Some{U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a))}, Some{rev}, True{}), symbols1(U.high(2n, 6n, a), U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url, rev, True{})) : {B.finish(_) == Some{List.reverse.go(&2, U32, rev, [B.octet(a)])} : Maybe<&2, List<&2, U32>>}
          {==}

def word2(+a: Word(8n), +b: Word(8n), +url: Bool, padded: Bool, +rev: List<&2, U32>) -> {B.decode_go(B.two(a, b, url, padded), url, padded, Some{rev}) == Some{List.reverse.go(&2, U32, rev, [B.octet(a), B.octet(b)])} : Maybe<&2, List<&2, U32>>}:
  match a b:
    case WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WCon{a6, WCon{a7, WNil{}}}}}}}}} WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WNil{}}}}}}}}}:
      match padded:
        case True{}:
          %Equal.sym(Maybe<&2, List<&2, U32>>, B.quartet(B.symbol(U.high(2n, 6n, a), url), B.symbol(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url), B.symbol(U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url), '=', url, True{}, True{}, Some{rev}), B.decode2(Some{U.high(2n, 6n, a)}, Some{U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a))}, Some{U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b))}, Some{rev}, True{}), tail2(U.high(2n, 6n, a), U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url, rev)) : {B.finish(_) == Some{List.reverse.go(&2, U32, rev, [B.octet(a), B.octet(b)])} : Maybe<&2, List<&2, U32>>}
          {==}
        case False{}:
          %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode2(B.value(B.symbol(U.high(2n, 6n, a), url), url), B.value(B.symbol(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url), url), B.value(B.symbol(U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url), url), Some{rev}, True{}), B.decode2(Some{U.high(2n, 6n, a)}, Some{U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a))}, Some{U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b))}, Some{rev}, True{}), symbols2(U.high(2n, 6n, a), U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url, rev, True{})) : {B.finish(_) == Some{List.reverse.go(&2, U32, rev, [B.octet(a), B.octet(b)])} : Maybe<&2, List<&2, U32>>}
          {==}

def word3(+a: Word(8n), +b: Word(8n), +c: Word(8n), +tail: String, +url: Bool, +padded: Bool, +rev: List<&2, U32>) -> {B.decode_go(B.three(a, b, c, url) ++ tail, url, padded, Some{rev}) == B.decode_go(tail, url, padded, Some{B.octet(c) <> B.octet(b) <> B.octet(a) <> rev}) : Maybe<&2, List<&2, U32>>}:
  match a b c:
    case WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WCon{a6, WCon{a7, WNil{}}}}}}}}} WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WNil{}}}}}}}}} WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WCon{c6, WCon{c7, WNil{}}}}}}}}}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.quartet(B.symbol(U.high(2n, 6n, a), url), B.symbol(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url), B.symbol(U.join(2n, 4n, U.high(6n, 2n, c), U.low(4n, 4n, b)), url), B.symbol(U.low(6n, 2n, c), url), url, padded, B.empty(tail), Some{rev}), B.decode3(Some{U.high(2n, 6n, a)}, Some{U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a))}, Some{U.join(2n, 4n, U.high(6n, 2n, c), U.low(4n, 4n, b))}, Some{U.low(6n, 2n, c)}, Some{rev}), quartet_symbols(U.high(2n, 6n, a), U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), U.join(2n, 4n, U.high(6n, 2n, c), U.low(4n, 4n, b)), U.low(6n, 2n, c), url, padded, B.empty(tail), rev)) : {B.decode_go(tail, url, padded, _) == B.decode_go(tail, url, padded, Some{B.octet(c) <> B.octet(b) <> B.octet(a) <> rev}) : Maybe<&2, List<&2, U32>>}
      {==}

def bytes1(+a: Word(32n), +url: Bool, +padded: Bool, +rev: List<&2, U32>, oka: {(U32{a} <= 255 : U32) == True{} : Bool}) -> {B.decode_go(B.one(U.low(8n, 24n, a), url, padded), url, padded, Some{rev}) == Some{List.reverse.go(&2, U32, rev, [U32{a}])} : Maybe<&2, List<&2, U32>>}:
  %S.byte_reconstruct(a, oka) : {B.decode_go(B.one(U.low(8n, 24n, a), url, padded), url, padded, Some{rev}) == Some{List.reverse.go(&2, U32, rev, [_])} : Maybe<&2, List<&2, U32>>}
  word1(U.low(8n, 24n, a), url, padded, rev)

def bytes2(+a: Word(32n), +b: Word(32n), +url: Bool, +padded: Bool, +rev: List<&2, U32>, oka: {(U32{a} <= 255 : U32) == True{} : Bool}, okb: {(U32{b} <= 255 : U32) == True{} : Bool}) -> {B.decode_go(B.two(U.low(8n, 24n, a), U.low(8n, 24n, b), url, padded), url, padded, Some{rev}) == Some{List.reverse.go(&2, U32, rev, [U32{a}, U32{b}])} : Maybe<&2, List<&2, U32>>}:
  %S.byte_reconstruct(a, oka) : {B.decode_go(B.two(U.low(8n, 24n, a), U.low(8n, 24n, b), url, padded), url, padded, Some{rev}) == Some{List.reverse.go(&2, U32, rev, [_, U32{b}])} : Maybe<&2, List<&2, U32>>}
  %S.byte_reconstruct(b, okb) : {B.decode_go(B.two(U.low(8n, 24n, a), U.low(8n, 24n, b), url, padded), url, padded, Some{rev}) == Some{List.reverse.go(&2, U32, rev, [B.octet(U.low(8n, 24n, a)), _])} : Maybe<&2, List<&2, U32>>}
  word2(U.low(8n, 24n, a), U.low(8n, 24n, b), url, padded, rev)

def bytes3(+a: Word(32n), +b: Word(32n), +c: Word(32n), +tail: String, +url: Bool, +padded: Bool, +rev: List<&2, U32>, oka: {(U32{a} <= 255 : U32) == True{} : Bool}, okb: {(U32{b} <= 255 : U32) == True{} : Bool}, okc: {(U32{c} <= 255 : U32) == True{} : Bool}) -> {B.decode_go(B.three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url) ++ tail, url, padded, Some{rev}) == B.decode_go(tail, url, padded, Some{U32{c} <> U32{b} <> U32{a} <> rev}) : Maybe<&2, List<&2, U32>>}:
  %S.byte_reconstruct(a, oka) : {B.decode_go(B.three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url) ++ tail, url, padded, Some{rev}) == B.decode_go(tail, url, padded, Some{U32{c} <> U32{b} <> _ <> rev}) : Maybe<&2, List<&2, U32>>}
  %S.byte_reconstruct(b, okb) : {B.decode_go(B.three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url) ++ tail, url, padded, Some{rev}) == B.decode_go(tail, url, padded, Some{U32{c} <> _ <> B.octet(U.low(8n, 24n, a)) <> rev}) : Maybe<&2, List<&2, U32>>}
  %S.byte_reconstruct(c, okc) : {B.decode_go(B.three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url) ++ tail, url, padded, Some{rev}) == B.decode_go(tail, url, padded, Some{_ <> B.octet(U.low(8n, 24n, b)) <> B.octet(U.low(8n, 24n, a)) <> rev}) : Maybe<&2, List<&2, U32>>}
  word3(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), tail, url, padded, rev)

def head(+x: U32, +xs: List<&2, U32>, ok: {O.valid(x <> xs) == True{} : Bool}) -> {(x <= 255 : U32) == True{} : Bool}:
  UP.and_left((x <= 255 : U32), O.valid(xs), ok)

def tail(+x: U32, +xs: List<&2, U32>, ok: {O.valid(x <> xs) == True{} : Bool}) -> {O.valid(xs) == True{} : Bool}:
  UP.and_right((x <= 255 : U32), O.valid(xs), ok)

def roundtrip_go(+xs: List<&2, U32>, +url: Bool, +padded: Bool, +rev: List<&2, U32>, +ok: {O.valid(xs) == True{} : Bool}) -> {B.decode_go(B.encode_spec(xs, url, padded), url, padded, Some{rev}) == Some{List.reverse.go(&2, U32, rev, xs)} : Maybe<&2, List<&2, U32>>}:
  match xs:
    case Nil{}:
      {==}
    case U32{+a} <> Nil{}:
      bytes1(a, url, padded, rev, head(U32{a}, [], ok))
    case U32{+a} <> U32{+b} <> Nil{}:
      bytes2(a, b, url, padded, rev, head(U32{a}, [U32{b}], ok), head(U32{b}, [], tail(U32{a}, [U32{b}], ok)))
    case U32{+a} <> U32{+b} <> U32{+c} <> +t:
      +okb = tail(U32{a}, U32{b} <> U32{c} <> t, ok)
      +okc = tail(U32{b}, U32{c} <> t, okb)
      okt = tail(U32{c}, t, okc)
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode_go(B.three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url) ++ B.encode_spec(t, url, padded), url, padded, Some{rev}), B.decode_go(B.encode_spec(t, url, padded), url, padded, Some{U32{c} <> U32{b} <> U32{a} <> rev}), bytes3(a, b, c, B.encode_spec(t, url, padded), url, padded, rev, head(U32{a}, U32{b} <> U32{c} <> t, ok), head(U32{b}, U32{c} <> t, okb), head(U32{c}, t, okc))) : {_ == Some{List.reverse.go(&2, U32, rev, U32{a} <> U32{b} <> U32{c} <> t)} : Maybe<&2, List<&2, U32>>}
      roundtrip_go(t, url, padded, U32{c} <> U32{b} <> U32{a} <> rev, okt)

def roundtrip(+xs: List<&2, U32>, +url: Bool, +padded: Bool, ok: {O.valid(xs) == True{} : Bool}) -> {B.decode(B.encode(xs, url, padded), url, padded) == Some{xs} : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(String, B.encode(xs, url, padded), B.encode_spec(xs, url, padded), encode_acc(xs, url, padded, "")) : {B.decode(_, url, padded) == Some{xs} : Maybe<&2, List<&2, U32>>}
  roundtrip_go(xs, url, padded, [], ok)
