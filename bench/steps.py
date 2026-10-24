#!/usr/bin/env python3
"""Per-commit Bendo throughput comparison (BND-68). Boat large sandboxes only.

Usage: python3 bench/steps.py OUT_DIR NAME=SRC_DIR [NAME=SRC_DIR ...]

Each SRC_DIR is a source tree of one commit. The script builds the five
benchmark servers for every tree, then measures them with the BND-68 profile
recipe: server on CPUs 0-3, oha on CPUs 4-7, 64 keep-alive connections, two
oha workers, 3 s discarded warmup, 10 s measured sample, three samples per
server. Sample rounds alternate forward and reverse variant order. Every
sample first checks status 200, the exact body and the middleware headers,
and a sample with any oha error or non-200 status fails the run.
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
VARIANTS = [arg.split("=", 1) for arg in sys.argv[2:]]
SAMPLES = int(os.environ.get("STEPS_SAMPLES", "3"))
OHA = os.environ.get("OHA", "oha")
PORT = "8787"
HEADERS = {"Content-Type": "application/json", "Origin": "https://bench.example"}

ECHO = subprocess.run(
    ["bun", "-e", 'import { scenarios } from "./bench/scenarios.ts"; process.stdout.write(scenarios.find((s) => s.name === "echo").body)'],
    cwd=VARIANTS[0][1], check=True, capture_output=True, text=True,
).stdout
SECURE = {
    "cross-origin-resource-policy": "same-origin",
    "cross-origin-opener-policy": "same-origin",
    "origin-agent-cluster": "?1",
    "referrer-policy": "no-referrer",
    "strict-transport-security": "max-age=15552000; includeSubDomains",
    "x-content-type-options": "nosniff",
    "x-dns-prefetch-control": "off",
    "x-download-options": "noopen",
    "x-frame-options": "SAMEORIGIN",
    "x-permitted-cross-domain-policies": "none",
    "x-xss-protection": "0",
}
SCENARIOS = {
    "hello": ("/", None, "Hello, world!", {}),
    "json": ("/json", None, '{"message":"Hello, world!"}', {}),
    "params": ("/user/42", None, "User 42", {}),
    "echo": ("/echo", ECHO, ECHO, {}),
    "middleware": ("/middleware", None, "Hello, world!", {"access-control-allow-origin": "*", "x-bench": "middleware", **SECURE}),
}


def build(name, src):
    for scenario in SCENARIOS:
        binary = OUT / "bin" / f"{name}-{scenario}"
        if binary.exists():
            continue
        c_file = OUT / "bin" / f"{name}-{scenario}.c"
        subprocess.run(["bend", f"bench/servers/{scenario}.bend", "-o", str(c_file)], cwd=src, check=True)
        subprocess.run(["clang", "-std=c11", "-O3", str(c_file), "-o", str(binary), "-lpthread", "-lm"], check=True)
        print("built", binary.name, flush=True)


def ready(path, body, process):
    for _ in range(200):
        try:
            request = urllib.request.Request(f"http://127.0.0.1:{PORT}{path}", data=body.encode() if body else None, headers=HEADERS)
            with urllib.request.urlopen(request, timeout=2) as response:
                return {"status": response.status, "headers": {k.lower(): v for k, v in response.headers.items()}, "body": response.read().decode()}
        except Exception:
            if process.poll() is not None:
                raise RuntimeError("server exited")
            time.sleep(0.1)
    raise RuntimeError("server not ready")


def cpu_ticks(pid):
    fields = pathlib.Path(f"/proc/{pid}/stat").read_text().split()
    return int(fields[13]) + int(fields[14])


def sample(name, scenario, index):
    path, body, expected, headers = SCENARIOS[scenario]
    tag = f"{name}-{scenario}-{index}"
    log = open(OUT / "raw" / f"{tag}.server.log", "w")
    process = subprocess.Popen(["taskset", "-c", "0-3", str(OUT / "bin" / f"{name}-{scenario}")], stdout=log, stderr=log, env={**os.environ, "PORT": PORT})
    try:
        check = ready(path, body, process)
        if check["status"] != 200 or check["body"] != expected:
            raise RuntimeError(f"wrong response for {tag}: {check['status']} {check['body'][:80]!r}")
        for key, value in headers.items():
            if check["headers"].get(key) != value:
                raise RuntimeError(f"wrong {key} for {tag}: {check['headers'].get(key)!r}")
        if scenario == "middleware" and not check["headers"].get("x-request-id"):
            raise RuntimeError(f"missing x-request-id for {tag}")
        common = [
            "taskset", "-c", "4-7", OHA, "--output-format", "json", "--no-tui", "-w", "-t", "5s", "--worker-threads", "2",
            "--http-version", "1.1", "-c", "64", "-H", "Content-Type: application/json", "-H", "Origin: https://bench.example",
        ]
        if body:
            common += ["-m", "POST", "-d", body]
        url = f"http://127.0.0.1:{PORT}{path}"
        subprocess.run(common + ["-z", "3s", url], check=True, stdout=subprocess.DEVNULL)
        before = cpu_ticks(process.pid)
        result = subprocess.run(common + ["-z", "10s", url], check=True, capture_output=True, text=True, timeout=30)
        after = cpu_ticks(process.pid)
        data = json.loads(result.stdout)
        (OUT / "raw" / f"{tag}.oha.json").write_text(result.stdout)
        codes = data.get("statusCodeDistribution", {})
        responses = sum(codes.values())
        errors = sum(data.get("errorDistribution", {}).values()) + sum(n for code, n in codes.items() if code != "200")
        if errors:
            raise RuntimeError(f"{tag}: {errors} errors {data.get('errorDistribution')} {codes}")
        seconds = (after - before) / os.sysconf("SC_CLK_TCK")
        row = {
            "variant": name, "scenario": scenario, "sample": index,
            "rps": data["summary"]["requestsPerSec"],
            "p50Ms": data["latencyPercentiles"]["p50"] * 1000,
            "p99Ms": data["latencyPercentiles"]["p99"] * 1000,
            "responses": responses, "errors": errors,
            "cpuUsPerResponse": seconds * 1e6 / responses,
            "check": check,
        }
        print(json.dumps({k: row[k] for k in ("variant", "scenario", "sample", "rps", "p50Ms", "cpuUsPerResponse")}), flush=True)
        return row
    finally:
        process.terminate()
        try:
            process.wait(timeout=4)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        log.close()


def main():
    (OUT / "bin").mkdir(parents=True, exist_ok=True)
    (OUT / "raw").mkdir(parents=True, exist_ok=True)
    for name, src in VARIANTS:
        build(name, src)
    names = [name for name, _ in VARIANTS]
    rows = []
    for index in range(1, SAMPLES + 1):
        order = names if index % 2 else list(reversed(names))
        for name in order:
            for scenario in SCENARIOS:
                rows.append(sample(name, scenario, index))
                (OUT / "samples.json").write_text(json.dumps(rows, indent=1))
    summary = {}
    for name in names:
        for scenario in SCENARIOS:
            got = [r for r in rows if r["variant"] == name and r["scenario"] == scenario]
            summary.setdefault(name, {})[scenario] = {
                metric: {"median": statistics.median(r[metric] for r in got), "min": min(r[metric] for r in got), "max": max(r[metric] for r in got)}
                for metric in ("rps", "p50Ms", "p99Ms", "cpuUsPerResponse")
            }
    (OUT / "summary.json").write_text(json.dumps(summary, indent=1))
    print("STEPS-DONE", flush=True)


main()
