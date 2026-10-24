import Base
import ../src/http/stream_framing.bend as Stream
import ../src/http/chunked.bend as Chunked
import ../src/http/bytes.bend as B
import ./bytes-tail.bend as BT

def canonical(+chunks: List<&2, List<&2, U32>>) -> {Stream.wire(chunks) == Chunked.encode(chunks) : List<&2, U32>}:
  match chunks:
    case Nil{}: {==}
    case +chunk <> +rest:
      Equal.cong(List<&2, U32>, List<&2, U32>, tail => Chunked.encode_chunk(chunk, tail), Stream.wire(rest), Chunked.encode(rest), canonical(rest))

def append_assoc(+xs: List<&2, U32>, +ys: List<&2, U32>, +zs: List<&2, U32>) -> {List.append(&2, U32, List.append(&2, U32, xs, ys), zs) == List.append(&2, U32, xs, List.append(&2, U32, ys, zs)) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t:
      Equal.cong(List<&2, U32>, List<&2, U32>, rest => h <> rest, List.append(&2, U32, List.append(&2, U32, t, ys), zs), List.append(&2, U32, t, List.append(&2, U32, ys, zs)), append_assoc(t, ys, zs))

def framed_append(+head: List<&2, U32>, +body: List<&2, U32>, +tail: List<&2, U32>) -> {List.append(&2, U32, List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, body, [13, 10])), tail) == List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, body, 13 <> 10 <> tail)) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, List.append(&2, U32, List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, body, [13, 10])), tail), List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, List.append(&2, U32, body, [13, 10]), tail)), List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, body, 13 <> 10 <> tail)), append_assoc(head, 13 <> 10 <> List.append(&2, U32, body, [13, 10]), tail), Equal.cong(List<&2, U32>, List<&2, U32>, rest => List.append(&2, U32, head, 13 <> 10 <> rest), List.append(&2, U32, List.append(&2, U32, body, [13, 10]), tail), List.append(&2, U32, body, 13 <> 10 <> tail), append_assoc(body, [13, 10], tail)))

# encode_chunk frames with Bytes.append; this restates the frame over List.append.
def framed_equiv(+head: List<&2, U32>, +body: List<&2, U32>, +end: List<&2, U32>) -> {B.append(head, 13 <> 10 <> B.append(body, end)) == List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, body, end)) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, B.append(head, 13 <> 10 <> B.append(body, end)), List.append(&2, U32, head, 13 <> 10 <> B.append(body, end)), List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, body, end)), BT.append_equiv(head, 13 <> 10 <> B.append(body, end)), Equal.cong(List<&2, U32>, List<&2, U32>, l => List.append(&2, U32, head, 13 <> 10 <> l), B.append(body, end), List.append(&2, U32, body, end), BT.append_equiv(body, end)))

def chunk_tail(+bytes: List<&2, U32>, +tail: List<&2, U32>) -> {List.append(&2, U32, Stream.chunk(bytes), tail) == Chunked.encode_chunk(bytes, tail) : List<&2, U32>}:
  match bytes:
    case Nil{}: {==}
    case +h <> +t:
      +head = Chunked.hex_go(8n, U32.from_nat(List.length(&2, U32, h <> t)), [])
      Equal.trans(List<&2, U32>, List.append(&2, U32, B.append(head, 13 <> 10 <> B.append(h <> t, [13, 10])), tail), List.append(&2, U32, List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, h <> t, [13, 10])), tail), B.append(head, 13 <> 10 <> B.append(h <> t, 13 <> 10 <> tail)), Equal.cong(List<&2, U32>, List<&2, U32>, x => List.append(&2, U32, x, tail), B.append(head, 13 <> 10 <> B.append(h <> t, [13, 10])), List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, h <> t, [13, 10])), framed_equiv(head, h <> t, [13, 10])), Equal.trans(List<&2, U32>, List.append(&2, U32, List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, h <> t, [13, 10])), tail), List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, h <> t, 13 <> 10 <> tail)), B.append(head, 13 <> 10 <> B.append(h <> t, 13 <> 10 <> tail)), framed_append(head, h <> t, tail), Equal.sym(List<&2, U32>, B.append(head, 13 <> 10 <> B.append(h <> t, 13 <> 10 <> tail)), List.append(&2, U32, head, 13 <> 10 <> List.append(&2, U32, h <> t, 13 <> 10 <> tail)), framed_equiv(head, h <> t, 13 <> 10 <> tail))))
