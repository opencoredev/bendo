# Pure Mandelbrot rendering and 24-bit BMP encoding. No IO here, so every mode
# computes the same bytes and the server only times the calls.
import Base

type Mode is Data:
  Single{}
  Cpu{}
  Gpu{}

# Escape-time loop: counts iterations until |z| > 2 or the fuel runs out. Flat:
# one tail call, so it compiles to a native loop on every lane.
def escape(fuel: Nat, escaped: Bool, +cr: F32, +ci: F32, +zr: F32, +zi: F32, +n: U32) -> U32:
  match fuel escaped:
    case 0n _:
      n
    case 1n+p True{}:
      n
    case 1n+p False{}:
      +nr = (zr * zr - zi * zi + cr : F32)
      +ni = (2.0 * zr * zi + ci : F32)
      escape(p, (nr * nr + ni * ni > 4.0 : F32), cr, ci, nr, ni, (n + 1 : U32))

def byte(v: F32) -> U32:
  F32.to_u32((v * 255.0 : F32))

# Points that never escape are black. The rest use the smooth Bernstein
# palette, with t = sqrt(n / iter) in [0, 1) to lift the faint outer bands.
# Prepends B, G, R onto acc.
def shade(inside: Bool, +t: F32, acc: List<&2, U32>) -> List<&2, U32>:
  match inside:
    case True{}:
      0 <> 0 <> 0 <> acc
    case False{}:
      +u = (1.0 - t : F32)
      byte((8.5 * u * u * u * t : F32)) <> byte((15.0 * u * u * t * t : F32)) <> byte((9.0 * u * t * t * t : F32)) <> acc

def pixel(+n: U32, +iter: U32, acc: List<&2, U32>) -> List<&2, U32>:
  shade(U32.is_eq(n, iter), F32.sqrt((U32.to_f32(n) / U32.to_f32(iter) : F32)), acc)

def zeros(n: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n: acc
    case 1n+p: zeros(p, 0 <> acc)

# Unit on the complex plane per pixel. 3.2 units span the shorter side.
def scale(+w: U32, +h: U32) -> F32:
  (3.2 / U32.to_f32(U32.min(w, h)) : F32)

# BMP pads each row to a multiple of four bytes.
def row_size(+w: U32) -> U32:
  ((w * 3 + 3 : U32) / 4 * 4 : U32)

# One image row, built right to left so each pixel is a prepend. x counts down
# with the fuel. Row y = 0 is the bottom of the picture, as BMP stores it.
def row(fuel: Nat, +x: U32, +y: U32, +w: U32, +h: U32, +iter: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      +s = scale(w, h)
      +cr = ((U32.to_f32(x) - 1.0 - U32.to_f32(w) / 2.0) * s - 0.65 : F32)
      +ci = ((U32.to_f32(y) - U32.to_f32(h) / 2.0) * s : F32)
      +n = escape(U32.to_nat(iter), False{}, cr, ci, 0.0, 0.0, 0)
      row(p, (x - 1 : U32), y, w, h, iter, pixel(n, iter, acc))

def line(+y: U32, +w: U32, +h: U32, +iter: U32) -> List<&2, U32>:
  row(U32.to_nat(w), w, y, w, h, iter, zeros(U32.to_nat((row_size(w) - w * 3 : U32)), []))

# Single mode: one core walks the rows from the top down, so the list ends up
# bottom-first.
def rows_single(fuel: Nat, +y: U32, +w: U32, +h: U32, +iter: U32, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      rows_single(p, (y - 1 : U32), w, h, iter, line((y - 1 : U32), w, h, iter) <> acc)

# Merges rows y0, y0+2s, .. with rows y0+s, y0+3s, .. back into y order. The
# left list is never shorter than the right one.
def interleave(a: List<&2, List<&2, U32>>, b: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match a b:
    case Nil{} _:
      b
    case x <> xs Nil{}:
      x <> xs
    case x <> xs y <> ys:
      x <> y <> interleave(xs, ys)

def leaf(present: Bool, +y: U32, +w: U32, +h: U32, +iter: U32) -> List<&2, List<&2, U32>>:
  match present:
    case False{}: []
    case True{}: [line(y, w, h, iter)]

# Parallel mode: a binary fork tree of depth d. Each branch takes every other
# row of its parent (stride s doubles per level), so the heavy middle rows of
# the set spread evenly over all lanes instead of landing on a few.
def rows_fork(+d: Nat, +y: U32, +s: U32, +w: U32, +h: U32, +iter: U32) -> List<&2, List<&2, U32>>:
  match d:
    case 0n:
      leaf((y < h : U32), y, w, h, iter)
    case 1n+p:
      a b = rows_fork(p, y, (s * 2 : U32), w, h, iter) rows_fork(p, (y + s : U32), (s * 2 : U32), w, h, iter)
      interleave(a, b)

# Smallest depth d with 2^d >= n. done says whether span = 2^d already covers n.
def depth(fuel: Nat, done: Bool, +n: U32, +span: U32, +d: Nat) -> Nat:
  match fuel done:
    case 0n _: d
    case 1n+p True{}: d
    case 1n+p False{}: depth(p, (span * 2 >= n : U32), n, (span * 2 : U32), Nat.add(d, 1n))

def rows_depth(+h: U32) -> Nat:
  depth(32n, (1 >= h : U32), h, 1, 0n)

def rows_cpu(+w: U32, +h: U32, +iter: U32) -> List<&2, List<&2, U32>>:
  rows_fork(rows_depth(h), 0, 1, w, h, iter)

# `!` hands the whole fork tree to the GPU. Without one (no CUDA or Metal, or
# `+RTS --gpu off`) Bend runs it on the CPU pool, still in parallel.
def rows_gpu(+w: U32, +h: U32, +iter: U32) -> List<&2, List<&2, U32>>:
  rows_fork!(rows_depth(h), 0, 1, w, h, iter)

# Rows of BGR bytes, bottom row first, each padded to a multiple of four.
def render(mode: Mode, +w: U32, +h: U32, +iter: U32) -> List<&2, List<&2, U32>>:
  match mode:
    case Single{}: rows_single(U32.to_nat(h), h, w, h, iter, [])
    case Cpu{}: rows_cpu(w, h, iter)
    case Gpu{}: rows_gpu(w, h, iter)

def le16(+v: U32, acc: List<&2, U32>) -> List<&2, U32>:
  (v .&. 255 : U32) <> ((v >> 8n : U32) .&. 255 : U32) <> acc

def le32(+v: U32, acc: List<&2, U32>) -> List<&2, U32>:
  le16((v .&. 65535 : U32), le16((v >> 16n : U32), acc))

# A bottom-up 24-bit BMP: 14-byte file header, 40-byte BITMAPINFOHEADER, rows.
def bmp(+w: U32, +h: U32, rows: List<&2, List<&2, U32>>) -> List<&2, U32>:
  +size = (row_size(w) * h : U32)
  66 <> 77 <> le32((size + 54 : U32), le32(0, le32(54,
    le32(40, le32(w, le32(h, le16(1, le16(24, le32(0, le32(size,
      le32(2835, le32(2835, le32(0, le32(0, List.concat(&2, U32, rows)))))))))))))))
