#!/usr/bin/env python3
"""Bounded native router lookup benchmark; no server or load generator."""
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
MODES = ("mixed", "last", "miss", "first", "dynamic-first", "dynamic-last")


def command(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs).stdout


def sample(binary, count, kind, mode, cycles):
    output = command(
        [str(binary), str(count), kind, mode, str(cycles), "+RTS", "--threads", "1"],
        timeout=30,
    )
    fields = dict(line.split("=", 1) for line in output.splitlines())
    iterations = count * cycles
    expected = (
        cycles * count * (count + 1) // 2 if mode == "mixed"
        else 0 if mode == "miss"
        else iterations if mode in ("first", "dynamic-first")
        else iterations * count
    ) & 0xFFFFFFFF
    checksum = int(fields["checksum"])
    if checksum != expected:
        raise RuntimeError(f"checksum {checksum} != {expected}: {output}")
    ms = int(fields["ms"])
    return dict(count=count, kind=kind, mode=mode, iterations=iterations,
                checksum=checksum, expected=expected, ms=ms,
                ns_per_lookup=ms * 1_000_000 / iterations,
                prepare_ms=int(fields["prepare_ms"]),
                prepared_weight=int(fields["prepared_weight"]),
                path_weight=int(fields["path_weight"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "bench/router/results.json")
    parser.add_argument("--quick", action="store_true", help="one short development repeat")
    args = parser.parse_args()
    repeats, target_ms, cap = (1, 25, 20000) if args.quick else (3, 200, 1000000)
    started = time.monotonic()
    samples = []
    with tempfile.TemporaryDirectory(prefix="bendo-router-bench-") as directory:
        binary = Path(directory) / "lookup"
        build_start = time.monotonic()
        command(["bend", str(ROOT / "bench/router/lookup.bend"), "-o", str(binary)], timeout=120)
        build_seconds = time.monotonic() - build_start
        cycles_for = {}
        for count in (5, 50, 500):
            for mode in MODES:
                for kind in ("spec", "trie"):
                    pilot = sample(binary, count, kind, mode, max(1, 100 // count))
                    desired = int(pilot["iterations"] * target_ms / max(1, pilot["ms"]))
                    cycles_for[count, mode, kind] = max(count, min(cap, desired)) // count
        for repeat in range(repeats):
            for count in (5, 50, 500):
                for mode in MODES:
                    for kind in (("spec", "trie") if repeat % 2 == 0 else ("trie", "spec")):
                        got = sample(binary, count, kind, mode, cycles_for[count, mode, kind])
                        samples.append(dict(repeat=repeat, **got))
        medians = []
        print("routes workload spec_ns trie_ns speedup")
        for count in (5, 50, 500):
            for mode in MODES:
                row = dict(count=count, mode=mode)
                for kind in ("spec", "trie"):
                    row[kind] = statistics.median(s["ns_per_lookup"] for s in samples
                                                  if s["count"] == count and s["mode"] == mode and s["kind"] == kind)
                row["speedup"] = row["spec"] / row["trie"] if row["trie"] else None
                medians.append(row)
                print(f"{count:6} {mode:13} {row['spec']:9.0f} {row['trie']:9.0f} {row['speedup'] or 0:7.2f}x")
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
        if not args.quick:
            mixed = next(row for row in medians if row["count"] == 500 and row["mode"] == "mixed")
            if mixed["speedup"] is None or mixed["speedup"] < 5:
                raise RuntimeError("500-route mixed lookup missed the 5x acceptance target")


if __name__ == "__main__":
    main()
