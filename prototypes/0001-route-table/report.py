#!/usr/bin/env python3
"""Summarize medians; optionally check a repeat run against a recorded run."""
import argparse
import json
from pathlib import Path
from statistics import median

parser = argparse.ArgumentParser()
parser.add_argument('result', type=Path)
parser.add_argument('--compare', type=Path)
args = parser.parse_args()
data = json.loads(args.result.read_text())

def summary(data):
    rows = {}
    for shape in ('list', 'data', 'chain'):
        for count in (5, 50, 500):
            samples = [s for s in data['samples'] if s['shape'] == shape and s['routes'] == count]
            assert samples, (shape, count)
            rows[shape, count] = [median(s['ns_per_request'][i] for s in samples) for i in range(3)] + [median(s['rps'] for s in samples)]
    return rows

rows = summary(data)
print('| Shape | Routes | Mixed ns/req | Last ns/req | Miss ns/req | HTTP req/s |')
print('|---|---:|---:|---:|---:|---:|')
for (shape, count), row in rows.items():
    print(f'| {shape} | {count} | ' + ' | '.join(f'{n:,.0f}' for n in row) + ' |')
if args.compare:
    baseline = summary(json.loads(args.compare.read_text()))
    deviations = [abs(value/base-1) for key in rows for value, base in zip(rows[key], baseline[key])]
    worst = max(deviations)
    print(f'{"PASS" if worst <= .2 else "FAIL"}: all 36 median metrics within 20%; maximum deviation={worst:.2%}')
    raise SystemExit(0 if worst <= .2 else 1)
