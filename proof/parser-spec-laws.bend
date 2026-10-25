# BND-92: the parsers that route validation's implementation and its
# specification share, specified independently. proof/validate-laws.bend
# states its laws relative to Bytes.fold and the raw query parser; these
# laws pin both down.
import Base
import ../src/http/bytes.bend as Bytes
import ./fold-spec.bend as FoldSpec
import ../src/data/urlencoded.bend as Url
import ./query-spec.bend as QuerySpec

# Header-name folding is ASCII lowercasing, character by character: each of
# the 26 capital letters becomes its small letter and every other
# character, non-ASCII included, is kept. The specification is a written-out
# letter table, not Base's numeric Char.to_lower.
law fold_matches_letter_table:
  for +s: String
  {Bytes.fold(s) == FoldSpec.fold(s) : String}

# The raw query parser is the WHATWG application/x-www-form-urlencoded
# parser under Bendo's strict policy (proof/query-spec.bend): split the
# UTF-8 octets on "&", skip empty pieces, split each piece at its first "=",
# read a literal "+" as a space and "%HH" as one octet, and decode UTF-8.
# A malformed "%" fails with InvalidPercent and non-UTF-8 octets with
# InvalidUtf8, the first failure in input order winning, name before value;
# otherwise a non-scalar character anywhere fails with InvalidUtf8.
law query_parse_matches_spec:
  for +s: String
  {Url.parse_pairs(s) == QuerySpec.parse(s) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}

# The specification on the standard's cases: repeated names stay in order
# and a piece without "=" has an empty value; "+" is a space but "%2B" is
# "+"; empty pieces are skipped and "=y" has an empty name; a bad escape and
# a non-UTF-8 octet are refused.
law query_spec_examples:
  {QuerySpec.parse("a=1&a=2&b") == Done{[Url.Entry{"a", "1"}, Url.Entry{"a", "2"}, Url.Entry{"b", ""}]} : Result<&2, &2, Url.Error, List<&2, Url.Entry>>} & ({QuerySpec.parse("x=%2B+%41&&=y&") == Done{[Url.Entry{"x", "+ A"}, Url.Entry{"", "y"}]} : Result<&2, &2, Url.Error, List<&2, Url.Entry>>} & ({QuerySpec.parse("q=caf%C3%A9&a=%4") == Fail{Url.InvalidPercent{}} : Result<&2, &2, Url.Error, List<&2, Url.Entry>>} & {QuerySpec.parse("a=%FF") == Fail{Url.InvalidUtf8{}} : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}))
