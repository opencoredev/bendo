# BND-85: the CSRF Content-Type rule as main stated it before BND-85, kept so
# law csrf_spec_v1_denies can say the current policy denies everything it
# denied. Main's essence trimmed with Base's String.trim, which also drops LF,
# VT, FF and CR, and exempted every value whose essence was not a form type.
# Only that rule differs from proof/csrf-spec.bend: methods, Sec-Fetch-Site
# and origins are read the same way, through the current definitions.
import Base
import ../src/http/request.bend as Request
import ../src/http/media.bend as Media
import ../src/http/bytes.bend as Bytes
import ./csrf-spec.bend as Spec

# Main's Media.essence.
def essence(value: String) -> String:
  Bytes.fold(String.trim(Media.before_params(value)))

def simple_body(content_type: Maybe<&2, String>) -> Bool:
  match content_type:
    case None{}: True{}
    case Some{v}: Spec.form_essence(essence(v))

def inspected(m: Request.Method, content_type: Maybe<&2, String>) -> Bool:
  Bool.not(Spec.reads_only(m)) && simple_body(content_type)

def allows(+origins: List<&2, String>, scheme: Maybe<&2, String>, method: Request.Method, content_type: Maybe<&2, String>, +site: Maybe<&2, String>, origin: Maybe<&2, String>, referer: Maybe<&2, String>, host: Maybe<&2, String>) -> Bool:
  Bool.not(inspected(method, content_type)) || Spec.site_is(site, "same-origin") || Spec.trusted(origins, scheme, site, Spec.source(origin, referer), host)
