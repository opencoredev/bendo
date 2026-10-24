# BND-84: every request-path helper in the router and the static resolver
# is a tail loop, so request-sized input cannot exhaust the JavaScript stack.
# Each law states that a rewritten helper equals its recursive original
# (`_spec`, or the static model). Every law proven against those originals
# therefore still holds for the code that runs.
import Base
import ../src/router/utf8-code.bend as Code
import ../src/router/encoding.bend as Encoding
import ../src/router/encoding-proofs.bend as EncodingProof
import ../src/router/constraint.bend as Constraint
import ../src/router/constraint-proofs.bend as ConstraintProof
import ../src/router/pattern.bend as Pattern
import ../src/router/pattern-stack-proofs.bend as PatternProof
import ../src/static/path.bend as StaticPath
import ./static-path-model.bend as StaticModel
import ./static-path-equiv.bend as StaticEquiv

law utf8_decode_stack_safe:
  for +bs: List<&2, U32>
  for +state: Code.State
  {Code.decode(bs, state) == Code.decode_spec(bs, state) : Maybe<&2, String>}

def utf8_decode_stack_safe(bs, state):
  Equal.sym(Maybe<&2, String>, Code.decode_spec(bs, state), Code.decode(bs, state), Code.decode_equiv(bs, state))

law url_scalars_stack_safe:
  for +s: String
  {Encoding.scalars(s) == Encoding.scalars_spec(s) : Bool}

def url_scalars_stack_safe(s):
  Equal.sym(Bool, Encoding.scalars_spec(s), Encoding.scalars(s), EncodingProof.scalars_equiv(s))

law url_encode_stack_safe:
  for +s: String
  {Encoding.encode(s) == Encoding.encode_spec(s) : String}

def url_encode_stack_safe(s):
  Equal.sym(String, Encoding.encode_spec(s), Encoding.encode(s), EncodingProof.encode_equiv(s))

law url_unescape_stack_safe:
  for +s: String
  {Encoding.unescape(s) == Encoding.unescape_spec(s) : Maybe<&2, List<&2, U32>>}

def url_unescape_stack_safe(s):
  Equal.sym(Maybe<&2, List<&2, U32>>, Encoding.unescape_spec(s), Encoding.unescape(s), EncodingProof.unescape_equiv(s))

law url_decode_stack_safe:
  for +s: String
  {Encoding.decode(s) == Encoding.decode_spec(s) : Maybe<&2, String>}

def url_decode_stack_safe(s):
  Equal.sym(Maybe<&2, String>, Encoding.decode_spec(s), Encoding.decode(s), EncodingProof.decode_equiv(s))

law constraint_digits_stack_safe:
  for +s: String
  {Constraint.digits(s) == Constraint.digits_spec(s) : Bool}

def constraint_digits_stack_safe(s):
  Equal.sym(Bool, Constraint.digits_spec(s), Constraint.digits(s), ConstraintProof.digits_equiv(s))

law constraint_slug_stack_safe:
  for +s: String
  {Constraint.slug(s) == Constraint.slug_spec(s) : Bool}

def constraint_slug_stack_safe(s):
  Equal.sym(Bool, Constraint.slug_spec(s), Constraint.slug(s), ConstraintProof.slug_equiv(s))

law constraint_uuid_stack_safe:
  for +s: String
  for +pos: Nat
  {Constraint.uuid(s, pos) == Constraint.uuid_spec(s, pos) : Bool}

def constraint_uuid_stack_safe(s, pos):
  Equal.sym(Bool, Constraint.uuid_spec(s, pos), Constraint.uuid(s, pos), ConstraintProof.uuid_equiv(s, pos))

law constraint_class_stack_safe:
  for +s: String
  for +ranges: List<&2, Constraint.Range>
  {Constraint.class_chars(s, ranges) == Constraint.class_chars_spec(s, ranges) : Bool}

def constraint_class_stack_safe(s, ranges):
  Equal.sym(Bool, Constraint.class_chars_spec(s, ranges), Constraint.class_chars(s, ranges), ConstraintProof.class_chars_equiv(s, ranges))

law pattern_segments_stack_safe:
  for +s: String
  {Pattern.path_segments(s) == String.split(s, '/') : List<&2, String>}

def pattern_segments_stack_safe(s):
  Equal.sym(List<&2, String>, String.split(s, '/'), Pattern.path_segments(s), PatternProof.segments_equiv(s))

law pattern_join_stack_safe:
  for +xs: List<&2, String>
  {Pattern.join_taken(xs) == String.join(List.reverse(&2, String, xs), "/") : String}

def pattern_join_stack_safe(xs):
  Equal.sym(String, String.join(List.reverse(&2, String, xs), "/"), Pattern.join_taken(xs), PatternProof.join_taken_equiv(xs))

law pattern_decode_segments_stack_safe:
  for +ps: List<&2, String>
  {Pattern.decode_segments(ps) == Pattern.decode_segments_spec(ps) : Maybe<&2, String>}

def pattern_decode_segments_stack_safe(ps):
  Equal.sym(Maybe<&2, String>, Pattern.decode_segments_spec(ps), Pattern.decode_segments(ps), PatternProof.decode_segments_equiv(ps))

law pattern_empty_rows_stack_safe:
  for +ps: List<&2, String>
  {Pattern.empty_rows(ps) == Pattern.empty_rows_spec(ps) : List<&2, Maybe<&2, Pattern.Params>>}

def pattern_empty_rows_stack_safe(ps):
  Equal.sym(List<&2, Maybe<&2, Pattern.Params>>, Pattern.empty_rows_spec(ps), Pattern.empty_rows(ps), PatternProof.empty_rows_equiv(ps))

# Stated for the default comparisons; the proof holds for any pair.
law pattern_rows_stack_safe:
  for +seg: Pattern.Segment
  for +last: Bool
  for +paths: List<&2, String>
  for +hits: List<&2, Maybe<&2, Pattern.Params>>
  {Pattern.rows_for(~String.eq, ~String.starts_with, seg, last, paths, hits) == Pattern.rows_for_spec(~String.eq, ~String.starts_with, seg, last, paths, hits) : List<&2, Maybe<&2, Pattern.Params>>}

def pattern_rows_stack_safe(seg, last, paths, hits):
  Equal.sym(List<&2, Maybe<&2, Pattern.Params>>, Pattern.rows_for_spec(~String.eq, ~String.starts_with, seg, last, paths, hits), Pattern.rows_for(~String.eq, ~String.starts_with, seg, last, paths, hits), PatternProof.rows_for_equiv(~String.eq, ~String.starts_with, seg, last, paths, hits))

law pattern_span_stack_safe:
  for +paths: List<&2, String>
  for +cells: List<&2, Maybe<&2, Pattern.Params>>
  for +name: String
  for +taken: List<&2, String>
  {Pattern.span_scan(paths, cells, name, taken) == Pattern.span_scan_spec(paths, cells, name, taken) : Maybe<&2, Pattern.Params>}

def pattern_span_stack_safe(paths, cells, name, taken):
  Equal.sym(Maybe<&2, Pattern.Params>, Pattern.span_scan_spec(paths, cells, name, taken), Pattern.span_scan(paths, cells, name, taken), PatternProof.span_scan_equiv(paths, cells, name, taken))

law static_resolve_stack_safe:
  for +raw: String
  for +index: String
  {StaticPath.resolve(raw, index) == StaticModel.resolve(raw, index) : Maybe<&2, String>}

def static_resolve_stack_safe(raw, index):
  Equal.sym(Maybe<&2, String>, StaticModel.resolve(raw, index), StaticPath.resolve(raw, index), StaticEquiv.resolve_equiv(raw, index))

law static_target_stack_safe:
  for root: String
  for +raw: String
  for +index: String
  {StaticPath.target(root, raw, index) == StaticModel.target(root, raw, index) : Maybe<&2, String>}

def static_target_stack_safe(root, raw, index):
  Equal.sym(Maybe<&2, String>, StaticModel.target(root, raw, index), StaticPath.target(root, raw, index), StaticEquiv.target_equiv(root, raw, index))
