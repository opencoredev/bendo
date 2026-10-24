import Base
import ../src/app/validate.bend as V
import ../src/data/schema.bend as S
import ../src/data/schema-prepared.bend as SP
import ../src/data/json.bend as J
import ../src/http/request.bend as Request
import ./validate-spec.bend as Spec
import ../src/app/context.bend as C
import ../src/app/config.bend as Config
import ../src/app/table.bend as Table
import ../src/app/table-schemas.bend as TableSchemas
import ../src/app/route-schemas.bend as RS
import ../src/app/scopes.bend as Scopes
import ../src/router/methods.bend as Methods
import ./scoped-assembly-spec.bend as AssemblySpec
import ./scoped-selection-spec.bend as ScopedSelectionSpec
import ../src/http/stream_marker.bend as Marker

# These laws trust the parsers the implementation and the specification share:
# J.parse, Bytes.fold and the raw query parser. Proving those independently
# is BND-92.

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
# first 100 of the slot-prefixed errors of every slot, in slot order. Params, query and headers decode their
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

# BND-36: the validator admits a request exactly when every declared slot
# decodes. handler_enters_iff_admitted carries this to handler entry.
law route_admits_iff_slots_decode:
  for +params: Maybe<&2, S.Schema>
  for +query: Maybe<&2, S.Schema>
  for +headers: Maybe<&2, S.Schema>
  for +body: Maybe<&2, S.Schema>
  for +response: Maybe<&2, S.Schema>
  for +input: V.Input
  {V.admits(V.request(V.prepared(params, query, headers, body, response), input)) == Spec.admitted(params, query, headers, body, input) : Bool}

# BND-36: a rejection lists the slots' errors, each path prefixed by its slot,
# slot by slot, cut to the first 100 for the whole request (Spec.reported);
# an admitted request lists none.
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

# BND-36: one reporting budget per request. Whatever every slot reports, a
# rejection lists at most 100 errors.
law route_rejection_within_budget:
  for +params: Maybe<&2, S.Schema>
  for +query: Maybe<&2, S.Schema>
  for +headers: Maybe<&2, S.Schema>
  for +body: Maybe<&2, S.Schema>
  for +response: Maybe<&2, S.Schema>
  for +input: V.Input
  {Nat.is_le(List.length(&2, S.Error, V.rejection_errors(V.request(V.prepared(params, query, headers, body, response), input))), 100n) == True{} : Bool}

# BND-36: the entrypoints without a decoder (B.handle, B.serve and friends)
# reject every route that declares a schema in any slot, a response schema
# alone included, and admit the rest with no decoded values.
law plain_admission_rejects_declared:
  for +schemas: V.Schemas
  for +input: V.Input
  {V.skip(V.RequestJob{schemas, input}) == V.Judged{Spec.plain(schemas)} : V.Answer}

# BND-36: handler entry. A valid verdict dispatches with exactly the
# verdict's values in the context.
law handler_entry_valid:
  for -Vars: Data
  for +ctx: C.Ctx<Vars>
  for +values: V.Values
  {C.entry(Vars, ctx, V.Valid{values}) == C.EnterHandler{C.with_values(Vars, ctx, values)} : C.Entry<Vars>}

# BND-36: an invalid verdict answers its rejection, and nothing is dispatched.
law handler_entry_invalid:
  for -Vars: Data
  for +ctx: C.Ctx<Vars>
  for +code: U32
  for +errors: List<&2, S.Error>
  {C.entry(Vars, ctx, V.Invalid{code, errors}) == C.RejectRequest{C.rejected(Vars, ctx, code, errors)} : C.Entry<Vars>}

# BND-36: with the decoding validator, the handler is entered exactly when
# every declared slot decodes.
law handler_enters_iff_admitted:
  for -Vars: Data
  for +ctx: C.Ctx<Vars>
  for +params: Maybe<&2, S.Schema>
  for +query: Maybe<&2, S.Schema>
  for +headers: Maybe<&2, S.Schema>
  for +body: Maybe<&2, S.Schema>
  for +response: Maybe<&2, S.Schema>
  for +input: V.Input
  {C.enters(Vars, C.entry(Vars, ctx, V.request(V.prepared(params, query, headers, body, response), input))) == Spec.admitted(params, query, headers, body, input) : Bool}

# BND-36: what happens to a response, in either mode and for either delivery
# (Spec.action): a streamed response is sent as it is; a buffered one that
# violates its schema is replaced by a 500 in development and sent with one
# log line of its errors in production; every other response is sent.
law route_response_policy:
  for +mode: Config.Mode
  for +delivery: V.Delivery
  for +response: Maybe<&2, S.Schema>
  for +code: U32
  for +headers: List<&2, Request.Header>
  for +bytes: List<&2, U32>
  {V.policy(mode, delivery, V.response(V.checked(response), code, headers, bytes)) == Spec.action(mode, delivery, response, code, headers, bytes) : V.Action}

# BND-36: innermost wins. For every built table, every route and every slot,
# the schema the route validates with is the last declaration of that slot
# among the route's placements, read outer to inner (Spec.effective); slots
# an inner scope leaves undeclared keep the outer declaration.
law route_schemas_innermost:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +route: Maybe<&2, Nat>
  for +which: Spec.Which
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Spec.slot(which, Table.route_schemas(Tag, layers, route)) == Spec.effective(Tag, which, entries, route) : Maybe<&2, SP.Checked>}

# BND-36: the same through a guard, against the independent assembly
# specification: the guard's schemas come before each member's own.
law route_schemas_guard_innermost:
  for -Tag: Data
  for +options: Table.GuardOptions<Tag>
  for +inside: List<&2, Table.Entry<Tag>>
  for +outside: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +route: Maybe<&2, Nat>
  for +which: Spec.Which
  for +built: {Table.build(Tag, List.append(&2, Table.Entry<Tag>, Scopes.guard(Tag, options, inside), outside)) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Spec.slot(which, Table.route_schemas(Tag, layers, route)) == Spec.effective(Tag, which, List.append(&2, Table.Entry<Tag>, AssemblySpec.guard(Tag, options, inside), outside), route) : Maybe<&2, SP.Checked>}

# BND-36: the same through a group or mount prefix.
law route_schemas_group_innermost:
  for -Tag: Data
  for +prefix: String
  for +hooks: List<&2, Table.HookSpec<Tag>>
  for +inside: List<&2, Table.Entry<Tag>>
  for +outside: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +route: Maybe<&2, Nat>
  for +which: Spec.Which
  for +built: {Table.build(Tag, List.append(&2, Table.Entry<Tag>, Scopes.group(Tag, prefix, hooks, inside), outside)) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Spec.slot(which, Table.route_schemas(Tag, layers, route)) == Spec.effective(Tag, which, List.append(&2, Table.Entry<Tag>, AssemblySpec.group(Tag, prefix, hooks, inside), outside), route) : Maybe<&2, SP.Checked>}

# BND-36/37: the manifest's schema list has one entry per route registration,
# so a validated app's manifest never fails the BND-37 count check.
law table_schemas_one_per_route:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {List.length(&2, RS.RouteSchemas, TableSchemas.effective(Tag, Table.Table{routes, compiled, layers, count})) == ScopedSelectionSpec.route_count(Tag, entries) : Nat}

# BND-36: transport selection hands a response to the request's registration
# exactly when Spec.handed_over says: a body stream needs its own marker, an
# upgrade its own marker and a 101, and with no registration nothing is
# handed over whatever headers the response carries. Transport.select and
# StreamResponse.select decide with Marker.eligible.
law transport_eligibility_matches_spec:
  for +claim: Marker.Claim
  for +code: U32
  for +headers: List<&2, Request.Header>
  {Marker.eligible(claim, code, headers) == Spec.handed_over(claim, code, headers) : Bool}

# BND-36: response validation treats a response as streamed or upgraded
# exactly when transport hands it over by that same eligibility; every other
# response is buffered and checked.
law route_response_delivery_matches_transport:
  for +claim: Marker.Claim
  for +code: U32
  for +headers: List<&2, Request.Header>
  {V.delivery(claim, code, headers) == Spec.delivery(claim, code, headers) : V.Delivery}

# BND-36: a marker header with no registration behind it never exempts a
# response from its schema.
law unclaimed_response_is_buffered:
  for +code: U32
  for +headers: List<&2, Request.Header>
  {V.delivery(Marker.Unclaimed{}, code, headers) == V.Buffered{} : V.Delivery}

# BND-36: route_response_policy with delivery decided from the registration:
# for every registration claim, status, headers and body, the runtime's action
# is Spec.action at the delivery transport eligibility gives.
law route_response_claimed_policy:
  for +mode: Config.Mode
  for +claim: Marker.Claim
  for +response: Maybe<&2, S.Schema>
  for +code: U32
  for +headers: List<&2, Request.Header>
  for +bytes: List<&2, U32>
  {V.policy(mode, V.delivery(claim, code, headers), V.response(V.checked(response), code, headers, bytes)) == Spec.action(mode, Spec.delivery(claim, code, headers), response, code, headers, bytes) : V.Action}

# BND-36/37: the manifest's schema list is, entry for entry, the routes in
# source order, each with the raw schemas of its effective set slot by slot
# (Spec.manifest_schemas). table_schemas_one_per_route is its length.
law table_schemas_in_source_order:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {TableSchemas.effective(Tag, Table.Table{routes, compiled, layers, count}) == Spec.manifest_schemas(Tag, entries) : List<&2, RS.RouteSchemas>}
