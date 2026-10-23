import Base
import ../src/data/cookie.bend as C
import ./cookie-serialization-spec.bend as Spec

law serialize_exact:
  for +name: String
  for +value: String
  for +options: C.Options
  for ok: {Spec.admissible(name, value, options) == True{} : Bool}
  {C.serialize(name, value, options) == Done{Spec.wire(name, value, options)} : Result<&2, &2, C.Error, String>}

law serialize_structure:
  for +name: String
  for +value: String
  for +options: C.Options
  for +output: String
  for ok: {C.serialize(name, value, options) == Done{output} : Result<&2, &2, C.Error, String>}
  Spec.structure(name, value, options, output)

law attribute_no_delimiters:
  for +s: String
  for ok: {Spec.attribute(s) == True{} : Bool}
  Spec.no_delimiters(s)

law admissible_payloads_safe:
  for +name: String
  for +value: String
  for +options: C.Options
  for ok: {Spec.admissible(name, value, options) == True{} : Bool}
  Spec.options_payloads_safe(options)
