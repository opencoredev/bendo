# Mandelbrot: parallel and GPU compute in a handler

This example renders the Mandelbrot set as a 24-bit BMP inside a Bendo handler.
The same pure renderer runs three ways: on one core, on every core through
Bend's parallel calls, or handed to the GPU with a `!` call. The response's
`Server-Timing` header says how long the render took.

## Run it

```sh
bend examples/mandelbrot/main.bend -o mandelbrot
./mandelbrot
```

Open http://127.0.0.1:8787/. The page shows one image per mode. Set `PORT` to
listen elsewhere. The server binds 127.0.0.1 only.

## Routes

`GET /` returns the HTML page.

`GET /mandelbrot.bmp` returns `image/bmp` with `cache-control: no-store`.

| Query | Values | Default |
| --- | --- | --- |
| `mode` | `single`, `cpu` or `gpu` | `cpu` |
| `w`, `h` | 1 to 1024 pixels | 512 |
| `iter` | 1 to 1024 iterations per pixel | 256 |

Numbers are 1 to 4 decimal digits. Anything else, including an unknown mode,
gets a plain-text 400. The largest request, 1024x1024 at 1024 iterations,
takes about 340 ms in `single` mode on the Boat machine below.

```sh
curl -sD - -o set.bmp 'http://127.0.0.1:8787/mandelbrot.bmp?mode=cpu&w=1024&h=1024&iter=1024'
# server-timing: compute;dur=53;desc="cpu", encode;dur=35
```

`compute` is the render, in milliseconds, read with `IO.now` before and after
the call. `encode` is the BMP header plus flattening the rows into one byte
list. Encoding is sequential in every mode. Every mode returns the same bytes.

## How the modes differ

`render.bend` holds the pure code; `main.bend` parses the query, reads the
clock and builds the response with `B.body`, `B.header` and `B.status`.

- `single`: `rows_single` loops over the rows on one core.
- `cpu`: `rows_fork` is a binary fork tree, `a b = rows_fork(..) rows_fork(..)`,
  with one row per leaf. Bend's scheduler deals each task to one core and
  never moves it, so balance matters. The middle rows of the set cost far more
  than the edges. Each branch therefore takes every other row of its parent,
  and `interleave` merges the halves back into order. Splitting into
  contiguous bands would leave a few cores with all the heavy rows.
- `gpu`: `rows_fork!(..)` runs the same tree with a `!` call.

The pixel loop, `escape`, is a single tail-recursive def with a `Nat` fuel
argument. Bend compiles it to a native loop.

## GPU behavior

A `!` call runs on the GPU only when the binary was built with one available:
CUDA 12 or 13 at `$CUDA_HOME`, `/usr/local/cuda` or `/opt/cuda` on Linux
(clang 19 or newer), or Metal on macOS. The build then writes `mandelbrot.gpu`,
which must stay next to the binary. `+RTS --gpu 4GB` caps the GPU heap.

Without a GPU, `mode=gpu` falls back to the CPU pool: the `!` call runs the
fork tree in parallel on the CPU, exactly like `mode=cpu`. `+RTS --gpu off`
forces that fallback on a GPU machine. Neither ms-a2 nor the Boat sandbox has
a GPU (no CUDA, no `nvidia-smi`), the build writes no `.gpu` file, and `gpu`
times match `cpu` within noise. **The GPU path itself is untested.** Bend's
guide lists Mandelbrot as GPU-friendly work, but this example gives each lane a
whole row and has only up to 1024 leaves. A GPU wants about 16384, so
expect it to leave most lanes idle until the tree splits rows further.

## Timings

`scripts/mandelbrot-timings.ts` starts the server, warms each mode once, then
interleaves the modes and prints medians from `Server-Timing`:

```sh
bun scripts/mandelbrot-timings.ts 9                            # 512x512, 256 iterations
bun scripts/mandelbrot-timings.ts 7 "w=1024&h=1024&iter=1024"
```

### Boat `large` sandbox (primary numbers)

8 vCPU, AMD Ryzen 9 9950X, 16 GB, idle (load average under 2.5). Measured
2026-10-23.

| Image | single | cpu | gpu (CPU fallback) | cpu vs single |
| --- | ---: | ---: | ---: | ---: |
| 512x512, 256 iter, 9 runs | 28 ms | 5 ms | 5 ms | 5.6x |
| 1024x1024, 1024 iter, 7 runs | 342 ms | 63 ms | 70 ms | 5.4x |

`cpu` mode at 1024x1024 with 1024 iterations, run with `+RTS --threads N`:

| Threads | 1 | 2 | 4 | 8 |
| --- | ---: | ---: | ---: | ---: |
| compute | 320 ms | 168 ms | 85 ms | 44-53 ms |

### ms-a2 (shared, noisy)

32 threads, AMD Ryzen 9 9955HX. Other users kept the load average at 190 to
475 during these runs, so the cores were already oversubscribed and the numbers
swing widely from run to run.

| Image | single | cpu | gpu (CPU fallback) | cpu vs single |
| --- | ---: | ---: | ---: | ---: |
| 512x512, 256 iter, 9 runs | 36 ms | 29 ms | 19 ms | 1.2x |
| 1024x1024, 1024 iter, 7 runs | 2204 ms | 303 ms | 324 ms | 7.3x |

An earlier spot check at the 512x512 default gave 56 ms single and 4 ms cpu
(14x). A 1024x1024 run at load 430 gave only 1.4x. Parallel calls help only
when cores are free. The Boat numbers are the ones to compare.

## Tests

```sh
bun test --timeout 200000 tests/mandelbrot.test.ts
```

The tests compile the example, check the BMP headers and row padding for every
mode, check that all modes return identical bytes, check the `Server-Timing`
format and the defaults, and send bad parameters that must get 400.
