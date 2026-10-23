# BND-32: configuration agrees with the independent secret specification.
import Base
import ../src/data/signed-cookie.bend as S
import ../src/data/utf8.bend as Utf8
import ./signed-cookie-spec.bend as Spec

def distinguish(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : distinguish(_)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def and_left(+a: Bool, +b: Bool, ok: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}: ok
    case True{}: {==}

def and_right(+a: Bool, +b: Bool, ok: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}: absurd({b == True{} : Bool}, false_true(ok))
    case True{}: ok

def scalar_go(+s: String, +ok: Bool) -> {S.scalar_valid_go(s, ok) == ok && Utf8.valid(s) : Bool}:
  match s:
    case SNil{}:
      match ok:
        case False{}: {==}
        case True{}: {==}
    case SCon{Chr{+c}, +t}:
      Equal.trans(Bool, S.scalar_valid_go(t, ok && Utf8.scalar(c)), (ok && Utf8.scalar(c)) && Utf8.valid(t), ok && (Utf8.scalar(c) && Utf8.valid(t)), scalar_go(t, ok && Utf8.scalar(c)), and_assoc(ok, Utf8.scalar(c), Utf8.valid(t)))

# The public scalar check is the structural Unicode-scalar predicate.
def scalar(+s: String) -> {S.scalar_valid(s) == Utf8.valid(s) : Bool}:
  scalar_go(s, True{})

def key(+s: String) -> {S.key_valid(s) == Spec.secret(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{+h, +t}: scalar(SCon{h, t})

def keys_go(+xs: List<&2, String>, +ok: Bool) -> {S.valid_keys_go(xs, ok) == ok && Spec.secrets(xs) : Bool}:
  match xs:
    case Nil{}:
      match ok:
        case False{}: {==}
        case True{}: {==}
    case +x <> +t:
      %Equal.sym(Bool, S.key_valid(x), Spec.secret(x), key(x)) : {S.valid_keys_go(t, ok && _) == ok && (Spec.secret(x) && Spec.secrets(t)) : Bool}
      Equal.trans(Bool, S.valid_keys_go(t, ok && Spec.secret(x)), (ok && Spec.secret(x)) && Spec.secrets(t), ok && (Spec.secret(x) && Spec.secrets(t)), keys_go(t, ok && Spec.secret(x)), and_assoc(ok, Spec.secret(x), Spec.secrets(t)))

def configured(+keys: S.Keys, +ok: Bool) -> {S.configured(keys, ok) == Spec.keys_when(keys, ok) : Maybe<&2, S.Keys>}:
  match ok:
    case False{}: {==}
    case True{}: {==}

def configure(+xs: List<&2, String>) -> {S.configure(xs) == Spec.configure(xs) : Maybe<&2, S.Keys>}:
  match xs:
    case Nil{}: {==}
    case +first <> +rest:
      %Equal.sym(Bool, S.key_valid(first), Spec.secret(first), key(first)) : {S.configured(S.Keys{first, rest}, S.valid_keys_go(rest, _)) == Spec.keys_when(S.Keys{first, rest}, Spec.secrets(first <> rest)) : Maybe<&2, S.Keys>}
      %Equal.sym(Bool, S.valid_keys_go(rest, Spec.secret(first)), Spec.secret(first) && Spec.secrets(rest), keys_go(rest, Spec.secret(first))) : {S.configured(S.Keys{first, rest}, _) == Spec.keys_when(S.Keys{first, rest}, Spec.secrets(first <> rest)) : Maybe<&2, S.Keys>}
      configured(S.Keys{first, rest}, Spec.secret(first) && Spec.secrets(rest))

def some_type(m: Maybe<&2, S.Keys>) -> Type:
  match m:
    case None{}: Unit
    case Some{k}: Empty

def none_some(+k: S.Keys, e: {None{} == Some{k} : Maybe<&2, S.Keys>}) -> Empty:
  %e : some_type(_)
  Unit{}

def accepted(+keys: S.Keys, +out: S.Keys, b: Bool, e: {Spec.keys_when(keys, b) == Some{out} : Maybe<&2, S.Keys>}) -> {b == True{} : Bool}:
  match b:
    case True{}: {==}
    case False{}: absurd({False{} == True{} : Bool}, none_some(out, e))

def secrets_nonempty(+xs: List<&2, String>, ok: {Spec.secrets(xs) == True{} : Bool}) -> {Spec.all_nonempty(xs) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> +t:
      match x:
        case SNil{}: absurd({Spec.all_nonempty("" <> t) == True{} : Bool}, false_true(ok))
        case SCon{+h, +u}: secrets_nonempty(t, and_right(Utf8.valid(SCon{h, u}), Spec.secrets(t), ok))

def spec_nonempty(+xs: List<&2, String>, +out: S.Keys, ok: {Spec.configure(xs) == Some{out} : Maybe<&2, S.Keys>}) -> {Spec.all_nonempty(xs) == True{} : Bool}:
  match xs:
    case Nil{}: absurd({Spec.all_nonempty([]) == True{} : Bool}, none_some(out, ok))
    case +first <> +rest:
      secrets_nonempty(first <> rest, accepted(S.Keys{first, rest}, out, Spec.secrets(first <> rest), ok))

def nonempty(+xs: List<&2, String>, +out: S.Keys, ok: {S.configure(xs) == Some{out} : Maybe<&2, S.Keys>}) -> {Spec.all_nonempty(xs) == True{} : Bool}:
  spec_nonempty(xs, out, Equal.trans(Maybe<&2, S.Keys>, Spec.configure(xs), S.configure(xs), Some{out}, Equal.sym(Maybe<&2, S.Keys>, S.configure(xs), Spec.configure(xs), configure(xs)), ok))
