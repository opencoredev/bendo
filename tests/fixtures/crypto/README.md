# Crypto test vectors

The four `.rsp` files are unmodified SHA-1 and SHA-256 byte-oriented short-
and long-message vectors from NIST CAVP's
[SHS byte test vectors](https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/shs/shabytetestvectors.zip)
(downloaded 2026-10-22). The tests run every `Len/Msg/MD` entry: 65 short
and 64 long messages per algorithm, 258 vectors in total. A zero-length
message uses `Msg = 00` as a placeholder; the input is empty.
These are known-answer tests, not CAVP certification or Monte Carlo tests.

`hash-vectors.json` adds empty, `abc`, the standard 448-bit and 896-bit
messages, and one million ASCII `a` characters. Sources:
[FIPS 180-4](https://doi.org/10.6028/NIST.FIPS.180-4) and NIST's
[secure hashing examples](https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines/example-values).
The JSON contains literal expected digests; tests do not derive them from
Bendo's implementation.

`hmac-vectors.json` transcribes all seven
[RFC 4231 section 4](https://www.rfc-editor.org/rfc/rfc4231#section-4)
HMAC-SHA256 test cases. Case 5 checks the first 128 bits; the library always
returns the full 256-bit tag. Base64 examples in `crypto.test.ts` come from
[RFC 4648 section 10](https://www.rfc-editor.org/rfc/rfc4648#section-10).
Seeded differential tests also compare encodings and digests with Bun's
independent implementations, including inputs around padding boundaries.

`entropy-fail.c` is test-only `LD_PRELOAD` fault injection for Linux: it
makes `getrandom` return `-1` with `errno = EIO`. It is never linked into
Bendo. The test checks that the public IO API returns that error and that
a zero-byte request succeeds without calling the entropy source.
