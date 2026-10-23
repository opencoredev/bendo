# Crypto and encoding primitives

Import the modules directly. Byte values use `List<&2, U32>` and must lie
between 0 and 255. `src/crypto/octets.bend` exposes `valid` to check that
precondition. Convert a Unicode scalar string to bytes with
`src/data/utf8.bend`'s `encode`; hashes operate on those UTF-8 octets.

```python
import Base
import ../src/data/utf8.bend as Utf8
import ../src/data/hex.bend as Hex
import ../src/crypto/sha256.bend as SHA256

def digest(text: String) -> String:
  Hex.encode(SHA256.hash(Utf8.encode(text)))
```

`src/data/hex.bend` exports `encode(bytes) -> String` and
`decode(text) -> Maybe<&2, List<&2, U32>>`. Encoding emits lowercase;
decoding accepts either case and rejects invalid characters or odd lengths.

`src/data/base64.bend` exports `encode(bytes, url, padded) -> String` and
`decode(text, url, padded) -> Maybe<&2, List<&2, U32>>`. Set `url` to
`True{}` for `-` and `_`, or `False{}` for `+` and `/`. Set `padded` to
`True{}` to emit and require trailing `=` when the final group needs it;
`False{}` omits and rejects padding. Decoding rejects whitespace, mixed
alphabets, misplaced padding, and nonzero unused bits. Empty input is valid
in every mode. Both encoding modules have strict-kernel roundtrip proofs
for every octet list; Base64's law quantifies both flags.

`src/crypto/sha1.bend` and `sha256.bend` each export
`hash(bytes) -> List<&2, U32>`, returning 20 and 32 bytes respectively in
big-endian order. Both implement FIPS 180-4 in pure Bend. SHA-1 exists for
protocol compatibility, including WebSocket accept keys; use SHA-256 or
HMAC-SHA256 for new authentication code.

`src/crypto/hmac.bend` exports
`sha256(key, message) -> List<&2, U32>`. It returns all 32 tag bytes,
including when a protocol later truncates the tag. Keys longer than 64
bytes are hashed before padding, as RFC 2104 requires.

`src/crypto/compare.bend` exports `ct_equal(a, b) -> Bool`. It visits every
element of both lists and accumulates differences without an early mismatch
exit, including when lengths differ. This is best effort: Bend's compiler
and runtime do not promise constant-time execution. Length, allocation,
and runtime behavior remain observable. The `ct_equal_spec` law proves it
returns exactly element-wise equality; decision
[0012](decisions/0012-constant-time-auth.md) covers what that does not promise.

`src/crypto/jwt.bend` signs and verifies HS256 JSON Web Tokens. `seal` and
`open` work on raw header and payload octets and carry the laws
`jwt_open_seal` and `jwt_rejects_bad_signature`. `sign(secret, claims)` and
`verify(secret, token, now, leeway)` add the JSON header, `alg` and time-claim
checks. See [authentication middleware](auth.md).

`src/crypto/random.bend` exports
`random_bytes(n: Nat) -> IO(Result<&1, &1, RandomError(), List<&2, U32>>)`,
where `RandomError()` is `U32 & String`. A successful result contains exactly
`n` octets. Zero requests no entropy; otherwise each byte takes the low
octet of one `IO.random_u32` word. There is no PRNG fallback and no
`IO.try` process exit. On Linux, a failed `getrandom` returns its original
`(errno, strerror)` as `Fail`; bytes already collected are discarded. On
macOS, Base uses `arc4random_buf`, which has no recoverable failure return.
Base's JavaScript twin uses WebCrypto and maps exceptions, including an
unavailable WebCrypto host, to `EIO` (5). Callers must handle `Fail`.

Run `bun test tests/crypto.test.ts` for native and JavaScript known-answer
checks, differential tests, and native entropy failure injection. Run
`bun run prove` for the universal encoding laws. Vector sources are listed
in `tests/fixtures/crypto/README.md`.

For a bounded native SHA-256 benchmark, compile
`tests/fixtures/crypto/benchmark.bend` and run the binary once. It allocates
1,000,000 ASCII `a` bytes before the start clock, hashes them, reads `IO.now`
again, then prints the full digest and elapsed milliseconds. The public
hash and encoding paths use tail-recursive input loops so compiling to
`.mjs` does not grow the JavaScript stack with message length.
