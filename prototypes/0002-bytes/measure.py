#!/usr/bin/env python3
"""Run only in an isolated sandbox. One native server, one local oha, sequential samples."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
from fixtures import CASES

OUT = Path(os.environ.get('BND4_OUT', '/tmp/bendo-0002-bytes'))
OHA = os.environ.get('OHA', '/home/user/oha')


def main():
    for sample in range(1, 4):
        for kind in ('bytes', 'strings'):
            result = subprocess.run([str(OUT / f'bench-{kind}'), '+RTS', '--threads', '1'], check=True, text=True, capture_output=True, timeout=60)
            print(json.dumps(dict(mode='pure', sample=sample, kind=kind, output=result.stdout.strip())), flush=True)
        # Alternate order to reduce warmup/order bias. All servers exit between samples.
        for kind in (('bytes', 'strings') if sample % 2 else ('strings', 'bytes')):
            server = subprocess.Popen([str(OUT / f'server-{kind}'), '+RTS', '--threads', '1'], env=dict(os.environ, PORT='18784', RECV_MAX='65536'), stdout=subprocess.PIPE)
            try:
                assert server.stdout.readline().strip() == b'ready'
                for case, body in CASES.items():
                    with tempfile.NamedTemporaryFile() as payload:
                        payload.write(body)
                        payload.flush()
                        result = subprocess.run([OHA, '--no-tui', '--disable-keepalive', '--output-format', 'json', '-c', '16', '-z', '3s', '-w', '-t', '3s', '-m', 'POST', '-T', 'application/json' if case == 'utf8' else 'application/octet-stream', '-D', payload.name, 'http://127.0.0.1:18784/echo?source=prototype'], check=True, capture_output=True, text=True, timeout=20)
                    report = json.loads(result.stdout)
                    print(json.dumps(dict(mode='http', sample=sample, kind=kind, case=case, report=report)), flush=True)
                    assert report['summary']['successRate'] == 1, report
            finally:
                server.terminate()
                server.communicate(timeout=5)


if __name__ == '__main__':
    main()
