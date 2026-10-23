#!/usr/bin/env python3
"""Run INSIDE a default Boat sandbox. Raw samples are retained for audit."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time
from verify import start, stop, request
import http.client

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=ROOT / 'results.json')
parser.add_argument('--repeats', type=int, default=3)
args = parser.parse_args()
assert 1 <= args.repeats <= 5
os.environ['BEND_NO_TELEMETRY'] = '1'
subprocess.run(['python3', str(ROOT / 'generate.py')], check=True)
(ROOT / 'bin').mkdir(exist_ok=True)
results = {'hardware': subprocess.check_output(['lscpu'], text=True),
           'memory': Path('/proc/meminfo').read_text(),
           'bend': subprocess.check_output(['bend', 'version'], text=True),
           'clang': subprocess.check_output(['clang', '--version'], text=True),
           'oha': subprocess.check_output(['oha', '--version'], text=True),
           'samples': [], 'builds': []}

def save():
    args.output.write_text(json.dumps(results, indent=2) + '\n')

def pure(binary, iterations):
    out = subprocess.check_output([str(binary), '+RTS', '--threads', '1'], text=True,
                                  timeout=120, env={**os.environ, 'MODE': 'bench', 'ITERATIONS': str(iterations)})
    checks = list(map(int, re.findall(r'checksum=(\d+)', out)))
    times = list(map(int, re.findall(r'ms=(\d+)', out)))
    assert len(checks) == len(times) == 3, out
    return checks, times

for count in (5, 50, 500):
    for shape in ('list', 'data', 'chain'):
        name = f'{shape}-{count}'
        binary = ROOT / 'bin' / name
        before = time.perf_counter()
        subprocess.run(['bend', str(ROOT / 'generated' / f'{name}.bend'), '-o', str(binary)], check=True, timeout=300)
        build = {'shape': shape, 'routes': count, 'seconds': time.perf_counter()-before, 'bytes': binary.stat().st_size}
        results['builds'].append(build)
        print('build', build, flush=True)
        save()

for repeat in range(args.repeats):
    order = ['list', 'data', 'chain']
    order = order[repeat % 3:] + order[:repeat % 3]
    for count in (5, 50, 500):
        for shape in order:
            binary = ROOT / 'bin' / f'{shape}-{count}'
            _, pilot = pure(binary, 20000)
            iterations = min(2000000, max(20000, int(20000 * 750 / max(pilot[0], 1))))
            # Round to full route cycles for an independent arithmetic checksum.
            iterations = max(count, iterations // count * count)
            checks, times = pure(binary, iterations)
            assert checks == [iterations * (count+1)//2 % 2**32, iterations*count % 2**32, 0], checks
            sample = {'repeat': repeat, 'shape': shape, 'routes': count, 'iterations': iterations,
                      'checksums': checks, 'ms': times,
                      'ns_per_request': [ms*1000000/iterations for ms in times]}
            process = start(binary, 'serve')
            try:
                conn = http.client.HTTPConnection('127.0.0.1', 18803, timeout=5)
                assert request(conn, f'/r{count:03}') == str(count)
                conn.close()
                subprocess.run(['oha', '--no-tui', '-z', '1s', '-c', '50', f'http://127.0.0.1:18803/r{count:03}'], check=True, stdout=subprocess.DEVNULL, timeout=15)
                output = subprocess.check_output(['oha', '--no-tui', '--json', '-z', '3s', '-c', '50', f'http://127.0.0.1:18803/r{count:03}'], text=True, timeout=20)
                http_result = json.loads(output)
                sample['http'] = http_result
                sample['rps'] = http_result['summary']['requestsPerSec']
                assert http_result['summary']['successRate'] == 1, http_result
            finally:
                stop(process)
            results['samples'].append(sample)
            save()
            print(shape, count, 'ns', sample['ns_per_request'], 'rps', sample['rps'], flush=True)
subprocess.run(['python3', str(ROOT / 'verify.py')], check=True, timeout=60)
