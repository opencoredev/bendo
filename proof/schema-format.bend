# The email and URL recognizers agree with the independent grammars
# (src/data/schema-spec.bend).
import Base
import ../src/data/schema-text.bend as T
import ../src/data/schema-spec.bend as Spec

def email_equiv(+s: String) -> {T.email(s) == Spec.email(s) : Bool}:
  ?TODO

def url_equiv(+s: String) -> {T.url(s) == Spec.url(s) : Bool}:
  ?TODO
