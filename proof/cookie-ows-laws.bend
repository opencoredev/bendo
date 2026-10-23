import Base
import ../src/data/cookie.bend as C
import ./cookie-ows-spec.bend as Spec

law cookies_semispace_ordered_list_roundtrip:
  for +entries: List<&2, C.Entry>
  for valid: {Spec.entries_valid(entries) == True{} : Bool}
  {C.parse(String.join(Spec.pairs(entries), "; ")) == entries : List<&2, C.Entry>}

law cookies_per_pair_ows_roundtrip:
  for +entries: List<&2, Spec.PaddedEntry>
  for valid: {Spec.padded_valid(entries) == True{} : Bool}
  {C.parse(String.join(Spec.padded_pairs(entries), ";")) == Spec.unpad(entries) : List<&2, C.Entry>}
