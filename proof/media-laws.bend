# BND-85: Media.essence equals the independent essence for every value.
import Base
import ../src/http/media.bend as Media
import ./media-spec.bend as MediaSpec

law media_essence_spec:
  for +value: String
  {Media.essence(value) == MediaSpec.essence(value) : String}

# Media.well_formed equals the independent grammar for every value.
law media_well_formed_spec:
  for +value: String
  {Media.well_formed(value) == MediaSpec.well_formed(value) : Bool}
