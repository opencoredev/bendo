import Base
import ../../../src/http/date_wire.bend as DateWire
import ../../../src/http/date_response.bend as DateResponse
import ../../../src/http/response.bend as Response
import ../../../src/http/bytes.bend as Bytes

def output(wire: List<&2, U32>) -> IO(Unit):
  IO.print(Bytes.ascii(wire))

def print_status(res: Response.Res) -> IO(Unit):
  Response.Res{status, hs, body, rep} = res
  IO.print(U32.show(status))

def main() -> IO(Unit):
  do IO<Unit>:
    a : List<&2, U32> <- DateWire.ensure(Bytes.encode("HTTP/1.1 103 Early Hints\r\n\r\n"))
    output(a)
    b : List<&2, U32> <- DateWire.ensure(Bytes.encode("HTTP/1.1 200 OK\r\nDaTe: Sun, 06 Nov 1994 08:49:37 GMT\r\ncontent-length: 4\r\n\r\nbody"))
    output(b)
    c : List<&2, U32> <- DateWire.ensure(Bytes.encode("HTTP/1.1 500 Internal Server Error\r\ncontent-length: 0\r\n\r\n"))
    output(c)
    e : List<&2, U32> <- DateWire.ensure(Bytes.encode("HTTP/1.1 200 OK\r\nconnection: close\r\ncontent-length: 0\r\n\r\n"))
    output(e)
    d : Response.Res <- DateResponse.ensure(Response.text(200, "hello"))
    print_status(d)
