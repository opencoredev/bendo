# Independent RFC 6265 serialization specification, including the documented
# stricter Path, Domain, Expires and security policies. C supplies data types only.
import Base
import ../src/data/cookie.bend as C

def tchar(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || String.contains("!#$%&'*+-.^_`|~", Char.show(Chr{c}))

def token_tail(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{c}, t}:
      tchar(c) && token_tail(t)

def token(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, t}:
      tchar(c) && token_tail(t)

def name_valid(s: String) -> Bool:
  token(s)

def octet(+c: U32) -> Bool:
  U32.is_eq(c, 33) || ((c >= 35 : U32) && (c <= 43 : U32)) || ((c >= 45 : U32) && (c <= 58 : U32)) || ((c >= 60 : U32) && (c <= 91 : U32)) || ((c >= 93 : U32) && (c <= 126 : U32))

def value_valid(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: octet(c) && value_valid(t)

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

def unrestricted(s: Maybe<&2, C.SameSite>) -> Bool:
  match s:
    case Some{C.NoRestriction{}}: True{}
    case _: False{}

# Independent admissibility: no serializer or implementation validator occurs.
def admissible(+name: String, +value: String, options: C.Options) -> Bool:
  C.Options{p, d, a, e, +secure, h, site, part} = options
  name_valid(name) && (value_valid(value) && (optional_valid(~path_valid, p) && (optional_valid(~domain_valid, d) && (optional_valid(~expires_valid, e) && ((Bool.not(unrestricted(site)) || secure) && (Bool.not(part) || secure))))))

def option_text(key: String, s: Maybe<&2, String>) -> String:
  match s:
    case None{}: ""
    case Some{value}: "; " ++ key ++ "=" ++ value

def flag(key: String, enabled: Bool) -> String:
  match enabled:
    case False{}: ""
    case True{}: "; " ++ key

def age_text(age: C.MaxAge) -> String:
  match age:
    case C.Seconds{n}: Nat.show(n)
    case C.NegativeSeconds{n}: "-" ++ Nat.show(n)

def age_option(age: Maybe<&2, C.MaxAge>) -> String:
  match age:
    case None{}: ""
    case Some{n}: "; Max-Age=" ++ age_text(n)

def site_text(site: Maybe<&2, C.SameSite>) -> String:
  match site:
    case None{}: ""
    case Some{C.Strict{}}: "; SameSite=Strict"
    case Some{C.Lax{}}: "; SameSite=Lax"
    case Some{C.NoRestriction{}}: "; SameSite=None"

def suffix(options: C.Options) -> String:
  C.Options{p, d, a, e, s, h, site, part} = options
  option_text("Path", p) ++ option_text("Domain", d) ++ age_option(a) ++ option_text("Expires", e) ++ flag("Secure", s) ++ flag("HttpOnly", h) ++ site_text(site) ++ flag("Partitioned", part)

# Exact independent wire order, spacing, casing and omission rules.
def wire(name: String, value: String, options: C.Options) -> String:
  (name ++ "=" ++ value) ++ suffix(options)

# Attribute payload safety, independently excluding the three injection bytes.
def no_delimiters(s: String) -> Type:
  match s:
    case SNil{}: Unit
    case SCon{Chr{+c}, t}:
      {c != 59 : U32} & ({c != 13 : U32} & ({c != 10 : U32} & no_delimiters(t)))

def optional_payload_safe(o: Maybe<&2, String>) -> Type:
  match o:
    case None{}: Unit
    case Some{s}: no_delimiters(s)

def age_payload_safe(o: Maybe<&2, C.MaxAge>) -> Type:
  match o:
    case None{}: Unit
    case Some{a}: no_delimiters(age_text(a))

def site_payload_safe(o: Maybe<&2, C.SameSite>) -> Type:
  match o:
    case None{}: Unit
    case Some{C.Strict{}}: no_delimiters("Strict")
    case Some{C.Lax{}}: no_delimiters("Lax")
    case Some{C.NoRestriction{}}: no_delimiters("None")

# Safety of every variable attribute payload, not the intentional separators
# between attributes. Boolean flags have no payload.
def options_payloads_safe(options: C.Options) -> Type:
  match options:
    case C.Options{p, d, a, e, sec, h, site, part}:
      optional_payload_safe(p) & (optional_payload_safe(d) & (optional_payload_safe(e) & (age_payload_safe(a) & site_payload_safe(site))))

# Successful output has independent admissibility, exact wire structure, and
# explicit no-semicolon/CR/LF evidence for all five attribute payload kinds.
def structure(+name: String, +value: String, +options: C.Options, wire_value: String) -> Type:
  {admissible(name, value, options) == True{} : Bool} & ({wire_value == wire(name, value, options) : String} & options_payloads_safe(options))
