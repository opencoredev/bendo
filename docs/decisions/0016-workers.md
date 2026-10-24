# 0016: Serve on several cores with SO_REUSEPORT worker processes

Date: 2026-10-24. Issue: BND-69 ("Use every CPU core for serving"; the ticket
proposed this record as 0006, which was taken). Status: accepted for M9.

A Bendo server uses about one CPU core whatever `+RTS --threads` says. Running
`N` processes on one port with `SO_REUSEPORT` multiplies throughput by about
`N`, up to the cores available. `B.workers(config, n)` now does this. The
default stays at one worker, because workers share no memory and would split
every store and rate limiter.

## How the runtime schedules

The Bend 2.0.38 native runtime runs all IO on one event loop (`io_loop` in the
generated C). `IO.spawn` queues a computation on that loop, and every
connection Bendo accepts is one such computation. The loop runs them one at a
time and switches when one parks on a socket or a timer. Connections are
concurrent but never parallel.

`--threads N` (default: the CPUs in the affinity mask) sizes a different pool.
It can spread the pure evaluation inside one IO step across threads when that
step forks enough work. With more than one thread, the evaluator builds heap
task nodes for forks instead of stack frames so the pool can take them. A
request's evaluation is short and mostly sequential, so the pool finds almost
nothing to share, and the IO loop, which runs every connection, stays on one
thread. That matches BND-67, which measured the default and `--threads 1` as
equal, and the thread rows below.

## Measurements

Requests per second, median (min–max) of three samples, then server CPU time
per response in microseconds (summed over every server process) and median p50
latency in milliseconds:

**Session 1: threads and an `SO_REUSEPORT` prototype**, main at `39158b9`.
`reuseport-N` runs `N` copies of a build whose `TCP.listen` also sets
`SO_REUSEPORT` (patched into the generated C), each with `--threads 1`.

| Variant | Hello | JSON | Middleware | CPU µs: hello | JSON | MW | p50 ms: hello | JSON | MW |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| default (4 threads) | 18,296 (17,893–18,405) | 16,705 (16,620–17,120) | 1,961 (1,914–2,016) | 55 | 60 | 609 | 3.39 | 3.72 | 32.15 |
| threads-1 | 19,150 (18,923–19,259) | 16,359 (15,886–16,631) | 1,938 (1,838–2,114) | 52 | 61 | 608 | 3.30 | 3.81 | 32.57 |
| threads-2 | 19,075 (19,037–20,329) | 16,609 (16,239–18,072) | 1,986 (1,962–2,102) | 52 | 60 | 592 | 3.27 | 3.75 | 31.79 |
| threads-4 | 18,365 (16,966–19,618) | 16,701 (15,300–17,703) | 2,080 (1,651–2,191) | 54 | 60 | 549 | 3.42 | 3.70 | 30.37 |
| reuseport-1 | 18,486 (18,106–19,628) | 17,521 (16,162–17,547) | 2,082 (2,001–2,123) | 54 | 57 | 565 | 3.33 | 3.67 | 30.14 |
| reuseport-2 | 36,997 (36,064–38,809) | 34,400 (31,753–34,960) | 4,156 (3,705–4,197) | 53 | 58 | 539 | 1.66 | 1.72 | 15.09 |
| reuseport-4 | 71,231 (67,861–74,130) | 66,056 (58,021–66,176) | 6,792 (6,453–6,837) | 54 | 59 | 537 | 0.75 | 0.87 | 8.59 |

**Session 2: the implemented `workers` option**, this branch. `workers-N`
sets `BENDO_WORKERS=N` on the hello, JSON and middleware servers, which keep
their default config otherwise.

| Variant | Hello | JSON | Middleware | CPU µs: hello | JSON | MW | p50 ms: hello | JSON | MW |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| default (one worker) | 19,031 (17,114–19,636) | 15,959 (15,467–17,160) | 1,969 (1,828–2,041) | 53 | 63 | 589 | 3.34 | 3.87 | 31.85 |
| threads-1 | 17,521 (16,570–18,855) | 15,865 (15,217–16,112) | 1,846 (1,781–2,059) | 57 | 63 | 642 | 3.51 | 3.99 | 34.20 |
| reuseport-4 (prototype) | 66,440 (60,281–67,799) | 57,789 (57,259–62,616) | 5,853 (5,210–6,216) | 58 | 66 | 651 | 0.67 | 0.82 | 10.05 |
| workers-1 | 16,951 (14,518–18,150) | 14,784 (14,075–16,502) | 1,605 (1,600–1,927) | 59 | 68 | 747 | 3.63 | 4.14 | 39.20 |
| workers-2 | 34,355 (33,471–36,549) | 31,276 (28,800–31,863) | 3,348 (2,496–3,391) | 57 | 63 | 654 | 1.83 | 1.98 | 18.85 |
| workers-4 | 63,129 (53,317–67,151) | 55,657 (55,094–60,147) | 5,278 (5,217–5,707) | 60 | 69 | 689 | 0.72 | 0.96 | 10.52 |
| workers-4, `--threads 1` | 64,663 (55,329–68,883) | 53,056 (49,804–56,583) | 5,390 (5,371–6,046) | 59 | 71 | 690 | 0.80 | 0.92 | 11.49 |

Four workers served 3.3× the default's hello throughput, 3.5× its JSON and
2.7× its middleware throughput, against 3.9×, 4.0× and 3.5× for the prototype
in session 1. CPU per response stays flat as workers are added, so the gain is
parallel work, not a cheaper path. `workers-1` runs the same code as the
default (one worker binds with plain `TCP.listen`); its lower medians sit
inside the default's sample range, and the CI budget below measured the
default hello server at 0.996 of the baseline. The thread count makes no
difference in either session.

Both sessions ran on Boat large sandboxes (AMD Ryzen 9 9950X, 8 vCPUs) with
`bench/cores.py`, which follows BND-68's `bench/steps.py`: server processes on
CPUs 0–3 (workers inherit the affinity), oha 1.16.0 on CPUs 4–7, 64 keep-alive
connections, two oha workers, a 3-second discarded warmup, a 10-second sample,
and three samples per variant with rounds in alternating order. Each sample
first checks the status, body and middleware headers and waits until every
worker has printed its listening line. All 126 recorded samples had zero
errors. The raw samples are in
[`bench/results/2026-10-24-bnd69-prototype.json`](../../bench/results/2026-10-24-bnd69-prototype.json)
and [`2026-10-24-bnd69-workers.json`](../../bench/results/2026-10-24-bnd69-workers.json).

An earlier attempt at session 2, with all eleven variants, overlapped five
sandboxes running this branch's checks. Its host slowed during the run: one
process measured between 9,900 and 14,200 hello requests per second and CPU
per response rose up to twice session 1's. Four workers still served about 3.5×
one worker there, but the samples are too noisy to compare across rows, so
session 2 above was rerun alone on a fresh sandbox with the same binaries. The
noisy run is kept in
[`2026-10-24-bnd69-workers-noisy.json`](../../bench/results/2026-10-24-bnd69-workers-noisy.json).

```sh
BENDO_BENCH_BOAT=1 python3 bench/cores.py OUT SRC_DIR
```

## The decision

`Config` gains a `workers: U32` field, set with `B.workers(config, n)`. `0`
means one worker per CPU in the affinity mask. A decimal `BENDO_WORKERS` from 0
to 256 overrides the config at startup, like `PORT`. [The workers
guide](../workers.md) is the user-facing description.

**Startup.** Every process, the first included, binds its own listener through
`src/effects/listen_shared`, which is base's `TCP.listen` plus `SO_REUSEPORT`,
and then runs `src/effects/workers`. In the first process that effect starts
`n - 1` copies of its own binary with `fork` and `execve`, passing the original
arguments from `/proc/self/cmdline` (so `+RTS` options carry over) and
`BENDO_WORKER_INDEX` set to 1 to `n - 1`. In a copy, the effect writes one
byte to a pipe inherited as descriptor 3 and returns at once. The first
process reads `n - 1` bytes before it returns, so it accepts and prints its
listening line only once every worker is bound, and the kernel spreads
connections over all listeners from then on. If a copy stops first, its end
of the pipe closes and its watcher thread (below) stops the server.

A child execs `/proc/self/exe` rather than the path it resolves to. The magic
link names the inode the parent is running, so a binary replaced on disk after
startup cannot start as a worker. The kernel then names the child `exe`, so
the parent passes its own name in `BENDO_WORKER_NAME` and the child sets it
with `PR_SET_NAME` when it loads, which keeps `ps -C <name>` and `pkill`
working. Before `execve` the child closes every descriptor above the pipe with
`close_range`, or a loop up to `_SC_OPEN_MAX` on kernels older than 5.9.

Exec rather than plain `fork`: by the time `B.serve` runs, the runtime has
started its thread pool and possibly IO helper threads. A forked child keeps
only the calling thread, while the runtime still believes its pool is up, so
the first parallel evaluation would wait forever. A child calls only
async-signal-safe functions between `fork` and `execve`, and starts with a
fresh runtime. The cost is that `main` runs once per worker.

**Shutdown.** Each copy sets `PR_SET_PDEATHSIG` to `SIGTERM` before `execve`
(and exits if the parent already died), so stopping the first process by any
means stops every worker. A detached thread in the first process waits for
each copy. When one exits or is killed, the first process reports it on stderr
and exits the same way, re-raising the signal or returning the status, which
stops the rest. A server therefore never runs with fewer workers than
configured, and a process manager sees one failure for the group. In-flight
requests are not drained on stop, the same as a one-worker server.

**Default of 1.** One process per core would be the fast default, but workers
share no memory. Every [store](../store.md) and [rate
limiter](../connection.md#rate-limiting) would silently become one per
worker: counters would disagree and a rate limit would allow `N` times its
budget. Startup side effects in `main` would also run `N` times. One worker
keeps today's behavior, and binds with plain `TCP.listen`, so a second copy on
a taken port still fails with EADDRINUSE instead of silently joining it. More
workers are an explicit choice whose caveats the guide states.

**Platforms.** The effect needs Linux (`/proc/self/cmdline`,
`PR_SET_PDEATHSIG`). On other platforms, and in JavaScript builds, any count
other than 1 fails with status 38, Linux's ENOSYS, on every platform (macOS
numbers ENOSYS 78), and prints that workers need Linux or the native build. The JS twin of `listen_shared` sets
`SO_REUSEPORT` through the runtime's socket helpers in executable builds.

**Threads.** Each worker keeps the runtime's default thread count. Session 2
measured no difference with `--threads 1`, so the effect does not change it.

## What was not done

- One process with several accept loops. Every computation shares the single
  IO loop, so more accept loops in one process cannot run in parallel.
- Sharing stores across workers. That needs an external process or shared
  memory with its own consistency story, and it is outside this issue.
- Restarting a dead worker in place. Stopping the group keeps state simple
  and leaves restart policy to the process manager.

## Verification

`tests/workers.test.ts` runs `tests/servers/workers.bend`, which serves with
`B.workers(B.config(), 3)` and answers with the serving PID from a test-only
`getpid` effect. It checks that requests on fresh connections reach all three
PIDs and that they are exactly the first process and its two children, running
the same command line under the same process name; that once the first process
answers, each of the three holds exactly one listener on the port; that stopping the first process leaves no worker
running and the port refusing connections; that killing one worker stops the
others and prints the stderr line; and that `BENDO_WORKERS` set to `1` or `2`
overrides the config while `many` keeps it. The JavaScript build of the same
fixture exits with status 38 under the default three workers and serves with
`BENDO_WORKERS=1`.

The CI performance budget passed on a Boat large sandbox: three alternating
pairs against the pinned baseline `853687e` measured ratios of 0.994, 0.996
and 1.001 (median 0.996). Startup does two more environment reads and one
effect call, and the request path is unchanged.
