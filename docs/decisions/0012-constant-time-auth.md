# 0012: What "constant-time" means for Bendo's auth middleware

Date: 2026-10-23. Issue: BND-43. Status: accepted for M5.

Basic auth, bearer auth and JWT verification compare a secret value supplied
by the client with one the server knows. A comparison that stops at the first
differing byte lets an attacker learn a secret one byte at a time by timing
responses. Bendo's comparisons are written so the algorithm has no such early
exit. The runtime does not promise more than that, and this decision records
the gap.

## What the code does

`src/crypto/compare.bend`'s `ct_equal` walks both lists to the end, XORs each
pair of elements and ORs the result into one accumulator. It only inspects the
accumulator after the walk. Unequal lengths add a nonzero difference and keep
walking the longer list.

The middleware never feeds raw secrets to it:

- Basic auth compares `SHA-256(user) ++ SHA-256(password)` of the request with
  the same 64 bytes for each configured user. Username and password are
  checked in one comparison, so a correct username does not take a different
  path than a wrong one.
- Bearer auth compares `SHA-256(token)` with the digest of each configured
  token.
- JWT compares the token's signature segment with the base64url encoding of the
  HMAC-SHA256 tag it computes. The tag is always 43 characters. A signature
  segment of another length is still walked to its end. Its length is not secret.

Hashing fixes the lengths passed to the basic and bearer comparison loops at 32
bytes per digest. Hashing itself can depend on secret length. Each configured
entry's result is folded with `U32.or`, which evaluates both operands;
`Bool.or` would skip the rest after the first match.

## What is proven

`ct_equal_spec` in `LAWS.bend` proves that `ct_equal` returns exactly the result
of an independent element-wise equality, for every pair of lists. This is
functional correctness: the comparison accepts exactly the equal inputs. The
JWT laws `jwt_open_seal` and `jwt_rejects_bad_signature` build on it.

No law states anything about time. Bend's laws describe values, not cost.

## What is not guaranteed

- Bend's compiler and runtime make no constant-time promise. The compiler
  emits its own C and JavaScript, and nothing promises that source without an
  early exit stays free of data-dependent branches or allocation. No one has
  measured the native or JavaScript output for timing differences.
- SHA-256 and HMAC run in pure Bend. Their running time depends on input length,
  which is public for tokens and headers, but nobody has audited the code for
  data-dependent branches.
- The number of configured users or tokens, and the length of the supplied
  header, affect total time.
- Base64 decoding and UTF-8 checks in basic auth run before the comparison and
  may exit early on malformed input. That reveals whether the input was well
  formed, not anything about the stored secret.

## Why accept this

The common attack, comparing byte by byte until the first mismatch, does not
apply: no comparison exits early, and digests make the compared bytes
unpredictable to the client. A stronger guarantee would require an audited
native comparison effect outside the proofs (decision 6 in the plan allows
Bendo to ship its own effects). If timing measurements on a Boat sandbox ever
show a data-dependent difference, that effect is the fix. Until then, docs
describe the comparison as best effort and never as constant-time execution.
