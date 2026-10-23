import Base
import ../src/http/stream_framing.bend as Stream
import ../src/http/chunked.bend as Chunked

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

def chunk_tail(+bytes: List<&2, U32>, +tail: List<&2, U32>) -> {List.append(&2, U32, Stream.chunk(bytes), tail) == Chunked.encode_chunk(bytes, tail) : List<&2, U32>}:
  match bytes:
    case Nil{}: {==}
    case +h <> +t:
      framed_append(Chunked.hex_go(8n, U32.from_nat(List.length(&2, U32, h <> t)), []), h <> t, tail)
