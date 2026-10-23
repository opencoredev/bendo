import Base
import ./strings.bend as P

def score(frame: Maybe<&2, P.Frame>) -> U32:
  match frame:
    case None{}: 0
    case Some{P.Frame{headers, body, expected, actual}}: (expected + actual : U32)

def repeat(n: Nat, +input: String, acc: U32) -> U32:
  match n:
    case 0n: acc
    case 1n+p: repeat(p, input, (acc + score(P.parse(input)) : U32))

def utf8() -> String:
  "POST /echo?source=prototype HTTP/1.1\r\nHost: bendo.test\r\nContent-Type: application/octet-stream\r\nContent-Length: 96\r\nX-Request-Id: 0002-bytes\r\nConnection: close\r\n\r\n{\"message\":\"café 東京 😀 café 東京 😀 café 東京 😀 café 東京 😀 \",\"ok\":true}"

def binary() -> String:
  "POST /echo?source=prototype HTTP/1.1\r\nHost: bendo.test\r\nContent-Type: application/octet-stream\r\nContent-Length: 512\r\nX-Request-Id: 0002-bytes\r\nConnection: close\r\n\r\n\u{0000}\u{0001}\u{0002}\u{0003}\u{0004}\u{0005}\u{0006}\u{0007}\u{8}\t\n\u{000b}\u{c}\r\u{000e}\u{000f}\u{0010}\u{0011}\u{0012}\u{0013}\u{0014}\u{0015}\u{0016}\u{0017}\u{0018}\u{0019}\u{001a}\u{001b}\u{001c}\u{001d}\u{001e}\u{001f} !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~��������������������������������������������������������������������������������������������������������������������������������\u{0000}\u{0001}\u{0002}\u{0003}\u{0004}\u{0005}\u{0006}\u{0007}\u{8}\t\n\u{000b}\u{c}\r\u{000e}\u{000f}\u{0010}\u{0011}\u{0012}\u{0013}\u{0014}\u{0015}\u{0016}\u{0017}\u{0018}\u{0019}\u{001a}\u{001b}\u{001c}\u{001d}\u{001e}\u{001f} !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~��������������������������������������������������������������������������������������������������������������������������������"

def measure(label: String, input: String) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    checksum : U32 = repeat(20000n, input, 0)
    stop : Nat <- IO.now()
    IO.print(label ++ " iterations=20000 ms=" ++ Nat.show(Nat.sub(stop, start)) ++ " checksum=" ++ U32.show(checksum))

def main() -> IO(Unit):
  do IO<Unit>:
    measure("utf8", utf8())
    measure("binary", binary())
