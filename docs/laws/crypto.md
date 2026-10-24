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
