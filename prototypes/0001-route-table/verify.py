#!/usr/bin/env python3
"""Exercise all 50 routes, then exactly 50 persistent sockets x 20 increments."""
import concurrent.futures
import http.client
import os
from pathlib import Path
import socket
import subprocess
import threading

ROOT = Path(__file__).resolve().parent

def start(binary, mode):
    process = subprocess.Popen([str(binary), '+RTS', '--threads', '1'],
                               env={**os.environ, 'MODE': mode}, stdout=subprocess.PIPE)
    assert process.stdout.readline() == b'ready\n'
    return process

def request(conn, path):
    conn.request('GET', path)
    response = conn.getresponse()
    assert response.status == 200
    return response.read().decode()

def stop(process):
    process.terminate()
    process.wait(timeout=5)

if __name__ == '__main__':
    binary = ROOT / 'bin/data-50'
    process = start(binary, 'serve')
    try:
        conn = http.client.HTTPConnection('127.0.0.1', 18803, timeout=10)
        for i in range(1, 51):
            assert request(conn, f'/r{i:03}') == str(i)
        assert request(conn, '/r999') == 'missing'
        conn.close()
        print('PASS data-50: all 50 route-specific responses, plus miss')
    finally:
        stop(process)
    process = start(binary, 'counter')
    try:
        # Pre-open exactly 50 sockets; each worker owns and reuses one socket.
        conns = [http.client.HTTPConnection('127.0.0.1', 18803, timeout=20) for _ in range(50)]
        for conn in conns:
            conn.connect()
        sockets = [conn.sock for conn in conns]
        barrier = threading.Barrier(50, timeout=15)
        def worker(pair):
            i, conn = pair
            barrier.wait()
            values = []
            for _ in range(20):
                values.append(int(request(conn, f'/r{i+1:03}')))
                assert conn.sock is sockets[i], 'connection was replaced'
            return values
        with concurrent.futures.ThreadPoolExecutor(max_workers=50) as pool:
            values = sum(pool.map(worker, enumerate(conns)), [])
        assert sorted(values) == list(range(1, 1001))
        assert request(conns[0], '/__count') == '1000'
        for conn in conns:
            conn.close()
        print('PASS counter: 50 unchanged sockets x 20 = 1000; replies 1..1000; final read=1000')
    finally:
        stop(process)
