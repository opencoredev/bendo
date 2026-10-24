# BND-85: Media.essence equals the independent essence for every value.
import Base
import ../src/http/media.bend as Media
import ./media-spec.bend as MediaSpec

law media_essence_spec:
  for +value: String
  {Media.essence(value) == MediaSpec.essence(value) : String}
