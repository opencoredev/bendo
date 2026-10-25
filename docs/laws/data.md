# Data laws

These laws cover JSON, URL-encoded forms and queries, cookies and signed
cookies, schemas, route validation, JSON Schema export and the schemas in the
route manifest. See the [laws index](README.md) for how to read an entry.

## JSON

- `json_roundtrip`: for every admissible JSON value and every writer setting (pretty or compact, ASCII-only or not), writing succeeds and parsing the UTF-8 output gives back the same value, member order and duplicate keys included. Admissible means valid JSON number text, strings and keys of Unicode scalar values, and at most 512 nested containers. See [JSON values and bodies](../data/json.md).

## UTF-8 text

`Utf8.encode` turns a `String` into UTF-8 octets. A Bend `Char` can hold any
32-bit value, so a program can build a string with a surrogate (U+D800 to
U+DFFF) or a value above U+10FFFF. The encoder writes each such character as
U+FFFD, as WHATWG `TextEncoder` does, and the decoders that read a string as
octets refuse it.

- `utf8_encode_char_non_scalar`: a character that is not a Unicode scalar value encodes as the three octets of U+FFFD.
- `utf8_encode_total`: every string encodes to valid UTF-8 that decodes back to the same string, with each non-scalar character replaced by U+FFFD. No character is dropped.
- `utf8_encode_response`: `Utf8.encode` and `Response.utf8`, the encoder behind text responses, give the same octets for every string.

## Forms and query strings

These laws cover percent-encoding and the lookup of repeated keys. See
[URL-encoded forms](../data/urlencoded.md).

- `query_component_roundtrip`: every string of Unicode scalar values survives query-component encoding and decoding.
- `form_component_roundtrip`: every such string survives WHATWG form encoding and decoding, including space as `+` and a literal `+` as `%2B`.
- `form_queries_all_in_order`: looking up a key returns every matching value, in order, for every entry list and key.
- `url_decode_non_scalar`, `url_decode_form_non_scalar`, `url_parse_pairs_non_scalar`: `Url.decode`, `Url.decode_form` and `Url.parse_pairs` fail on any text that holds a non-scalar character, rather than decoding it as U+FFFD.

## Cookies

Reading and writing cookies follows an independent RFC 6265 specification
(`proof/cookie-spec.bend`, `proof/cookie-ows-spec.bend` and
`proof/cookie-serialization-spec.bend`) with Bendo's stricter rules for Path,
Domain, Expires and the security attributes. The serializer can never inject
an attribute: no payload it writes contains `;`, CR or LF. See
[cookies](../cookies.md).

- `cookies_pair_roundtrip`: a valid name and value, serialized as a pair, parse back to exactly that one cookie.
- `cookies_defaults_checked`: serializing with default options gives exactly `name=value`.
- `cookies_ordered_list_roundtrip`: a whole `Cookie` header of valid pairs joined by `;` parses back to the same list, in order, repeated names included.
- `cookies_semispace_ordered_list_roundtrip`: the same with pairs joined by `; `, as browsers send them.
- `cookies_per_pair_ows_roundtrip`: optional whitespace around each pair is dropped and the pairs come back unpadded, in order.
- `serialize_exact`: for an admissible name, value and options, the `Set-Cookie` text is exactly the specification's: attribute order, spacing, casing and omissions.
- `serialize_structure`: every successful serialization is admissible, has that exact structure, and carries no `;`, CR or LF in any of its five attribute payload kinds.
- `attribute_no_delimiters`: an attribute value the specification accepts contains no `;`, CR or LF.
- `admissible_payloads_safe`: every variable attribute payload of admissible options is free of those bytes.

## Signed cookies

A signed cookie is the value, a dot and the base64 HMAC-SHA256 of the value,
all percent-encoded (the format Hono uses). Keys rotate: Bendo signs with the first key and accepts any
listed key. These laws say verification accepts exactly what a reference
verifier accepts, for every wire string, tampered or not; that unusable keys
sign and verify nothing; and that a cookie Bendo set reads back through a real
`Cookie` header. The reference verifier in `signed_cookie_wire_spec` calls the
library's percent and base64 decoders, so a second group of laws specifies those
decoders independently and restates verification without them. Those laws
turn strings into octets with Bendo's UTF-8 encoder, which has its own laws.
See [cookies](../cookies.md).

- `signed_cookie_wire_spec`: for every key set and every wire string, `verify` accepts exactly what the reference verifier accepts: bad keys, malformed escapes or UTF-8, no dot, non-canonical base64, or a tag unequal to every listed key's HMAC all fail; a match under any listed key succeeds.
- `signed_cookie_wire_first`, `signed_cookie_wire_member`: a value signed with the first key, or with any listed key, verifies back to the value.
- `signed_cookie_digest_first`, `signed_cookie_digest_member`: the same one level down, for the raw HMAC tag of the first or any listed key.
- `signed_cookie_digest_reject`: a tag that differs from every listed key's HMAC of the value is rejected.
- `signed_cookie_compare_structural`: the constant-time comparison used for tags equals plain byte equality.
- `signed_cookie_sign_spec`: the signer's output is exactly the RFC 4648 and RFC 3986 wire format the specification spells out.
- `signed_cookie_sign_first`: the checked signer signs with the first key exactly when the keys are usable and the value is a Unicode scalar string.
- `signed_cookie_sign_invalid`, `signed_cookie_serialize_invalid`, `signed_cookie_setter_invalid`: a value that is not a Unicode scalar string is refused by the signer, the serializer and the context setter.
- `signed_cookie_percent_roundtrip`: every Unicode scalar string survives the percent encoding used on the wire.
- `signed_cookie_configure_spec`: configuration accepts exactly the nonempty lists of nonempty Unicode scalar secrets.
- `signed_cookie_configure_nonempty`: every configured key set came from a list of nonempty secrets.
- `signed_cookie_empty_configuration`: an empty key list configures nothing.
- `signed_cookie_unusable_digest`, `signed_cookie_unusable_verify`, `signed_cookie_unusable_read`, `signed_cookie_unusable_sign`, `signed_cookie_unusable_serialize`, `signed_cookie_unusable_setter`, `signed_cookie_unusable_context`: key sets can be built without `configure`, so every entry point rechecks them. If any slot fails the secret check, nothing verifies, nothing is read and nothing is signed; serializing and setting fail with `InvalidSecret`.
- `signed_cookie_serialize_first`: serializing signs with the first key, then applies the ordinary cookie rules.
- `signed_cookie_set_cookie_field`: for an admissible name and options, the `Set-Cookie` text is the independent cookie serialization of `name=` and the signed wire value.
- `signed_cookie_setter_first`: the context setter is the ordinary cookie setter applied to the signed wire value.
- `signed_cookie_setter_appends`: the context setter appends exactly one `set-cookie` header after the existing response headers and changes nothing else in the context.
- `signed_cookie_context_read`: the context reader takes the first cookie with that name and verifies it.
- `signed_cookie_request_roundtrip`: a `Cookie` header carrying the signed pair, after differently named valid pairs and before any others (later duplicates included), verifies under every key list that contains the signing key.
- `signed_cookie_context_request`: the same end to end through the request context, with any other request headers around the field as long as none is named `cookie`.
- `signed_cookie_base64_canonical`: when strict padded standard base64 decoding returns bytes, the input is exactly the independent RFC 4648 encoding of those bytes and every byte is an octet. Wrong alphabet, misplaced or missing padding and nonzero unused bits are all rejected, so no two strings decode to the same tag.
- `signed_cookie_percent_spec`: the percent stage of `Url.decode` equals an independent RFC 3986 decoder for every octet list: `%HH` with hex digits in either case becomes one octet, a `%` without two hex digits fails with `InvalidPercent`, and every other octet, `+` included, stays literal.
- `signed_cookie_utf8_sound`: when strict UTF-8 decoding returns a string, that string holds only Unicode scalars and encodes back to exactly the input octets. Overlong forms, surrogates, values above U+10FFFF, stray continuation bytes and non-octets cannot decode.
- `signed_cookie_url_decode_sound`: a value `Url.decode` returns is a Unicode scalar string whose UTF-8 octets are the independent percent decoding of the wire's octets.
- `signed_cookie_url_decode_complete`: conversely, for a wire of Unicode scalars, every scalar string whose UTF-8 octets are that percent decoding is returned. A wire with a non-scalar character fails instead (`url_decode_non_scalar`).
- `signed_cookie_url_decode_percent_error`: a wire the independent percent decoder rejects fails with the same error.
- `signed_cookie_url_decode_utf8_error`: a failure after a successful percent stage is always `InvalidUtf8`. With the three laws above and `url_decode_non_scalar`, this fixes the result of `Url.decode` for every wire string.
- `signed_cookie_verify_sound`: verification restated against the independent decoders. If `verify` returns a value, the keys are usable, the value is a Unicode scalar string, and some listed key signed it: the wire percent decodes to the UTF-8 octets of the value, a dot, and the canonical base64 of that key's HMAC of the value.
- `signed_cookie_verify_complete`: every wire of that form made of Unicode scalars verifies to its value, under usable keys and any listed signing key, however its octets are escaped (either hex case, or unreserved characters escaped or not).

## Schemas

A schema decodes a JSON value into a typed value or a list of errors. These
laws compare the decoder with an independent statement of what each schema
accepts (`src/data/schema-spec.bend`). Together they say a value is accepted
exactly when it satisfies the schema, an accepted value keeps its exact input,
and a rejection names every failing location and nothing else, up to 100
errors. Text sources (route params, query strings, headers, forms) are first
coerced; the same laws hold of the coerced value. See
[schemas](../data/schema.md).

- `schema_acceptance_iff`: the decoder accepts a value exactly when the specification says it satisfies the schema.
- `schema_preserves_typed_value`: every success has the right typed constructor and keeps the exact input, decimal spelling included; compound values are built item by item and field by field in schema order, and a union records which member accepted.
- `schema_children_satisfy`: in an accepted compound value, every array item, every declared member, a non-null value under a nullable, and at least one union member satisfy their schemas.
- `schema_errors_name_failing_paths`: a rejection lists between 1 and 100 errors, and every error path is a place where the specification finds a failing check. An invalid schema is one error at the root.
- `schema_errors_complete`: every place the specification finds a failing check is reported with exactly that path, unless the list already holds 100 errors. Nothing below a failed kind or length check, and nothing inside a union, counts as a place.
- `schema_coerce_matches_spec`: text coercion equals the specification: number tokens under number and integer schemas, `true` and `false` under booleans, items under arrays, the inner schema under nullables, and the repeated members of an array field gathered, in order, into one array. JSON bodies are not coerced.
- `schema_coerced_acceptance_iff`, `schema_coerced_preserves_typed_value`, `schema_coerced_errors_name_failing_paths`, `schema_coerced_errors_complete`: the four laws above, for text sources, read against the coerced value.

## Route validation

Routes declare schemas for params, query, headers, body and the response.
These laws say the handler runs exactly when every declared request slot
decodes, with the decoded values; that a rejection reports every slot's errors
within one budget of 100; that the innermost scope's schema wins; and that
buffered responses are checked after the response policies run. See
[route validation](../validation.md).

They trust three parsers the implementation and the specification share: the
JSON parser, `Bytes.fold` and the raw query parser. Proving those against
independent specifications is BND-92.

- `schema_prepared_decode`: a schema prepared once (validity checked and pattern tables built) decodes exactly as the plain schema, from either source, so every schema law above holds for route validation.
- `route_validation_matches_spec`: for every schema set and request, validation returns the specification's verdict: the decoded values when every declared slot decodes, otherwise the status and the first 100 slot-prefixed errors in slot order. Params, query and headers are coerced text; a body needs a JSON media type and well-formed JSON, and is not coerced.
- `route_admits_iff_slots_decode`: a request is admitted exactly when every declared slot decodes.
- `route_rejection_lists_slot_errors`: a rejection lists each slot's errors with the slot as path prefix, cut to 100 for the whole request; an admitted request lists none.
- `route_rejection_within_budget`: a rejection never lists more than 100 errors.
- `handler_entry_valid`: a valid verdict enters the handler with exactly its values in the context.
- `handler_entry_invalid`: an invalid verdict answers its rejection and runs no handler.
- `handler_enters_iff_admitted`: with the decoding validator, the handler runs exactly when every declared slot decodes.
- `plain_admission_rejects_declared`: entry points built without a decoder (`B.handle`, `B.serve` and friends) reject every route that declares any schema, a response schema alone included, and admit the rest with no values.
- `route_response_matches_spec`: a 2xx response other than 204 conforms exactly when it has a JSON body the response schema decodes; other responses are not checked.
- `route_response_policy`: a streamed response is sent as is; a buffered one that breaks its schema becomes a 500 in development and is sent with one log line in production; every other response is sent.
- `route_response_claimed_policy`: the same, with streamed or buffered decided from the route's transport registration.
- `transport_eligibility_matches_spec`: a response is handed to the route's stream or upgrade transport exactly when the specification says: a stream needs its own marker, an upgrade its marker and a 101, and with no registration nothing is handed over, whatever headers the response carries.
- `route_response_delivery_matches_transport`: validation treats a response as streamed or upgraded exactly when the transport would take it; everything else is buffered and checked.
- `unclaimed_response_is_buffered`: a marker header with no registration behind it never exempts a response from its schema.
- `finalized_policies_keep_delivery`: response policies (CORS, secure headers) cannot set or remove the stream marker, so finalization hands a response over exactly when the hooks' response was handed over, unless the policies made it invalid, in which case the 500 replacing it is buffered.
- `finalization_sends_checked_response`: finalization applies the response policies before checking a buffered response, so the schema sees the final fields, and then sends the response it checked, unless development replaces it with a 500 that gets the same policies.
- `finalizers_only_stamp`: the request-ID and Server-Timing finalizers that run after validation add or replace only their own fields.
- `route_schemas_innermost`, `route_schemas_guard_innermost`, `route_schemas_group_innermost`: for every built table, route and slot, the schema used is the last declaration of that slot among the route's scopes, read outer to inner, directly, through a guard or through a group or mount prefix. A slot an inner scope leaves undeclared keeps the outer schema.
- `table_schemas_one_per_route`: the manifest's schema list has one entry per route registration.
- `table_schemas_in_source_order`: that list is the routes in source order, each with the raw schemas of its effective set, slot by slot.
- `undeclared_table_checks_nothing`: in a table that declares no schema, every route's schema set is empty, so serving it can skip the per-route schema lookup, the request check and the response check.
- `response_without_schema_is_sent_run`, `response_without_schema_is_sent_skip`: with or without the decoder, the response check sends a route's response unchanged when the route has no response schema, so finalization can skip building the check.
- `request_free_route_is_admitted_run`, `request_free_route_is_admitted_skip`: when a validator's own probe says a route's schemas check nothing in the request, its request check would have admitted the request with no decoded values. With the decoder that includes a route with only a response schema; without it, only a route with no schema at all, so `B.handle` still refuses a response-only route.
- `request_free_route_enters_cleared_run`, `request_free_route_enters_cleared_skip`: for every context, including one where earlier middleware stored decoded values through `C.with_values`, a route that skips the request step enters with exactly the context the step would have admitted: `C.without_values`, which clears those values. The later hooks and the handler see the same context either way.
- `no_values_entry_reads_unchanged`: for a context that carries no decoded values yet, admitting it with no values leaves the values a handler reads as they were. A route with no schema at all never ran the request step, before BND-96 or after, so values a hook stores there reach the handler unchanged.

## JSON Schema export

Each schema exports a JSON Schema 2020-12 document for OpenAPI and the typed
client. These laws are structural: they fix the keywords emitted for every
node kind. They do not prove that a standard validator accepts exactly what
the decoder accepts. That equivalence is tested, and it has known exceptions:
a validator accepts `1.0` and `1e0` for an integer, for example, while Bendo
rejects them. See [JSON Schema export](../data/json-schema.md#decoder-policy-and-validator-differences)
and [OpenAPI](../openapi.md).

- `json_schema_invalid_rejects_all`: an invalid schema, which the decoder rejects for every input, exports as `not: {}`, which accepts nothing.
- `json_schema_valid_exports_node`: a valid schema exports its node with the same function that exports every child, so the node laws below hold at every depth.
- `json_schema_type_keyword`: every node's `type` is the JSON type its kind requires; literal, enum, nullable and union nodes have none.
- `json_schema_object_node_exact`, `json_schema_string_node_exact`, `json_schema_boolean_node_exact`: object, string and boolean nodes are exactly the specification's, keys and order included, which rules out duplicate or contradictory keywords. A boolean node is only `{"type": "boolean"}`.
- `json_schema_object_properties`, `json_schema_required_keys`, `json_schema_unknown_keys`: an object lists every field's exported child under `properties`, requires exactly its required keys in order (optional and defaulted fields never), and sets `additionalProperties` to false for strict objects and true for stripping ones.
- `json_schema_string_min_length`, `json_schema_string_max_length`, `json_schema_string_pattern`, `json_schema_string_format`: a string node carries its lower bound, its upper bound when it has one, the ECMAScript source of its own pattern when it has one, and its format checks.
- `json_schema_string_wellformed`: every string node rejects lone surrogates, which the decoder never accepts.
- `json_schema_number_bounds`, `json_schema_integer_bounds`: number and integer nodes carry their bounds; an integer node also notes that only integer tokens are accepted, so `1.0` and `1e0` are rejected.
- `json_schema_array_items_bounds`, `json_schema_nullable_child`, `json_schema_union_members`: array, nullable and union nodes wrap their exported children as the specification says.
- `json_schema_literal_const`, `json_schema_enum_values`: a literal exports as `const`, and an enum lists its distinct values.
- `json_schema_empty_enum`, `json_schema_empty_union`: an empty enum or union exports as an always-false schema rather than the invalid `enum: []` or `anyOf: []`.
- `json_schema_default_annotation`, `json_schema_no_default`: a node gets a `default` only when its parent field declares one, and the annotation is the specification's.
- `json_schema_document_dialect`: a full document is the exported node with the 2020-12 dialect added as the specification says.

## Schemas in the route manifest

- `manifest_schema_rows`: attaching route schemas never changes the manifest's rows, so schemas are purely additive. See [route manifest](../manifest.md).
- `manifest_schema_positions`: schemas are positional: entry `i` belongs to registration `i` and appears on every row that registration prints, so duplicate registrations keep their own schemas.
- `manifest_schema_accepted`: attachment succeeds exactly when there is one entry per registration and every set slot holds a valid schema.
- `manifest_schema_documents`: each attached bundle serializes exactly its present slots as standalone 2020-12 documents, or reports the first slot that cannot be written.
