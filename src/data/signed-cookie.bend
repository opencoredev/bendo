# Hono-compatible signed cookies. Names are deliberately not authenticated.
import Base
import ./cookie.bend as Cookie
import ./urlencoded.bend as Url
import ./utf8.bend as Utf8
import ./base64.bend as Base64
import ../crypto/hmac.bend as Hmac
import ../crypto/compare.bend as Compare

# A nonempty rotation set. Construct it at startup with configure. Bend
# cannot hide the constructor, so every entry point rechecks the slots.
type Keys is Data:
  Keys{first: String, rest: List<&2, String>}

# Validate external strings with constant JavaScript call depth.
def scalar_valid_go(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok
    case SCon{Chr{c}, t}: scalar_valid_go(t, ok && Utf8.scalar(c))

def scalar_valid(s: String) -> Bool:
  scalar_valid_go(s, True{})

# Empty secrets are rejected in every rotation slot, as WebCrypto does: an
# attacker can compute the HMAC under an empty key.
def key_valid(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{h, t}: scalar_valid(SCon{h, t})

def valid_keys_go(xs: List<&2, String>, ok: Bool) -> Bool:
  match xs:
    case Nil{}: ok
    case x <> t: valid_keys_go(t, ok && key_valid(x))

# Every slot holds a usable secret, as configure requires.
def usable(keys: Keys) -> Bool:
  match keys:
    case Keys{first, rest}: valid_keys_go(rest, key_valid(first))

def configured(keys: Keys, ok: Bool) -> Maybe<&2, Keys>:
  match ok:
    case True{}: Some{keys}
    case False{}: None{}

def configure(xs: List<&2, String>) -> Maybe<&2, Keys>:
  match xs:
    case Nil{}: None{}
    case +first <> +rest: configured(Keys{first, rest}, valid_keys_go(rest, key_valid(first)))

def digest(key: String, value: String) -> List<&2, U32>:
  Hmac.sha256(Utf8.encode(key), Utf8.encode(value))

# Unchecked signing primitive: it trusts the key and expects a Unicode
# scalar value. Applications use sign or serialize.
def unchecked_sign(key: String, +value: String) -> String:
  Url.encode(value ++ "." ++ Base64.encode(digest(key, value), False{}, True{}))

# Always check every key, and every digest byte, including after a match.
def matches_go(keys: List<&2, String>, +value: String, +signature: List<&2, U32>, found: Bool) -> Bool:
  match keys:
    case Nil{}: found
    case key <> rest:
      matches_go(rest, value, signature, found || Compare.ct_equal(digest(key, value), signature))

def matches(keys: Keys, value: String, signature: List<&2, U32>) -> Bool:
  Keys{first, rest} = keys
  matches_go(first <> rest, value, signature, False{})

def verified(value: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: Some{value}
    case False{}: None{}

def verify_usable(keys: Keys, +value: String, signature: List<&2, U32>, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: verified(value, matches(keys, value, signature))
    case False{}: None{}

# A directly built Keys with an empty or non-scalar slot accepts nothing:
# anyone can compute the HMAC under an empty key.
def verify_digest(+keys: Keys, +value: String, signature: List<&2, U32>) -> Maybe<&2, String>:
  verify_usable(keys, value, signature, usable(keys))

def verify_base64(keys: Keys, value: String, signature: Maybe<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match signature:
    case None{}: None{}
    case Some{bytes}: verify_digest(keys, value, bytes)

# Split the reversed string at its first dot, so values may contain dots.
def verify_parts(keys: Keys, parts: String & Maybe<&2, String>) -> Maybe<&2, String>:
  (signature, value) = parts
  match value:
    case None{}: None{}
    case Some{rev}: verify_base64(keys, String.reverse(rev), Base64.decode(String.reverse(signature), False{}, True{}))

def verify_decoded(keys: Keys, decoded: Result<&2, &2, Url.Error, String>) -> Maybe<&2, String>:
  match decoded:
    case Fail{error}: None{}
    case Done{value}: verify_parts(keys, Cookie.split(String.reverse(value), '.'))

def verify(keys: Keys, wire: String) -> Maybe<&2, String>:
  verify_decoded(keys, Url.decode(wire))

def read(keys: Keys, wire: Maybe<&2, String>) -> Maybe<&2, String>:
  match wire:
    case None{}: None{}
    case Some{value}: verify(keys, value)

def signed(keys: Keys, +value: String, ok: Bool) -> Maybe<&2, String>:
  match keys ok:
    case _ False{}: None{}
    case Keys{first, rest} True{}: Some{unchecked_sign(first, value)}

# Sign with the first key. None for unusable keys or a non-scalar value.
def sign(+keys: Keys, +value: String) -> Maybe<&2, String>:
  signed(keys, value, usable(keys) && scalar_valid(value))

def serialize_keys(name: String, value: String, keys: Keys, options: Cookie.Options, ok: Bool) -> Result<&2, &2, Cookie.Error, String>:
  match keys ok:
    case _ False{}: Fail{Cookie.InvalidSecret{}}
    case Keys{first, rest} True{}:
      Cookie.serialize(name, unchecked_sign(first, value), options)

# The value is checked before the keys, so a non-scalar value is always
# InvalidValue; unusable keys give InvalidSecret.
def serialize_valid(name: String, value: String, +keys: Keys, options: Cookie.Options, valid: Bool) -> Result<&2, &2, Cookie.Error, String>:
  match valid:
    case False{}: Fail{Cookie.InvalidValue{}}
    case True{}: serialize_keys(name, value, keys, options, usable(keys))

def serialize(name: String, +value: String, keys: Keys, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, String>:
  serialize_valid(name, value, keys, options, scalar_valid(value))
