import Base
import ../src/app/validate.bend as V
import ../src/data/schema.bend as S
import ../src/data/schema-prepared.bend as SP
import ../src/data/json.bend as J
import ../src/http/request.bend as Request
import ./validate-spec.bend as Spec

# BND-36: a schema prepared once, its validity checked and every pattern's
# automaton table built and checked up front, decodes exactly as the schema
# does, from either source. Routes decode with these prepared schemas, so every
# BND-33/34/35 schema law holds of route validation too.
law schema_prepared_decode:
  for src: S.Source
  for +schema: S.Schema
  for +value: J.Json
  {SP.decode_from(src, SP.check(schema), value) == S.decode_from(src, schema, value) : Result<&2, &2, S.Errors(), S.Value>}

# BND-36: for every route schema set and every request, validation answers
# the specification's verdict (proof/validate-spec.bend): the decoded value of
# each declared slot when every slot decodes, otherwise the status and the
# slot-prefixed errors of every slot. Params, query and headers decode their
# text objects with coercion; a body needs a JSON media type and well-formed
# JSON and decodes without coercion.
law route_validation_matches_spec:
  for +params: Maybe<&2, S.Schema>
  for +query: Maybe<&2, S.Schema>
  for +headers: Maybe<&2, S.Schema>
  for +body: Maybe<&2, S.Schema>
  for +response: Maybe<&2, S.Schema>
  for +input: V.Input
  {V.request(V.prepared(params, query, headers, body, response), input) == Spec.verdict(params, query, headers, body, input) : V.Verdict}

# BND-36: the handler runs exactly when every declared slot decodes.
law route_admits_iff_slots_decode:
  for +params: Maybe<&2, S.Schema>
  for +query: Maybe<&2, S.Schema>
  for +headers: Maybe<&2, S.Schema>
  for +body: Maybe<&2, S.Schema>
  for +response: Maybe<&2, S.Schema>
  for +input: V.Input
  {V.admits(V.request(V.prepared(params, query, headers, body, response), input)) == Spec.admitted(params, query, headers, body, input) : Bool}

# BND-36: a rejection lists exactly the union of the slots' errors, each path
# prefixed by its slot, slot by slot; an admitted request lists none.
law route_rejection_lists_slot_errors:
  for +params: Maybe<&2, S.Schema>
  for +query: Maybe<&2, S.Schema>
  for +headers: Maybe<&2, S.Schema>
  for +body: Maybe<&2, S.Schema>
  for +response: Maybe<&2, S.Schema>
  for +input: V.Input
  {V.rejection_errors(V.request(V.prepared(params, query, headers, body, response), input)) == Spec.errors(params, query, headers, body, input) : List<&2, S.Error>}

# BND-36: a 2xx response other than 204 conforms exactly when it carries a
# JSON body the response schema decodes; other responses are not checked.
law route_response_matches_spec:
  for +response: Maybe<&2, S.Schema>
  for +code: U32
  for +headers: List<&2, Request.Header>
  for +bytes: List<&2, U32>
  {V.response(V.checked(response), code, headers, bytes) == Spec.response(response, code, headers, bytes) : V.Check}
