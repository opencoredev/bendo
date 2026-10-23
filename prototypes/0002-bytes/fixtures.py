"""Shared deterministic request fixtures; no third-party Python dependencies."""
import json

UTF8 = json.dumps({'message': 'café 東京 😀 ' * 4, 'ok': True}, ensure_ascii=False, separators=(',', ':')).encode()
BINARY = bytes(range(256)) * 2
CASES = {"utf8": UTF8, "binary": BINARY}


def request(body, content_type="application/octet-stream"):
    return (
        "POST /echo?source=prototype HTTP/1.1\r\n"
        "Host: bendo.test\r\n"
        f"Content-Type: {content_type}\r\n"
        f"Content-Length: {len(body)}\r\n"
        "X-Request-Id: 0002-bytes\r\n"
        "Connection: close\r\n\r\n"
    ).encode() + body
