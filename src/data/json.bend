# RFC 8259 JSON. Ordered object members retain duplicates; lookup takes first.
import Base
import ./utf8.bend as Utf8
import ../http/bytes.bend as Bytes

type Json is Data:
  JNull{}
  JBool{value: Bool}
  JNumber{value: String}
  JString{value: String}
  JArray{items: List<&2, Json>}
  JObject{fields: List<&2, Field>}

type Field is Data:
  Field{key: String, value: Json}

type Error is Data:
  Syntax{}
  InvalidUtf8{}
  DepthLimit{}
  InvalidValue{}
  FuelExhausted{}

type Frame is Data:
  ArrayFrame{rev: List<&2, Json>}
  ObjectFrame{rev: List<&2, Field>}
  MemberFrame{key: String, rev: List<&2, Field>}

type Mode is Data:
  MValue{}
  MArrayFirst{}
  MReadKey{empty: Bool}
  MColon{key: String}
  MArrayAfter{rev: List<&2, Json>}
  MObjectAfter{rev: List<&2, Field>}
  MEmit{value: Json}
  MEnd{value: Json}
  MText{rev: String, key: Bool}
  MEscape{rev: String, key: Bool}
  MHex{left: Nat, code: U32, high: U32, rev: String, key: Bool}
  MLowSlash{high: U32, rev: String, key: Bool}
  MLowU{high: U32, rev: String, key: Bool}
  MLiteral{rest: String, value: Json}
  MNumber{phase: U32, rev: String}
  MBad{error: Error}

type Machine is Data:
  Machine{mode: Mode, input: String, stack: List<&2, Frame>, depth: Nat}

def whitespace(c: U32) -> Bool:
  match c:
    case 32: True{}
    case 9: True{}
    case 10: True{}
    case 13: True{}
    case _: False{}

def digit(+c: U32) -> Bool:
  (c >= 48 : U32) && (c <= 57 : U32)

# 0=start, 1=minus, 2=zero, 3=integer, 4=dot, 5=fraction,
# 6=exponent marker, 7=exponent sign, 8=exponent digits, 99=invalid.
def number_digit(phase: U32, c: U32, yes: Bool) -> U32:
  match phase c yes:
    case 0 45 _: 1
    case 0 48 _: 2
    case 1 48 _: 2
    case 0 _ True{}: 3
    case 1 _ True{}: 3
    case 3 _ True{}: 3
    case 4 _ True{}: 5
    case 5 _ True{}: 5
    case 6 _ True{}: 8
    case 7 _ True{}: 8
    case 8 _ True{}: 8
    case 2 46 _: 4
    case 3 46 _: 4
    case 2 101 _: 6
    case 2 69 _: 6
    case 3 101 _: 6
    case 3 69 _: 6
    case 5 101 _: 6
    case 5 69 _: 6
    case 6 43 _: 7
    case 6 45 _: 7
    case _ _ _: 99

def number_step(phase: U32, +c: U32) -> U32:
  number_digit(phase, c, digit(c))

def number_end(phase: U32) -> Bool:
  match phase:
    case 2: True{}
    case 3: True{}
    case 5: True{}
    case 8: True{}
    case _: False{}

def number_valid_go(s: String, phase: U32) -> Bool:
  match s:
    case SNil{}: number_end(phase)
    case SCon{Chr{c}, t}: number_valid_go(t, number_step(phase, c))

def number_valid(s: String) -> Bool:
  number_valid_go(s, 0)

def scalar_go(s: String, ok: Bool) -> Bool:
  match s ok:
    case _ False{}: False{}
    case SNil{} True{}: True{}
    case SCon{Chr{c}, t} True{}: scalar_go(t, Utf8.scalar(c))

def scalars(s: String) -> Bool:
  scalar_go(s, True{})

def finished_text(s: String, key: Bool) -> Mode:
  match key:
    case True{}: MColon{s}
    case False{}: MEmit{JString{s}}

def ordinary(+c: U32, rev: String, key: Bool, ok: Bool) -> Mode:
  match ok:
    case True{}: MText{SCon{Chr{c}, rev}, key}
    case False{}: MBad{Syntax{}}

def escaped(c: U32, rev: String, key: Bool) -> Mode:
  match c:
    case 34: MText{SCon{'"', rev}, key}
    case 92: MText{SCon{Chr{92}, rev}, key}
    case 47: MText{SCon{'/', rev}, key}
    case 98: MText{SCon{Chr{8}, rev}, key}
    case 102: MText{SCon{Chr{12}, rev}, key}
    case 110: MText{SCon{'\n', rev}, key}
    case 114: MText{SCon{'\r', rev}, key}
    case 116: MText{SCon{'\t', rev}, key}
    case 117: MHex{4n, 0, 0, rev, key}
    case _: MBad{Syntax{}}

def unhex_lower(+c: U32, lower: Bool) -> U32:
  match lower:
    case True{}: (c - 87 : U32)
    case False{}: (c - 55 : U32)

def unhex(+c: U32, decimal: Bool) -> U32:
  match decimal:
    case True{}: (c - 48 : U32)
    case False{}: unhex_lower(c, (c >= 97 : U32))

def hex_step(n: Nat, code: U32, high: U32, rev: String, key: Bool, +c: U32, ok: Bool) -> Mode:
  match ok:
    case True{}: MHex{n, ((code << 4n : U32) + unhex(c, digit(c)) : U32), high, rev, key}
    case False{}: MBad{Syntax{}}

def unicode_low(+code: U32, high: U32, rev: String, key: Bool, ok: Bool) -> Mode:
  match ok:
    case True{}: MText{SCon{Chr{(65536 + ((high - 55296 : U32) << 10n : U32) + code - 56320 : U32)}, rev}, key}
    case False{}: MBad{Syntax{}}

def unicode_single(+code: U32, rev: String, key: Bool, high: Bool) -> Mode:
  match high:
    case True{}: MLowSlash{code, rev, key}
    case False{}: ordinary(code, rev, key, Utf8.scalar(code))

def unicode_done(+code: U32, high: U32, rev: String, key: Bool) -> Mode:
  match high:
    case 0: unicode_single(code, rev, key, (code >= 55296 : U32) && (code <= 56319 : U32))
    case h: unicode_low(code, h, rev, key, (code >= 56320 : U32) && (code <= 57343 : U32))

def number_finish(rev: String, ok: Bool) -> Mode:
  match ok:
    case True{}: MEmit{JNumber{String.reverse(rev)}}
    case False{}: MBad{Syntax{}}

def number_next(next: U32, phase: U32, rev: String, +c: U32, t: String, stack: List<&2, Frame>, depth: Nat) -> Machine:
  match next:
    case 99: Machine{number_finish(rev, number_end(phase)), SCon{Chr{c}, t}, stack, depth}
    case n: Machine{MNumber{n, SCon{Chr{c}, rev}}, t, stack, depth}

def open_container(mode: Mode, t: String, stack: List<&2, Frame>, depth: Nat, full: Bool) -> Machine:
  match full:
    case True{}: Machine{MBad{DepthLimit{}}, t, stack, depth}
    case False{}: Machine{mode, t, stack, 1n+depth}

def literal_next(rest: String, value: Json, ok: Bool) -> Mode:
  match ok:
    case True{}: MLiteral{rest, value}
    case False{}: MBad{Syntax{}}

# Each call performs one finite-state transition. Only parse_go recurses.
def token(mode: Mode, input: String, stack: List<&2, Frame>, depth: Nat) -> Machine:
  match mode input stack depth:
    case MEmit{v} s Nil{} d: Machine{MEnd{v}, s, [], d}
    case MEmit{v} s ArrayFrame{rev} <> fs d: Machine{MArrayAfter{v <> rev}, s, fs, d}
    case MEmit{v} s MemberFrame{k, rev} <> fs d: Machine{MObjectAfter{Field{k, v} <> rev}, s, fs, d}
    case MHex{0n, c, h, rev, k} s fs d: Machine{unicode_done(c, h, rev, k), s, fs, d}
    case MLiteral{SNil{}, v} s fs d: Machine{MEmit{v}, s, fs, d}
    case MLiteral{SCon{+c, rest}, v} SCon{+got, t} fs d:
      Machine{literal_next(rest, v, Char.is_eq(c, got)), t, fs, d}
    case MNumber{+p, rev} SNil{} fs d: Machine{number_finish(rev, number_end(p)), "", fs, d}
    case MNumber{+p, rev} SCon{Chr{+c}, t} fs d: number_next(number_step(p, c), p, rev, c, t, fs, d)
    case MValue{} SCon{Chr{110}, t} fs d: Machine{MLiteral{"ull", JNull{}}, t, fs, d}
    case MValue{} SCon{Chr{116}, t} fs d: Machine{MLiteral{"rue", JBool{True{}}}, t, fs, d}
    case MValue{} SCon{Chr{102}, t} fs d: Machine{MLiteral{"alse", JBool{False{}}}, t, fs, d}
    case MValue{} SCon{Chr{34}, t} fs d: Machine{MText{"", False{}}, t, fs, d}
    case MValue{} SCon{Chr{91}, t} fs +d: open_container(MArrayFirst{}, t, fs, d, Nat.is_ge(d, 512n))
    case MValue{} SCon{Chr{123}, t} fs +d: open_container(MReadKey{True{}}, t, ObjectFrame{[]} <> fs, d, Nat.is_ge(d, 512n))
    case MValue{} SCon{Chr{+c}, t} fs d: number_next(number_step(0, c), 0, "", c, t, fs, d)
    case MArrayFirst{} SCon{Chr{93}, t} fs 1n+d: Machine{MEmit{JArray{[]}}, t, fs, d}
    case MArrayFirst{} s fs d: Machine{MValue{}, s, ArrayFrame{[]} <> fs, d}
    case MArrayAfter{rev} SCon{Chr{44}, t} fs d: Machine{MValue{}, t, ArrayFrame{rev} <> fs, d}
    case MArrayAfter{rev} SCon{Chr{93}, t} fs 1n+d: Machine{MEmit{JArray{List.reverse(&2, Json, rev)}}, t, fs, d}
    case MReadKey{True{}} SCon{Chr{125}, t} ObjectFrame{rev} <> fs 1n+d: Machine{MEmit{JObject{List.reverse(&2, Field, rev)}}, t, fs, d}
    case MReadKey{k} SCon{Chr{34}, t} fs d: Machine{MText{"", True{}}, t, fs, d}
    case MColon{k} SCon{Chr{58}, t} ObjectFrame{rev} <> fs d: Machine{MValue{}, t, MemberFrame{k, rev} <> fs, d}
    case MObjectAfter{rev} SCon{Chr{44}, t} fs d: Machine{MReadKey{False{}}, t, ObjectFrame{rev} <> fs, d}
    case MObjectAfter{rev} SCon{Chr{125}, t} fs 1n+d: Machine{MEmit{JObject{List.reverse(&2, Field, rev)}}, t, fs, d}
    case MText{rev, k} SCon{Chr{34}, t} fs d: Machine{finished_text(String.reverse(rev), k), t, fs, d}
    case MText{rev, k} SCon{Chr{92}, t} fs d: Machine{MEscape{rev, k}, t, fs, d}
    case MText{rev, k} SCon{Chr{+c}, t} fs d: Machine{ordinary(c, rev, k, (c >= 32 : U32) && Utf8.scalar(c)), t, fs, d}
    case MEscape{rev, k} SCon{Chr{c}, t} fs d: Machine{escaped(c, rev, k), t, fs, d}
    case MHex{1n+n, c, h, rev, k} SCon{Chr{+b}, t} fs d: Machine{hex_step(n, c, h, rev, k, b, Bytes.hex(b)), t, fs, d}
    case MLowSlash{h, rev, k} SCon{Chr{92}, t} fs d: Machine{MLowU{h, rev, k}, t, fs, d}
    case MLowU{h, rev, k} SCon{Chr{117}, t} fs d: Machine{MHex{4n, 0, h, rev, k}, t, fs, d}
    case _ s fs d: Machine{MBad{Syntax{}}, s, fs, d}

def allows_space(m: Mode) -> Bool:
  match m:
    case MValue{}: True{}
    case MArrayFirst{}: True{}
    case MReadKey{k}: True{}
    case MColon{k}: True{}
    case MArrayAfter{r}: True{}
    case MObjectAfter{r}: True{}
    case MEnd{v}: True{}
    case _: False{}

def skip(mode: Mode, original: String, t: String, fs: List<&2, Frame>, d: Nat, yes: Bool) -> Machine:
  match yes:
    case True{}: Machine{mode, t, fs, d}
    case False{}: token(mode, original, fs, d)

def step_input(+mode: Mode, original: String, input: String, fs: List<&2, Frame>, d: Nat) -> Machine:
  match input:
    case SCon{Chr{+c}, t}: skip(mode, original, t, fs, d, allows_space(mode) && whitespace(c))
    case SNil{}: token(mode, original, fs, d)

def step(m: Machine) -> Machine:
  match m:
    case Machine{mode, +s, fs, d}: step_input(mode, s, s, fs, d)

def parse_go(fuel: Nat, m: Machine) -> Result<&2, &2, Error, Json>:
  match fuel m:
    case _ Machine{MBad{e}, s, fs, d}: Fail{e}
    case _ Machine{MEnd{v}, SNil{}, Nil{}, 0n}: Done{v}
    case 0n _: Fail{FuelExhausted{}}
    case 1n+f machine: parse_go(f, step(machine))

# Four transitions per scalar plus EOF slack cover token completions and
# container returns, including the four hex digits of each Unicode escape.
def fuel_go(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}: acc
    case SCon{c, t}: fuel_go(t, 4n+acc)

def parse_string(+s: String) -> Result<&2, &2, Error, Json>:
  parse_go(fuel_go(s, 16n), Machine{MValue{}, s, [], 0n})

def parse_decoded(s: Maybe<&2, String>) -> Result<&2, &2, Error, Json>:
  match s:
    case None{}: Fail{InvalidUtf8{}}
    case Some{s}: parse_string(s)

# ASCII bytes need no bit-structural UTF-8 reconstruction. All other bytes
# still go through the shared strict state machine, including non-octets.
def advance_ascii(state: Utf8.State, +b: U32, ascii: Bool) -> Utf8.State:
  match state ascii:
    case Utf8.UtfReady{rev} True{}: Utf8.UtfReady{SCon{Chr{b}, rev}}
    case st _: Utf8.advance(st, Utf8.byte_view(b))

def decode_go(xs: List<&2, U32>, state: Utf8.State) -> Maybe<&2, String>:
  match xs state:
    case _ Utf8.Bad{}: None{}
    case Nil{} Utf8.UtfReady{rev}: Some{String.reverse(rev)}
    case Nil{} _: None{}
    case +b <> t st: decode_go(t, advance_ascii(st, b, (b < 128 : U32)))

def decode(body: List<&2, U32>) -> Maybe<&2, String>:
  decode_go(body, Utf8.UtfReady{""})

def parse(body: List<&2, U32>) -> Result<&2, &2, Error, Json>:
  parse_decoded(decode(body))

def select(v: Json, found: Maybe<&2, Json>, same: Bool) -> Maybe<&2, Json>:
  match found same:
    case None{} True{}: Some{v}
    case r _: r

def lookup_go(fields: List<&2, Field>, +key: String, found: Maybe<&2, Json>) -> Maybe<&2, Json>:
  match fields found:
    case _ Some{v}: Some{v}
    case Nil{} None{}: None{}
    case Field{k, v} <> t None{}: lookup_go(t, key, select(v, None{}, String.eq(k, key)))

def lookup(fields: List<&2, Field>, key: String) -> Maybe<&2, Json>:
  lookup_go(fields, key, None{})

# Independent scalar/number/depth admissibility; the fuel count covers only
# writer work items. Long text is escaped by a separate tail-recursive pass.
type Scan is Data:
  Scan{fuel: Nat, valid: Bool}

def count(s: Scan, good: Bool) -> Scan:
  match s:
    case Scan{n, ok}: Scan{16n+n, ok && good}

def scan(depth: Nat, v: Json, s: Scan) -> Scan:
  match depth v:
    case _ JNull{}: count(s, True{})
    case _ JBool{b}: count(s, True{})
    case _ JNumber{n}: count(s, number_valid(n))
    case _ JString{text}: count(s, scalars(text))
    case 0n _: count(s, False{})
    case 1n++d JArray{Nil{}}: count(s, True{})
    case 1n++d JArray{h <> t}: scan(1n+d, JArray{t}, scan(d, h, count(s, True{})))
    case 1n++d JObject{Nil{}}: count(s, True{})
    case 1n++d JObject{Field{k, h} <> t}: scan(1n+d, JObject{t}, scan(d, h, count(s, scalars(k))))

def scan_valid(s: Scan) -> Bool:
  match s:
    case Scan{n, ok}: ok

def admissible(v: Json) -> Bool:
  scan_valid(scan(512n, v, Scan{0n, True{}}))

def hex_char(+n: U32, low: Bool) -> Char:
  match low:
    case True{}: Chr{(48 + n : U32)}
    case False{}: Chr{(87 + n : U32)}

def nibble(+n: U32) -> Char:
  hex_char(n, (n < 10 : U32))

def hex4(+c: U32) -> String:
  SCon{Chr{92}, SCon{'u', SCon{nibble((c >> 12n : U32)), SCon{nibble(((c >> 8n : U32) .&. 15 : U32)), SCon{nibble(((c >> 4n : U32) .&. 15 : U32)), SCon{nibble((c .&. 15 : U32)), ""}}}}}}

def unicode_escape(+c: U32, bmp: Bool) -> String:
  match bmp:
    case True{}: hex4(c)
    case False{}: hex4((55296 + ((c - 65536 : U32) >> 10n : U32) : U32)) ++ hex4((56320 + ((c - 65536 : U32) .&. 1023 : U32) : U32))

def escaped_other(+c: U32, escape: Bool) -> String:
  match escape:
    case True{}: unicode_escape(c, (c <= 65535 : U32))
    case False{}: SCon{Chr{c}, ""}

def escape_char(+c: U32, ascii: Bool) -> String:
  match c:
    case 34: "\\\""
    case 92: "\\\\"
    case 8: "\\b"
    case 12: "\\f"
    case 10: "\\n"
    case 13: "\\r"
    case 9: "\\t"
    case n: escaped_other(n, (n < 32 : U32) || (ascii && (n > 127 : U32)))

def quote_go(s: String, +ascii: Bool, rev: String) -> String:
  match s:
    case SNil{}: String.reverse(SCon{'"', rev})
    case SCon{Chr{c}, t}: quote_go(t, ascii, String.reverse.go(escape_char(c, ascii), rev))

def quote(s: String, ascii: Bool) -> String:
  quote_go(s, ascii, "\"")

def indent(n: Nat, acc: String) -> String:
  match n:
    case 0n: acc
    case 1n+p: indent(p, SCon{' ', SCon{' ', acc}})

def line(pretty: Bool, depth: Nat) -> String:
  match pretty:
    case False{}: ""
    case True{}: SCon{'\n', indent(depth, "")}

def prefix(first: Bool, pretty: Bool, depth: Nat) -> String:
  match first:
    case True{}: line(pretty, depth)
    case False{}: SCon{',', line(pretty, depth)}

def close(first: Bool, pretty: Bool, depth: Nat, c: Char) -> String:
  match first depth:
    case True{} _: Char.show(c)
    case False{} 0n: Char.show(c)
    case False{} 1n+d: line(pretty, d) ++ Char.show(c)

def colon(pretty: Bool) -> String:
  match pretty:
    case True{}: ": "
    case False{}: ":"

type Work is Data:
  WValue{value: Json, depth: Nat}
  WArray{items: List<&2, Json>, depth: Nat, first: Bool}
  WObject{fields: List<&2, Field>, depth: Nat, first: Bool}
  WText{text: String}

def write_go(fuel: Nat, work: List<&2, Work>, +pretty: Bool, +ascii: Bool, rev: String) -> Result<&2, &2, Error, String>:
  match fuel work:
    case _ Nil{}: Done{String.reverse(rev)}
    case 0n _: Fail{FuelExhausted{}}
    case 1n+f WText{s} <> rest: write_go(f, rest, pretty, ascii, String.reverse.go(s, rev))
    case 1n+f WValue{JNull{}, d} <> rest: write_go(f, WText{"null"} <> rest, pretty, ascii, rev)
    case 1n+f WValue{JBool{True{}}, d} <> rest: write_go(f, WText{"true"} <> rest, pretty, ascii, rev)
    case 1n+f WValue{JBool{False{}}, d} <> rest: write_go(f, WText{"false"} <> rest, pretty, ascii, rev)
    case 1n+f WValue{JNumber{n}, d} <> rest: write_go(f, WText{n} <> rest, pretty, ascii, rev)
    case 1n+f WValue{JString{s}, d} <> rest: write_go(f, WText{quote(s, ascii)} <> rest, pretty, ascii, rev)
    case 1n+f WValue{JArray{xs}, d} <> rest: write_go(f, WArray{xs, 1n+d, True{}} <> rest, pretty, ascii, SCon{'[', rev})
    case 1n+f WValue{JObject{xs}, d} <> rest: write_go(f, WObject{xs, 1n+d, True{}} <> rest, pretty, ascii, SCon{'{', rev})
    case 1n+f WArray{Nil{}, d, first} <> rest: write_go(f, WText{close(first, pretty, d, ']')} <> rest, pretty, ascii, rev)
    case 1n+f WArray{h <> t, +d, first} <> rest: write_go(f, WText{prefix(first, pretty, d)} <> WValue{h, d} <> WArray{t, d, False{}} <> rest, pretty, ascii, rev)
    case 1n+f WObject{Nil{}, d, first} <> rest: write_go(f, WText{close(first, pretty, d, '}')} <> rest, pretty, ascii, rev)
    case 1n+f WObject{Field{k, v} <> t, +d, first} <> rest: write_go(f, WText{prefix(first, pretty, d)} <> WText{quote(k, ascii)} <> WText{colon(pretty)} <> WValue{v, d} <> WObject{t, d, False{}} <> rest, pretty, ascii, rev)

def write_checked(v: Json, pretty: Bool, ascii: Bool, s: Scan) -> Result<&2, &2, Error, String>:
  match s:
    case Scan{n, True{}}: write_go(n, [WValue{v, 0n}], pretty, ascii, "")
    case Scan{n, False{}}: Fail{InvalidValue{}}

# Both options are independent. No number normalization or key deduplication.
def write(+v: Json, pretty: Bool, ascii: Bool) -> Result<&2, &2, Error, String>:
  write_checked(v, pretty, ascii, scan(512n, v, Scan{0n, True{}}))

def stringify(v: Json) -> Result<&2, &2, Error, String>:
  write(v, False{}, False{})

# Exact, checked conversion only for unsigned integer spellings. No implicit
# exponent expansion, rounding, saturation, or wrapping at this boundary.
def integer_digits(s: String, ok: Bool) -> Bool:
  match s ok:
    case _ False{}: False{}
    case SNil{} True{}: True{}
    case SCon{Chr{c}, t} True{}: integer_digits(t, digit(c))

def unsigned_text(s: String, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}: U32.read(s)
    case False{}: None{}

def to_u32(v: Json) -> Maybe<&2, U32>:
  match v:
    case JNumber{+s}: unsigned_text(s, number_valid(s) && integer_digits(s, True{}))
    case _: None{}
