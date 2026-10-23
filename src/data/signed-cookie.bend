# Hono-compatible signed cookies. Names are deliberately not authenticated.
import Base
import ./cookie.bend as Cookie
import ./urlencoded.bend as Url
import ./utf8.bend as Utf8
import ./base64.bend as Base64
import ../crypto/hmac.bend as Hmac
import ../crypto/compare.bend as Compare

# A nonempty rotation set. Construct at startup with configure.
type Keys is Data:
  Keys{first: String, rest: List<&2, String>}

def valid_keys_go(xs: List<&2, String>, ok: Bool) -> Bool:
  match xs:
    case Nil{}: ok
    case x <> t: valid_keys_go(t, ok && Utf8.valid(x))

def configured(keys: Keys, ok: Bool) -> Maybe<&2, Keys>:
  match ok:
    case True{}: Some{keys}
    case False{}: None{}

def configure(xs: List<&2, String>) -> Maybe<&2, Keys>:
  match xs:
    case Nil{}: None{}
    case +first <> +rest: configured(Keys{first, rest}, valid_keys_go(rest, Utf8.valid(first)))

def digest(key: String, value: String) -> List<&2, U32>:
  Hmac.sha256(Utf8.encode(key), Utf8.encode(value))

# Pure unchecked signing primitive; callers supply Unicode scalar strings.
def sign(key: String, +value: String) -> String:
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

def verify_digest(keys: Keys, +value: String, signature: List<&2, U32>) -> Maybe<&2, String>:
  verified(value, matches(keys, value, signature))

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

def serialize_valid(name: String, value: String, keys: Keys, options: Cookie.Options, valid: Bool) -> Result<&2, &2, Cookie.Error, String>:
  match keys valid:
    case _ False{}: Fail{Cookie.InvalidValue{}}
    case Keys{first, rest} True{}:
      Cookie.serialize(name, sign(first, value), options)

def serialize(name: String, +value: String, keys: Keys, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, String>:
  serialize_valid(name, value, keys, options, Utf8.valid(value))
