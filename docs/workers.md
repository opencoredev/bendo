# Serve on every CPU core with workers

A Bendo server runs every connection on one event loop thread, so one process
uses about one CPU core however many cores the machine has. To use more,
run several worker processes on the same port:

```python
B.serve(~Tag, ~Env, ~dispatch, table, env, B.workers(B.config(), 4))
```

`B.workers(config, n)` sets the config's `workers` field. `0` means one worker
per CPU the process may run on (its affinity mask). The default is `1`: one
process, no copies, and the same `TCP.listen` as before. Setting
`BENDO_WORKERS` to a decimal number from 0 to 256 overrides the config at
startup, the same way `PORT` overrides the port; any other value is ignored.
A config count above 256 stops startup with EINVAL (22).

On four CPUs of a Boat sandbox, four workers served 3.3 times the requests of
one: 63,000 hello requests per second against 19,000. [Decision
0017](decisions/0017-workers.md) has the measurements.

## Workers share nothing

Each worker is a separate copy of the binary that runs `main` from the start.
Workers share no memory, so anything `main` creates exists once per worker:

- A [store](store.md) holds the state of one worker. A request sees the
  counter, session or cache of whichever worker the kernel gave its
  connection to.
- A [rate limiter](connection.md#rate-limiting) counts per worker, so a client
  spread across `N` workers can make up to `N` times the limit.
- Startup side effects in `main` (printing, writing files, calling another
  service) run once per worker.

Keep state that must be global in an external service, or serve with one
worker. That is why one worker is the default.

## How it works

At startup, the first process binds its listener with `SO_REUSEPORT` and
starts `n - 1` copies of its own binary with the same arguments, `+RTS`
options included, and `BENDO_WORKER_INDEX` set to the copy's index (1 to
`n - 1`). Each copy binds its own listener the same way and reports back. The
first process waits for every report before it accepts a connection or prints
its listening line, so once that line appears the kernel spreads new
connections across all workers. Connections that arrive earlier wait in the
first process's queue. A keep-alive connection stays on the worker that
accepted it. Every worker prints its own listening line.

Because every listener sets `SO_REUSEPORT`, a second multi-worker server
started by the same user on the same port joins the first one instead of
failing with "address in use". A one-worker server binds without
`SO_REUSEPORT` and still fails on a taken port.

## Stopping

Stop the server by stopping the first process (the one you started). Each
worker asks the kernel for `SIGTERM` when the first process exits, so
`kill <pid>`, Ctrl-C and a process manager's stop all end every worker, and
the port is free once they exit. In-flight requests are not drained; this is
the same as a one-worker server.

If any worker exits or is killed, the first process prints
`bendo: worker <pid> stopped by signal <n>; stopping the server` (or `exited
with status <n>`) and exits the same way, which stops the remaining workers.
The server never keeps running with fewer workers than configured, so a
process manager sees the failure and can restart the whole group.

## Limits

- Workers need the native build on Linux. On macOS, and in JavaScript builds,
  any count other than 1 stops startup with exit status 38 (Linux's ENOSYS, on
  every platform) and prints `bendo: workers > 1 needs Linux` (`needs the
  native build` from JavaScript).
- Each worker keeps the runtime's default thread count, which is the number
  of CPUs it may use. Those threads only share out pure evaluation inside one
  step; requests within a worker run on one event loop thread. Passing
  `+RTS --threads 1 -RTS` gives every worker one thread; it measured the same.
