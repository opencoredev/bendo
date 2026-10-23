"""Run only on an isolated Boat VM: real 1/100 MiB streams and a paused peer."""
import http.client
import json
import os
import socket
import subprocess
import sys
import threading
import time


class Server:
    def __init__(self, binary, extra_env=None):
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            self.port = probe.getsockname()[1]
        self.counts = {"pull": 0, "cleanup": 0, "after": 0}
        self.events = []
        self.proc = subprocess.Popen(
            [binary], env={**os.environ, "PORT": str(self.port), **(extra_env or {})},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        self.reader = threading.Thread(target=self.logs, daemon=True)
        self.reader.start()
        deadline = time.monotonic() + 20
        while True:
            try:
                with socket.create_connection(("127.0.0.1", self.port), timeout=1) as peer:
                    peer.sendall(b"GET / HTTP/1.1\r\nHost: test\r\nConnection: close\r\n\r\n")
                    peer.recv(4096)
                break
            except OSError:
                if self.proc.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("server startup failed")
                time.sleep(0.025)
        time.sleep(0.02)
        self.counts = {"pull": 0, "cleanup": 0, "after": 0}
        self.events = []

    def logs(self):
        for line in self.proc.stdout:
            key = line.strip()
            if key in self.counts:
                self.counts[key] += 1
                self.events.append(key)

    def rss(self):
        fields = {}
        with open(f"/proc/{self.proc.pid}/status") as status:
            for line in status:
                if line.startswith(("VmRSS:", "VmHWM:")):
                    key, value, _unit = line.split()
                    fields[key[:-1]] = int(value)
        return fields

    def queued(self):
        total = 0
        with open("/proc/net/tcp") as table:
            for line in list(table)[1:]:
                columns = line.split()
                if int(columns[1].split(":")[1], 16) == self.port:
                    total += int(columns[4].split(":")[0], 16)
        return total

    def close(self):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=5)
        self.reader.join(timeout=2)
        self.proc.stdout.close()
        self.proc.stderr.close()


def download(binary, mib):
    server = Server(binary)
    try:
        before = server.rss()
        client = http.client.HTTPConnection("127.0.0.1", server.port, timeout=20)
        started = time.monotonic()
        client.request("GET", f"/stream?chunks={mib * 256}", headers={"Connection": "close"})
        response = client.getresponse()
        assert response.status == 200
        assert response.getheader("transfer-encoding") == "chunked"
        total = 0
        while True:
            data = response.read(65536)
            if not data:
                break
            assert data == b"x" * len(data)
            total += len(data)
        client.close()
        time.sleep(0.05)
        assert total == mib * 1048576, total
        assert server.counts["pull"] == mib * 256, server.counts
        assert server.counts["cleanup"] == 1 and server.counts["after"] == 1, server.counts
        return {"mib": mib, "bytes": total, "baseline_rss_kib": before["VmRSS"],
                "peak_rss_kib": server.rss()["VmHWM"], "seconds": round(time.monotonic()-started, 3)}
    finally:
        server.close()


def paused(binary, mib):
    server = Server(binary)
    try:
        peer = socket.socket()
        peer.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)
        peer.settimeout(5)
        peer.connect(("127.0.0.1", server.port))
        peer.sendall(f"GET /stream?chunks={mib * 256} HTTP/1.1\r\nHost: test\r\n\r\n".encode())
        # Deliberately do not recv. The producer must stop at the socket budget.
        samples = []
        for _ in range(3):
            time.sleep(0.15)
            samples.append({"rss_kib": server.rss()["VmRSS"], "queued_bytes": server.queued(),
                            "pulls": server.counts["pull"]})
        time.sleep(0.45)
        assert server.counts["cleanup"] == 1 and server.counts["after"] == 1, server.counts
        assert samples[-1]["pulls"] == samples[-2]["pulls"], samples
        assert samples[-1]["pulls"] < mib * 256, samples
        # Drain after the write deadline: incomplete framing must end with EOF,
        # and must never be mistaken for a successfully terminated response.
        received = 0
        last = b""
        while True:
            data = peer.recv(65536)
            if not data:
                break
            received += len(data)
            last = (last + data)[-5:]
        peer.close()
        assert last != b"0\r\n\r\n", last
        return {"mib": mib, "samples": samples, "pulled_bytes": server.counts["pull"] * 4096,
                "drained_bytes": received, "peak_rss_kib": server.rss()["VmHWM"],
                "cleanup": server.counts["cleanup"], "after": server.counts["after"]}
    finally:
        server.close()


def lifecycle(binary):
    for method, path, status, cleanups in [
        ("GET", "/empty", 200, 1),
        ("GET", "/late", 504, 1),
        ("GET", "/broken", 200, 1),
        ("HEAD", "/stream", 200, 1),
        ("GET", "/status?code=103", 103, 1),
        ("GET", "/status?code=204", 204, 1),
        ("GET", "/status?code=205", 205, 1),
        ("GET", "/status?code=304", 304, 1),
        ("GET", "/replace", 200, 1),
        ("GET", "/duplicate", 500, 2),
        ("GET", "/invalid", 200, 1),
        ("GET", "/oversize", 200, 1),
    ]:
        server = Server(binary)
        try:
            client = http.client.HTTPConnection("127.0.0.1", server.port, timeout=5)
            client.request(method, path, headers={"Connection": "close"})
            response = client.getresponse()
            assert response.status == status, (path, response.status)
            try:
                response.read()
            except http.client.IncompleteRead:
                assert path in ("/broken", "/invalid", "/oversize"), path
            client.close()
            deadline = time.monotonic() + 2
            while server.counts["cleanup"] < cleanups and time.monotonic() < deadline:
                time.sleep(0.01)
            assert server.counts["cleanup"] == cleanups, (path, server.counts)
            assert server.counts["after"] == 1, (path, server.counts)
            assert server.events[-1] == ("cleanup" if path == "/late" else "after"), (path, server.events)
            if path not in ("/empty", "/invalid", "/oversize"):
                assert server.counts["pull"] == 0, (path, server.counts)
        finally:
            server.close()
    print("lifecycle: cleanup and after_response exactly once, suppression never pulls")


def clock_failure(binary, preload):
    server = Server(binary, {"LD_PRELOAD": preload})
    try:
        with socket.create_connection(("127.0.0.1", server.port), timeout=5) as peer:
            peer.sendall(b"GET /stream HTTP/1.1\r\nHost: test\r\n\r\nGET / HTTP/1.1\r\nHost: test\r\nConnection: close\r\n\r\n")
            wire = b""
            while True:
                data = peer.recv(4096)
                if not data:
                    break
                wire += data
        responses = wire.split(b"\r\n\r\n")
        assert len(responses) == 3 and responses[-1] == b"", wire
        assert all(head.startswith(b"HTTP/1.1 500 ") for head in responses[:2]), wire
        assert all(b"content-length: 0" in head for head in responses[:2]), wire
        assert b"transfer-encoding" not in wire and b"x-bendo-stream-internal" not in wire, wire
        time.sleep(0.05)
        assert server.counts == {"pull": 0, "cleanup": 1, "after": 2}, server.counts
        print("clock failure: stream cancelled before head, pipeline intact")
    finally:
        server.close()


if __name__ == "__main__":
    if len(sys.argv) > 3 and sys.argv[2] == "--clock-fail":
        clock_failure(sys.argv[1], sys.argv[3])
        sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[2] == "--small":
        lifecycle(sys.argv[1])
        sys.exit(0)
    binary = sys.argv[1]
    small = download(binary, 1)
    large = download(binary, 100)
    # Compare growth rather than absolute RSS: 100x output permits at most twice
    # the 1 MiB peak, plus that same run's measured baseline for startup variance.
    assert large["peak_rss_kib"] <= 2 * small["peak_rss_kib"] + small["baseline_rss_kib"], (small, large)
    slow_small = paused(binary, 4)
    slow_large = paused(binary, 100)
    assert slow_large["peak_rss_kib"] <= 2 * slow_small["peak_rss_kib"], (slow_small, slow_large)
    assert slow_large["pulled_bytes"] <= 2 * slow_small["pulled_bytes"], (slow_small, slow_large)
    assert max(s["queued_bytes"] for s in slow_large["samples"]) <= 2 * max(s["queued_bytes"] for s in slow_small["samples"]), (slow_small, slow_large)
    print(json.dumps({"downloads": [small, large], "paused": [slow_small, slow_large]}, indent=2))
