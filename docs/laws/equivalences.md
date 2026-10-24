# Equivalence laws

About a quarter of Bendo's laws do not state a new guarantee. Each says that a
rewritten function computes exactly what an earlier definition computed, for
every input. The earlier definition is kept in the source (usually with a
`_spec` suffix, sometimes a Base function or a model), and the other laws were
proven against it. The equivalence carries every one of those laws over to the
code that actually runs.

For an app author the result is simple: the fast or stack-safe version behaves
exactly like the straightforward one. The laws say nothing about speed or stack
depth themselves. Benchmarks and the stack tests (`tests/review-stack.test.ts`,
`tests/routing-stack.test.ts`) check those. See the [laws index](README.md) for
how to read an entry.

## Hot-path rewrites

BND-68 rewrote the code on every request's path for speed. Each `hot_*` law
says the rewrite equals the retained definition for every input. See
[decision 0014](../decisions/0014-performance.md).

- `hot_utf8_encode_char`, `hot_response_utf8`, `hot_bytes_tchar`: UTF-8 encoding of a character and of a response string, and the HTTP token-character test.
- `hot_context_text`, `hot_context_html`, `hot_context_json_result`: the context's text, HTML and JSON response builders.
- `hot_connection_header_hit`: matching one `Connection` header token.
- `hot_body_head_feed`, `hot_body_head_feed_policy`: the request-head scan inside the body reader, for the default limit policy and for any policy type, selector and value.
- `hot_cors_middleware`, `hot_cors_actual`, `hot_cors_policy`: the CORS middleware runs the earlier sequence (a preflight is answered without calling the next handler; any other request runs it and is decorated), and the single policy it retains per request is the one the response used to be built with.
- `hot_secure_prepared`, `hot_secure_prepared_spec`, `hot_secure_dispatch`, `hot_secure_dispatch_registration`: secure headers now run a policy prepared at registration; that shell, and the registration that uses it, behave exactly like the earlier per-request middleware and registration, for any Server-Timing and JWT templates in the dispatcher.

## Tail-loop rewrites

BND-84 rewrote every helper that walks a request-sized string or byte list as a
tail loop, so a 64 KiB input cannot overflow the JavaScript stack in `.mjs`
builds. Each `tail_*` law equates a loop with its earlier direct recursion or
with the Base function it replaces. The laws ending in `_go` state what the
loop's accumulator means, for example that lowering a reversed string onto an
accumulator gives the lowered string followed by the accumulator.

- `tail_text_split`, `tail_text_lower`, `tail_text_lower_go`, `tail_text_upper`, `tail_text_upper_go`, `tail_text_join`, `tail_text_join_go`, `tail_text_cut`: string splitting, ASCII case mapping, joining and cutting at a separator.
- `tail_text_bytes_append`, `tail_text_list_append`, `tail_text_length`, `tail_text_length_go`: list append and length.
- `tail_bytes_encode`, `tail_bytes_encode_go`, `tail_bytes_ascii`, `tail_bytes_ascii_go`, `tail_bytes_append`, `tail_bytes_fold`: string-to-byte encoding, byte-to-ASCII decoding, byte append and ASCII lowercase folding.
- `tail_bytes_token_tail`, `tail_bytes_token_go`, `tail_bytes_value`, `tail_bytes_value_go`, `tail_bytes_uri`, `tail_bytes_uri_go`, `tail_bytes_split_target`: the token, header-value and URI checks and the path/query split of the request parser.
- `tail_parse_field`, `tail_request_lookup_folded`: splitting a header line into name and value, and header lookup by folded name.
- `tail_media_before_params`, `tail_media_before_params_go`: reading a media type up to its parameters.
- `tail_connection_tokens`, `tail_connection_has_token`: finding a `Connection` token.
- `tail_errors_parameters`, `tail_errors_accepts_json_tokens`: the `Accept` checks used for error negotiation.
- `tail_utf8_valid`: the Unicode scalar check.
- `tail_origin_cut`, `tail_origin_authority`, `tail_origin_digits`, `tail_origin_name_chars`, `tail_origin_ipv6_chars`: the pieces of the origin parser.
- `tail_jwt_split`, `tail_jwt_dotfree`, `tail_jwt_dotfree_go`, `tail_jwt_codes`: splitting a token and checking its segments.
- `tail_ip_split`, `tail_ip_all_digits`, `tail_ip_all_digits_go`, `tail_ip_all_hex`, `tail_ip_all_hex_go`, `tail_ip_has`, `tail_ip_has_go`, `tail_ip_groups`, `tail_ip_groups_go`, `tail_ip_doubles`: the IP address parser.
- `tail_conn_strip_lead`, `tail_conn_strip_trail`, `tail_conn_entry_texts`, `tail_conn_entries`, `tail_conn_walk_entries`: reading and walking `X-Forwarded-For` entries.
- `tail_conditional_opaque`, `tail_conditional_segments`, `tail_conditional_segments_go`, `tail_conditional_members`: parsing `If-None-Match` lists.
- `tail_auth_cut`, `tail_auth_escape`, `tail_auth_escape_go`, `tail_bearer_body`: splitting and escaping in the auth middleware, and the bearer token check.
- `tail_cors_tokens`, `tail_cors_request_texts`: reading CORS header token lists.
- `tail_trailing_clean`, `tail_trailing_trim_last`, `tail_trailing_final_slash`: the trailing-slash path checks.
- `tail_websocket_has_element`, `tail_websocket_listed`, `tail_websocket_zeros`, `tail_websocket_has_offer`, `tail_websocket_offered_any`: the WebSocket handshake's header checks.

## Review rewrites

The BND-84 review found more helpers to convert. Each `review_*` law equates
one with its retained recursive definition, with no restriction on the input.

- `review_j_nonzero`, `review_j_zeros`: digit-string helpers in the JWT module.
- `review_m_texts`, `review_m_field_values`: reading method-override values from headers and multipart fields.
- `review_h_named`, `review_h_strip_lead`, `review_h_strip_trail`, `review_h_commas`, `review_h_token_names`, `review_h_listed`, `review_h_listed_pick`, `review_h_keep_all`: the proxy's hop-by-hop header filter.
- `review_u_named`, `review_u_without`, `review_u_ascii_values`, `review_u_quote_chars`, `review_u_sane_all`, `review_u_lengths`, `review_u_same_length`, `review_u_all_values`, `review_u_coding`, `review_u_chain`: the proxy's upstream request head and its parsing and framing of the upstream response.
- `review_write_headers`, `review_text_concat`, `review_text_take`: writing a header list, list concatenation and taking a string prefix.

## Stack-safe routing

The same conversion for the router, URL encoding and the static resolver. Each
`*_stack_safe` law equates the loop with its recursive original, or, for the
static resolver, with the model the static laws were proven against.

- `utf8_decode_stack_safe`, `url_scalars_stack_safe`, `url_encode_stack_safe`, `url_unescape_stack_safe`, `url_decode_stack_safe`: UTF-8 decoding and URL percent-encoding.
- `constraint_digits_stack_safe`, `constraint_slug_stack_safe`, `constraint_uuid_stack_safe`, `constraint_class_stack_safe`: route parameter constraints.
- `pattern_segments_stack_safe`, `pattern_join_stack_safe`, `pattern_decode_segments_stack_safe`, `pattern_empty_rows_stack_safe`, `pattern_rows_stack_safe`, `pattern_span_stack_safe`: path splitting and matching inside the pattern matcher.
- `routing_options_stack_safe`: path adaptation for non-default routing options.
- `static_resolve_stack_safe`, `static_target_stack_safe`: the static path resolver and the open target.
- `legacy_path_of_stack_safe`: the original `Http.path_of` helper.

## Proof building blocks

A few general facts are stated in `LAWS.bend` because other proofs use them.
They say nothing about HTTP.

- `append_nil`, `reverse_twice`, `reverse_go_twice`: appending an empty list changes nothing, reversing twice restores a list, and two accumulator reversals compose by appending.
- `and_left`, `and_right`: a true conjunction has both sides true.
- `u32_eq_sound`, `word_eq_sound`, `string_eq_sound`: when the equality test on 32-bit numbers, fixed-width words or strings says equal, the values are equal.
- `word_cmp_self`: a word compares equal to itself.
- `cmp_fin_tail`, `cmp_step_tail`: an equal word or string comparison has an equal comparison of the remaining part.
