# 0002: Keep HTTP framing and bodies as bytes

Accepted for BND-4, 2026-10-22, Bend 2.0.38. This confirms design decision 2 in
[the plan](../PLAN.md). The prototypes are measurement instruments, not the M1
parser.

## Decision

M1 will read `TCP.recv_bytes` into `List<&2, U32>` and send bodies with
`TCP.send_bytes`. Each element represents one octet, constrained to 0–255;
Bend 2.0.38 Base has neither a `U8` nor a `Bytes` type. Keep framing offsets,
limits and `Content-Length` in octets. A body remains a `List<&2, U32>` until a
handler explicitly asks to decode it.

Use an ordered `List` of header records. A record holds a validated ASCII name
as a lowercase `String` and a value as `List<&2, U32>`, with surrounding optional
whitespace removed according to the HTTP grammar. Preserve repeated headers in
arrival order. Header values are octets, including permitted obs-text; do not
assume they are UTF-8. An ASCII accessor can return a `String` after validation.
The prototype converts ASCII fixture headers to a temporary `String` to extract
`Content-Length`; this is not the final header storage model.

A handler's text accessor should return a typed decoding result, such as
`Result<&2, &2, Utf8Error, String>`, from a pure strict UTF-8 decoder over the
complete body. Validate continuation bytes, overlong sequences, surrogates and
values above U+10FFFF. Base currently has no public UTF-8 encode/decode helper:
M1 must supply pure helpers, rather than treating `Char.from_u32(byte)` as UTF-8
decoding. A text response must UTF-8 encode once, count the resulting octets and
send those same octets. Lossy decoding, if offered later, must be explicit.

Keep the parser and decoder pure. Laws can quantify over byte lists with an
explicit 0–255 predicate, state that feeding any partition of an input produces
the same frame and unused suffix, and state that a successful frame consumes
exactly the declared byte count. Encoder/decoder laws can state that decoding an
encoded valid Unicode string returns that string. Header lookup laws can cover
ASCII case folding and preservation of repeated-value order. These are proposed
M1 laws, not proofs delivered by this experiment. No existing law changed.

## What was compared

Both native Bend implementations scan for CRLFCRLF, read the decimal
`Content-Length` from realistic ASCII headers, measure the accumulated body,
and echo it with an explicit response length. The byte candidate retains raw
body octets. The String candidate uses `TCP.recv` and `TCP.send`, and counts each
decoded scalar's UTF-8 width. This gives String a stronger comparison than
`String.length`, which counts characters and cannot frame a multibyte body by
`Content-Length`.

`fixtures.py` supplies a valid UTF-8 JSON object with a repeated message containing
`café`, `東京` and `😀` (96 octets), and `bytes(range(256)) * 2` (512 octets).
The latter includes NUL, every 0x80–0xFF value and invalid UTF-8. Requests include
method, target/query, Host, Content-Type, Content-Length, a request ID and
Connection. Pure fixtures use the same bytes, with the String binary fixture
already decoded with replacement, matching native `TCP.recv` on an unsplit read.

The parsers deliberately accept only the fixture's framing subset. They are not
HTTP conformance implementations: no chunking, pipelining, rejection matrix,
limits or timeouts. Each connection closes after one response. They accumulate
and rescan on each receive; M1 should retain incremental state and leave bytes
after a complete body for the next request. Throughput here chooses a
representation; it does not predict the finished framework's capacity.

## Correctness

Run from the repository root:

```sh
prototypes/0002-bytes/build.sh
timeout 60 python3 prototypes/0002-bytes/correctness.py
```

The script starts both actual native servers, sends raw POSTs, compares the echo
byte for byte, checks the response Content-Length against emitted and original
bytes, and terminates every process. It tests whole writes, seven-byte body
writes separated by 2 ms, `RECV_MAX=7`, and `RECV_MAX=1`. The one-byte receive
limit guarantees separate calls inside multibyte sequences regardless of TCP
coalescing. Client writes use TCP_NODELAY.

All eight byte-mode combinations preserve the complete body and original length:
96/96 for JSON and 512/512 for binary. String preserves unsplit JSON, but an
unsplit binary receive returns 1,024 bytes instead of 512. Split JSON returns
101 bytes rather than 96; split binary returns 515 rather than 512. With
one-byte receives, output lengths can equal the original lengths while content
is still wrong. The script checks content as well as length for that reason.

Native `TCP.recv` calls the runtime's `io_str` separately for each read.
`io_str` replaces invalid or unfinished UTF-8 with U+FFFD; it keeps no decoder
state between reads. `TCP.send` UTF-8 encodes the replacement characters.
Counting their byte widths cannot recover discarded octets, and can mistake a
partial body for a complete one. NUL itself survives: invalid UTF-8 and read
boundaries cause the observed corruption. A hybrid that reads bytes and only
decodes headers after framing is compatible with this decision, but using
`TCP.recv` for body data is not.

These figures describe the observed fixture runs, not every possible network
schedule. The script asserts byte preservation on every byte case and String
corruption for binary and one-byte receives. Other String JSON cases are
observations, since a whole write may fragment and split writes may coalesce. Exact split failure sizes can change if receive coalescing changes;
byte preservation must not change.

## Measurements

Measured on 2026-10-22 (2026-10-23 UTC) in Boat default sandbox
`bx_qnpnhjs6`: four virtual CPUs on an AMD Ryzen 9 9950X, 8,322,519,040 bytes
of visible RAM, Ubuntu 24.04.4 LTS, x86-64, clang 18.1.3, Bend 2.0.38 and
oha 1.14.0. No HTTP load ran on ms-a2. The complete `boat.sh` workflow was also rerun
in `bx_f3m5qsbc`; both sandboxes were deleted after measurement. These are medians of three samples.

| Input | Bytes pure parses/s | String pure parses/s | Bytes HTTP req/s | String HTTP req/s |
| --- | ---: | ---: | ---: | ---: |
| UTF-8 JSON, 96 octets | 96,618 | 117,647 | 30,403 | 34,440 |
| Binary, 512 octets | 89,286 | 105,263 | 26,100 | 29,710 |

Pure elapsed milliseconds for 20,000 parses, in sample order:

- Bytes JSON: 206, 207, 208; binary: 234, 222, 224.
- String JSON: 174, 170, 170; binary: 199, 186, 190.

HTTP requests/s in sample order:

- Bytes JSON: 29,087, 31,681, 30,403; binary: 25,973, 26,100, 27,908.
- String JSON: 35,284, 31,740, 34,440; binary: 29,710, 29,779, 28,990.

Every HTTP sample had successRate 1, only status 200 and an empty error
map. Each String binary response contained 1,024 bytes, so its apparent speed
is not useful binary serving throughput. Both JSON pure checksums were
3,840,000; binary checksums were 20,480,000 for bytes and 30,720,000 for String,
reflecting the corrupted body's larger re-encoded length.

String was faster in this prototype: roughly 22% for JSON pure parsing and 13%
for JSON HTTP serving. Byte mode's temporary header conversion and its
`List.length`/`U32.from_nat` body traversal contribute to the difference; this
is not a fundamental lower bound for byte parsing. Correctness decides the
choice: the faster candidate loses data, including valid UTF-8 split across
reads. Keep bytes and optimize the measured costs during M1.

## Reproduce in Boat

Prerequisites: the repository's pinned Bend toolchain under `~/.bend`, Python 3,
`clang`, `boat`, and `boat-sbx` on the controlling machine. No TypeScript files,
root package scripts, production sources or test configuration are changed.

```sh
export PATH="$HOME/.bend/bin:$HOME/.elan/bin:$HOME/.bun/bin:$PATH"
bun install --frozen-lockfile
# Creates one default sandbox, installs pinned oha, runs both checks and measures,
# then deletes that sandbox through an EXIT trap, including command failures.
prototypes/0002-bytes/boat.sh > /tmp/bnd4-reproduction.log 2>&1
```

`boat.sh` transfers the installed Bend 2.0.38 toolchain rather than fetching an
unversioned installer. `build.sh` refuses any other version. It downloads the
Linux amd64 oha 1.14.0 release. The VM needs Ubuntu's clang and Python 3.
`measure.py` invokes each native benchmark three times with
`+RTS --threads 1`; each fixture is parsed 20,000 times in-process. It prints
elapsed monotonic milliseconds and a checksum using both parsed and actual body
lengths. Inputs and outputs remain live across loop iterations. Compilation and
input decoding are outside this pure timing; allocation, scanning, ASCII header
conversion and body-length traversal are inside it.

HTTP samples run sequentially, three per variant/body, alternating server order
between rounds. Each starts the same native server with one Bend runtime thread,
`RECV_MAX=65536` and port 18784. oha and the server run in the same VM over
loopback. Its exact command, with a temporary file containing one fixture, is:

```sh
/home/user/oha --no-tui --disable-keepalive --output-format json \
  -c 16 -z 3s -w -t 3s -m POST -T application/json \
  -D "$payload" 'http://127.0.0.1:18784/echo?source=prototype'
# Binary uses -T application/octet-stream and the binary fixture file instead.
```

Connection setup/close, body reads, parsing, response construction and writes are
included in HTTP timing. oha success means a complete HTTP response, not a
correct echo; String binary throughput measures corrupted output. The independent
correctness script supplies the byte comparison. `-w` drains requests at the
deadline; `-t 3s` bounds each request. The outer measurement timeout is 180 seconds.

Inside an already prepared isolated VM, the exact entry points are:

```sh
./build.sh
timeout 60 python3 correctness.py
timeout 180 python3 measure.py
```

Never run `measure.py` on the shared server. Hardware, VM contention and TCP
scheduling change results; reproduce the method and correctness guarantees,
not an identical requests-per-second value.
