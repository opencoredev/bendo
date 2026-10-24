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
def first_eq(+parts: List<&2, String>) -> {V.first(parts) == Spec.before_semicolon(parts) : String}:
  match parts:
    case Nil{}: {==}
    case h <> t: {==}

def media_eq(+values: List<&2, List<&2, U32>>) -> {V.json_media(values) == Spec.first_json(values) : Bool}:
  match values:
    case Nil{}: {==}
    case v <> t:
      Equal.cong(String, Bool, z => Spec.json_media(Bytes.fold(Bytes.ascii(Bytes.trim(Bytes.encode(z))))), V.first(String.split(Bytes.ascii(v), ';')), Spec.before_semicolon(String.split(Bytes.ascii(v), ';')), first_eq(String.split(Bytes.ascii(v), ';')))

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
