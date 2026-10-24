#!/usr/bin/env python3
"""Multi-core serving comparison (BND-69). Boat large sandboxes only.

Usage: python3 bench/cores.py OUT_DIR SRC_DIR

Builds the hello, JSON and middleware servers from SRC_DIR, then measures
runtime thread counts and SO_REUSEPORT worker processes with the BND-68
recipe: server processes on CPUs 0-3, oha on CPUs 4-7, 64 keep-alive
connections, two oha workers, 3 s discarded warmup, 10 s measured sample,
three samples per variant. Sample rounds alternate forward and reverse
variant order.

Variants:
  default      one process, the runtime's default thread count (4 here)
  threads-N    one process, +RTS --threads N
  reuseport-N  N processes of a build whose TCP.listen also sets
               SO_REUSEPORT (patched into the generated C), each run with
               --threads 1, so the kernel spreads connections over N
               accept loops
  workers-N    the real `workers` option through BENDO_WORKERS=N, default
               threads (only when SRC_DIR's src/serve.bend supports it)
  workers-4-threads-1
               the same with +RTS --threads 1, which every worker inherits

Every sample first checks status 200, the exact body and the middleware
headers, and waits until every process has printed its listening line.
Server CPU per response sums every server process. A rerun skips samples
already in OUT/samples.json.
"""

import json
import os
import pathlib
import statistics
import subprocess
import sys
import time
import urllib.request

if os.environ.get("BENDO_BENCH_BOAT") != "1" or os.cpu_count() < 8:
    sys.exit("Load generation is Boat-only: set BENDO_BENCH_BOAT=1 on a large sandbox")

OUT = pathlib.Path(sys.argv[1])
SRC = pathlib.Path(sys.argv[2])
SAMPLES = int(os.environ.get("CORES_SAMPLES", "3"))
OHA = os.environ.get("OHA", "oha")
PORT = "8787"
HEADERS = {"Content-Type": "application/json", "Origin": "https://bench.example"}
SECURE = {
    "cross-origin-resource-policy": "same-origin",
    "x-content-type-options": "nosniff",
    "x-frame-options": "SAMEORIGIN",
}
SCENARIOS = {
    "hello": ("/", "Hello, world!", {}),
    "json": ("/json", '{"message":"Hello, world!"}', {}),
    "middleware": ("/middleware", "Hello, world!", {"access-control-allow-origin": "*", "x-bench": "middleware", **SECURE}),
}
REUSE = "setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));"
WORKERS = "BENDO_WORKERS" in (SRC / "src" / "serve.bend").read_text()

# name -> (build, processes, runtime args, extra env)
VARIANTS = {
    "default": ("plain", 1, [], {}),
    "threads-1": ("plain", 1, ["+RTS", "--threads", "1", "-RTS"], {}),
    "threads-2": ("plain", 1, ["+RTS", "--threads", "2", "-RTS"], {}),
    "threads-4": ("plain", 1, ["+RTS", "--threads", "4", "-RTS"], {}),
    "reuseport-1": ("reuse", 1, ["+RTS", "--threads", "1", "-RTS"], {}),
    "reuseport-2": ("reuse", 2, ["+RTS", "--threads", "1", "-RTS"], {}),
    "reuseport-4": ("reuse", 4, ["+RTS", "--threads", "1", "-RTS"], {}),
}
if WORKERS:
    for n in (1, 2, 4):
        VARIANTS[f"workers-{n}"] = ("plain", 1, [], {"BENDO_WORKERS": str(n)})
    VARIANTS["workers-4-threads-1"] = ("plain", 1, ["+RTS", "--threads", "1", "-RTS"], {"BENDO_WORKERS": "4"})
ONLY = os.environ.get("CORES_VARIANTS")
if ONLY:
    VARIANTS = {k: v for k, v in VARIANTS.items() if k in ONLY.split(",")}


def build(scenario):
    plain = OUT / "bin" / f"plain-{scenario}"
    reuse = OUT / "bin" / f"reuse-{scenario}"
    if plain.exists() and reuse.exists():
        return
    c_file = OUT / "bin" / f"{scenario}.c"
    subprocess.run(["bend", f"bench/servers/{scenario}.bend", "-o", str(c_file)], cwd=SRC, check=True)
    subprocess.run(["clang", "-std=c11", "-O3", str(c_file), "-o", str(plain), "-lpthread", "-lm"], check=True)
    text = c_file.read_text()
    start = text.find("Term tcp_listen_run(")
    at = text.find(REUSE, start)
    if start < 0 or at < 0 or text.find("return io_done", start) < at:
        raise RuntimeError("TCP.listen's SO_REUSEADDR line not found")
    at += len(REUSE)
    patched = OUT / "bin" / f"{scenario}-reuse.c"
    patched.write_text(text[:at] + "\n  setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &one, sizeof(one));" + text[at:])
    subprocess.run(["clang", "-std=c11", "-O3", str(patched), "-o", str(reuse), "-lpthread", "-lm"], check=True)
    print("built", scenario, flush=True)


def fetch(path):
    request = urllib.request.Request(f"http://127.0.0.1:{PORT}{path}", headers=HEADERS)
    with urllib.request.urlopen(request, timeout=2) as response:
        return {"status": response.status, "headers": {k.lower(): v for k, v in response.headers.items()}, "body": response.read().decode()}


def ready(path, processes, logs, workers):
    for _ in range(300):
        if any(p.poll() is not None for p in processes):
            raise RuntimeError("server exited")
        listening = sum(pathlib.Path(log.name).read_text().count("listening") for log in logs)
        if listening >= workers:
            try:
                return fetch(path)
            except Exception:
                pass
        time.sleep(0.1)
    raise RuntimeError("server not ready")


def descendants(pid):
    found = [pid]
    for child in pathlib.Path(f"/proc/{pid}/task/{pid}/children").read_text().split():
        found += descendants(int(child))
    return found


def cpu_ticks(pids):
    total = 0
    for pid in pids:
        fields = pathlib.Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        total += int(fields[11]) + int(fields[12])
    return total


def sample(name, scenario, index):
    kind, count, rts, extra = VARIANTS[name]
    path, expected, headers = SCENARIOS[scenario]
    tag = f"{name}-{scenario}-{index}"
    logs = [open(OUT / "raw" / f"{tag}.server{i}.log", "w") for i in range(count)]
    env = {**os.environ, "PORT": PORT, **extra}
    processes = [
        subprocess.Popen(["taskset", "-c", "0-3", str(OUT / "bin" / f"{kind}-{scenario}"), *rts], stdout=log, stderr=log, env=env)
        for log in logs
    ]
    workers = int(extra.get("BENDO_WORKERS", count))
    try:
        check = ready(path, processes, logs, workers)
        if check["status"] != 200 or check["body"] != expected:
            raise RuntimeError(f"wrong response for {tag}: {check['status']} {check['body'][:80]!r}")
        for key, value in headers.items():
            if check["headers"].get(key) != value:
                raise RuntimeError(f"wrong {key} for {tag}: {check['headers'].get(key)!r}")
        pids = [pid for p in processes for pid in descendants(p.pid)]
        if len(pids) != workers:
            raise RuntimeError(f"{tag}: expected {workers} server processes, found {len(pids)}")
        common = [
            "taskset", "-c", "4-7", OHA, "--output-format", "json", "--no-tui", "-w", "-t", "5s", "--worker-threads", "2",
            "--http-version", "1.1", "-c", "64", "-H", "Content-Type: application/json", "-H", "Origin: https://bench.example",
        ]
        url = f"http://127.0.0.1:{PORT}{path}"
        subprocess.run(common + ["-z", "3s", url], check=True, stdout=subprocess.DEVNULL)
        before = cpu_ticks(pids)
        result = subprocess.run(common + ["-z", "10s", url], check=True, capture_output=True, text=True, timeout=30)
        after = cpu_ticks(pids)
        data = json.loads(result.stdout)
        (OUT / "raw" / f"{tag}.oha.json").write_text(result.stdout)
        codes = data.get("statusCodeDistribution", {})
        responses = sum(codes.values())
        errors = sum(data.get("errorDistribution", {}).values()) + sum(n for code, n in codes.items() if code != "200")
        seconds = (after - before) / os.sysconf("SC_CLK_TCK")
        row = {
            "variant": name, "scenario": scenario, "sample": index, "processes": len(pids),
            "rps": data["summary"]["requestsPerSec"],
            "p50Ms": data["latencyPercentiles"]["p50"] * 1000,
            "p99Ms": data["latencyPercentiles"]["p99"] * 1000,
            "responses": responses, "errors": errors,
            "cpuUsPerResponse": seconds * 1e6 / responses,
            "check": check,
        }
        print(json.dumps({k: row[k] for k in ("variant", "scenario", "sample", "rps", "p50Ms", "cpuUsPerResponse", "errors")}), flush=True)
        return row
    finally:
        for p in processes:
            p.terminate()
        for p in processes:
            try:
                p.wait(timeout=4)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait()
        for log in logs:
            log.close()


def main():
    (OUT / "bin").mkdir(parents=True, exist_ok=True)
    (OUT / "raw").mkdir(parents=True, exist_ok=True)
    for scenario in SCENARIOS:
        build(scenario)
    names = list(VARIANTS)
    saved = OUT / "samples.json"
    rows = json.loads(saved.read_text()) if saved.exists() else []
    for index in range(1, SAMPLES + 1):
        order = names if index % 2 else list(reversed(names))
        for name in order:
            for scenario in SCENARIOS:
                if any(r["variant"] == name and r["scenario"] == scenario and r["sample"] == index for r in rows):
                    continue
                rows.append(sample(name, scenario, index))
                saved.write_text(json.dumps(rows, indent=1))
    summary = {}
    for name in names:
        for scenario in SCENARIOS:
            got = [r for r in rows if r["variant"] == name and r["scenario"] == scenario]
            summary.setdefault(name, {})[scenario] = {
                metric: {"median": statistics.median(r[metric] for r in got), "min": min(r[metric] for r in got), "max": max(r[metric] for r in got)}
                for metric in ("rps", "p50Ms", "p99Ms", "cpuUsPerResponse")
            } | {"errors": sum(r["errors"] for r in got)}
    (OUT / "summary.json").write_text(json.dumps(summary, indent=1))
    print("CORES-DONE", flush=True)


main()
