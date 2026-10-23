# serve_static: the IO shell around the pure static modules (BND-45).
# Path resolution, ranges, MIME types and entity tags are pure; this file
# only opens, reads and closes the file. See docs/static.md.
import Base
import ../app/context.bend as C
import ../app/errors.bend as Errors
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
# max_bytes: the largest body read into memory for one response.
# cache_control: an optional Cache-Control value for served files.
type Options is Data:
  Options{root: String, prefix: String, index: String, max_bytes: Nat, cache_control: Maybe<&2, String>}

def defaults(root: String) -> Options:
  Options{root, "", "index.html", 8388608n, None{}}

def mounted(options: Options, prefix: String) -> Options:
  Options{root, old, index, max, cache} = options
  Options{root, prefix, index, max, cache}

def with_index(options: Options, index: String) -> Options:
  Options{root, prefix, old, max, cache} = options
  Options{root, prefix, index, max, cache}

def with_max_bytes(options: Options, max: Nat) -> Options:
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

# Validators and fixed fields on every file response, 304 included.
def validated(-Vars: Data, c: C.Ctx<Vars>, +tag: String, +modified: String, cache: Maybe<&2, String>) -> C.Ctx<Vars>:
  +a = C.header(Vars, c, "etag", tag)
  +b = maybe_header(Vars, a, "last-modified", nonempty(modified))
  +d = C.header(Vars, C.header(Vars, b, "accept-ranges", "bytes"), "x-content-type-options", "nosniff")
  maybe_header(Vars, d, "cache-control", cache)

def since_parsed(+mtime: Nat, parsed: Maybe<&2, Nat>) -> Bool:
  match parsed:
    case None{}: False{}
    case Some{t}: Nat.is_le(mtime, t)

# A date that does not parse as IMF-fixdate is ignored.
def since(+mtime: Nat, value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}: False{}
    case Some{v}: since_parsed(mtime, HttpDate.parse_imf(v))

# If-None-Match decides when present; If-Modified-Since only without it.
def fresh(+tags: List<&2, String>, +tag: String, +mtime: Nat, modified_since: Maybe<&2, String>) -> Bool:
  match tags:
    case Nil{}: since(mtime, modified_since)
    case h <> t: Etag.none_match(tags, tag)

# If-Range: a strong tag that matches, or the exact Last-Modified date. The
# tags here are weak, so only the date form can keep a range.
def range_holds(value: Maybe<&2, String>, +tag: String, +modified: String) -> Bool:
  match value:
    case None{}: True{}
    case Some{+v}: Etag.strong_eq(String.trim(v), tag) || (Bool.not(String.is_empty(modified)) && String.eq(String.trim(v), modified))

def range_field(-Vars: Data, +c: C.Ctx<Vars>, +tag: String, +modified: String) -> Maybe<&2, String>:
  E.choose(Maybe<&2, String>, range_holds(C.request_header(Vars, c, "if-range"), tag, modified), u => C.request_header(Vars, c, "range"), u => None{})

def closed(file: File, res: Response.Res) -> IO(Response.Res):
  do IO<Response.Res>:
    File.close(file)
    return res

def sent(-Vars: Data, c: C.Ctx<Vars>, +media: String, read: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Response.Res):
  (file, result) = read
  match result:
    case Fail{e}: closed(file, C.error(Vars, c, Errors.http_error(500, "")))
    case Done{bytes}: closed(file, C.body(Vars, c, bytes, Some{media}))

def body_fits(-Vars: Data, +c: C.Ctx<Vars>, +media: String, file: File, +start: Nat, +length: Nat, fits: Bool) -> IO(Response.Res):
  match fits:
    case True{}:
      do IO<Response.Res>:
        read : File & Result<&1, &1, U32 & String, List<&2, U32>> <- read_range(file, start, length)
        sent(Vars, c, media, read)
    case False{}: closed(file, C.error(Vars, c, Errors.http_error(500, "")))

# Without streaming (BND-48), a body above max_bytes is refused with 500
# instead of being buffered. Ranges within the cap still work.
def body(-Vars: Data, +c: C.Ctx<Vars>, +max: Nat, +media: String, file: File, +start: Nat, +length: Nat) -> IO(Response.Res):
  body_fits(Vars, c, media, file, start, length, Nat.is_le(length, max))

def content_range(+first: Nat, +last: Nat, +size: Nat) -> String:
  "bytes " ++ Nat.show(first) ++ "-" ++ Nat.show(last) ++ "/" ++ Nat.show(size)

def respond_range(-Vars: Data, +c: C.Ctx<Vars>, +max: Nat, +media: String, file: File, +size: Nat, r: Range.Range) -> IO(Response.Res):
  match r:
    case Range.Whole{}: body(Vars, c, max, media, file, 0n, size)
    case Range.Part{+first, +last}:
      body(Vars, C.header(Vars, C.status(Vars, c, 206), "content-range", content_range(first, last, size)), max, media, file, first, Nat.add(Nat.sub(last, first), 1n))
    case Range.Unsatisfiable{}:
      closed(file, C.error(Vars, C.header(Vars, c, "content-range", "bytes */" ++ Nat.show(size)), Errors.http_error(416, "")))

def respond_fresh(-Vars: Data, +c: C.Ctx<Vars>, +max: Nat, +media: String, file: File, +size: Nat, +tag: String, +modified: String, is_fresh: Bool) -> IO(Response.Res):
  match is_fresh:
    case True{}: closed(file, Response.not_modified(headers_of(Vars, c), None{}))
    case False{}: respond_range(Vars, c, max, media, file, size, Range.select(range_field(Vars, c, tag, modified), size))

def respond(-Vars: Data, +c: C.Ctx<Vars>, +max: Nat, cache: Maybe<&2, String>, +media: String, file: File, +size: Nat, +mtime: Nat) -> IO(Response.Res):
  +tag = Etag.weak(size, mtime)
  +modified = HttpDate.format_imf(mtime)
  +conditional = fresh(ascii_all(C.header_bytes(Vars, c, "if-none-match")), tag, mtime, C.request_header(Vars, c, "if-modified-since"))
  respond_fresh(Vars, validated(Vars, c, tag, modified, cache), max, media, file, size, tag, modified, conditional)

def opened(-Vars: Data, +c: C.Ctx<Vars>, +rest: String, +index: String, +max: Nat, cache: Maybe<&2, String>, +media: String, result: Result<&1, &1, U32 & String, File & (Nat & Nat)>) -> IO(Response.Res):
  match result:
    case Fail{(code, message)}: open_failed(Vars, c, rest, index, code)
    case Done{(file, (size, mtime))}: respond(Vars, c, max, cache, media, file, size, mtime)

def located(-Vars: Data, +c: C.Ctx<Vars>, +rest: String, target: Maybe<&2, String>, +options: Options) -> IO(Response.Res):
  match target:
    case None{}: not_found(Vars, c)
    case Some{+full}:
      Options{+root, prefix, +index, +max, cache} = options
      do IO<Response.Res>:
        result : Result<&1, &1, U32 & String, File & (Nat & Nat)> <- StaticFile.open_beneath(root, full)
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
