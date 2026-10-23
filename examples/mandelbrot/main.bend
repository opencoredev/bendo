# Mandelbrot as BMP, computed on one core, every core, or the GPU.
# Run: bend examples/mandelbrot/main.bend -o mandelbrot && ./mandelbrot
# Then open http://127.0.0.1:8787/ (PORT overrides the port).
import Base
import ../../src/main.bend as B
import ../../src/router/methods.bend as Methods
import ./render.bend as R

type Tag is Data:
  Index{}
  Image{}

# A validated image request.
type Job is Data:
  Job{mode: R.Mode, w: U32, h: U32, iter: U32}

def page() -> String:
  "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">" ++
  "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" ++
  "<title>Bendo Mandelbrot</title><style>" ++
  "body{margin:0;padding:24px;font:16px/1.5 system-ui,sans-serif;background:#111;color:#eee}" ++
  "main{max-width:1280px;margin:0 auto}h1{font-size:24px;margin:0 0 8px}p{margin:0 0 24px;color:#bbb}" ++
  ".grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}" ++
  "figure{margin:0}img{display:block;width:100%;height:auto;aspect-ratio:1;background:#000;border-radius:8px}" ++
  "figcaption{margin-top:8px;font-family:ui-monospace,monospace;font-size:14px}code{color:#9cf}" ++
  "</style></head><body><main><h1>Bendo Mandelbrot</h1>" ++
  "<p>Each image is a 24-bit BMP rendered by a Bend handler. The <code>Server-Timing</code> header carries the compute time.</p>" ++
  "<div class=\"grid\">" ++
  "<figure><img src=\"/mandelbrot.bmp?mode=single&amp;w=384&amp;h=384\" alt=\"Mandelbrot set, single core\"><figcaption>mode=single</figcaption></figure>" ++
  "<figure><img src=\"/mandelbrot.bmp?mode=cpu&amp;w=384&amp;h=384\" alt=\"Mandelbrot set, all CPU cores\"><figcaption>mode=cpu</figcaption></figure>" ++
  "<figure><img src=\"/mandelbrot.bmp?mode=gpu&amp;w=384&amp;h=384\" alt=\"Mandelbrot set, GPU or CPU fallback\"><figcaption>mode=gpu</figcaption></figure>" ++
  "</div></main></body></html>"

def digits(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+n}, tail}:
      (n >= 48 : U32) && (n <= 57 : U32) && digits(tail)

def in_range(+n: U32, +lo: U32, +hi: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}: Some{n}
    case False{}: None{}

def bounded(parsed: Maybe<&2, U32>, +lo: U32, +hi: U32) -> Maybe<&2, U32>:
  match parsed:
    case None{}: None{}
    case Some{+n}: in_range(n, lo, hi, (n >= lo : U32) && (n <= hi : U32))

def decimal(s: String, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}: U32.read(s)
    case False{}: None{}

# A missing parameter takes its default; a present one must be 1-4 decimal
# digits within [lo, hi]. The length cap keeps U32.read from wrapping.
def number(value: Maybe<&2, String>, +fallback: U32, +lo: U32, +hi: U32) -> Maybe<&2, U32>:
  match value:
    case None{}: Some{fallback}
    case Some{+s}:
      bounded(decimal(s, Bool.not(String.is_empty(s)) && Nat.is_le(String.length(s), 4n) && digits(s)), lo, hi)

def mode_named(single: Bool, cpu: Bool, gpu: Bool) -> Maybe<&2, R.Mode>:
  match single cpu gpu:
    case True{} _ _: Some{R.Single{}}
    case False{} True{} _: Some{R.Cpu{}}
    case False{} False{} True{}: Some{R.Gpu{}}
    case False{} False{} False{}: None{}

def mode_of(value: Maybe<&2, String>) -> Maybe<&2, R.Mode>:
  match value:
    case None{}: Some{R.Cpu{}}
    case Some{+s}:
      mode_named(String.eq(s, "single"), String.eq(s, "cpu"), String.eq(s, "gpu"))

def job(mode: Maybe<&2, R.Mode>, w: Maybe<&2, U32>, h: Maybe<&2, U32>, iter: Maybe<&2, U32>) -> Maybe<&2, Job>:
  match mode w h iter:
    case Some{m} Some{x} Some{y} Some{n}: Some{Job{m, x, y, n}}
    case _ _ _ _: None{}

# Defaults 512x512 at 256 iterations. Bounds cap the worst case (single mode,
# every point inside the set) at about 10^9 iterations.
def parse(+c: B.Ctx) -> Maybe<&2, Job>:
  job(mode_of(B.query(c, "mode")),
    number(B.query(c, "w"), 512, 1, 1024),
    number(B.query(c, "h"), 512, 1, 1024),
    number(B.query(c, "iter"), 256, 1, 1024))

def mode_name(mode: R.Mode) -> String:
  match mode:
    case R.Single{}: "single"
    case R.Cpu{}: "cpu"
    case R.Gpu{}: "gpu"

def timing(mode: R.Mode, compute: Nat, encode: Nat) -> String:
  "compute;dur=" ++ Nat.show(compute) ++ ";desc=\"" ++ mode_name(mode) ++ "\", encode;dur=" ++ Nat.show(encode)

# Times the pure render and the BMP encoding with IO.now (milliseconds).
# Both are strict, so each runs between the clock reads around it.
def draw(+c: B.Ctx, job: Job) -> IO(B.Res):
  match job:
    case Job{+mode, +w, +h, +iter}:
      do IO<B.Res>:
        +t0 : Nat <- IO.now()
        rows : List<&2, List<&2, U32>> = R.render(mode, w, h, iter)
        +t1 : Nat <- IO.now()
        bytes : List<&2, U32> = R.bmp(w, h, rows)
        +t2 : Nat <- IO.now()
        timed : B.Ctx = B.header(c, "server-timing", timing(mode, Nat.sub(t1, t0), Nat.sub(t2, t1)))
        return B.body(B.header(timed, "cache-control", "no-store"), bytes, Some{"image/bmp"})

def image(+c: B.Ctx, job: Maybe<&2, Job>) -> IO(B.Res):
  match job:
    case None{}:
      IO.pure(B.Res, B.text(B.status(c, 400), "mode must be single, cpu or gpu; w and h 1-1024; iter 1-1024"))
    case Some{j}:
      draw(c, j)

def respond(tag: Tag, +c: B.Ctx) -> IO(B.Res):
  match tag:
    case Index{}: IO.pure(B.Res, B.html(c, page()))
    case Image{}: image(c, parse(c))

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  respond(tag, c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid mandelbrot routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Index{}), B.get(Tag, "/mandelbrot.bmp", Image{})]))
