# The email and URL recognizers agree with the independent grammars.
import Base
import ../src/data/schema-text.bend as T
import ../src/data/schema-spec.bend as Spec
import ./schema-text.bend as Text
import ../src/data/decimal.bend as D

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def and_true(+a: Bool) -> {a && True{} == a : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def one_of_equiv(+c: U32, +xs: List<&2, U32>) -> {T.one_of(c, xs) == Spec.one_of(c, xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case x <> t:
      %one_of_equiv(c, t) : {T.one_of(c, x <> t) == U32.is_eq(c, x) || _ : Bool}
      {==}

def atom_equiv(+c: U32) -> {T.atom(c) == Spec.atom_char(c) : Bool}:
  %one_of_equiv(c, [33, 35, 36, 37, 38, 39, 42, 43, 45, 47, 61, 63, 94, 95, 96, 123, 124, 125, 126]) : {T.atom(c) == Spec.alnum(c) || _ : Bool}
  {==}

def uri_equiv(+c: U32) -> {T.uri_char(c) == Spec.uri_char(c) : Bool}:
  %one_of_equiv(c, [45, 46, 95, 126, 58, 47, 63, 35, 91, 93, 64, 33, 36, 38, 39, 40, 41, 42, 43, 44, 59, 61]) : {T.uri_char(c) == Spec.alnum(c) || _ : Bool}
  {==}

def cut_equiv(+here: Bool, +c: U32, +pieces: List<&2, String>) -> {T.cut(here, c, pieces) == Spec.cut(here, c, pieces) : List<&2, String>}:
  match here pieces:
    case True{} _: {==}
    case False{} Nil{}: {==}
    case False{} h <> t: {==}

# A proof-only right fold connects the tail splitter to the independent split.
def split_fold(s: String, +sep: U32, pieces: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}: pieces
    case SCon{Chr{+c}, t}: Spec.cut(U32.is_eq(c, sep), c, split_fold(t, sep, pieces))

def split_reverse(+s: String, +rev: String, +sep: U32, +pieces: List<&2, String>) -> {T.split_go(String.reverse.go(s, rev), sep, pieces) == T.split_go(rev, sep, split_fold(s, sep, pieces)) : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      %cut_equiv(U32.is_eq(c, sep), c, split_fold(t, sep, pieces)) : {T.split_go(String.reverse.go(s, rev), sep, pieces) == T.split_go(rev, sep, _) : List<&2, String>}
      split_reverse(t, SCon{Chr{c}, rev}, sep, pieces)

def split_fold_equiv(+s: String, +sep: U32) -> {split_fold(s, sep, [""]) == Spec.split(s, sep) : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      %split_fold_equiv(t, sep) : {split_fold(s, sep, [""]) == Spec.cut(U32.is_eq(c, sep), c, _) : List<&2, String>}
      {==}

def split_equiv(+s: String, +sep: U32) -> {T.split(s, sep) == Spec.split(s, sep) : List<&2, String>}:
  %split_fold_equiv(s, sep) : {T.split(s, sep) == _ : List<&2, String>}
  split_reverse(s, "", sep, [""])

def char_spec(mode: T.Chars, s: String) -> Bool:
  match mode:
    case T.LabelChars{}: Spec.label_chars(s)
    case T.AtomChars{}: Spec.atom(s)
    case T.Digits{}: Spec.digits(s)

def chars_cons(+mode: T.Chars, +c: U32, +t: String) -> {T.char_ok(mode, c) && char_spec(mode, t) == char_spec(mode, SCon{Chr{c}, t}) : Bool}:
  match mode:
    case T.LabelChars{}: {==}
    case T.AtomChars{}:
      %atom_equiv(c) : {T.atom(c) && Spec.atom(t) == _ && Spec.atom(t) : Bool}
      {==}
    case T.Digits{}: {==}

def chars_nil(+mode: T.Chars, +ok: Bool) -> {ok == ok && char_spec(mode, "") : Bool}:
  match mode:
    case T.LabelChars{}: Equal.sym(Bool, ok && True{}, ok, and_true(ok))
    case T.AtomChars{}: Equal.sym(Bool, ok && True{}, ok, and_true(ok))
    case T.Digits{}: Equal.sym(Bool, ok && True{}, ok, and_true(ok))

def chars_equiv(+s: String, +mode: T.Chars, +ok: Bool) -> {T.chars(s, mode, ok) == ok && char_spec(mode, s) : Bool}:
  match s:
    case SNil{}: chars_nil(mode, ok)
    case SCon{Chr{c}, t}:
      %chars_cons(mode, c, t) : {T.chars(s, mode, ok) == ok && _ : Bool}
      %and_assoc(ok, T.char_ok(mode, c), char_spec(mode, t)) : {T.chars(s, mode, ok) == _ : Bool}
      chars_equiv(t, mode, ok && T.char_ok(mode, c))

def last_equiv(+s: String, +last: Bool) -> {T.last_alnum(s, last) == Bool.pick(Bool, String.is_empty(s), last, Spec.last_alnum(s)) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, SNil{}}: {==}
    case SCon{c, SCon{h, t}}: last_equiv(SCon{h, t}, T.first_alnum(SCon{c, ""}))

def first_equiv(+s: String) -> {T.first_alnum(s) == Spec.first_alnum(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: {==}

def last_final(+s: String) -> {T.last_alnum(s, False{}) == Spec.last_alnum(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{c, t}: last_equiv(s, False{})

def label_equiv(+s: String) -> {T.label(s) == Spec.label(s) : Bool}:
  %Text.length_equiv(s) : {T.label(s) == Nat.is_le(1n, _) && Nat.is_le(_, 63n) && Spec.label_chars(s) && Spec.first_alnum(s) && Spec.last_alnum(s) : Bool}
  %chars_equiv(s, T.LabelChars{}, True{}) : {T.label(s) == Nat.is_le(1n, D.length(s)) && Nat.is_le(D.length(s), 63n) && _ && Spec.first_alnum(s) && Spec.last_alnum(s) : Bool}
  %first_equiv(s) : {T.label(s) == Nat.is_le(1n, D.length(s)) && Nat.is_le(D.length(s), 63n) && T.chars(s, T.LabelChars{}, True{}) && _ && Spec.last_alnum(s) : Bool}
  %last_final(s) : {T.label(s) == Nat.is_le(1n, D.length(s)) && Nat.is_le(D.length(s), 63n) && T.chars(s, T.LabelChars{}, True{}) && T.first_alnum(s) && _ : Bool}
  {==}

def labels_equiv(+ls: List<&2, String>, +ok: Bool) -> {T.labels(ls, ok) == ok && Spec.labels(ls) : Bool}:
  match ls:
    case Nil{}: Equal.sym(Bool, ok && True{}, ok, and_true(ok))
    case h <> t:
      %label_equiv(h) : {T.labels(ls, ok) == ok && (_ && Spec.labels(t)) : Bool}
      %and_assoc(ok, T.label(h), Spec.labels(t)) : {T.labels(ls, ok) == _ : Bool}
      labels_equiv(t, ok && T.label(h))

def host_equiv(+s: String) -> {T.host(s) == Spec.hostname(s) : Bool}:
  %Text.length_equiv(s) : {T.host(s) == Nat.is_le(_, 253n) && Spec.labels(Spec.split(s, 46)) : Bool}
  %split_equiv(s, 46) : {T.host(s) == Nat.is_le(D.length(s), 253n) && Spec.labels(_) : Bool}
  %labels_equiv(T.split(s, 46), True{}) : {T.host(s) == Nat.is_le(D.length(s), 253n) && _ : Bool}
  {==}

def atoms_step(+ok: Bool, +p: String, +t: List<&2, String>) -> {((ok && Bool.not(String.is_empty(p))) && T.chars(p, T.AtomChars{}, True{})) && Spec.atoms(t) == ok && (Bool.not(String.is_empty(p)) && Spec.atom(p) && Spec.atoms(t)) : Bool}:
  match ok:
    case False{}: {==}
    case True{}:
      %chars_equiv(p, T.AtomChars{}, True{}) : {Bool.not(String.is_empty(p)) && T.chars(p, T.AtomChars{}, True{}) && Spec.atoms(t) == Bool.not(String.is_empty(p)) && _ && Spec.atoms(t) : Bool}
      {==}

def atoms_equiv(+ps: List<&2, String>, +ok: Bool) -> {T.atoms(ps, ok) == ok && Spec.atoms(ps) : Bool}:
  match ps:
    case Nil{}: Equal.sym(Bool, ok && True{}, ok, and_true(ok))
    case p <> t:
      %atoms_step(ok, p, t) : {T.atoms(ps, ok) == _ : Bool}
      atoms_equiv(t, ok && Bool.not(String.is_empty(p)) && T.chars(p, T.AtomChars{}, True{}))

def dot_atom_equiv(+s: String) -> {T.dot_atom(s) == Spec.dot_atom(s) : Bool}:
  %Text.length_equiv(s) : {T.dot_atom(s) == Nat.is_le(_, 64n) && Spec.atoms(Spec.split(s, 46)) : Bool}
  %split_equiv(s, 46) : {T.dot_atom(s) == Nat.is_le(D.length(s), 64n) && Spec.atoms(_) : Bool}
  %atoms_equiv(T.split(s, 46), True{}) : {T.dot_atom(s) == Nat.is_le(D.length(s), 64n) && _ : Bool}
  {==}

# Prefix scans carry a reversed prefix or a saved suffix. The stop flag makes
# each recursive call a tail call, including when the separator has just arrived.
def before_result(stop: Bool, s: String, codes: List<&2, U32>, rev: String) -> String:
  match stop:
    case True{}: String.reverse(rev)
    case False{}: String.reverse.go(rev, Spec.before(s, codes))

def before_transition(+here: Bool, +c: U32, +rev: String, +t: String, +codes: List<&2, U32>) -> {before_result(here, t, codes, T.before_rev(here, c, rev)) == String.reverse.go(rev, Bool.pick(String, here, "", SCon{Chr{c}, Spec.before(t, codes)})) : String}:
  match here:
    case True{}: {==}
    case False{}: {==}

def before_go_equiv(+s: String, +codes: List<&2, U32>, +rev: String, +stop: Bool) -> {T.before_go(s, codes, rev, stop) == before_result(stop, s, codes, rev) : String}:
  match s stop:
    case _ True{}: {==}
    case SNil{} False{}: {==}
    case SCon{Chr{c}, t} False{}:
      %one_of_equiv(c, codes) : {T.before_go(s, codes, rev, False{}) == String.reverse.go(rev, Bool.pick(String, _, "", SCon{Chr{c}, Spec.before(t, codes)})) : String}
      %before_transition(T.one_of(c, codes), c, rev, t, codes) : {T.before_go(s, codes, rev, False{}) == _ : String}
      before_go_equiv(t, codes, T.before_rev(T.one_of(c, codes), c, rev), T.one_of(c, codes))

def before_equiv(+s: String, +codes: List<&2, U32>) -> {T.before(s, codes) == Spec.before(s, codes) : String}:
  before_go_equiv(s, codes, "", False{})

def from_go_equiv(+s: String, +codes: List<&2, U32>, +rest: String, +stop: Bool) -> {T.from_go(s, codes, rest, stop) == Bool.pick(String, stop, rest, Spec.from(s, codes)) : String}:
  match s stop:
    case _ True{}: {==}
    case SNil{} False{}: {==}
    case SCon{Chr{c}, t} False{}:
      %one_of_equiv(c, codes) : {T.from_go(s, codes, rest, False{}) == Bool.pick(String, _, s, Spec.from(t, codes)) : String}
      from_go_equiv(t, codes, s, T.one_of(c, codes))

def from_equiv(+s: String, +codes: List<&2, U32>) -> {T.from(s, codes) == Spec.from(s, codes) : String}:
  from_go_equiv(s, codes, "", False{})

def email_domain_equiv(+local: String, +rest: String) -> {T.email_domain(local, rest) == Spec.email_domain(local, rest) : Bool}:
  match rest:
    case SNil{}: {==}
    case SCon{at, domain}:
      %dot_atom_equiv(local) : {T.email_domain(local, rest) == _ && Spec.hostname(domain) : Bool}
      %host_equiv(domain) : {T.email_domain(local, rest) == T.dot_atom(local) && _ : Bool}
      {==}

def email_equiv(+s: String) -> {T.email(s) == Spec.email(s) : Bool}:
  %Text.length_equiv(s) : {T.email(s) == Nat.is_le(_, 254n) && Spec.email_domain(Spec.before(s, [64]), Spec.from(s, [64])) : Bool}
  %before_equiv(s, [64]) : {T.email(s) == Nat.is_le(D.length(s), 254n) && Spec.email_domain(_, Spec.from(s, [64])) : Bool}
  %from_equiv(s, [64]) : {T.email(s) == Nat.is_le(D.length(s), 254n) && Spec.email_domain(T.before(s, [64]), _) : Bool}
  %email_domain_equiv(T.before(s, [64]), T.from(s, [64])) : {T.email(s) == Nat.is_le(D.length(s), 254n) && _ : Bool}
  {==}

def strip_transition(+ok: Bool, +same: Bool, +rest: Maybe<&2, String>) -> {Bool.pick(Maybe<&2, String>, ok && same, rest, None{}) == Bool.pick(Maybe<&2, String>, ok, Bool.pick(Maybe<&2, String>, same, rest, None{}), None{}) : Maybe<&2, String>}:
  match ok same:
    case False{} _: {==}
    case True{} _: {==}

def strip_none(+ok: Bool) -> {None{} == Bool.pick(Maybe<&2, String>, ok, None{}, None{}) : Maybe<&2, String>}:
  match ok:
    case False{}: {==}
    case True{}: {==}

def strip_go_equiv(+prefix: String, +s: String, +ok: Bool) -> {T.strip_go(prefix, s, ok) == Bool.pick(Maybe<&2, String>, ok, Spec.strip(prefix, s), None{}) : Maybe<&2, String>}:
  match prefix s:
    case SNil{} _: {==}
    case SCon{Chr{x}, p} SCon{Chr{y}, t}:
      %strip_transition(ok, U32.is_eq(x, y), Spec.strip(p, t)) : {T.strip_go(prefix, s, ok) == _ : Maybe<&2, String>}
      strip_go_equiv(p, t, ok && U32.is_eq(x, y))
    case SCon{c, p} SNil{}: strip_none(ok)

def strip_equiv(+prefix: String, +s: String) -> {T.strip(prefix, s) == Spec.strip(prefix, s) : Maybe<&2, String>}:
  strip_go_equiv(prefix, s, True{})

# Generalize the suffix law over both accumulated validity and hex digits owed.
def suffix_transition(+percent: Bool, +ok: Bool, +uri: Bool, +t: String) -> {(ok && (percent || uri)) && Spec.suffix(t, Bool.pick(Nat, percent, 2n, 0n)) == ok && Bool.pick(Bool, percent, Spec.suffix(t, 2n), uri && Spec.suffix(t, 0n)) : Bool}:
  match percent:
    case True{}: Equal.cong(Bool, Bool, b => b && Spec.suffix(t, 2n), ok && True{}, ok, and_true(ok))
    case False{}: and_assoc(ok, uri, Spec.suffix(t, 0n))

def suffix_equiv(+s: String, +due: Nat, +ok: Bool) -> {T.suffix(s, due, ok) == ok && Spec.suffix(s, due) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      match due:
        case 0n:
          %uri_equiv(c) : {T.suffix(s, 0n, ok) == ok && Bool.pick(Bool, U32.is_eq(c, 37), Spec.suffix(t, 2n), _ && Spec.suffix(t, 0n)) : Bool}
          %suffix_transition(U32.is_eq(c, 37), ok, T.uri_char(c), t) : {T.suffix(s, 0n, ok) == _ : Bool}
          suffix_equiv(t, T.suffix_due(0n, c), ok && T.suffix_ok(0n, c))
        case 1n+k:
          %and_assoc(ok, T.hex(c), Spec.suffix(t, k)) : {T.suffix(s, 1n+k, ok) == _ : Bool}
          suffix_equiv(t, k, ok && T.hex(c))

def value_equiv(+s: String, +acc: Nat) -> {T.value(s, acc) == Spec.value(s, acc) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: value_equiv(t, Nat.add(Nat.mul(acc, 10n), Spec.digit_value(c)))

def port_gate_equiv(+p: String, +valid: Bool) -> {T.port_gate(p, valid) == valid && Nat.is_le(Spec.value(p, 0n), 65535n) : Bool}:
  match valid:
    case False{}: {==}
    case True{}:
      %value_equiv(p, 0n) : {T.port_gate(p, True{}) == Nat.is_le(_, 65535n) : Bool}
      {==}

def port_equiv(+p: String) -> {T.port(p) == Spec.port(p) : Bool}:
  %Text.length_equiv(p) : {T.port(p) == Nat.is_le(1n, _) && Nat.is_le(_, 5n) && Spec.digits(p) && Nat.is_le(Spec.value(p, 0n), 65535n) : Bool}
  %chars_equiv(p, T.Digits{}, True{}) : {T.port(p) == Nat.is_le(1n, D.length(p)) && Nat.is_le(D.length(p), 5n) && _ && Nat.is_le(Spec.value(p, 0n), 65535n) : Bool}
  port_gate_equiv(p, Nat.is_le(1n, D.length(p)) && Nat.is_le(D.length(p), 5n) && T.chars(p, T.Digits{}, True{}))

def after_host_equiv(+s: String) -> {T.after_host(s) == Spec.after_host(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      %before_equiv(t, [47, 63, 35]) : {T.after_host(s) == Bool.pick(Bool, U32.is_eq(c, 58), Spec.port(_) && Spec.suffix(Spec.from(t, [47, 63, 35]), 0n), Spec.suffix(s, 0n)) : Bool}
      %from_equiv(t, [47, 63, 35]) : {T.after_host(s) == Bool.pick(Bool, U32.is_eq(c, 58), Spec.port(T.before(t, [47, 63, 35])) && Spec.suffix(_, 0n), Spec.suffix(s, 0n)) : Bool}
      %port_equiv(T.before(t, [47, 63, 35])) : {T.after_host(s) == Bool.pick(Bool, U32.is_eq(c, 58), _ && Spec.suffix(T.from(t, [47, 63, 35]), 0n), Spec.suffix(s, 0n)) : Bool}
      %suffix_equiv(T.from(t, [47, 63, 35]), 0n, True{}) : {T.after_host(s) == Bool.pick(Bool, U32.is_eq(c, 58), T.port(T.before(t, [47, 63, 35])) && _, Spec.suffix(s, 0n)) : Bool}
      %suffix_equiv(s, 0n, True{}) : {T.after_host(s) == Bool.pick(Bool, U32.is_eq(c, 58), T.port(T.before(t, [47, 63, 35])) && T.suffix(T.from(t, [47, 63, 35]), 0n, True{}), _) : Bool}
      {==}

def authority_equiv(+rest: Maybe<&2, String>) -> {T.authority(rest) == Spec.authority(rest) : Bool}:
  match rest:
    case None{}: {==}
    case Some{x}:
      %before_equiv(x, [58, 47, 63, 35]) : {T.authority(rest) == Spec.hostname(_) && Spec.after_host(Spec.from(x, [58, 47, 63, 35])) : Bool}
      %from_equiv(x, [58, 47, 63, 35]) : {T.authority(rest) == Spec.hostname(T.before(x, [58, 47, 63, 35])) && Spec.after_host(_) : Bool}
      %host_equiv(T.before(x, [58, 47, 63, 35])) : {T.authority(rest) == _ && Spec.after_host(T.from(x, [58, 47, 63, 35])) : Bool}
      %after_host_equiv(T.from(x, [58, 47, 63, 35])) : {T.authority(rest) == T.host(T.before(x, [58, 47, 63, 35])) && _ : Bool}
      {==}

def url_equiv(+s: String) -> {T.url(s) == Spec.url(s) : Bool}:
  %strip_equiv("http://", s) : {T.url(s) == Spec.authority(_) || Spec.authority(Spec.strip("https://", s)) : Bool}
  %strip_equiv("https://", s) : {T.url(s) == Spec.authority(T.strip("http://", s)) || Spec.authority(_) : Bool}
  %authority_equiv(T.strip("http://", s)) : {T.url(s) == _ || Spec.authority(T.strip("https://", s)) : Bool}
  %authority_equiv(T.strip("https://", s)) : {T.url(s) == T.authority(T.strip("http://", s)) || _ : Bool}
  {==}
