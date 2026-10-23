# serve_static: the IO shell around the pure static modules (BND-45).
# Path resolution, ranges, MIME types and entity tags are pure; this file
# only opens, reads, streams and closes the file. See docs/static.md.
import Base
import ../app/context.bend as C
import ../app/errors.bend as Errors
import ../app/observability.bend as Observation
import ../stream.bend as Stream
import ../http/stream_types.bend as T
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/date.bend as HttpDate
import ../http/etag.bend as Etag
import ../effects/static_file.bend as StaticFile
import ../router/encoding.bend as E
import ./path.bend as Path
import ./range.bend as Range
import ./mime.bend as Mime

# root: the directory to serve, absolute or relative to the working directory.
# prefix: the mount path stripped from the request path, "" at the site root.
# index: the file served for a path ending in '/', "" for none.
# buffer_bytes: the largest body read into memory and sent with a
# Content-Length. A longer body streams in 64 KiB reads.
# cache_control: an optional Cache-Control value for served files.
type Options is Data:
  Options{root: String, prefix: String, index: String, buffer_bytes: Nat, cache_control: Maybe<&2, String>}

def defaults(root: String) -> Options:
  Options{root, "", "index.html", 1048576n, None{}}

def mounted(options: Options, prefix: String) -> Options:
  Options{root, old, index, max, cache} = options
  Options{root, prefix, index, max, cache}

def with_index(options: Options, index: String) -> Options:
  Options{root, prefix, old, max, cache} = options
  Options{root, prefix, index, max, cache}

def with_buffer_bytes(options: Options, max: Nat) -> Options:
  Options{root, prefix, index, old, cache} = options
  Options{root, prefix, index, max, cache}

def with_cache_control(options: Options, value: String) -> Options:
  Options{root, prefix, index, max, old} = options
  Options{root, prefix, index, max, Some{value}}

def chunk() -> Nat: 65536n

# Reading: pure bookkeeping between reads, so the IO loop never branches.
type Reading is Data:
  Reading{next: Nat, left: Nat, pending: Nat, chunks: List<&2, List<&2, U32>>}
  Broken{}

def absorb_bytes(+bytes: List<&2, U32>, next: Nat, left: Nat, +pending: Nat, chunks: List<&2, List<&2, U32>>) -> Reading:
  E.choose(Reading, Nat.is_eq(List.length(&2, U32, bytes), pending), u => Reading{next, left, 0n, bytes <> chunks}, u => Broken{})

# A read must return exactly the bytes requested; a short read means the
# file shrank after it was measured.
def absorb(r: Result<&1, &1, U32 & String, List<&2, U32>>, s: Reading) -> Reading:
  match r s:
    case Fail{e} _: Broken{}
    case Done{bytes} Broken{}: Broken{}
    case Done{bytes} Reading{next, left, pending, chunks}: absorb_bytes(bytes, next, left, pending, chunks)

def request(+left: Nat) -> Nat:
  E.choose(Nat, Nat.is_lt(left, chunk()), u => left, u => chunk())

def plan(s: Reading) -> Reading:
  match s:
    case Broken{}: Broken{}
    case Reading{+next, +left, pending, chunks}:
      +size = request(left)
      Reading{Nat.add(next, size), Nat.sub(left, size), size, chunks}

def offset(+s: Reading) -> U32:
  match s:
    case Broken{}: 0
    case Reading{next, left, pending, chunks}: U32.from_nat(Nat.sub(next, pending))

def amount(+s: Reading) -> U32:
  match s:
    case Broken{}: 0
    case Reading{next, left, pending, chunks}: U32.from_nat(pending)

def finish(s: Reading) -> Result<&1, &1, U32 & String, List<&2, U32>>:
  match s:
    case Broken{}: Fail{(5, "short read")}
    case Reading{next, 0n, pending, chunks}: Done{List.concat(&2, U32, List.reverse(&2, List<&2, U32>, chunks))}
    case Reading{next, 1n+l, pending, chunks}: Fail{(5, "short read")}

# k is the number of reads still to make. Each step folds the previous
# read's result into the state, then issues the next read.
def read_go(k: Nat, got: File & Result<&1, &1, U32 & String, List<&2, U32>>, s: Reading) -> IO(File & Result<&1, &1, U32 & String, List<&2, U32>>):
  match k:
    case 0n:
      (file, r) = got
      IO.pure(File & Result<&1, &1, U32 & String, List<&2, U32>>, (file, finish(absorb(r, s))))
    case 1n+j:
      (file, r) = got
      +planned = plan(absorb(r, s))
      do IO<File & Result<&1, &1, U32 & String, List<&2, U32>>>:
        next : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_at(file, offset(planned), amount(planned))
        read_go(j, next, planned)

# Bytes start..start+length-1, read in 64 KiB chunks.
def read_range(file: File, start: Nat, +length: Nat) -> IO(File & Result<&1, &1, U32 & String, List<&2, U32>>):
  read_go(Nat.div(Nat.add(length, Nat.sub(chunk(), 1n)), chunk()), (file, Done{[]}), Reading{start, length, 0n, []})

# Streaming: the producer owns the file and reads the next chunk only when
# the previous one has been sent. Cleanup closes the file exactly once,
# whether the stream ends, fails, is cancelled or is never pulled (HEAD).
type Pump is Type:
  Pump{file: File, next: Nat, left: Nat}

def pump_chunk(file: File, +next: Nat, +left: Nat, +size: Nat, bytes: List<&2, U32>, full: Bool) -> T.Step<Pump>:
  match full:
    case True{}: T.Chunk{bytes, Pump{file, Nat.add(next, size), Nat.sub(left, size)}}
    case False{}: T.Failed{Pump{file, next, left}}

# A short read means the file shrank after it was measured.
def pump_result(file: File, +next: Nat, +left: Nat, +size: Nat, r: Result<&1, &1, U32 & String, List<&2, U32>>) -> T.Step<Pump>:
  match r:
    case Fail{e}: T.Failed{Pump{file, next, left}}
    case Done{+bytes}: pump_chunk(file, next, left, size, bytes, Nat.is_eq(List.length(&2, U32, bytes), size))

def pumped(+next: Nat, +left: Nat, +size: Nat, got: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> T.Step<Pump>:
  (file, r) = got
  pump_result(file, next, left, size, r)

def pump_at(file: File, +next: Nat, left: Nat) -> IO(T.Step<Pump>):
  match left:
    case 0n: IO.pure(T.Step<Pump>, T.End{Pump{file, next, 0n}})
    case 1n+(+l):
      +size = request(1n+l)
      do IO<T.Step<Pump>>:
        got : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_at(file, U32.from_nat(next), U32.from_nat(size))
        return pumped(next, 1n+l, size, got)

def pump_step(p: Pump) -> IO(T.Step<Pump>):
  match p:
    case Pump{file, next, left}: pump_at(file, next, left)

def pump_close(p: Pump) -> IO(Unit):
  match p:
    case Pump{file, next, left}: File.close(file)

# Request fields.

def ascii(bytes: List<&2, U32>) -> String:
  match bytes:
    case Nil{}: SNil{}
    case b <> t: SCon{Chr{b}, ascii(t)}

def ascii_all(values: List<&2, List<&2, U32>>) -> List<&2, String>:
  match values:
    case Nil{}: []
    case v <> t: ascii(v) <> ascii_all(t)

def path_of(-Vars: Data, c: C.Ctx<Vars>) -> String:
  C.path(Vars, c)

def strip_prefix(+prefix: String, +path: String) -> Maybe<&2, String>:
  E.choose(Maybe<&2, String>, String.starts_with(path, prefix), u => Some{String.drop(path, String.length(prefix))}, u => None{})

def ends_slash(+s: String) -> Bool:
  String.ends_with(s, "/")

def get_or_head(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: True{}
    case Request.Head{}: True{}
    case _: False{}

# Responses.

def not_found(-Vars: Data, c: C.Ctx<Vars>) -> IO(Response.Res):
  IO.pure(Response.Res, C.not_found(Vars, c))

def failure(-Vars: Data, c: C.Ctx<Vars>, code: U32) -> IO(Response.Res):
  IO.pure(Response.Res, C.error(Vars, c, Errors.http_error(code, "")))

def query_of(r: Request.Req) -> String:
  Request.Req{m, p, q, v, hs} = r
  Request.query_text(q)

def query_suffix(-Vars: Data, c: C.Ctx<Vars>) -> String:
  query_of(C.request(Vars, c))

# A directory requested without its trailing slash moves to the slash form,
# so relative URLs inside its index resolve against the directory.
def directory(-Vars: Data, +c: C.Ctx<Vars>, +rest: String, +index: String) -> IO(Response.Res):
  E.choose(IO(Response.Res), ends_slash(rest) || String.is_empty(index), u => not_found(Vars, c), u => (
    IO.pure(Response.Res, C.redirect_status(Vars, c, path_of(Vars, c) ++ "/" ++ query_suffix(Vars, c), 301))
  ))

def server_error(+code: U32) -> Bool:
  U32.is_eq(code, 5) || U32.is_eq(code, 12) || U32.is_eq(code, 23) || U32.is_eq(code, 24) || U32.is_eq(code, 27)

def open_failed(-Vars: Data, +c: C.Ctx<Vars>, +rest: String, +index: String, +code: U32) -> IO(Response.Res):
  E.choose(IO(Response.Res), U32.is_eq(code, 21), u => directory(Vars, c, rest, index), u => (
    E.choose(IO(Response.Res), server_error(code), u => failure(Vars, c, 500), u => not_found(Vars, c))
  ))

def headers_of(-Vars: Data, c: C.Ctx<Vars>) -> List<&2, Request.Header>:
  C.Ctx{r, p, b, q, s, hs, v, o} = c
  hs

def maybe_header(-Vars: Data, c: C.Ctx<Vars>, name: String, value: Maybe<&2, String>) -> C.Ctx<Vars>:
  match value:
    case None{}: c
    case Some{v}: C.header(Vars, c, name, v)

def nonempty(+s: String) -> Maybe<&2, String>:
  E.choose(Maybe<&2, String>, String.is_empty(s), u => None{}, u => Some{s})

# Validators exist only for a settled file, one whose mtime and ctime are at
# least two seconds old (see static_file.bend). A file still being written
# gets no ETag or Last-Modified and every conditional field is ignored, so a
# change within the same second can never produce a stale 304.
# changed is the later of mtime and ctime, in seconds.
type Validators is Data:
  Settled{tag: String, modified: String, mtime: Nat, changed: Nat}
  Unsettled{}

def validators_of(stamp: Maybe<&2, String>, +mtime: Nat, changed: Nat) -> Validators:
  match stamp:
    case None{}: Unsettled{}
    case Some{s}: Settled{Etag.strong(s), HttpDate.format_imf(mtime), mtime, changed}

def validator_headers(-Vars: Data, c: C.Ctx<Vars>, v: Validators) -> C.Ctx<Vars>:
  match v:
    case Unsettled{}: c
    case Settled{tag, modified, mtime, changed}: C.header(Vars, C.header(Vars, c, "etag", tag), "last-modified", modified)

# Validators and fixed fields on every file response, 304 included.
def validated(-Vars: Data, c: C.Ctx<Vars>, v: Validators, cache: Maybe<&2, String>) -> C.Ctx<Vars>:
  +d = C.header(Vars, C.header(Vars, validator_headers(Vars, c, v), "accept-ranges", "bytes"), "x-content-type-options", "nosniff")
  maybe_header(Vars, d, "cache-control", cache)

def since_parsed(+changed: Nat, parsed: Maybe<&2, Nat>) -> Bool:
  match parsed:
    case None{}: False{}
    case Some{t}: Nat.is_le(changed, t)

# If-Modified-Since holds when neither the content nor the inode changed
# after the date: ctime counts too, so a copy that restored an old mtime
# (cp -p, rsync -t) is not reported unmodified. A date that does not parse
# as IMF-fixdate is ignored.
def since(+changed: Nat, value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}: False{}
    case Some{v}: since_parsed(changed, HttpDate.parse_imf(v))

def fresh_settled(+tags: List<&2, String>, +tag: String, +changed: Nat, modified_since: Maybe<&2, String>) -> Bool:
  match tags:
    case Nil{}: since(changed, modified_since)
    case h <> t: Etag.none_match(tags, tag)

# If-None-Match decides when present; If-Modified-Since only without it.
def fresh(+tags: List<&2, String>, v: Validators, modified_since: Maybe<&2, String>) -> Bool:
  match v:
    case Unsettled{}: False{}
    case Settled{+tag, modified, mtime, +changed}: fresh_settled(tags, tag, changed, modified_since)

# If-Range: a strong tag that matches, or the exact Last-Modified date of a
# file whose ctime is no later than that date. Anything else, including any
# If-Range on an unsettled file, sends the whole file.
def range_settled(+v: String, +tag: String, +modified: String, +mtime: Nat, +changed: Nat) -> Bool:
  Etag.strong_eq(v, tag) || (String.eq(v, modified) && Nat.is_le(changed, mtime))

def range_validated(+field: String, v: Validators) -> Bool:
  match v:
    case Unsettled{}: False{}
    case Settled{+tag, +modified, +mtime, +changed}: range_settled(field, tag, modified, mtime, changed)

def range_holds(value: Maybe<&2, String>, v: Validators) -> Bool:
  match value:
    case None{}: True{}
    case Some{+field}: range_validated(String.trim(field), v)

def range_field(-Vars: Data, +c: C.Ctx<Vars>, +v: Validators) -> Maybe<&2, String>:
  E.choose(Maybe<&2, String>, range_holds(C.request_header(Vars, c, "if-range"), v), u => C.request_header(Vars, c, "range"), u => None{})

def closed(file: File, res: Response.Res) -> IO(Response.Res):
  do IO<Response.Res>:
    File.close(file)
    return res

def sent(-Vars: Data, c: C.Ctx<Vars>, +media: String, read: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Response.Res):
  (file, result) = read
  match result:
    case Fail{e}: closed(file, C.error(Vars, c, Errors.http_error(500, "")))
    case Done{bytes}: closed(file, C.body(Vars, c, bytes, Some{media}))

def buffered(-Vars: Data, +c: C.Ctx<Vars>, +media: String, file: File, +start: Nat, +length: Nat) -> IO(Response.Res):
  do IO<Response.Res>:
    read : File & Result<&1, &1, U32 & String, List<&2, U32>> <- read_range(file, start, length)
    sent(Vars, c, media, read)

# Hand the file to the stream transport, which pulls one 64 KiB chunk per
# send and never runs ahead of the socket.
def streamed(-Vars: Data, +c: C.Ctx<Vars>, +media: String, file: File, +start: Nat, +length: Nat) -> IO(Response.Res):
  Stream.register(Observation.stream(C.observation(Vars, c)), C.body(Vars, c, [], Some{media}), Stream.plan(~Pump, ~pump_step, ~pump_close, Pump{file, start, length}, Stream.defaults()))

def body_by(-Vars: Data, +c: C.Ctx<Vars>, +media: String, file: File, +start: Nat, +length: Nat, stream: Bool) -> IO(Response.Res):
  match stream:
    case True{}: streamed(Vars, c, media, file, start, length)
    case False{}: buffered(Vars, c, media, file, start, length)

def http11(v: Request.Version) -> Bool:
  match v:
    case Request.Http11{}: True{}
    case Request.Http10{}: False{}

def is_head(m: Request.Method) -> Bool:
  match m:
    case Request.Head{}: True{}
    case _: False{}

def head_request(r: Request.Req) -> Bool:
  Request.Req{m, p, q, v, hs} = r
  is_head(m) && http11(v)

# A body up to buffer_bytes is read and sent with Content-Length. A longer
# one streams with chunked encoding, so memory stays at one chunk whatever
# the file size. HEAD over HTTP/1.1 also goes through the stream, which the
# transport never pulls for HEAD, so its body is never read. HTTP/1.0 cannot
# carry a stream: a body above buffer_bytes is answered 505 there.
def body(-Vars: Data, +c: C.Ctx<Vars>, +max: Nat, +media: String, file: File, +start: Nat, +length: Nat) -> IO(Response.Res):
  body_by(Vars, c, media, file, start, length, head_request(C.request(Vars, c)) || Nat.is_lt(max, length))

def content_range(+first: Nat, +last: Nat, +size: Nat) -> String:
  "bytes " ++ Nat.show(first) ++ "-" ++ Nat.show(last) ++ "/" ++ Nat.show(size)

def respond_range(-Vars: Data, +c: C.Ctx<Vars>, +max: Nat, +media: String, file: File, +size: Nat, r: Range.Range) -> IO(Response.Res):
  match r:
    case Range.Whole{}: body(Vars, c, max, media, file, 0n, size)
    case Range.Part{+first, +last}:
      body(Vars, C.header(Vars, C.status(Vars, c, 206), "content-range", content_range(first, last, size)), max, media, file, first, Nat.add(Nat.sub(last, first), 1n))
    case Range.Unsatisfiable{}:
      closed(file, C.error(Vars, C.header(Vars, c, "content-range", "bytes */" ++ Nat.show(size)), Errors.http_error(416, "")))

def respond_fresh(-Vars: Data, +c: C.Ctx<Vars>, +max: Nat, +media: String, file: File, +size: Nat, +v: Validators, is_fresh: Bool) -> IO(Response.Res):
  match is_fresh:
    case True{}: closed(file, Response.not_modified(headers_of(Vars, c), None{}))
    case False{}: respond_range(Vars, c, max, media, file, size, Range.select(range_field(Vars, c, v), size))

def respond(-Vars: Data, +c: C.Ctx<Vars>, +max: Nat, cache: Maybe<&2, String>, +media: String, file: File, +size: Nat, +mtime: Nat, +changed: Nat, +stamp: String) -> IO(Response.Res):
  +v = validators_of(nonempty(stamp), mtime, changed)
  +conditional = fresh(ascii_all(C.header_bytes(Vars, c, "if-none-match")), v, C.request_header(Vars, c, "if-modified-since"))
  respond_fresh(Vars, validated(Vars, c, v, cache), max, media, file, size, v, conditional)

def opened(-Vars: Data, +c: C.Ctx<Vars>, +rest: String, +index: String, +max: Nat, cache: Maybe<&2, String>, +media: String, result: Result<&1, &1, U32 & String, File & (Nat & (Nat & (Nat & String)))>) -> IO(Response.Res):
  match result:
    case Fail{(code, message)}: open_failed(Vars, c, rest, index, code)
    case Done{(file, (size, (mtime, (changed, stamp))))}: respond(Vars, c, max, cache, media, file, size, mtime, changed, stamp)

def located(-Vars: Data, +c: C.Ctx<Vars>, +rest: String, target: Maybe<&2, String>, +options: Options) -> IO(Response.Res):
  match target:
    case None{}: not_found(Vars, c)
    case Some{+full}:
      Options{+root, prefix, +index, +max, cache} = options
      do IO<Response.Res>:
        result : Result<&1, &1, U32 & String, File & (Nat & (Nat & (Nat & String)))> <- StaticFile.open_beneath(root, full)
        opened(Vars, c, rest, index, max, cache, Mime.content_type(full), result)

# The mount path itself ("" after the prefix) is treated as its directory.
def within(-Vars: Data, +c: C.Ctx<Vars>, rest: Maybe<&2, String>, +options: Options) -> IO(Response.Res):
  match rest:
    case None{}: not_found(Vars, c)
    case Some{+r}:
      Options{+root, prefix, +index, max, cache} = options
      E.choose(IO(Response.Res), String.is_empty(r), u => directory(Vars, c, r, index), u => located(Vars, c, r, Path.target(root, r, index), options))

def by_method(-Vars: Data, +c: C.Ctx<Vars>, ok: Bool, +options: Options) -> IO(Response.Res):
  match ok:
    case False{}: IO.pure(Response.Res, C.error(Vars, C.header(Vars, c, "allow", "GET, HEAD"), Errors.http_error(405, "")))
    case True{}:
      Options{root, +prefix, index, max, cache} = options
      within(Vars, c, strip_prefix(prefix, path_of(Vars, c)), options)

# Serve the file the request path names beneath options.root. Register it
# for GET (HEAD follows) on a wildcard route such as "/static/*" with prefix
# "/static", or "*" with prefix "". The raw, undecoded request path is
# resolved, not the decoded wildcard capture, so encoded separators are seen.
def serve(-Vars: Data, +c: C.Ctx<Vars>, +options: Options) -> IO(Response.Res):
  by_method(Vars, c, get_or_head(C.method(Vars, c)), options)
