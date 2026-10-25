# Crypto and JWT laws

These laws cover the hex and base64 codecs, constant-time comparison and HS256
JSON Web Tokens. See the [laws index](README.md) for how to read an entry, and
[crypto and encoding primitives](../crypto.md) and
[authentication](../auth.md) for the features.

No law states that SHA-1, SHA-256 or HMAC compute the right digest. Those
primitives are checked against the NIST and RFC test vectors in
`tests/crypto.test.ts`. The JWT laws below use HMAC as given and say what the
token code does with it.

## Encodings and comparison

- `hex_roundtrip`: decoding the hex encoding of any byte list (every element at most 255) gives back the bytes.
- `base64_roundtrip`: the same for base64 in all four RFC 4648 modes: standard or URL alphabet, each with or without padding.
- `ct_equal_spec`: the constant-time comparison returns exactly element-wise equality for every pair of lists of any lengths. The law covers its result, not its timing.

## JSON Web Tokens

A token is three dot-separated segments: header, payload and an HS256
signature. `open` checks shape, signature and encoding; `verify` adds the JSON,
algorithm and claim checks. These laws say a token sealed with a secret opens
to exactly its contents, and that each kind of bad token fails, for every
secret, time and leeway rather than sample tokens.

- `jwt_open_seal`: opening a token sealed with the same secret returns exactly the sealed header and payload bytes.
- `jwt_rejects_malformed`: a token that does not have exactly two dots is `Malformed`, whatever the secret.
- `jwt_rejects_bad_signature`: a three-segment token whose signature is not the unpadded base64url HMAC-SHA256 of `header.payload` under the secret is `BadSignature`.
- `jwt_rejects_bad_encoding`: a token with the correct signature whose header or payload is not strict unpadded base64url (alphabet, length and unused bits) is `BadEncoding`. The signature is checked first.
- `jwt_verify_keeps_open_failure`: every failure of `open` is returned by `verify` unchanged.
- `jwt_verify_rejects_non_object_header`, `jwt_verify_rejects_non_object_payload`: a header or payload that decodes to bytes that are not a JSON object never verifies.
- `jwt_verify_rejects_repeated_header_member`, `jwt_verify_rejects_repeated_claim`: a header or payload object with two top-level members of the same name never verifies.
- `jwt_verify_rejects_bad_alg`: a header object without exactly one `alg` member holding the string `HS256` never verifies, whether `alg` is missing, repeated, not a string or another algorithm.
- `jwt_verify_bad_alg_exact`: with canonical segments, the correct signature and no repeated header member, such a header fails with exactly `BadAlgorithm`.

### Empty keys

The laws above hold for every secret, including the empty one, because they
describe the raw `Jwt.open` and `Jwt.verify`. HMAC under an empty key is no
secret at all, so the configured entry points (`B.jwt`, `B.jwt_with`,
`B.jwt_verify`, `B.jwt_sign` and `B.jwt_signed`) refuse it. These laws are in
`proof/jwt-key-laws.bend`.

- `jwt_empty_key_verifies_nothing`: under an empty key no token verifies, even in a config built directly with the constructor. Every token fails with `BadSignature`.
- `jwt_empty_key_signs_nothing`: under an empty key no claim set is signed. Signing fails with `BadEncoding`.
- `jwt_empty_secret_has_no_key`: the empty string secret gives no key, like a secret with no UTF-8 form.
- `jwt_nonempty_key_verifies_as_jwt`, `jwt_nonempty_key_signs_as_jwt`: a key with at least one byte verifies and signs exactly as `Jwt.verify` and `Jwt.sign` do, so the laws above apply to it unchanged.
