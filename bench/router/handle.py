#!/usr/bin/env python3
"""Bounded native full-request benchmark for route-count overhead (run on Boat).

Each shape builds a table of 10 or 2,000 routes and times a static hit on the
first one: plain routes (BND-24), or every route inside one group or one guard
with a before-handle hook (BND-82), so each extra route adds a scoped layer.
The gate is a growth ratio per shape, not an absolute time.
"""
import argparse
import json
import statistics
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHAPES = ("plain", "group", "guard")
COUNTS = (10, 2000)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--shapes", default=",".join(SHAPES))
    parser.add_argument("--no-gate", action="store_true")
    args = parser.parse_args()
    shapes = [shape for shape in args.shapes.split(",") if shape]
    samples = []
    iterations = 10000
    for repeat in range(5):
        for shape in shapes:
            for count in (COUNTS if repeat % 2 == 0 else COUNTS[::-1]):
                run = subprocess.run([str(args.binary), str(count), str(iterations), shape,
                                      "+RTS", "--threads", "1"], check=True,
                                     capture_output=True, text=True, timeout=60)
                fields = dict(line.split("=", 1) for line in run.stdout.splitlines())
                if int(fields["checksum"]) != iterations * 200:
                    raise RuntimeError(f"incorrect request status checksum: {run.stdout}")
                samples.append(dict(repeat=repeat, shape=shape, count=count, iterations=iterations,
                                    ns_per_request=int(fields["ms"]) * 1000000 / iterations))
    result = dict(samples=samples, shapes={})
    failures = []
    for shape in shapes:
        medians = {str(count): statistics.median(s["ns_per_request"] for s in samples
                                               if s["shape"] == shape and s["count"] == count)
                   for count in COUNTS}
        ratio = medians["2000"] / max(1, medians["10"])
        result["shapes"][shape] = dict(median_ns=medians, large_to_small=ratio)
        # 200x as many routes must not turn the fixed static hit into linear
        # work. Allow 25% noise across five medians.
        if ratio > 1.25:
            failures.append(f"{shape}: {ratio:.2f}x")
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result["shapes"]))
    if failures and not args.no_gate:
        raise RuntimeError("request cost scales with route count: " + ", ".join(failures))


if __name__ == "__main__":
    main()
