# RFC 7578 multipart forms. All input-sized loops are tail calls for .mjs.
import Base
import ./urlencoded.bend as Url
import ./utf8.bend as Utf8
import ../http/bytes.bend as Bytes

type Error is Data:
  Malformed{}
  TooLarge{}
  Urlencoded{error: Url.Error}

type Part is Data:
  Field{name: String, value: String}
  File{name: String, filename: String, content_type: String, bytes: List<&2, U32>}

type Limits is Data:
  Limits{file_size: U32, total_size: U32, parts: U32, header_size: U32}

def defaults() -> Limits:
  Limits{1048576, 2097152, 128, 8192}

def error_status(e: Error) -> U32:
  match e:
    case TooLarge{}:
      413
    case _:
      400

def octet(ok: Bool) -> Result<&2, &2, Error, Unit>:
  match ok:
    case True{}:
      Done{Unit{}}
    case False{}:
      Fail{Malformed{}}

# Count before allocating parser buffers. Includes preamble and epilogue,
# and validates even octets in ignored regions. No counter wraparound.
def measure_go(xs: List<&2, U32>, left: U32, n: Nat, ok: Bool) -> Result<&2, &2, Error, Nat>:
  match xs left ok:
    case _ _ False{}:
      Fail{Malformed{}}
    case Nil{} _ True{}:
      Done{n}
    case _ 0 True{}:
      Fail{TooLarge{}}
    case +b <> t left True{}:
      measure_go(t, U32.sub(left, 1), 1n+n, (b <= 255 : U32))

def measure(xs: List<&2, U32>, left: U32, n: Nat) -> Result<&2, &2, Error, Nat>:
  measure_go(xs, left, n, True{})

# Strict parameter grammar, confined to multipart. Reuse BND-29's quoted
# semicolon scanner without changing URL-encoded acceptance or errors.
def media_end(s: Url.MediaScan) -> Maybe<&2, List<&2, String>>:
  match s:
    case Url.MediaScan{False{}, False{}, rev, parts}:
      Some{List.reverse(&2, String, String.reverse(rev) <> parts)}
    case _:
      None{}

def media_go(s: String, state: Url.MediaScan) -> Maybe<&2, List<&2, String>>:
  match s:
    case SNil{}:
      media_end(state)
    case SCon{c, t}:
      media_go(t, Url.media_char(state, c))

def media(s: String) -> Maybe<&2, List<&2, String>>:
  media_go(s, Url.MediaScan{False{}, False{}, "", []})

def token_go(s: String, ok: Bool) -> Bool:
  match s ok:
    case _ False{}:
      False{}
    case SNil{} True{}:
      True{}
    case SCon{Chr{c}, t} True{}:
      token_go(t, Bytes.tchar(c))

def token(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, t}:
      token_go(t, Bytes.tchar(c))

def value_token(s: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}:
      Some{s}
    case False{}:
      None{}

def param_value(s: String) -> Maybe<&2, String>:
  match s:
    case SCon{Chr{34}, t}:
      Url.unquote(t, "", False{})
    case +s:
      value_token(s, token(s))

type Param is Data:
  Param{key: String, value: String}

def parameter(s: String, rev: String) -> Maybe<&2, Param>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{61}, t}:
      +k = String.trim(String.reverse(rev))
      do Maybe<&2, Param>:
        u : String <- value_token(k, token(k))
        v : String <- param_value(String.trim(t))
        return Param{Url.lower(k), v}
    case SCon{c, t}:
      parameter(t, SCon{c, rev})

def bchar(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || String.contains("'()+_,-./:=? ", Char.show(Chr{c}))

def boundary_go(s: String, left: U32, last: U32) -> Bool:
  match s left:
    case SNil{} _:
      U32.is_ne(last, 32)
    case _ 0:
      False{}
    case SCon{Chr{+c}, t} left:
      # Boundary length is at most 70, so this recursion is bounded.
      bchar(c) && boundary_go(t, U32.sub(left, 1), c)

def boundary_valid(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{c, t}:
      boundary_go(SCon{c, t}, 70, 32)

def boundary_param(kv: Param, found: Maybe<&2, String>) -> Maybe<&2, Maybe<&2, String>>:
  Param{k, +v} = kv
  match k found:
    case "boundary" None{}:
      do Maybe<&2, Maybe<&2, String>>:
        b : String <- value_token(v, boundary_valid(v))
        return Some{b}
    case "boundary" Some{b}:
      None{}
    case _ found:
      Some{found}

def boundary_parameter(kv: Maybe<&2, Param>, found: Maybe<&2, String>) -> Maybe<&2, Maybe<&2, String>>:
  match kv:
    case None{}:
      None{}
    case Some{kv}:
      boundary_param(kv, found)

def boundary_params_go(xs: List<&2, String>, state: Maybe<&2, Maybe<&2, String>>) -> Maybe<&2, String>:
  match xs state:
    case _ None{}:
      None{}
    case Nil{} Some{found}:
      found
    case s <> t Some{found}:
      boundary_params_go(t, boundary_parameter(parameter(s, ""), found))

def boundary_params(xs: List<&2, String>, found: Maybe<&2, String>) -> Maybe<&2, String>:
  boundary_params_go(xs, Some{found})

def boundary_media(m: String, ps: List<&2, String>) -> Maybe<&2, String>:
  match m:
    case "multipart/form-data":
      boundary_params(ps, None{})
    case _:
      None{}

def boundary_parts(xs: List<&2, String>) -> Maybe<&2, String>:
  match xs:
    case m <> ps:
      boundary_media(Url.lower(String.trim(m)), ps)
    case _:
      None{}

def boundary(ct: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    xs : List<&2, String> <- media(ct)
    boundary_parts(xs)

# Part metadata rejects duplicate semantic headers/parameters. filename* is
# prohibited by RFC 7578 section 4.2, so reject rather than guess precedence.
type Meta is Data:
  Meta{name: Maybe<&2, String>, filename: Maybe<&2, String>, content_type: Maybe<&2, String>, disposition: Bool}

def disposition_param(kv: Param, meta: Meta) -> Maybe<&2, Meta>:
  Param{k, v} = kv
  match k meta:
    case "name" Meta{None{}, f, c, d}:
      Some{Meta{Some{v}, f, c, d}}
    case "filename" Meta{n, None{}, c, d}:
      Some{Meta{n, Some{v}, c, d}}
    case "name" _:
      None{}
    case "filename" _:
      None{}
    case "filename*" _:
      None{}
    case _ meta:
      Some{meta}

def disposition_parameter(kv: Maybe<&2, Param>, meta: Meta) -> Maybe<&2, Meta>:
  match kv:
    case None{}:
      None{}
    case Some{kv}:
      disposition_param(kv, meta)

def disposition_params_go(xs: List<&2, String>, state: Maybe<&2, Meta>) -> Maybe<&2, Meta>:
  match xs state:
    case _ None{}:
      None{}
    case Nil{} Some{meta}:
      Some{meta}
    case s <> t Some{meta}:
      disposition_params_go(t, disposition_parameter(parameter(s, ""), meta))

def disposition_params(xs: List<&2, String>, meta: Meta) -> Maybe<&2, Meta>:
  disposition_params_go(xs, Some{meta})

def disposition_media(m: String, ps: List<&2, String>, meta: Meta) -> Maybe<&2, Meta>:
  match m meta:
    case "form-data" Meta{n, f, c, False{}}:
      disposition_params(ps, Meta{n, f, c, True{}})
    case _ _:
      None{}

def disposition(xs: List<&2, String>, meta: Meta) -> Maybe<&2, Meta>:
  match xs:
    case m <> ps:
      disposition_media(Url.lower(String.trim(m)), ps, meta)
    case _:
      None{}

# Explicit charset parameters must be UTF-8. _charset_ is an ordinary field;
# it never changes decoding. File bytes are not charset-decoded.
def media_type(s: String, rev: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{47}, t}:
      token(String.reverse(rev)) && token(t)
    case SCon{c, t}:
      media_type(t, SCon{c, rev})

def content_parameter(kv: Maybe<&2, Param>) -> Bool:
  match kv:
    case None{}:
      False{}
    case Some{Param{k, v}}:
      Url.parameter_value(k, v)

def content_parameters(xs: List<&2, String>, ok: Bool) -> Bool:
  match xs ok:
    case _ False{}:
      False{}
    case Nil{} True{}:
      True{}
    case s <> t True{}:
      content_parameters(t, content_parameter(parameter(s, "")))

def content_type_parts(xs: List<&2, String>) -> Bool:
  match xs:
    case m <> ps:
      media_type(String.trim(m), "") && content_parameters(ps, True{})
    case _:
      False{}

def header_value(name: String, +value: String, meta: Meta) -> Maybe<&2, Meta>:
  match name meta:
    case "content-disposition" meta:
      do Maybe<&2, Meta>:
        xs : List<&2, String> <- media(value)
        disposition(xs, meta)
    case "content-type" Meta{n, f, None{}, d}:
      do Maybe<&2, Meta>:
        xs : List<&2, String> <- media(value)
        u : String <- value_token(value, content_type_parts(xs))
        return Meta{n, f, Some{value}, d}
    case "content-type" _:
      None{}
    case "content-transfer-encoding" _:
      None{}
    case _ meta:
      Some{meta}

def header_split(s: String, rev: String, meta: Meta) -> Maybe<&2, Meta>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{58}, t}:
      +name = String.reverse(rev)
      do Maybe<&2, Meta>:
        u : String <- value_token(name, token(name))
        header_value(Url.lower(name), String.trim(t), meta)
    case SCon{c, t}:
      header_split(t, SCon{c, rev}, meta)

def header_text(s: Maybe<&2, String>, meta: Meta) -> Maybe<&2, Meta>:
  match s:
    case None{}:
      None{}
    case Some{s}:
      header_split(s, "", meta)

def maybe_meta(m: Maybe<&2, Meta>) -> Result<&2, &2, Error, Meta>:
  match m:
    case None{}:
      Fail{Malformed{}}
    case Some{m}:
      Done{m}

# Headers are octets checked before strict UTF-8 decoding. CRLF only,
# no folded lines, controls, or whitespace before the header colon.
type Head is Data:
  Head{meta: Meta, bytes: List<&2, U32>}

def header_line(line: List<&2, U32>, meta: Meta, enough: Bool) -> Result<&2, &2, Error, Meta>:
  match enough:
    case False{}:
      Fail{TooLarge{}}
    case True{}:
      maybe_meta(header_text(Utf8.decode(List.reverse(&2, U32, line)), meta))

def header_end(meta: Meta, xs: List<&2, U32>, enough: Bool) -> Result<&2, &2, Error, Head>:
  match enough:
    case False{}:
      Fail{TooLarge{}}
    case True{}:
      Done{Head{meta, xs}}

def header_byte(meta: Meta, valid: Bool) -> Result<&2, &2, Error, Meta>:
  match valid:
    case True{}:
      Done{meta}
    case False{}:
      Fail{Malformed{}}

def headers_go(xs: List<&2, U32>, +left: U32, line: List<&2, U32>, state: Result<&2, &2, Error, Meta>) -> Result<&2, &2, Error, Head>:
  match xs left line state:
    case _ _ _ Fail{e}:
      Fail{e}
    case 13 <> 10 <> t left Nil{} Done{meta}:
      header_end(meta, t, (left >= 2 : U32))
    case 13 <> 10 <> t left line Done{meta}:
      headers_go(t, U32.sub(left, 2), [], header_line(line, meta, (left >= 2 : U32)))
    case _ 0 _ _:
      Fail{TooLarge{}}
    case Nil{} _ _ _:
      Fail{Malformed{}}
    case +c <> t left line Done{meta}:
      headers_go(t, U32.sub(left, 1), c <> line, header_byte(meta, Bytes.value_octet(c)))

def headers(xs: List<&2, U32>, left: U32, line: List<&2, U32>, meta: Meta) -> Result<&2, &2, Error, Head>:
  headers_go(xs, left, line, Done{meta})

# Prefix lookahead is bounded by the validated 70-byte boundary. The scan
# advances once through input; unsuccessful prefix candidates stay payload.
def prefix(p: List<&2, U32>, xs: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match p xs:
    case Nil{} xs:
      Some{xs}
    case a <> ps b <> bs:
      do Maybe<&2, List<&2, U32>>:
        u : String <- value_token("", U32.is_eq(a, b))
        prefix(ps, bs)
    case _ _:
      None{}

type Delimiter is Data:
  Delimiter{rest: List<&2, U32>, close: Bool}

# Transport padding cannot contain another candidate prefix; looking over
# it does not multiply work. A closing delimiter may end at EOF.
def padding(xs: List<&2, U32>, close: Bool) -> Maybe<&2, Delimiter>:
  match xs close:
    case 32 <> t close:
      padding(t, close)
    case 9 <> t close:
      padding(t, close)
    case 13 <> 10 <> t close:
      Some{Delimiter{t, close}}
    case Nil{} True{}:
      Some{Delimiter{[], True{}}}
    case _ _:
      None{}

def delimiter_suffix(xs: List<&2, U32>) -> Maybe<&2, Delimiter>:
  match xs:
    case 45 <> 45 <> t:
      padding(t, True{})
    case xs:
      padding(xs, False{})

def delimiter(xs: List<&2, U32>, p: List<&2, U32>) -> Maybe<&2, Delimiter>:
  do Maybe<&2, Delimiter>:
    rest : List<&2, U32> <- prefix(p, xs)
    delimiter_suffix(rest)

def text_part(name: String, text: Maybe<&2, String>) -> Result<&2, &2, Error, Part>:
  match text:
    case None{}:
      Fail{Malformed{}}
    case Some{v}:
      Done{Field{name, v}}

def file_type(ct: Maybe<&2, String>) -> String:
  match ct:
    case None{}:
      "application/octet-stream"
    case Some{s}:
      s

def part(meta: Meta, bytes: List<&2, U32>) -> Result<&2, &2, Error, Part>:
  match meta:
    case Meta{Some{n}, None{}, ct, True{}}:
      text_part(n, Utf8.decode(bytes))
    case Meta{Some{n}, Some{f}, ct, True{}}:
      Done{File{n, f, file_type(ct), bytes}}
    case _:
      Fail{Malformed{}}

type Mode is Data:
  Seeking{}
  Reading{meta: Meta, reverse: List<&2, U32>, left: U32}

type Step is Data:
  Running{input: List<&2, U32>, mode: Mode, parts: List<&2, Part>, remaining_parts: U32}
  Success{parts: List<&2, Part>}
  Failure{error: Error}

def open_head(h: Result<&2, &2, Error, Head>, parts: List<&2, Part>, count: U32, file_limit: U32, total_limit: U32) -> Step:
  match h:
    case Fail{e}:
      Failure{e}
    case Done{Head{Meta{Some{n}, Some{f}, ct, True{}}, xs}}:
      Running{xs, Reading{Meta{Some{n}, Some{f}, ct, True{}}, [], file_limit}, parts, count}
    case Done{Head{Meta{Some{n}, None{}, ct, True{}}, xs}}:
      Running{xs, Reading{Meta{Some{n}, None{}, ct, True{}}, [], total_limit}, parts, count}
    case _:
      Failure{Malformed{}}

def after_delimiter(d: Delimiter, parts: List<&2, Part>, count: U32, limits: Limits) -> Step:
  match d count:
    case Delimiter{xs, True{}} _:
      Success{List.reverse(&2, Part, parts)}
    case Delimiter{xs, False{}} 0:
      Failure{TooLarge{}}
    case Delimiter{xs, False{}} count:
      Limits{f, t, p, h} = limits
      open_head(headers(xs, h, [], Meta{None{}, None{}, None{}, False{}}), parts, U32.sub(count, 1), f, t)

def finished_part(r: Result<&2, &2, Error, Part>, d: Delimiter, parts: List<&2, Part>, count: U32, limits: Limits) -> Step:
  match r:
    case Fail{e}:
      Failure{e}
    case Done{p}:
      after_delimiter(d, p <> parts, count, limits)

def found(d: Delimiter, mode: Mode, parts: List<&2, Part>, count: U32, limits: Limits) -> Step:
  match mode:
    case Seeking{}:
      after_delimiter(d, parts, count, limits)
    case Reading{meta, rev, left}:
      finished_part(part(meta, List.reverse(&2, U32, rev)), d, parts, count, limits)

def ordinary(xs: List<&2, U32>, mode: Mode, parts: List<&2, Part>, count: U32) -> Step:
  match xs mode:
    case Nil{} _:
      Failure{Malformed{}}
    case c <> t Seeking{}:
      Running{t, Seeking{}, parts, count}
    case c <> t Reading{m, rev, 0}:
      Failure{TooLarge{}}
    case c <> t Reading{m, rev, left}:
      Running{t, Reading{m, c <> rev, U32.sub(left, 1)}, parts, count}

def candidate(d: Maybe<&2, Delimiter>, xs: List<&2, U32>, mode: Mode, parts: List<&2, Part>, count: U32, limits: Limits) -> Step:
  match d:
    case None{}:
      ordinary(xs, mode, parts, count)
    case Some{d}:
      found(d, mode, parts, count, limits)

def advance(step: Step, +p: List<&2, U32>, limits: Limits) -> Step:
  match step:
    case Running{13 <> +xs, mode, parts, count}:
      candidate(delimiter(13 <> xs, p), 13 <> xs, mode, parts, count, limits)
    case Running{xs, mode, parts, count}:
      ordinary(xs, mode, parts, count)
    case step:
      step

# Each step consumes >=1 input octet (often an entire delimiter/header).
# Two synthetic octets permit the first delimiter at byte zero. Fuel keeps
# termination visible even when lookahead returns a suffix of the input.
def scan(fuel: Nat, step: Step, +p: List<&2, U32>, +limits: Limits) -> Result<&2, &2, Error, List<&2, Part>>:
  match fuel step:
    case _ Success{parts}:
      Done{parts}
    case _ Failure{e}:
      Fail{e}
    case 0n _:
      Fail{Malformed{}}
    case 1n+f step:
      scan(f, advance(step, p, limits), p, limits)

def parse_boundary(b: Maybe<&2, String>, body: List<&2, U32>, fuel: Nat, +limits: Limits) -> Result<&2, &2, Error, List<&2, Part>>:
  match b:
    case None{}:
      Fail{Malformed{}}
    case Some{b}:
      Limits{f, t, p, h} = limits
      scan(3n+fuel, Running{13 <> 10 <> body, Seeking{}, [], p}, 13 <> 10 <> 45 <> 45 <> Utf8.encode(b), limits)

def header_chars(s: String, ok: Bool) -> Bool:
  match s ok:
    case _ False{}:
      False{}
    case SNil{} True{}:
      True{}
    case SCon{Chr{+c}, t} True{}:
      header_chars(t, U32.is_eq(c, 9) || ((c >= 32 : U32) && U32.is_ne(c, 127) && Utf8.scalar(c)))

def parse_with_limits(+content_type: String, +body: List<&2, U32>, +limits: Limits) -> Result<&2, &2, Error, List<&2, Part>>:
  Limits{f, t, p, h} = limits
  do Result<&2, &2, Error, List<&2, Part>>:
    size : Nat <- measure(body, t, 0n)
    hs : Nat <- measure(Utf8.encode(content_type), h, 0n)
    u : Unit <- octet(header_chars(content_type, True{}))
    parse_boundary(boundary(content_type), body, size, limits)

def parse(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Error, List<&2, Part>>:
  parse_with_limits(content_type, body, defaults())
