# BND-85: failing closed on malformed media types only adds denials. Every
# request main's CSRF rule inspected is still inspected, so every request it
# denied is still denied.
import Base
import ../src/http/request.bend as Request
import ./csrf-spec.bend as CsrfSpec
import ./csrf-spec-v1.bend as CsrfSpecV1

law csrf_spec_v1_inspected:
  for +method: Request.Method
  for +content_type: Maybe<&2, String>
  for e: {CsrfSpecV1.inspected(method, content_type) == True{} : Bool}
  {CsrfSpec.inspected(method, content_type) == True{} : Bool}

law csrf_spec_v1_denies:
  for +origins: List<&2, String>
  for +scheme: Maybe<&2, String>
  for +method: Request.Method
  for +content_type: Maybe<&2, String>
  for +site: Maybe<&2, String>
  for +origin: Maybe<&2, String>
  for +referer: Maybe<&2, String>
  for +host: Maybe<&2, String>
  for e: {CsrfSpecV1.allows(origins, scheme, method, content_type, site, origin, referer, host) == False{} : Bool}
  {CsrfSpec.allows(origins, scheme, method, content_type, site, origin, referer, host) == False{} : Bool}
