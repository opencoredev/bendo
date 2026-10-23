#!/usr/bin/env python3
"""Exercise real native TCP effects. Expected String corruption is evidence, not a pass."""
import json
import os
from pathlib import Path
import socket
import subprocess
import time
from fixtures import CASES, request

OUT = Path(os.environ.get("BND4_OUT", "/tmp/bendo-0002-bytes"))


def exchange(port, raw, split):
    with socket.create_connection(("127.0.0.1", port), timeout=3) as client:
        client.settimeout(3)
        client.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        if split:
            head, body = raw.split(b"\r\n\r\n", 1)
            chunks = [head + b"\r\n\r\n"] + [body[i:i + 7] for i in range(0, len(body), 7)]
        else:
            chunks = [raw]
        for chunk in chunks:
            try:
                client.sendall(chunk)
            except (BrokenPipeError, ConnectionResetError):
                break
            if split:
                time.sleep(0.002)
        received = bytearray()
        while True:
            try:
                chunk = client.recv(65536)
            except ConnectionResetError:
                break
            if not chunk:
                break
            received.extend(chunk)
    head, body = bytes(received).split(b"\r\n\r\n", 1)
    length = int(next(line.split(b":", 1)[1] for line in head.split(b"\r\n") if line.lower().startswith(b"content-length:")))
    return body, length


def main():
    for kind in ("bytes", "strings"):
        for limit, split in ((65536, False), (65536, True), (1, False), (7, True)):
            with socket.socket() as reserve:
                reserve.bind(("127.0.0.1", 0))
                port = reserve.getsockname()[1]
            env = dict(os.environ, PORT=str(port), RECV_MAX=str(limit))
            server = subprocess.Popen([str(OUT / f"server-{kind}"), "+RTS", "--threads", "1"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                assert server.stdout.readline().strip() == b"ready"
                for case, original in CASES.items():
                    body, length = exchange(port, request(original), split)
                    exact = body == original and length == len(original)
                    print(json.dumps(dict(kind=kind, case=case, recv_max=limit, split=split, input=len(original), output=len(body), content_length=length, exact=exact)), flush=True)
                    assert length == len(body), "Response length does not describe emitted bytes"
                    if kind == "bytes":
                        assert exact
                    elif case == "binary" or limit == 1:
                        assert not exact, "String candidate unexpectedly preserved this fixture; revisit decision"
                    # Whole writes may fragment; delayed writes may coalesce. String JSON
                    # with larger recv limits is observational. RECV_MAX=1 proves the loss.
            finally:
                server.terminate()
                server.communicate(timeout=5)
    print("PASS: bytes preserve both bodies across reads; String failures reproduced")


if __name__ == "__main__":
    main()
