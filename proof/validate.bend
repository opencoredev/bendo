# Proofs of the BND-36 route validation laws (proof/validate-laws.bend).
# Each slot of src/app/validate.bend is first shown to compute the spec's slot
# state; a case split over the four states then shows the verdicts agree.
import Base
import ./validate-laws.bend as L
import ./validate-spec.bend as Spec
import ./schema-prepared.bend as Prep
import ../src/app/validate.bend as V
import ../src/data/schema.bend as S
import ../src/data/schema-prepared.bend as SP
import ../src/data/json.bend as J
import ../src/data/utf8.bend as Utf8
import ../src/data/urlencoded.bend as Query
import ../src/http/bytes.bend as Bytes
import ../src/http/media.bend as Media
import ./media-spec.bend as MediaSpec
import ./media.bend as MediaProof
import ../src/http/request.bend as Request
import ../src/router/pattern.bend as Pattern
import ../src/app/context.bend as C
import ../src/app/config.bend as Config
import ../src/app/table.bend as Table
import ../src/app/table-schemas.bend as TableSchemas
import ../src/app/route-schemas.bend as RS
import ../src/router/methods.bend as Methods
import ./validate-scopes.bend as Scopes
import ./scoped-selection.bend as Sel
import ./scoped-selection-spec.bend as ScopedSpec
import ./scoped-assembly.bend as Assembly
import ./scoped-assembly-spec.bend as AssemblySpec
import ../src/app/scopes.bend as RuntimeScopes
import ../src/http/stream_marker.bend as Marker
import ./stream-marker.bend as SM
import ../src/http/response.bend as Response
import ../src/app/finalize.bend as Final
import ../src/app/observability.bend as Obs
import ../src/mw/response_policy.bend as Policy

def Res() -> Data:
  Result<&2, &2, S.Errors(), S.Value>

def State() -> Data:
  Maybe<&2, Result<&2, &2, S.Errors(), S.Value>>

def L.schema_prepared_decode(src, schema, value):
  Prep.decode_from_check(src, schema, value)

def prefix_under(+slot: String, +es: List<&2, S.Error>) -> {S.prefix(S.PathKey{slot}, es) == Spec.under(slot, es) : List<&2, S.Error>}:
  match es:
    case Nil{}: {==}
    case S.Error{c, m, p} <> t:
      Equal.cong(List<&2, S.Error>, List<&2, S.Error>, z => S.Error{c, m, S.PathKey{slot} <> p} <> z, S.prefix(S.PathKey{slot}, t), Spec.under(slot, t), prefix_under(slot, t))

# The implementation's reading of a spec slot state.
def outcome_of(+slot: String, t: State()) -> V.Outcome:
  match t:
    case None{}: V.Passed{None{}}
    case Some{Done{x}}: V.Passed{Some{x}}
    case Some{Fail{es}}: V.Rejected{Spec.under(slot, es)}

def body_of(b: Spec.Body) -> V.Body:
  match b:
    case Spec.NoBody{}: V.BodyPassed{None{}}
    case Spec.NotJsonType{}: V.WrongMedia{}
    case Spec.NotJson{}: V.Malformed{}
    case Spec.Decoded{Done{x}}: V.BodyPassed{Some{x}}
    case Spec.Decoded{Fail{es}}: V.BodyRejected{Spec.under("body", es)}

def outcome_eq(+slot: String, +r: Res()) -> {V.outcome(slot, r) == outcome_of(slot, Some{r}) : V.Outcome}:
  match r:
    case Done{x}: {==}
    case Fail{es}: Equal.cong(List<&2, S.Error>, V.Outcome, z => V.Rejected{z}, S.prefix(S.PathKey{slot}, es), Spec.under(slot, es), prefix_under(slot, es))

def text_slot_eq(+slot: String, +m: Maybe<&2, S.Schema>, +mem: List<&2, J.Field>) -> {V.text_slot(slot, V.checked(m), J.JObject{mem}) == outcome_of(slot, Spec.text_state(m, mem)) : V.Outcome}:
  match m:
    case None{}: {==}
    case Some{s}:
      %Equal.sym(Res(), SP.decode_from(S.TextSource{}, SP.check(s), J.JObject{mem}), S.decode_from(S.TextSource{}, s, J.JObject{mem}), Prep.decode_from_check(S.TextSource{}, s, J.JObject{mem})) : {V.outcome(slot, _) == outcome_of(slot, Some{Spec.text(s, mem)}) : V.Outcome}
      outcome_eq(slot, S.decode_from(S.TextSource{}, s, J.JObject{mem}))

# Text objects.
def params_go_eq(+ps: Pattern.Params, +rev: List<&2, J.Field>) -> {V.params_go(ps, rev) == J.JObject{List.reverse.go(&2, J.Field, rev, Spec.params_members(ps))} : J.Json}:
  match ps:
    case Nil{}: {==}
    case Pattern.Param{k, v} <> t: params_go_eq(t, J.Field{k, J.JString{v}} <> rev)

def query_go_eq(+qs: List<&2, Query.Entry>, +rev: List<&2, J.Field>) -> {V.query_go(qs, rev) == J.JObject{List.reverse.go(&2, J.Field, rev, Spec.query_members(qs))} : J.Json}:
  match qs:
    case Nil{}: {==}
    case Query.Entry{k, v} <> t: query_go_eq(t, J.Field{k, J.JString{v}} <> rev)

def latin1_eq(+v: List<&2, U32>, +d: Maybe<&2, String>) -> {V.text_or_latin1(v, d) == Spec.latin1(v, d) : String}:
  match d:
    case Some{s}: {==}
    case None{}: {==}

def headers_go_eq(+hs: List<&2, Request.Header>, +rev: List<&2, J.Field>) -> {V.headers_go(hs, rev) == J.JObject{List.reverse.go(&2, J.Field, rev, Spec.header_members(hs))} : J.Json}:
  match hs:
    case Nil{}: {==}
    case Request.Header{k, v} <> t:
      %latin1_eq(v, Utf8.decode(v)) : {V.headers_go(t, J.Field{Bytes.fold(k), J.JString{V.header_text(v)}} <> rev) == J.JObject{List.reverse.go(&2, J.Field, rev, J.Field{Bytes.fold(k), J.JString{_}} <> Spec.header_members(t))} : J.Json}
      headers_go_eq(t, J.Field{Bytes.fold(k), J.JString{V.header_text(v)}} <> rev)

# Media types.
def media_eq(+values: List<&2, List<&2, U32>>) -> {V.json_media(values) == Spec.first_json(values) : Bool}:
  match values:
    case Nil{}: {==}
    case v <> t:
      Equal.cong(String, Bool, z => Spec.json_media(z), Media.essence(Bytes.ascii(v)), MediaSpec.essence(Bytes.ascii(v)), MediaProof.essence(Bytes.ascii(v)))

def json_body_eq(+hs: List<&2, Request.Header>) -> {V.json_body(hs) == Spec.json_type(hs) : Bool}:
  media_eq(Request.lookup(hs, "content-type"))

# Bodies.
def decoded_eq(+r: Res()) -> {V.body_decoded(r) == body_of(Spec.Decoded{r}) : V.Body}:
  match r:
    case Done{x}: {==}
    case Fail{es}: Equal.cong(List<&2, S.Error>, V.Body, z => V.BodyRejected{z}, S.prefix(S.PathKey{"body"}, es), Spec.under("body", es), prefix_under("body", es))

def parsed_eq(+s: S.Schema, +pr: Result<&2, &2, J.Error, J.Json>) -> {V.body_parsed(SP.check(s), pr) == body_of(Spec.parsed(s, pr)) : V.Body}:
  match pr:
    case Fail{e}: {==}
    case Done{v}:
      %Equal.sym(Res(), SP.decode_from(S.JsonBody{}, SP.check(s), v), S.decode_from(S.JsonBody{}, s, v), Prep.decode_from_check(S.JsonBody{}, s, v)) : {V.body_decoded(_) == body_of(Spec.Decoded{S.decode_from(S.JsonBody{}, s, v)}) : V.Body}
      decoded_eq(S.decode_from(S.JsonBody{}, s, v))

def typed_eq(+s: S.Schema, +bytes: List<&2, U32>, c: Bool) -> {V.body_typed(SP.check(s), bytes, c) == body_of(Spec.typed(s, bytes, c)) : V.Body}:
  match c:
    case False{}: {==}
    case True{}: parsed_eq(s, J.parse(bytes))

def body_eq(+m: Maybe<&2, S.Schema>, +hs: List<&2, Request.Header>, +bytes: List<&2, U32>) -> {V.body_slot(V.checked(m), hs, bytes) == body_of(Spec.body(m, hs, bytes)) : V.Body}:
  match m:
    case None{}: {==}
    case Some{s}:
      %Equal.sym(Bool, V.json_body(hs), Spec.json_type(hs), json_body_eq(hs)) : {V.body_typed(SP.check(s), bytes, _) == body_of(Spec.typed(s, bytes, Spec.json_type(hs))) : V.Body}
      typed_eq(s, bytes, Spec.json_type(hs))

def combine_eq(+p: State(), +q: State(), +h: State(), +b: Spec.Body) -> {V.verdict(outcome_of("params", p), outcome_of("query", q), outcome_of("headers", h), body_of(b)) == Spec.combine(p, q, h, b) : V.Verdict}:
  match p q h b:
    case None{} None{} None{} Spec.NoBody{}: {==}
    case None{} None{} None{} Spec.NotJsonType{}: {==}
    case None{} None{} None{} Spec.NotJson{}: {==}
    case None{} None{} None{} Spec.Decoded{Done{x4}}: {==}
    case None{} None{} None{} Spec.Decoded{Fail{e4}}: {==}
    case None{} None{} Some{Done{x3}} Spec.NoBody{}: {==}
    case None{} None{} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case None{} None{} Some{Done{x3}} Spec.NotJson{}: {==}
    case None{} None{} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case None{} None{} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} None{} Some{Fail{e3}} Spec.NoBody{}: {==}
    case None{} None{} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case None{} None{} Some{Fail{e3}} Spec.NotJson{}: {==}
    case None{} None{} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case None{} None{} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Done{x2}} None{} Spec.NoBody{}: {==}
    case None{} Some{Done{x2}} None{} Spec.NotJsonType{}: {==}
    case None{} Some{Done{x2}} None{} Spec.NotJson{}: {==}
    case None{} Some{Done{x2}} None{} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Done{x2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Fail{e2}} None{} Spec.NoBody{}: {==}
    case None{} Some{Fail{e2}} None{} Spec.NotJsonType{}: {==}
    case None{} Some{Fail{e2}} None{} Spec.NotJson{}: {==}
    case None{} Some{Fail{e2}} None{} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Fail{e2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} None{} None{} Spec.NoBody{}: {==}
    case Some{Done{x1}} None{} None{} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} None{} None{} Spec.NotJson{}: {==}
    case Some{Done{x1}} None{} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} None{} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} None{} None{} Spec.NoBody{}: {==}
    case Some{Fail{e1}} None{} None{} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} None{} None{} Spec.NotJson{}: {==}
    case Some{Fail{e1}} None{} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} None{} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}

def errors_eq(+p: State(), +q: State(), +h: State(), +b: Spec.Body) -> {V.rejection_errors(Spec.combine(p, q, h, b)) == Spec.reported(p, q, h, b) : List<&2, S.Error>}:
  match p q h b:
    case None{} None{} None{} Spec.NoBody{}: {==}
    case None{} None{} None{} Spec.NotJsonType{}: {==}
    case None{} None{} None{} Spec.NotJson{}: {==}
    case None{} None{} None{} Spec.Decoded{Done{x4}}: {==}
    case None{} None{} None{} Spec.Decoded{Fail{e4}}: {==}
    case None{} None{} Some{Done{x3}} Spec.NoBody{}: {==}
    case None{} None{} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case None{} None{} Some{Done{x3}} Spec.NotJson{}: {==}
    case None{} None{} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case None{} None{} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} None{} Some{Fail{e3}} Spec.NoBody{}: {==}
    case None{} None{} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case None{} None{} Some{Fail{e3}} Spec.NotJson{}: {==}
    case None{} None{} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case None{} None{} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Done{x2}} None{} Spec.NoBody{}: {==}
    case None{} Some{Done{x2}} None{} Spec.NotJsonType{}: {==}
    case None{} Some{Done{x2}} None{} Spec.NotJson{}: {==}
    case None{} Some{Done{x2}} None{} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Done{x2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Fail{e2}} None{} Spec.NoBody{}: {==}
    case None{} Some{Fail{e2}} None{} Spec.NotJsonType{}: {==}
    case None{} Some{Fail{e2}} None{} Spec.NotJson{}: {==}
    case None{} Some{Fail{e2}} None{} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Fail{e2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case None{} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} None{} None{} Spec.NoBody{}: {==}
    case Some{Done{x1}} None{} None{} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} None{} None{} Spec.NotJson{}: {==}
    case Some{Done{x1}} None{} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} None{} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} None{} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} None{} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Done{x1}} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} None{} None{} Spec.NoBody{}: {==}
    case Some{Fail{e1}} None{} None{} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} None{} None{} Spec.NotJson{}: {==}
    case Some{Fail{e1}} None{} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} None{} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} None{} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} None{} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Done{x2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} None{} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Done{x3}} Spec.Decoded{Fail{e4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NoBody{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJsonType{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.NotJson{}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Done{x4}}: {==}
    case Some{Fail{e1}} Some{Fail{e2}} Some{Fail{e3}} Spec.Decoded{Fail{e4}}: {==}

def admits_decide(+p: State(), +q: State(), +h: State(), +b: Spec.Body, yes: Bool) -> {V.admits(Spec.decide(p, q, h, b, yes)) == yes : Bool}:
  match yes:
    case True{}: {==}
    case False{}: {==}

def L.route_validation_matches_spec(params, query, headers, body, response, input):
  match input:
    case V.Input{ps, qs, hs, bytes}:
      e1 = Equal.trans(V.Outcome, V.text_slot("params", V.checked(params), V.params_json(ps)), V.text_slot("params", V.checked(params), J.JObject{Spec.params_members(ps)}), outcome_of("params", Spec.text_state(params, Spec.params_members(ps))), Equal.cong(J.Json, V.Outcome, z => V.text_slot("params", V.checked(params), z), V.params_json(ps), J.JObject{Spec.params_members(ps)}, params_go_eq(ps, [])), text_slot_eq("params", params, Spec.params_members(ps)))
      e2 = Equal.trans(V.Outcome, V.text_slot("query", V.checked(query), V.query_json(qs)), V.text_slot("query", V.checked(query), J.JObject{Spec.query_members(qs)}), outcome_of("query", Spec.text_state(query, Spec.query_members(qs))), Equal.cong(J.Json, V.Outcome, z => V.text_slot("query", V.checked(query), z), V.query_json(qs), J.JObject{Spec.query_members(qs)}, query_go_eq(qs, [])), text_slot_eq("query", query, Spec.query_members(qs)))
      e3 = Equal.trans(V.Outcome, V.text_slot("headers", V.checked(headers), V.headers_json(hs)), V.text_slot("headers", V.checked(headers), J.JObject{Spec.header_members(hs)}), outcome_of("headers", Spec.text_state(headers, Spec.header_members(hs))), Equal.cong(J.Json, V.Outcome, z => V.text_slot("headers", V.checked(headers), z), V.headers_json(hs), J.JObject{Spec.header_members(hs)}, headers_go_eq(hs, [])), text_slot_eq("headers", headers, Spec.header_members(hs)))
      %Equal.sym(V.Outcome, V.text_slot("params", V.checked(params), V.params_json(ps)), outcome_of("params", Spec.text_state(params, Spec.params_members(ps))), e1) : {V.verdict(_, V.text_slot("query", V.checked(query), V.query_json(qs)), V.text_slot("headers", V.checked(headers), V.headers_json(hs)), V.body_slot(V.checked(body), hs, bytes)) == Spec.verdict(params, query, headers, body, V.Input{ps, qs, hs, bytes}) : V.Verdict}
      %Equal.sym(V.Outcome, V.text_slot("query", V.checked(query), V.query_json(qs)), outcome_of("query", Spec.text_state(query, Spec.query_members(qs))), e2) : {V.verdict(outcome_of("params", Spec.text_state(params, Spec.params_members(ps))), _, V.text_slot("headers", V.checked(headers), V.headers_json(hs)), V.body_slot(V.checked(body), hs, bytes)) == Spec.verdict(params, query, headers, body, V.Input{ps, qs, hs, bytes}) : V.Verdict}
      %Equal.sym(V.Outcome, V.text_slot("headers", V.checked(headers), V.headers_json(hs)), outcome_of("headers", Spec.text_state(headers, Spec.header_members(hs))), e3) : {V.verdict(outcome_of("params", Spec.text_state(params, Spec.params_members(ps))), outcome_of("query", Spec.text_state(query, Spec.query_members(qs))), _, V.body_slot(V.checked(body), hs, bytes)) == Spec.verdict(params, query, headers, body, V.Input{ps, qs, hs, bytes}) : V.Verdict}
      %Equal.sym(V.Body, V.body_slot(V.checked(body), hs, bytes), body_of(Spec.body(body, hs, bytes)), body_eq(body, hs, bytes)) : {V.verdict(outcome_of("params", Spec.text_state(params, Spec.params_members(ps))), outcome_of("query", Spec.text_state(query, Spec.query_members(qs))), outcome_of("headers", Spec.text_state(headers, Spec.header_members(hs))), _) == Spec.verdict(params, query, headers, body, V.Input{ps, qs, hs, bytes}) : V.Verdict}
      combine_eq(Spec.text_state(params, Spec.params_members(ps)), Spec.text_state(query, Spec.query_members(qs)), Spec.text_state(headers, Spec.header_members(hs)), Spec.body(body, hs, bytes))

def L.route_admits_iff_slots_decode(params, query, headers, body, response, input):
  match input:
    case V.Input{ps, qs, hs, bytes}:
      %Equal.sym(V.Verdict, V.request(V.prepared(params, query, headers, body, response), V.Input{ps, qs, hs, bytes}), Spec.verdict(params, query, headers, body, V.Input{ps, qs, hs, bytes}), L.route_validation_matches_spec(params, query, headers, body, response, V.Input{ps, qs, hs, bytes})) : {V.admits(_) == Spec.admitted(params, query, headers, body, V.Input{ps, qs, hs, bytes}) : Bool}
      admits_decide(Spec.text_state(params, Spec.params_members(ps)), Spec.text_state(query, Spec.query_members(qs)), Spec.text_state(headers, Spec.header_members(hs)), Spec.body(body, hs, bytes), Spec.all_decode(Spec.text_state(params, Spec.params_members(ps)), Spec.text_state(query, Spec.query_members(qs)), Spec.text_state(headers, Spec.header_members(hs)), Spec.body(body, hs, bytes)))

def L.route_rejection_lists_slot_errors(params, query, headers, body, response, input):
  match input:
    case V.Input{ps, qs, hs, bytes}:
      %Equal.sym(V.Verdict, V.request(V.prepared(params, query, headers, body, response), V.Input{ps, qs, hs, bytes}), Spec.verdict(params, query, headers, body, V.Input{ps, qs, hs, bytes}), L.route_validation_matches_spec(params, query, headers, body, response, V.Input{ps, qs, hs, bytes})) : {V.rejection_errors(_) == Spec.errors(params, query, headers, body, V.Input{ps, qs, hs, bytes}) : List<&2, S.Error>}
      errors_eq(Spec.text_state(params, Spec.params_members(ps)), Spec.text_state(query, Spec.query_members(qs)), Spec.text_state(headers, Spec.header_members(hs)), Spec.body(body, hs, bytes))

# Responses.
def resp_result_eq(+r: Res()) -> {V.response_decoded(r) == Spec.response_result(r) : V.Check}:
  match r:
    case Done{x}: {==}
    case Fail{es}: Equal.cong(List<&2, S.Error>, V.Check, z => V.Violates{z}, S.prefix(S.PathKey{"body"}, es), Spec.under("body", es), prefix_under("body", es))

def resp_parsed_eq(+s: S.Schema, +pr: Result<&2, &2, J.Error, J.Json>) -> {V.response_errors(SP.check(s), pr) == Spec.response_body(s, pr) : V.Check}:
  match pr:
    case Fail{e}: {==}
    case Done{v}:
      %Equal.sym(Res(), SP.decode_from(S.JsonBody{}, SP.check(s), v), S.decode_from(S.JsonBody{}, s, v), Prep.decode_from_check(S.JsonBody{}, s, v)) : {V.response_decoded(_) == Spec.response_result(S.decode_from(S.JsonBody{}, s, v)) : V.Check}
      resp_result_eq(S.decode_from(S.JsonBody{}, s, v))

def resp_typed_eq(+s: S.Schema, +bytes: List<&2, U32>, c: Bool) -> {V.response_typed(SP.check(s), bytes, c) == Spec.response_typed(s, bytes, c) : V.Check}:
  match c:
    case False{}: {==}
    case True{}: resp_parsed_eq(s, J.parse(bytes))

def resp_when_eq(+s: S.Schema, +code: U32, +hs: List<&2, Request.Header>, +bytes: List<&2, U32>, c: Bool) -> {V.response_checked(SP.check(s), code, hs, bytes, c) == Spec.response_when(s, hs, bytes, c) : V.Check}:
  match c:
    case False{}: {==}
    case True{}:
      %Equal.sym(Bool, V.json_body(hs), Spec.json_type(hs), json_body_eq(hs)) : {V.response_typed(SP.check(s), bytes, _) == Spec.response_typed(s, bytes, Spec.json_type(hs)) : V.Check}
      resp_typed_eq(s, bytes, Spec.json_type(hs))

def L.route_response_matches_spec(response, code, headers, bytes):
  match response:
    case None{}: {==}
    case Some{s}: resp_when_eq(s, code, headers, bytes, Spec.checked_status(code))

# The request budget.
def take_within(xs: List<&2, S.Error>, n: Nat) -> {Nat.is_le(List.length(&2, S.Error, List.take(&2, S.Error, xs, n)), n) == True{} : Bool}:
  match xs n:
    case Nil{} 0n: {==}
    case Nil{} 1n+k: {==}
    case h <> t 0n: {==}
    case h <> t 1n+k: take_within(t, k)

def L.route_rejection_within_budget(params, query, headers, body, response, input):
  match input:
    case V.Input{ps, qs, hs, bytes}:
      %Equal.sym(List<&2, S.Error>, V.rejection_errors(V.request(V.prepared(params, query, headers, body, response), V.Input{ps, qs, hs, bytes})), Spec.errors(params, query, headers, body, V.Input{ps, qs, hs, bytes}), L.route_rejection_lists_slot_errors(params, query, headers, body, response, V.Input{ps, qs, hs, bytes})) : {Nat.is_le(List.length(&2, S.Error, _), 100n) == True{} : Bool}
      take_within(Spec.all_errors(Spec.text_state(params, Spec.params_members(ps)), Spec.text_state(query, Spec.query_members(qs)), Spec.text_state(headers, Spec.header_members(hs)), Spec.body(body, hs, bytes)), 100n)

# Plain admission: every combination of declared slots.
def L.plain_admission_rejects_declared(schemas, input):
  match schemas:
    case V.Schemas{None{}, None{}, None{}, None{}, None{}}: {==}
    case V.Schemas{None{}, None{}, None{}, None{}, Some{c4}}: {==}
    case V.Schemas{None{}, None{}, None{}, Some{c3}, None{}}: {==}
    case V.Schemas{None{}, None{}, None{}, Some{c3}, Some{c4}}: {==}
    case V.Schemas{None{}, None{}, Some{c2}, None{}, None{}}: {==}
    case V.Schemas{None{}, None{}, Some{c2}, None{}, Some{c4}}: {==}
    case V.Schemas{None{}, None{}, Some{c2}, Some{c3}, None{}}: {==}
    case V.Schemas{None{}, None{}, Some{c2}, Some{c3}, Some{c4}}: {==}
    case V.Schemas{None{}, Some{c1}, None{}, None{}, None{}}: {==}
    case V.Schemas{None{}, Some{c1}, None{}, None{}, Some{c4}}: {==}
    case V.Schemas{None{}, Some{c1}, None{}, Some{c3}, None{}}: {==}
    case V.Schemas{None{}, Some{c1}, None{}, Some{c3}, Some{c4}}: {==}
    case V.Schemas{None{}, Some{c1}, Some{c2}, None{}, None{}}: {==}
    case V.Schemas{None{}, Some{c1}, Some{c2}, None{}, Some{c4}}: {==}
    case V.Schemas{None{}, Some{c1}, Some{c2}, Some{c3}, None{}}: {==}
    case V.Schemas{None{}, Some{c1}, Some{c2}, Some{c3}, Some{c4}}: {==}
    case V.Schemas{Some{c0}, None{}, None{}, None{}, None{}}: {==}
    case V.Schemas{Some{c0}, None{}, None{}, None{}, Some{c4}}: {==}
    case V.Schemas{Some{c0}, None{}, None{}, Some{c3}, None{}}: {==}
    case V.Schemas{Some{c0}, None{}, None{}, Some{c3}, Some{c4}}: {==}
    case V.Schemas{Some{c0}, None{}, Some{c2}, None{}, None{}}: {==}
    case V.Schemas{Some{c0}, None{}, Some{c2}, None{}, Some{c4}}: {==}
    case V.Schemas{Some{c0}, None{}, Some{c2}, Some{c3}, None{}}: {==}
    case V.Schemas{Some{c0}, None{}, Some{c2}, Some{c3}, Some{c4}}: {==}
    case V.Schemas{Some{c0}, Some{c1}, None{}, None{}, None{}}: {==}
    case V.Schemas{Some{c0}, Some{c1}, None{}, None{}, Some{c4}}: {==}
    case V.Schemas{Some{c0}, Some{c1}, None{}, Some{c3}, None{}}: {==}
    case V.Schemas{Some{c0}, Some{c1}, None{}, Some{c3}, Some{c4}}: {==}
    case V.Schemas{Some{c0}, Some{c1}, Some{c2}, None{}, None{}}: {==}
    case V.Schemas{Some{c0}, Some{c1}, Some{c2}, None{}, Some{c4}}: {==}
    case V.Schemas{Some{c0}, Some{c1}, Some{c2}, Some{c3}, None{}}: {==}
    case V.Schemas{Some{c0}, Some{c1}, Some{c2}, Some{c3}, Some{c4}}: {==}

# Handler entry.
def L.handler_entry_valid(Vars, ctx, values): {==}

def L.handler_entry_invalid(Vars, ctx, code, errors): {==}

def enters_decide(-Vars: Data, +ctx: C.Ctx<Vars>, +p: State(), +q: State(), +h: State(), +b: Spec.Body, yes: Bool) -> {C.enters(Vars, C.entry(Vars, ctx, Spec.decide(p, q, h, b, yes))) == yes : Bool}:
  match yes:
    case True{}: {==}
    case False{}: {==}

def L.handler_enters_iff_admitted(Vars, ctx, params, query, headers, body, response, input):
  match input:
    case V.Input{ps, qs, hs, bytes}:
      %Equal.sym(V.Verdict, V.request(V.prepared(params, query, headers, body, response), V.Input{ps, qs, hs, bytes}), Spec.verdict(params, query, headers, body, V.Input{ps, qs, hs, bytes}), L.route_validation_matches_spec(params, query, headers, body, response, V.Input{ps, qs, hs, bytes})) : {C.enters(Vars, C.entry(Vars, ctx, _)) == Spec.admitted(params, query, headers, body, V.Input{ps, qs, hs, bytes}) : Bool}
      enters_decide(Vars, ctx, Spec.text_state(params, Spec.params_members(ps)), Spec.text_state(query, Spec.query_members(qs)), Spec.text_state(headers, Spec.header_members(hs)), Spec.body(body, hs, bytes), Spec.all_decode(Spec.text_state(params, Spec.params_members(ps)), Spec.text_state(query, Spec.query_members(qs)), Spec.text_state(headers, Spec.header_members(hs)), Spec.body(body, hs, bytes)))

# The response policy.
def act_eq(delivery: V.Delivery, c: V.Check, mode: Config.Mode) -> {V.policy(mode, delivery, c) == Spec.act(mode, delivery, c) : V.Action}:
  match delivery c mode:
    case V.Streamed{} _ _: {==}
    case V.Buffered{} V.Unchecked{} _: {==}
    case V.Buffered{} V.Conforms{} _: {==}
    case V.Buffered{} V.Violates{es} Config.Development{}: {==}
    case V.Buffered{} V.Violates{es} Config.Production{}: {==}

def L.route_response_policy(mode, delivery, response, code, headers, bytes):
  %Equal.sym(V.Check, V.response(V.checked(response), code, headers, bytes), Spec.response(response, code, headers, bytes), L.route_response_matches_spec(response, code, headers, bytes)) : {V.policy(mode, delivery, _) == Spec.action(mode, delivery, response, code, headers, bytes) : V.Action}
  act_eq(delivery, Spec.response(response, code, headers, bytes), mode)

# Innermost wins (proof/validate-scopes.bend).
def L.route_schemas_innermost(Tag, entries, routes, compiled, layers, count, route, which, built):
  Scopes.innermost(Tag, entries, routes, compiled, layers, count, route, which, built)

def L.route_schemas_guard_innermost(Tag, options, inside, outside, routes, compiled, layers, count, route, which, built):
  Equal.trans(Maybe<&2, SP.Checked>, Spec.slot(which, Table.route_schemas(Tag, layers, route)), Spec.effective(Tag, which, List.append(&2, Table.Entry<Tag>, RuntimeScopes.guard(Tag, options, inside), outside), route), Spec.effective(Tag, which, List.append(&2, Table.Entry<Tag>, AssemblySpec.guard(Tag, options, inside), outside), route),
    Scopes.innermost(Tag, List.append(&2, Table.Entry<Tag>, RuntimeScopes.guard(Tag, options, inside), outside), routes, compiled, layers, count, route, which, built),
    Equal.cong(List<&2, Table.Entry<Tag>>, Maybe<&2, SP.Checked>, xs => Spec.effective(Tag, which, List.append(&2, Table.Entry<Tag>, xs, outside), route), RuntimeScopes.guard(Tag, options, inside), AssemblySpec.guard(Tag, options, inside), Assembly.guard(Tag, options, inside)))

def L.route_schemas_group_innermost(Tag, prefix, hooks, inside, outside, routes, compiled, layers, count, route, which, built):
  Equal.trans(Maybe<&2, SP.Checked>, Spec.slot(which, Table.route_schemas(Tag, layers, route)), Spec.effective(Tag, which, List.append(&2, Table.Entry<Tag>, RuntimeScopes.group(Tag, prefix, hooks, inside), outside), route), Spec.effective(Tag, which, List.append(&2, Table.Entry<Tag>, AssemblySpec.group(Tag, prefix, hooks, inside), outside), route),
    Scopes.innermost(Tag, List.append(&2, Table.Entry<Tag>, RuntimeScopes.group(Tag, prefix, hooks, inside), outside), routes, compiled, layers, count, route, which, built),
    Equal.cong(List<&2, Table.Entry<Tag>>, Maybe<&2, SP.Checked>, xs => Spec.effective(Tag, which, List.append(&2, Table.Entry<Tag>, xs, outside), route), RuntimeScopes.group(Tag, prefix, hooks, inside), AssemblySpec.group(Tag, prefix, hooks, inside), Assembly.group(Tag, prefix, hooks, inside)))

# One manifest entry per route.
def effective_length(-Tag: Data, +layers: List<&2, Table.Middleware<Tag>>, k: Nat) -> {List.length(&2, RS.RouteSchemas, TableSchemas.effective_go(Tag, layers, k)) == k : Nat}:
  match k:
    case 0n: {==}
    case 1n+(+j): Equal.cong(Nat, Nat, z => 1n+z, List.length(&2, RS.RouteSchemas, TableSchemas.effective_go(Tag, layers, j)), j, effective_length(Tag, layers, j))

def L.table_schemas_one_per_route(Tag, entries, routes, compiled, layers, count, built):
  Equal.trans(Nat, List.length(&2, RS.RouteSchemas, TableSchemas.effective_go(Tag, layers, count)), count, ScopedSpec.route_count(Tag, entries), effective_length(Tag, layers, count), Sel.successful_count(Tag, entries, routes, compiled, layers, count, built))

# Delivery: the transport's marker scan is the spec's, so validation and
# transport classify alike.
def marked_carries(hs: List<&2, Request.Header>, +id: String) -> {Marker.marked(hs, id) == Spec.carries(hs, id) : Bool}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> t:
      # BND-96: the transport tests the name with Marker.named, equal to the
      # spec's lowered comparison (law hot_marker_named).
      Equal.trans(Bool, (Marker.named(n) && String.eq(Bytes.ascii(v), id)) || Marker.marked(t, id), (Marker.named_spec(n) && String.eq(Bytes.ascii(v), id)) || Marker.marked(t, id), (String.eq(Bytes.fold(n), "x-bendo-stream-internal") && String.eq(Bytes.ascii(v), id)) || Spec.carries(t, id),
        Equal.cong(Bool, Bool, z => (z && String.eq(Bytes.ascii(v), id)) || Marker.marked(t, id), Marker.named(n), Marker.named_spec(n), SM.named_equiv(n)),
        Equal.cong(Bool, Bool, z => (String.eq(Bytes.fold(n), "x-bendo-stream-internal") && String.eq(Bytes.ascii(v), id)) || z, Marker.marked(t, id), Spec.carries(t, id), marked_carries(t, id)))

def L.transport_eligibility_matches_spec(claim, code, headers):
  match claim:
    case Marker.Unclaimed{}: {==}
    case Marker.BodyClaim{id}: marked_carries(headers, id)
    case Marker.UpgradeClaim{id}: Equal.cong(Bool, Bool, z => z && U32.is_eq(code, 101), Marker.marked(headers, id), Spec.carries(headers, id), marked_carries(headers, id))

def delivered_when(b: Bool) -> {V.delivered(b) == Spec.delivery_when(b) : V.Delivery}:
  match b:
    case True{}: {==}
    case False{}: {==}

def L.route_response_delivery_matches_transport(claim, code, headers):
  Equal.trans(V.Delivery, V.delivered(Marker.eligible(claim, code, headers)), V.delivered(Spec.handed_over(claim, code, headers)), Spec.delivery_when(Spec.handed_over(claim, code, headers)),
    Equal.cong(Bool, V.Delivery, b => V.delivered(b), Marker.eligible(claim, code, headers), Spec.handed_over(claim, code, headers), L.transport_eligibility_matches_spec(claim, code, headers)),
    delivered_when(Spec.handed_over(claim, code, headers)))

def L.unclaimed_response_is_buffered(code, headers): {==}

def L.route_response_claimed_policy(mode, claim, response, code, headers, bytes):
  Equal.trans(V.Action, V.policy(mode, V.delivery(claim, code, headers), V.response(V.checked(response), code, headers, bytes)), V.policy(mode, Spec.delivery(claim, code, headers), V.response(V.checked(response), code, headers, bytes)), Spec.action(mode, Spec.delivery(claim, code, headers), response, code, headers, bytes),
    Equal.cong(V.Delivery, V.Action, d => V.policy(mode, d, V.response(V.checked(response), code, headers, bytes)), V.delivery(claim, code, headers), Spec.delivery(claim, code, headers), L.route_response_delivery_matches_transport(claim, code, headers)),
    L.route_response_policy(mode, Spec.delivery(claim, code, headers), response, code, headers, bytes))

# The manifest list in source order. `down` counts identities from k - 1 to
# 0, as TableSchemas.effective_go does, over the spec's bundles.
def down(-Tag: Data, +xs: List<&2, Table.Entry<Tag>>, k: Nat) -> List<&2, RS.RouteSchemas>:
  match k:
    case 0n: []
    case 1n+(+j): Spec.bundle(Tag, xs, j) <> down(Tag, xs, j)

def raw_eq(m: Maybe<&2, SP.Checked>) -> {TableSchemas.raw(m) == Spec.raw(m) : Maybe<&2, S.Schema>}:
  match m:
    case None{}: {==}
    case Some{SP.Checked{s, ok, t}}: {==}

def bundle_slots(+set: V.Schemas) -> {TableSchemas.route_schemas(set) == RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, set)), Spec.raw(Spec.slot(Spec.InQuery{}, set)), Spec.raw(Spec.slot(Spec.InHeaders{}, set)), Spec.raw(Spec.slot(Spec.InBody{}, set)), Spec.raw(Spec.slot(Spec.InResponse{}, set))} : RS.RouteSchemas}:
  match set:
    case V.Schemas{+p, +q, +h, +b, +r}:
      %raw_eq(p) : {RS.RouteSchemas{TableSchemas.raw(p), TableSchemas.raw(q), TableSchemas.raw(h), TableSchemas.raw(b), TableSchemas.raw(r)} == RS.RouteSchemas{_, Spec.raw(q), Spec.raw(h), Spec.raw(b), Spec.raw(r)} : RS.RouteSchemas}
      %raw_eq(q) : {RS.RouteSchemas{TableSchemas.raw(p), TableSchemas.raw(q), TableSchemas.raw(h), TableSchemas.raw(b), TableSchemas.raw(r)} == RS.RouteSchemas{TableSchemas.raw(p), _, Spec.raw(h), Spec.raw(b), Spec.raw(r)} : RS.RouteSchemas}
      %raw_eq(h) : {RS.RouteSchemas{TableSchemas.raw(p), TableSchemas.raw(q), TableSchemas.raw(h), TableSchemas.raw(b), TableSchemas.raw(r)} == RS.RouteSchemas{TableSchemas.raw(p), TableSchemas.raw(q), _, Spec.raw(b), Spec.raw(r)} : RS.RouteSchemas}
      %raw_eq(b) : {RS.RouteSchemas{TableSchemas.raw(p), TableSchemas.raw(q), TableSchemas.raw(h), TableSchemas.raw(b), TableSchemas.raw(r)} == RS.RouteSchemas{TableSchemas.raw(p), TableSchemas.raw(q), TableSchemas.raw(h), _, Spec.raw(r)} : RS.RouteSchemas}
      %raw_eq(r) : {RS.RouteSchemas{TableSchemas.raw(p), TableSchemas.raw(q), TableSchemas.raw(h), TableSchemas.raw(b), TableSchemas.raw(r)} == RS.RouteSchemas{TableSchemas.raw(p), TableSchemas.raw(q), TableSchemas.raw(h), TableSchemas.raw(b), _} : RS.RouteSchemas}
      {==}

# Each bundle the table lists is the spec's, slot by slot (route_schemas_innermost).
def slots_effective(-Tag: Data, +entries: List<&2, Table.Entry<Tag>>, +routes: List<&2, Methods.Registration(Tag)>, +compiled: Methods.Index<Tag>, +layers: List<&2, Table.Middleware<Tag>>, +count: Nat, +j: Nat, +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}) -> {RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InHeaders{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InBody{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InResponse{}, Table.route_schemas(Tag, layers, Some{j})))} == Spec.bundle(Tag, entries, j) : RS.RouteSchemas}:
  %Scopes.innermost(Tag, entries, routes, compiled, layers, count, Some{j}, Spec.InParams{}, built) : {RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InHeaders{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InBody{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InResponse{}, Table.route_schemas(Tag, layers, Some{j})))} == RS.RouteSchemas{Spec.raw(_), Spec.raw(Spec.effective(Tag, Spec.InQuery{}, entries, Some{j})), Spec.raw(Spec.effective(Tag, Spec.InHeaders{}, entries, Some{j})), Spec.raw(Spec.effective(Tag, Spec.InBody{}, entries, Some{j})), Spec.raw(Spec.effective(Tag, Spec.InResponse{}, entries, Some{j}))} : RS.RouteSchemas}
  %Scopes.innermost(Tag, entries, routes, compiled, layers, count, Some{j}, Spec.InQuery{}, built) : {RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InHeaders{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InBody{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InResponse{}, Table.route_schemas(Tag, layers, Some{j})))} == RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(_), Spec.raw(Spec.effective(Tag, Spec.InHeaders{}, entries, Some{j})), Spec.raw(Spec.effective(Tag, Spec.InBody{}, entries, Some{j})), Spec.raw(Spec.effective(Tag, Spec.InResponse{}, entries, Some{j}))} : RS.RouteSchemas}
  %Scopes.innermost(Tag, entries, routes, compiled, layers, count, Some{j}, Spec.InHeaders{}, built) : {RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InHeaders{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InBody{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InResponse{}, Table.route_schemas(Tag, layers, Some{j})))} == RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(_), Spec.raw(Spec.effective(Tag, Spec.InBody{}, entries, Some{j})), Spec.raw(Spec.effective(Tag, Spec.InResponse{}, entries, Some{j}))} : RS.RouteSchemas}
  %Scopes.innermost(Tag, entries, routes, compiled, layers, count, Some{j}, Spec.InBody{}, built) : {RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InHeaders{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InBody{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InResponse{}, Table.route_schemas(Tag, layers, Some{j})))} == RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InHeaders{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(_), Spec.raw(Spec.effective(Tag, Spec.InResponse{}, entries, Some{j}))} : RS.RouteSchemas}
  %Scopes.innermost(Tag, entries, routes, compiled, layers, count, Some{j}, Spec.InResponse{}, built) : {RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InHeaders{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InBody{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InResponse{}, Table.route_schemas(Tag, layers, Some{j})))} == RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InHeaders{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InBody{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(_)} : RS.RouteSchemas}
  {==}

def bundle_eq(-Tag: Data, +entries: List<&2, Table.Entry<Tag>>, +routes: List<&2, Methods.Registration(Tag)>, +compiled: Methods.Index<Tag>, +layers: List<&2, Table.Middleware<Tag>>, +count: Nat, +j: Nat, +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}) -> {TableSchemas.route_schemas(Table.route_schemas(Tag, layers, Some{j})) == Spec.bundle(Tag, entries, j) : RS.RouteSchemas}:
  Equal.trans(RS.RouteSchemas, TableSchemas.route_schemas(Table.route_schemas(Tag, layers, Some{j})), RS.RouteSchemas{Spec.raw(Spec.slot(Spec.InParams{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InQuery{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InHeaders{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InBody{}, Table.route_schemas(Tag, layers, Some{j}))), Spec.raw(Spec.slot(Spec.InResponse{}, Table.route_schemas(Tag, layers, Some{j})))}, Spec.bundle(Tag, entries, j), bundle_slots(Table.route_schemas(Tag, layers, Some{j})), slots_effective(Tag, entries, routes, compiled, layers, count, j, built))

def go_down(-Tag: Data, +entries: List<&2, Table.Entry<Tag>>, +routes: List<&2, Methods.Registration(Tag)>, +compiled: Methods.Index<Tag>, +layers: List<&2, Table.Middleware<Tag>>, +count: Nat, k: Nat, +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}) -> {TableSchemas.effective_go(Tag, layers, k) == down(Tag, entries, k) : List<&2, RS.RouteSchemas>}:
  match k:
    case 0n: {==}
    case 1n+(+j):
      %go_down(Tag, entries, routes, compiled, layers, count, j, built) : {TableSchemas.route_schemas(Table.route_schemas(Tag, layers, Some{j})) <> TableSchemas.effective_go(Tag, layers, j) == Spec.bundle(Tag, entries, j) <> _ : List<&2, RS.RouteSchemas>}
      %bundle_eq(Tag, entries, routes, compiled, layers, count, j, built) : {TableSchemas.route_schemas(Table.route_schemas(Tag, layers, Some{j})) <> TableSchemas.effective_go(Tag, layers, j) == _ <> TableSchemas.effective_go(Tag, layers, j) : List<&2, RS.RouteSchemas>}
      {==}

def down_source(-Tag: Data, +all: List<&2, Table.Entry<Tag>>, xs: List<&2, Table.Entry<Tag>>) -> {down(Tag, all, ScopedSpec.route_count(Tag, xs)) == Spec.in_source_order(Tag, all, xs) : List<&2, RS.RouteSchemas>}:
  match xs:
    case Nil{}: {==}
    case Table.Route{r} <> +tail: Equal.cong(List<&2, RS.RouteSchemas>, List<&2, RS.RouteSchemas>, z => Spec.bundle(Tag, all, ScopedSpec.route_count(Tag, tail)) <> z, down(Tag, all, ScopedSpec.route_count(Tag, tail)), Spec.in_source_order(Tag, all, tail), down_source(Tag, all, tail))
    case Table.ScopedRoute{r, ps} <> +tail: Equal.cong(List<&2, RS.RouteSchemas>, List<&2, RS.RouteSchemas>, z => Spec.bundle(Tag, all, ScopedSpec.route_count(Tag, tail)) <> z, down(Tag, all, ScopedSpec.route_count(Tag, tail)), Spec.in_source_order(Tag, all, tail), down_source(Tag, all, tail))
    case Table.Hook{st, tg} <> tail: down_source(Tag, all, tail)
    case Table.Use{src, tg} <> tail: down_source(Tag, all, tail)
    case Table.PrefixedUse{src, tg} <> tail: down_source(Tag, all, tail)

def L.table_schemas_in_source_order(Tag, entries, routes, compiled, layers, count, built):
  Equal.trans(List<&2, RS.RouteSchemas>, TableSchemas.effective_go(Tag, layers, count), down(Tag, entries, count), Spec.in_source_order(Tag, entries, entries),
    go_down(Tag, entries, routes, compiled, layers, count, count, built),
    Equal.trans(List<&2, RS.RouteSchemas>, down(Tag, entries, count), down(Tag, entries, ScopedSpec.route_count(Tag, entries)), Spec.in_source_order(Tag, entries, entries),
      Equal.cong(Nat, List<&2, RS.RouteSchemas>, n => down(Tag, entries, n), count, ScopedSpec.route_count(Tag, entries), Sel.successful_count(Tag, entries, routes, compiled, layers, count, built)),
      down_source(Tag, entries, entries)))

# Finalization keeps delivery. `claims` keeps a header list's marker fields and
# `unclaimed` the rest; `marked` only ever finds a marker field, so a list and
# its claims mark the same ids. Each step decides the field-name test with a
# Bool parameter and its equation.
def claims_append_step(+n: String, +v: List<&2, U32>, +a: List<&2, Request.Header>, +b: List<&2, Request.Header>, +c: List<&2, Request.Header>, same: Bool, ih: {a == List.append(&2, Request.Header, b, c) : List<&2, Request.Header>}) -> {Marker.claim_field(Request.Header{n, v}, a, same) == List.append(&2, Request.Header, Marker.claim_field(Request.Header{n, v}, b, same), c) : List<&2, Request.Header>}:
  match same:
    case True{}: Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, l => Request.Header{n, v} <> l, a, List.append(&2, Request.Header, b, c), ih)
    case False{}: ih

def claims_append(+xs: List<&2, Request.Header>, +ys: List<&2, Request.Header>) -> {Marker.claims(List.append(&2, Request.Header, xs, ys)) == List.append(&2, Request.Header, Marker.claims(xs), Marker.claims(ys)) : List<&2, Request.Header>}:
  match xs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> +t: claims_append_step(n, v, Marker.claims(List.append(&2, Request.Header, t, ys)), Marker.claims(t), Marker.claims(ys), Marker.named(n), claims_append(t, ys))

def claims_twice_step(+n: String, +v: List<&2, U32>, +t: List<&2, Request.Header>, same: Bool, e: {Marker.named(n) == same : Bool}, ih: {Marker.claims(Marker.claims(t)) == Marker.claims(t) : List<&2, Request.Header>}) -> {Marker.claims(Marker.claim_field(Request.Header{n, v}, Marker.claims(t), same)) == Marker.claim_field(Request.Header{n, v}, Marker.claims(t), same) : List<&2, Request.Header>}:
  match same:
    case True{}:
      %Equal.sym(Bool, Marker.named(n), True{}, e) : {Marker.claim_field(Request.Header{n, v}, Marker.claims(Marker.claims(t)), _) == Request.Header{n, v} <> Marker.claims(t) : List<&2, Request.Header>}
      Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, l => Request.Header{n, v} <> l, Marker.claims(Marker.claims(t)), Marker.claims(t), ih)
    case False{}: ih

def claims_twice(+hs: List<&2, Request.Header>) -> {Marker.claims(Marker.claims(hs)) == Marker.claims(hs) : List<&2, Request.Header>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> +t: claims_twice_step(n, v, t, Marker.named(n), {==}, claims_twice(t))

def claims_unclaimed_step(+n: String, +v: List<&2, U32>, +t: List<&2, Request.Header>, same: Bool, e: {Marker.named(n) == same : Bool}, ih: {Marker.claims(Marker.unclaimed(t)) == [] : List<&2, Request.Header>}) -> {Marker.claims(Marker.other_field(Request.Header{n, v}, Marker.unclaimed(t), same)) == [] : List<&2, Request.Header>}:
  match same:
    case True{}: ih
    case False{}:
      %Equal.sym(Bool, Marker.named(n), False{}, e) : {Marker.claim_field(Request.Header{n, v}, Marker.claims(Marker.unclaimed(t)), _) == [] : List<&2, Request.Header>}
      ih

def claims_unclaimed(+hs: List<&2, Request.Header>) -> {Marker.claims(Marker.unclaimed(hs)) == [] : List<&2, Request.Header>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> +t: claims_unclaimed_step(n, v, t, Marker.named(n), {==}, claims_unclaimed(t))

def marked_claims_step(+n: String, +v: List<&2, U32>, +t: List<&2, Request.Header>, +id: String, same: Bool, e: {Marker.named(n) == same : Bool}, ih: {Marker.marked(t, id) == Marker.marked(Marker.claims(t), id) : Bool}) -> {(same && String.eq(Bytes.ascii(v), id)) || Marker.marked(t, id) == Marker.marked(Marker.claim_field(Request.Header{n, v}, Marker.claims(t), same), id) : Bool}:
  match same:
    case True{}:
      %Equal.sym(Bool, Marker.named(n), True{}, e) : {(True{} && String.eq(Bytes.ascii(v), id)) || Marker.marked(t, id) == (_ && String.eq(Bytes.ascii(v), id)) || Marker.marked(Marker.claims(t), id) : Bool}
      Equal.cong(Bool, Bool, z => (True{} && String.eq(Bytes.ascii(v), id)) || z, Marker.marked(t, id), Marker.marked(Marker.claims(t), id), ih)
    case False{}: ih

def marked_claims(+hs: List<&2, Request.Header>, +id: String) -> {Marker.marked(hs, id) == Marker.marked(Marker.claims(hs), id) : Bool}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> +t: marked_claims_step(n, v, t, id, Marker.named(n), {==}, marked_claims(t, id))

def header_append_nil(+xs: List<&2, Request.Header>) -> {List.append(&2, Request.Header, xs, []) == xs : List<&2, Request.Header>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t: Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, l => h <> l, List.append(&2, Request.Header, t, []), t, header_append_nil(t))

def reserved_parts(+hs: List<&2, Request.Header>, +fields: List<&2, Request.Header>) -> {List.append(&2, Request.Header, Marker.claims(Marker.claims(hs)), Marker.claims(Marker.unclaimed(fields))) == Marker.claims(hs) : List<&2, Request.Header>}:
  %Equal.sym(List<&2, Request.Header>, Marker.claims(Marker.claims(hs)), Marker.claims(hs), claims_twice(hs)) : {List.append(&2, Request.Header, _, Marker.claims(Marker.unclaimed(fields))) == Marker.claims(hs) : List<&2, Request.Header>}
  %Equal.sym(List<&2, Request.Header>, Marker.claims(Marker.unclaimed(fields)), [], claims_unclaimed(fields)) : {List.append(&2, Request.Header, Marker.claims(hs), _) == Marker.claims(hs) : List<&2, Request.Header>}
  header_append_nil(Marker.claims(hs))

# A reserved header list claims exactly what the original claimed.
def reserved_claims(+hs: List<&2, Request.Header>, +fields: List<&2, Request.Header>) -> {Marker.claims(List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields))) == Marker.claims(hs) : List<&2, Request.Header>}:
  Equal.trans(List<&2, Request.Header>, Marker.claims(List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields))), List.append(&2, Request.Header, Marker.claims(Marker.claims(hs)), Marker.claims(Marker.unclaimed(fields))), Marker.claims(hs),
    claims_append(Marker.claims(hs), Marker.unclaimed(fields)),
    reserved_parts(hs, fields))

def reserved_marked(+hs: List<&2, Request.Header>, +fields: List<&2, Request.Header>, +id: String) -> {Marker.marked(List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields)), id) == Marker.marked(hs, id) : Bool}:
  Equal.trans(Bool, Marker.marked(List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields)), id), Marker.marked(Marker.claims(hs), id), Marker.marked(hs, id),
    Equal.trans(Bool, Marker.marked(List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields)), id), Marker.marked(Marker.claims(List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields))), id), Marker.marked(Marker.claims(hs), id),
      marked_claims(List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields)), id),
      Equal.cong(List<&2, Request.Header>, Bool, z => Marker.marked(z, id), Marker.claims(List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields))), Marker.claims(hs), reserved_claims(hs, fields))),
    Equal.sym(Bool, Marker.marked(hs, id), Marker.marked(Marker.claims(hs), id), marked_claims(hs, id)))

def reserved_eligible(+claim: Marker.Claim, +code: U32, +hs: List<&2, Request.Header>, +fields: List<&2, Request.Header>) -> {Marker.eligible(claim, code, List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields))) == Marker.eligible(claim, code, hs) : Bool}:
  match claim:
    case Marker.Unclaimed{}: {==}
    case Marker.BodyClaim{id}: reserved_marked(hs, fields, id)
    case Marker.UpgradeClaim{id}: Equal.cong(Bool, Bool, z => z && U32.is_eq(code, 101), Marker.marked(List.append(&2, Request.Header, Marker.claims(hs), Marker.unclaimed(fields)), id), Marker.marked(hs, id), reserved_marked(hs, fields, id))

def reserved_delivers(+original: Response.Res, +changed: Response.Res, +claim: Marker.Claim) -> {Marker.delivers(claim, Marker.reserved(original, changed)) == Marker.delivers(claim, original) : Bool}:
  match original changed:
    case Response.Res{code, hs, b, r} Response.Res{old, fields, body, rep}: reserved_eligible(claim, code, hs, fields)

def failure_delivers(+claim: Marker.Claim) -> {Marker.delivers(claim, Response.body(500, [], [])) == False{} : Bool}:
  match claim:
    case Marker.Unclaimed{}: {==}
    case Marker.BodyClaim{id}: {==}
    case Marker.UpgradeClaim{id}: {==}

def checked_delivers(+policies: List<&2, Policy.Policy>, +res: Response.Res, +claim: Marker.Claim, v: Bool) -> {Marker.delivers(claim, Policy.checked(policies, Marker.reserved(res, Policy.all(policies, res)), v)) == (v && Marker.delivers(claim, res)) : Bool}:
  match v:
    case True{}: reserved_delivers(res, Policy.all(policies, res), claim)
    case False{}:
      Equal.trans(Bool, Marker.delivers(claim, Marker.reserved(Response.body(500, [], []), Policy.safe_all(policies, Response.body(500, [], [])))), Marker.delivers(claim, Response.body(500, [], [])), False{},
        reserved_delivers(Response.body(500, [], []), Policy.safe_all(policies, Response.body(500, [], [])), claim),
        failure_delivers(claim))

def L.finalized_policies_keep_delivery(claim, policies, res):
  checked_delivers(policies, res, claim, Response.valid(Marker.reserved(res, Policy.all(policies, res))))

def answered_sent(+policies: List<&2, Policy.Policy>, +x: Response.Res, +a: V.Action, +r: Response.Res) -> {Final.answered(policies, x, a, r) == Spec.sent(a, x, Policy.finalized(policies, r)) : Response.Res}:
  match a:
    case V.Replace{}: {==}
    case V.Send{}: {==}
    case V.Report{es}: {==}

def finalization_sent(+mode: Config.Mode, +claim: Marker.Claim, +response: Maybe<&2, S.Schema>, +policies: List<&2, Policy.Policy>, +x: Response.Res, +r: Response.Res) -> {Final.answered(policies, x, Final.action(~V.run, mode, claim, V.checked(response), x), r) == Spec.finalized(mode, claim, response, x, Policy.finalized(policies, r)) : Response.Res}:
  match x:
    case Response.Res{+code, +hs, +body, +rep}:
      Equal.trans(Response.Res, Final.answered(policies, Response.Res{code, hs, body, rep}, V.policy(mode, V.delivery(claim, code, hs), V.response(V.checked(response), code, hs, body)), r), Final.answered(policies, Response.Res{code, hs, body, rep}, Spec.action(mode, Spec.delivery(claim, code, hs), response, code, hs, body), r), Spec.sent(Spec.action(mode, Spec.delivery(claim, code, hs), response, code, hs, body), Response.Res{code, hs, body, rep}, Policy.finalized(policies, r)),
        Equal.cong(V.Action, Response.Res, a => Final.answered(policies, Response.Res{code, hs, body, rep}, a, r), V.policy(mode, V.delivery(claim, code, hs), V.response(V.checked(response), code, hs, body)), Spec.action(mode, Spec.delivery(claim, code, hs), response, code, hs, body), L.route_response_claimed_policy(mode, claim, response, code, hs, body)),
        answered_sent(policies, Response.Res{code, hs, body, rep}, Spec.action(mode, Spec.delivery(claim, code, hs), response, code, hs, body), r))

def L.finalization_sends_checked_response(mode, claim, response, policies, res, replacement):
  finalization_sent(mode, claim, response, policies, Policy.finalized(policies, res), replacement)

def without_ids_step(+k: String, +v: List<&2, U32>, +t: List<&2, Request.Header>, same: Bool, e: {String.eq(Bytes.fold(k), "x-request-id") == same : Bool}, ih: {Final.unstamped_fields(Obs.without_ids(t)) == Final.unstamped_fields(t) : List<&2, Request.Header>}) -> {Final.unstamped_fields(Obs.keep_field(Request.Header{k, v}, Obs.without_ids(t), same)) == Final.unstamped_field(Request.Header{k, v}, Final.unstamped_fields(t), Final.stamp(Bytes.fold(k))) : List<&2, Request.Header>}:
  match same:
    case True{}:
      %Equal.sym(Bool, String.eq(Bytes.fold(k), "x-request-id"), True{}, e) : {Final.unstamped_fields(Obs.without_ids(t)) == Final.unstamped_field(Request.Header{k, v}, Final.unstamped_fields(t), _ || String.eq(Bytes.fold(k), "server-timing")) : List<&2, Request.Header>}
      ih
    case False{}:
      Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, z => Final.unstamped_field(Request.Header{k, v}, z, Final.stamp(Bytes.fold(k))), Final.unstamped_fields(Obs.without_ids(t)), Final.unstamped_fields(t), ih)

# Dropping X-Request-ID fields drops nothing the unstamped view keeps.
def without_ids_unstamped(+hs: List<&2, Request.Header>) -> {Final.unstamped_fields(Obs.without_ids(hs)) == Final.unstamped_fields(hs) : List<&2, Request.Header>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t: without_ids_step(k, v, t, String.eq(Bytes.fold(k), "x-request-id"), {==}, without_ids_unstamped(t))

def missing_stamped(+b: Bool, +res: Response.Res, +name: String, +value: String, s: {Final.stamp(Bytes.fold(name)) == True{} : Bool}) -> {Final.unstamped(Obs.missing(b, res, name, value)) == Final.unstamped(res) : Response.Res}:
  match b:
    case True{}: {==}
    case False{}:
      match res:
        case Response.Res{+c, +hs, +bd, +rp}:
          %Equal.sym(Bool, Final.stamp(Bytes.fold(name)), True{}, s) : {Response.Res{c, Final.unstamped_field(Request.Header{name, Response.utf8(value)}, Final.unstamped_fields(hs), _), bd, rp} == Response.Res{c, Final.unstamped_fields(hs), bd, rp} : Response.Res}
          {==}

def header_stamped(+res: Response.Res, +name: String, +m: Maybe<&2, String>, s: {Final.stamp(Bytes.fold(name)) == True{} : Bool}) -> {Final.unstamped(Obs.header(res, name, m)) == Final.unstamped(res) : Response.Res}:
  match res m:
    case Response.Res{+c, +hs, +bd, +rp} None{}: {==}
    case Response.Res{+c, +hs, +bd, +rp} Some{+text}: missing_stamped(Obs.has_header(hs, name), Response.Res{c, hs, bd, rp}, name, text, s)

def request_id_stamped(+res: Response.Res, +id: Maybe<&2, String>) -> {Final.unstamped(Obs.request_id(res, id)) == Final.unstamped(res) : Response.Res}:
  match res:
    case Response.Res{+c, +hs, +bd, +rp}:
      Equal.trans(Response.Res, Final.unstamped(Obs.header(Response.Res{c, Obs.without_ids(hs), bd, rp}, "x-request-id", Obs.explicit_id(hs, id))), Final.unstamped(Response.Res{c, Obs.without_ids(hs), bd, rp}), Final.unstamped(Response.Res{c, hs, bd, rp}),
        header_stamped(Response.Res{c, Obs.without_ids(hs), bd, rp}, "x-request-id", Obs.explicit_id(hs, id), {==}),
        Equal.cong(List<&2, Request.Header>, Response.Res, z => Response.Res{c, z, bd, rp}, Final.unstamped_fields(Obs.without_ids(hs)), Final.unstamped_fields(hs), without_ids_unstamped(hs)))

def L.finalizers_only_stamp(res, id, timing):
  Equal.trans(Response.Res, Final.unstamped(Obs.header(Obs.request_id(res, id), "server-timing", timing)), Final.unstamped(Obs.request_id(res, id)), Final.unstamped(res),
    header_stamped(Obs.request_id(res, id), "server-timing", timing, {==}),
    request_id_stamped(res, id))

# BND-96: Unchecked is sent whatever the delivery.
def policy_unchecked(+mode: Config.Mode, d: V.Delivery) -> {V.policy(mode, d, V.Unchecked{}) == V.Send{} : V.Action}:
  match d:
    case V.Buffered{}: {==}
    case V.Streamed{}: {==}

def L.response_without_schema_is_sent_run(mode, claim, res):
  match res:
    case Response.Res{+code, +hs, +body, +rep}: policy_unchecked(mode, V.delivery(claim, code, hs))

def L.response_without_schema_is_sent_skip(mode, claim, res):
  match res:
    case Response.Res{+code, +hs, +body, +rep}: policy_unchecked(mode, V.delivery(claim, code, hs))

# BND-96: a table that declares no schema validates nothing.
def bool_seen(b: Bool) -> Type:
  match b:
    case True{}: Unit
    case False{}: Empty

def true_false(e: {True{} == False{} : Bool}) -> Empty:
  %e : bool_seen(_)
  Unit{}

def never(-A: Type, e: Empty) -> A:
  match e:

def or_false_left(a: Bool, +b: Bool, e: {a || b == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: never({True{} == False{} : Bool}, true_false(e))

def or_false_right(a: Bool, +b: Bool, e: {a || b == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case False{}: e
    case True{}: never({b == False{} : Bool}, true_false(e))

# A set that declares nothing has every slot empty, so overriding with it
# keeps the outer set.
def undeclared_override(+acc: V.Schemas, +set: V.Schemas, e: {V.declares(set) == False{} : Bool}) -> {V.override(acc, set) == acc : V.Schemas}:
  match acc set:
    case V.Schemas{+p, +q, +h, +b, +r} V.Schemas{None{}, None{}, None{}, None{}, None{}}: {==}
    case V.Schemas{+p, +q, +h, +b, +r} V.Schemas{Some{c}, sq, sh, sb, sr}: never({V.override(V.Schemas{p, q, h, b, r}, V.Schemas{Some{c}, sq, sh, sb, sr}) == V.Schemas{p, q, h, b, r} : V.Schemas}, true_false(e))
    case V.Schemas{+p, +q, +h, +b, +r} V.Schemas{None{}, Some{c}, sh, sb, sr}: never({V.override(V.Schemas{p, q, h, b, r}, V.Schemas{None{}, Some{c}, sh, sb, sr}) == V.Schemas{p, q, h, b, r} : V.Schemas}, true_false(e))
    case V.Schemas{+p, +q, +h, +b, +r} V.Schemas{None{}, None{}, Some{c}, sb, sr}: never({V.override(V.Schemas{p, q, h, b, r}, V.Schemas{None{}, None{}, Some{c}, sb, sr}) == V.Schemas{p, q, h, b, r} : V.Schemas}, true_false(e))
    case V.Schemas{+p, +q, +h, +b, +r} V.Schemas{None{}, None{}, None{}, Some{c}, sr}: never({V.override(V.Schemas{p, q, h, b, r}, V.Schemas{None{}, None{}, None{}, Some{c}, sr}) == V.Schemas{p, q, h, b, r} : V.Schemas}, true_false(e))
    case V.Schemas{+p, +q, +h, +b, +r} V.Schemas{None{}, None{}, None{}, None{}, Some{c}}: never({V.override(V.Schemas{p, q, h, b, r}, V.Schemas{None{}, None{}, None{}, None{}, Some{c}}) == V.Schemas{p, q, h, b, r} : V.Schemas}, true_false(e))

def placed_undeclared(-Tag: Data, +hooks: List<&2, Table.Placement<Tag>>, +acc: V.Schemas, +e: {Table.placed_declares(Tag, hooks) == False{} : Bool}) -> {Table.placed_schemas(Tag, hooks, acc) == acc : V.Schemas}:
  match hooks:
    case Nil{}: {==}
    case Table.Placement{scope, hook} <> +tail: placed_undeclared(Tag, tail, acc, e)
    case Table.Checks{scope, +schemas} <> +tail:
      Equal.trans(V.Schemas, Table.placed_schemas(Tag, tail, V.override(acc, schemas)), V.override(acc, schemas), acc,
        placed_undeclared(Tag, tail, V.override(acc, schemas), or_false_right(V.declares(schemas), Table.placed_declares(Tag, tail), e)),
        undeclared_override(acc, schemas, or_false_left(V.declares(schemas), Table.placed_declares(Tag, tail), e)))

def here_undeclared(-Tag: Data, +hooks: List<&2, Table.Placement<Tag>>, yes: Bool, e: {Table.placed_declares(Tag, hooks) == False{} : Bool}) -> {Table.schemas_here(Tag, hooks, yes) == V.none() : V.Schemas}:
  match yes:
    case True{}: placed_undeclared(Tag, hooks, V.none(), e)
    case False{}: {==}

def route_undeclared(-Tag: Data, +layers: List<&2, Table.Middleware<Tag>>, +route: Maybe<&2, Nat>, +e: {Table.declares_schemas(Tag, layers) == False{} : Bool}) -> {Table.route_schemas(Tag, layers, route) == V.none() : V.Schemas}:
  match layers:
    case Nil{}: {==}
    case Table.Staged{stage, tag} <> +tail: route_undeclared(Tag, tail, route, e)
    case Table.Middleware{pattern, tag} <> +tail: route_undeclared(Tag, tail, route, e)
    case Table.Scoped{+index, +hooks} <> +tail:
      match route:
        case None{}: {==}
        case Some{+n}:
          Equal.trans(V.Schemas, V.override(Table.route_schemas(Tag, tail, Some{n}), Table.schemas_here(Tag, hooks, Nat.is_eq(index, n))), V.override(V.none(), Table.schemas_here(Tag, hooks, Nat.is_eq(index, n))), V.none(),
            Equal.cong(V.Schemas, V.Schemas, x => V.override(x, Table.schemas_here(Tag, hooks, Nat.is_eq(index, n))), Table.route_schemas(Tag, tail, Some{n}), V.none(), route_undeclared(Tag, tail, Some{n}, or_false_right(Table.placed_declares(Tag, hooks), Table.declares_schemas(Tag, tail), e))),
            Equal.cong(V.Schemas, V.Schemas, y => V.override(V.none(), y), Table.schemas_here(Tag, hooks, Nat.is_eq(index, n)), V.none(), here_undeclared(Tag, hooks, Nat.is_eq(index, n), or_false_left(Table.placed_declares(Tag, hooks), Table.declares_schemas(Tag, tail), e))))

def L.undeclared_table_checks_nothing(Tag, layers, route, undeclared):
  route_undeclared(Tag, layers, route, undeclared)

# BND-96: a set with no request slot is admitted with no values.
def request_free_run(+set: V.Schemas, +input: V.Input, e: {Bool.not(V.requests_nothing(set)) == False{} : Bool}) -> {V.run(V.RequestJob{set, input}) == V.Judged{V.Valid{V.no_values()}} : V.Answer}:
  match set input:
    case V.Schemas{None{}, None{}, None{}, None{}, +r} V.Input{+ps, +qs, +hs, +body}: {==}
    case V.Schemas{Some{c}, sq, sh, sb, sr} +i: never({V.run(V.RequestJob{V.Schemas{Some{c}, sq, sh, sb, sr}, i}) == V.Judged{V.Valid{V.no_values()}} : V.Answer}, true_false(e))
    case V.Schemas{None{}, Some{c}, sh, sb, sr} +i: never({V.run(V.RequestJob{V.Schemas{None{}, Some{c}, sh, sb, sr}, i}) == V.Judged{V.Valid{V.no_values()}} : V.Answer}, true_false(e))
    case V.Schemas{None{}, None{}, Some{c}, sb, sr} +i: never({V.run(V.RequestJob{V.Schemas{None{}, None{}, Some{c}, sb, sr}, i}) == V.Judged{V.Valid{V.no_values()}} : V.Answer}, true_false(e))
    case V.Schemas{None{}, None{}, None{}, Some{c}, sr} +i: never({V.run(V.RequestJob{V.Schemas{None{}, None{}, None{}, Some{c}, sr}, i}) == V.Judged{V.Valid{V.no_values()}} : V.Answer}, true_false(e))

def L.request_free_route_is_admitted_run(set, input, unchecked):
  request_free_run(set, input, unchecked)

def L.request_free_route_is_admitted_skip(set, input, unchecked):
  Equal.cong(Bool, V.Answer, d => V.Judged{V.skipped(Bool.not(d))}, V.declares(set), False{}, unchecked)

def L.request_free_route_enters_cleared_run(Vars, c, set, input, unchecked):
  Equal.cong(V.Answer, C.Entry<Vars>, a => C.answered(Vars, c, a), V.run(V.RequestJob{set, input}), V.Judged{V.Valid{V.no_values()}}, request_free_run(set, input, unchecked))

def L.request_free_route_enters_cleared_skip(Vars, c, set, input, unchecked):
  Equal.cong(V.Answer, C.Entry<Vars>, a => C.answered(Vars, c, a), V.skip(V.RequestJob{set, input}), V.Judged{V.Valid{V.no_values()}}, L.request_free_route_is_admitted_skip(set, input, unchecked))

def L.no_values_entry_reads_unchanged(Vars, c, fresh):
  match c:
    case C.Ctx{+r, +p, +b, +q, +s, +hs, +vars, Obs.State{+id, +timing, +finalized, +policies, +stream, +peer, +access, +valid}}:
      Equal.cong(Maybe<&2, V.Values>, V.Values, x => C.values_of(x), None{}, valid, Equal.sym(Maybe<&2, V.Values>, valid, None{}, fresh))
