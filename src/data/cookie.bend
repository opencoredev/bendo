# RFC 6265 cookies. Values are raw cookie-octets, never percent-decoded.
import Base
import ../http/bytes.bend as Bytes

type Entry is Data:
  Entry{name: String, value: String}

type Error is Data:
  InvalidName{}
  InvalidValue{}
  InvalidPath{}
  InvalidDomain{}
  InvalidExpires{}
  SameSiteRequiresSecure{}
  PartitionedRequiresSecure{}

type SameSite is Data:
  Strict{}
  Lax{}
  NoRestriction{}

# Bend Base has no signed integer. Both constructors count whole seconds.
type MaxAge is Data:
  Seconds{seconds: Nat}
  NegativeSeconds{seconds: Nat}

type Options is Data:
  Options{path: Maybe<&2, String>, domain: Maybe<&2, String>, max_age: Maybe<&2, MaxAge>, expires: Maybe<&2, String>, secure: Bool, http_only: Bool, same_site: Maybe<&2, SameSite>, partitioned: Bool}

def defaults() -> Options:
  Options{None{}, None{}, None{}, None{}, False{}, False{}, None{}, False{}}

def name_valid(s: String) -> Bool:
  Bytes.token(s)

def octet(+c: U32) -> Bool:
  U32.is_eq(c, 33) || ((c >= 35 : U32) && (c <= 43 : U32)) || ((c >= 45 : U32) && (c <= 58 : U32)) || ((c >= 60 : U32) && (c <= 91 : U32)) || ((c >= 93 : U32) && (c <= 126 : U32))

def value_valid(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: octet(c) && value_valid(t)

# Accumulate validity for untrusted, potentially long request values.
def value_valid_go(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok
    case SCon{Chr{c}, t}: value_valid_go(t, ok && octet(c))

def value_valid_fast(s: String) -> Bool:
  value_valid_go(s, True{})

def name_valid_go(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok
    case SCon{Chr{c}, t}: name_valid_go(t, ok && Bytes.tchar(c))

def name_valid_fast(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{c}, t}: name_valid_go(t, Bytes.tchar(c))

# Unchecked wire pair; callers use serialize to validate external input.
def serialize_pair(name: String, value: String) -> String:
  name ++ "=" ++ value

# Scan to the first delimiter with a reversed prefix, then restore its order.
def split_prefix(h: Char, rev: String, same: Bool) -> String:
  match same:
    case True{}: rev
    case False{}: SCon{h, rev}

def split_go(s: String, stop: Bool, +sep: Char, rev: String) -> String & Maybe<&2, String>:
  match s stop:
    case _ True{}: (String.reverse(rev), Some{s})
    case SNil{} False{}: (String.reverse(rev), None{})
    case SCon{+h, t} False{}: split_go(t, Char.is_eq(h, sep), sep, split_prefix(h, rev, Char.is_eq(h, sep)))

def split(s: String, sep: Char) -> String & Maybe<&2, String>:
  split_go(s, False{}, sep, "")

def trim_start(s: String) -> String:
  match s:
    case SCon{Chr{32}, t}: trim_start(t)
    case SCon{Chr{9}, t}: trim_start(t)
    case _: s

def trim(s: String) -> String:
  String.reverse(trim_start(String.reverse(trim_start(s))))

def unquote_end(s: String) -> Maybe<&2, String>:
  match s:
    case SCon{Chr{34}, t}: Some{String.reverse(t)}
    case _: None{}

def unquote(s: String) -> Maybe<&2, String>:
  match s:
    case SCon{Chr{34}, t}: unquote_end(String.reverse(t))
    case _: Some{s}

def accepted(+name: String, +value: String, valid: Bool) -> Maybe<&2, Entry>:
  match valid:
    case False{}: None{}
    case True{}: Some{Entry{name, value}}

def pair_value(+name: String, value: Maybe<&2, String>) -> Maybe<&2, Entry>:
  match value:
    case None{}: None{}
    case Some{+s}: accepted(name, s, name_valid_fast(name) && value_valid_fast(s))

def pair_parts(parts: String & Maybe<&2, String>) -> Maybe<&2, Entry>:
  (name, value) = parts
  match value:
    case None{}: None{}
    case Some{s}: pair_value(name, unquote(s))

def parse_pair(s: String) -> Maybe<&2, Entry>:
  pair_parts(split(trim(s), '='))

def keep(p: Maybe<&2, Entry>, tail: List<&2, Entry>) -> List<&2, Entry>:
  match p:
    case None{}: tail
    case Some{pair}: pair <> tail

# Fold from right to left so both scans use constant JavaScript call depth.
def segments_go(s: String, acc: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}: acc
    case SCon{+h, t}: segments_go(t, String.split.fin(h, acc, Char.is_eq(h, ';')))

def segments(s: String) -> List<&2, String>:
  segments_go(String.reverse(s), [""])

def parse_parts_go(parts: List<&2, String>, acc: List<&2, Entry>) -> List<&2, Entry>:
  match parts:
    case Nil{}: acc
    case s <> t: parse_parts_go(t, keep(parse_pair(s), acc))

def parse_parts(parts: List<&2, String>) -> List<&2, Entry>:
  parse_parts_go(List.reverse(&2, String, parts), [])

def parse(s: String) -> List<&2, Entry>:
  parse_parts(segments(s))

def first_pick(value: String, rest: Maybe<&2, String>, same: Bool) -> Maybe<&2, String>:
  match same:
    case True{}: Some{value}
    case False{}: rest

def first(pairs: List<&2, Entry>, +name: String) -> Maybe<&2, String>:
  match pairs:
    case Nil{}: None{}
    case Entry{k, v} <> t: first_pick(v, first(t, name), String.eq(k, name))

# Attribute-value excludes delimiters, controls, DEL and non-ASCII.
def attribute(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, t}: (c >= 32 : U32) && (c <= 126 : U32) && U32.is_ne(c, 59) && attribute(t)

def path_body(s: String) -> Bool:
  match s:
    case SCon{Chr{47}, t}: attribute(t)
    case _: False{}

def path_valid(s: String) -> Bool:
  +value = s
  path_body(value) && Bool.not(String.ends_with(value, " "))

def domain_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, t}: (((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || U32.is_eq(c, 45)) && domain_chars(t)

def label_valid(+s: String) -> Bool:
  Bool.not(String.is_empty(s)) && Bool.not(String.starts_with(s, "-")) && Bool.not(String.ends_with(s, "-")) && (String.length(s) <= 63n : Nat) && domain_chars(s)

def labels_valid(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case h <> t: label_valid(h) && labels_valid(t)

def domain_body(s: String) -> String:
  match s:
    case SCon{Chr{46}, t}: t
    case _: s

def domain_valid(s: String) -> Bool:
  +value = s
  (String.length(value) <= 254n : Nat) && labels_valid(String.split(domain_body(value), '.'))

def digit(+c: U32) -> Bool:
  (c >= 48 : U32) && (c <= 57 : U32)

def february(leap: Bool) -> U32:
  match leap:
    case True{}: 29
    case False{}: 28

def month_days(+month: String, +year: U32) -> U32:
  match month:
    case "Feb":
      february(U32.is_eq((year % 4 : U32), 0) && (U32.is_ne((year % 100 : U32), 0) || U32.is_eq((year % 400 : U32), 0)))
    case "Apr": 30
    case "Jun": 30
    case "Sep": 30
    case "Nov": 30
    case "Jan": 31
    case "Mar": 31
    case "May": 31
    case "Jul": 31
    case "Aug": 31
    case "Oct": 31
    case "Dec": 31
    case _: 0

def weekday(s: String) -> Bool:
  match s:
    case "Mon": True{}
    case "Tue": True{}
    case "Wed": True{}
    case "Thu": True{}
    case "Fri": True{}
    case "Sat": True{}
    case "Sun": True{}
    case _: False{}

def date_numbers(day: Maybe<&2, U32>, year: Maybe<&2, U32>, hour: Maybe<&2, U32>, minute: Maybe<&2, U32>, second: Maybe<&2, U32>, month: String) -> Bool:
  match day year hour minute second:
    case Some{+d} Some{+y} Some{h} Some{m} Some{s}:
      (y >= 1601 : U32) && (d >= 1 : U32) && (d <= month_days(month, y) : U32) && (h <= 23 : U32) && (m <= 59 : U32) && (s <= 59 : U32)
    case _ _ _ _ _: False{}

# Fixed-width IMF-fixdate, with calendar-day and time ranges checked.
def expires_valid(s: String) -> Bool:
  match s:
    case SCon{+w1, SCon{+w2, SCon{+w3, SCon{',', SCon{' ', SCon{Chr{+d1}, SCon{Chr{+d2}, SCon{' ', SCon{+m1, SCon{+m2, SCon{+m3, SCon{' ', SCon{Chr{+y1}, SCon{Chr{+y2}, SCon{Chr{+y3}, SCon{Chr{+y4}, SCon{' ', SCon{Chr{+h1}, SCon{Chr{+h2}, SCon{':', SCon{Chr{+i1}, SCon{Chr{+i2}, SCon{':', SCon{Chr{+s1}, SCon{Chr{+s2}, SCon{' ', SCon{'G', SCon{'M', SCon{'T', SNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      weekday(SCon{w1, SCon{w2, SCon{w3, ""}}}) && digit(d1) && digit(d2) && digit(y1) && digit(y2) && digit(y3) && digit(y4) && digit(h1) && digit(h2) && digit(i1) && digit(i2) && digit(s1) && digit(s2) && date_numbers(U32.read(SCon{Chr{d1}, SCon{Chr{d2}, ""}}), U32.read(SCon{Chr{y1}, SCon{Chr{y2}, SCon{Chr{y3}, SCon{Chr{y4}, ""}}}}), U32.read(SCon{Chr{h1}, SCon{Chr{h2}, ""}}), U32.read(SCon{Chr{i1}, SCon{Chr{i2}, ""}}), U32.read(SCon{Chr{s1}, SCon{Chr{s2}, ""}}), SCon{m1, SCon{m2, SCon{m3, ""}}})
    case _: False{}

def optional_valid(~valid: String -> Bool, s: Maybe<&2, String>) -> Bool:
  match s:
    case None{}: True{}
    case Some{value}: valid(value)

def unrestricted(s: Maybe<&2, SameSite>) -> Bool:
  match s:
    case Some{NoRestriction{}}: True{}
    case _: False{}

def require(ok: Bool, error: Error, rest: Result<&2, &2, Error, Unit>) -> Result<&2, &2, Error, Unit>:
  match ok:
    case True{}: rest
    case False{}: Fail{error}

def validate(+name: String, +value: String, options: Options) -> Result<&2, &2, Error, Unit>:
  Options{p, d, a, e, +secure, h, s, partitioned} = options
  require(name_valid(name), InvalidName{}, require(value_valid(value), InvalidValue{}, require(optional_valid(~path_valid, p), InvalidPath{}, require(optional_valid(~domain_valid, d), InvalidDomain{}, require(optional_valid(~expires_valid, e), InvalidExpires{}, require(Bool.not(unrestricted(s)) || secure, SameSiteRequiresSecure{}, require(Bool.not(partitioned) || secure, PartitionedRequiresSecure{}, Done{Unit{}})))))))

def option_text(key: String, s: Maybe<&2, String>) -> String:
  match s:
    case None{}: ""
    case Some{value}: "; " ++ key ++ "=" ++ value

def flag(key: String, enabled: Bool) -> String:
  match enabled:
    case False{}: ""
    case True{}: "; " ++ key

def age_text(age: MaxAge) -> String:
  match age:
    case Seconds{n}: Nat.show(n)
    case NegativeSeconds{n}: "-" ++ Nat.show(n)

def age_option(age: Maybe<&2, MaxAge>) -> String:
  match age:
    case None{}: ""
    case Some{n}: "; Max-Age=" ++ age_text(n)

def site_text(site: Maybe<&2, SameSite>) -> String:
  match site:
    case None{}: ""
    case Some{Strict{}}: "; SameSite=Strict"
    case Some{Lax{}}: "; SameSite=Lax"
    case Some{NoRestriction{}}: "; SameSite=None"

def attributes(options: Options) -> String:
  Options{p, d, a, e, s, h, site, part} = options
  option_text("Path", p) ++ option_text("Domain", d) ++ age_option(a) ++ option_text("Expires", e) ++ flag("Secure", s) ++ flag("HttpOnly", h) ++ site_text(site) ++ flag("Partitioned", part)

def serialize_checked(name: String, value: String, options: Options, checked: Result<&2, &2, Error, Unit>) -> Result<&2, &2, Error, String>:
  match checked:
    case Fail{error}: Fail{error}
    case Done{u}: Done{serialize_pair(name, value) ++ attributes(options)}

def serialize(+name: String, +value: String, +options: Options) -> Result<&2, &2, Error, String>:
  serialize_checked(name, value, options, validate(name, value, options))

# Match the original scope/security options; persistence is always overridden.
def deletion(options: Options) -> Options:
  Options{p, d, a, e, s, h, site, part} = options
  Options{p, d, Some{Seconds{0n}}, None{}, s, h, site, part}
