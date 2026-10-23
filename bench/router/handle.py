#!/usr/bin/env python3
"""Bounded native full-request benchmark for route-count overhead (run on Boat)."""
import argparse
import json
import statistics
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--no-gate", action="store_true")
    args = parser.parse_args()
    samples = []
    iterations = 10000
    for repeat in range(5):
        for count in ((10, 2000) if repeat % 2 == 0 else (2000, 10)):
            run = subprocess.run([str(args.binary), str(count), str(iterations),
                                  "+RTS", "--threads", "1"], check=True,
                                 capture_output=True, text=True, timeout=30)
            fields = dict(line.split("=", 1) for line in run.stdout.splitlines())
            if int(fields["checksum"]) != iterations * 200:
                raise RuntimeError(f"incorrect request status checksum: {run.stdout}")
            samples.append(dict(repeat=repeat, count=count, iterations=iterations,
                                ns_per_request=int(fields["ms"]) * 1000000 / iterations))
    medians = {str(count): statistics.median(s["ns_per_request"] for s in samples
                                           if s["count"] == count) for count in (10, 2000)}
    ratio = medians["2000"] / max(1, medians["10"])
    result = dict(samples=samples, median_ns=medians, large_to_small=ratio)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    # 200x as many routes must not turn the fixed static hit into linear work.
    # Allow 25% noise across five medians; extra routes must add no traversal.
    if not args.no_gate and ratio > 1.25:
        raise RuntimeError(f"request cost scales with route count: {ratio:.2f}x")


if __name__ == "__main__":
    main()
