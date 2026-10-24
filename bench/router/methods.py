#!/usr/bin/env python3
"""Bounded native Methods.resolve_with benchmark; no server or load generator."""
import argparse
import json
import os
import platform
from pathlib import Path
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
COUNTS = (5, 50, 500)
MODES = ("first", "last", "miss", "405", "head")
# Found adds its tag (+1,000,000 for HEAD from GET); 405 adds 100,000 plus the
# Allow length ([GET, HEAD]); 404 adds nothing.
PER_LOOKUP = {"first": lambda n: 1, "last": lambda n: n, "miss": lambda n: 0,
              "405": lambda n: 100002, "head": lambda n: 1000001}


def command(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs).stdout


def sample(binary, count, kind, mode, iterations):
    output = command(
        [str(binary), str(count), kind, mode, str(iterations), "+RTS", "--threads", "1"],
        timeout=30,
    )
    fields = dict(line.split("=", 1) for line in output.splitlines())
    expected = (iterations * PER_LOOKUP[mode](count)) & 0xFFFFFFFF
    checksum = int(fields["checksum"])
    if checksum != expected:
        raise RuntimeError(f"{count} {kind} {mode}: checksum {checksum} != {expected}: {output}")
    ms = int(fields["ms"])
    return dict(count=count, kind=kind, mode=mode, iterations=iterations,
                checksum=checksum, expected=expected, ms=ms,
                ns_per_lookup=ms * 1_000_000 / iterations,
                prepare_ms=int(fields["prepare_ms"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "bench/router/methods-results.json")
    parser.add_argument("--quick", action="store_true", help="one short development repeat")
    parser.add_argument("--no-gate", action="store_true", help="report without the slowdown gate")
    args = parser.parse_args()
    repeats, target_ms, cap = (1, 25, 20000) if args.quick else (3, 200, 1000000)
    started = time.monotonic()
    samples = []
    with tempfile.TemporaryDirectory(prefix="bendo-methods-bench-") as directory:
        binary = Path(directory) / "methods"
        build_start = time.monotonic()
        command(["bend", str(ROOT / "bench/router/methods.bend"), "-o", str(binary)], timeout=180)
        build_seconds = time.monotonic() - build_start
        iterations_for = {}
        for count in COUNTS:
            for mode in MODES:
                for kind in ("spec", "trie"):
                    pilot = sample(binary, count, kind, mode, 10)
                    desired = int(10 * target_ms / max(1, pilot["ms"]))
                    iterations_for[count, mode, kind] = max(1, min(cap, desired))
        for repeat in range(repeats):
            for count in COUNTS:
                for mode in MODES:
                    for kind in (("spec", "trie") if repeat % 2 == 0 else ("trie", "spec")):
                        got = sample(binary, count, kind, mode, iterations_for[count, mode, kind])
                        samples.append(dict(repeat=repeat, **got))
        medians = []
        print("routes workload spec_ns trie_ns spec/trie")
        for count in COUNTS:
            for mode in MODES:
                row = dict(count=count, mode=mode)
                for kind in ("spec", "trie"):
                    row[kind] = statistics.median(s["ns_per_lookup"] for s in samples
                                                  if s["count"] == count and s["mode"] == mode and s["kind"] == kind)
                row["speedup"] = row["spec"] / row["trie"] if row["trie"] else None
                medians.append(row)
                print(f"{count:6} {mode:8} {row['spec']:11.0f} {row['trie']:11.0f} {row['speedup'] or 0:7.2f}x")
        result = dict(sandbox=os.getenv("BOAT_SANDBOX_ID", "local"),
                      bend=command(["bend", "version"]).strip(), platform=platform.platform(),
                      cpu=command(["sh", "-c", "lscpu | sed -n '/Model name:/p'"]).strip(),
                      clang=command(["clang", "--version"]).splitlines()[0],
                      build_seconds=build_seconds, binary_bytes=binary.stat().st_size,
                      target_ms=target_ms, cap=cap, repeats=repeats,
                      seconds=time.monotonic() - started, samples=samples, medians=medians)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n")
        print(f"checksums verified: {len(samples)} samples; results={args.output}")
        if not (args.quick or args.no_gate):
            # The trie may add prefix traversal, but never more than twice the
            # spec cost plus 2 microseconds on any workload.
            slow = [row for row in medians if row["trie"] > 2 * row["spec"] + 2000]
            if slow:
                raise RuntimeError(f"trie slower than spec beyond the bound: {slow}")


if __name__ == "__main__":
    main()
