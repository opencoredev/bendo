# Pure incremental framing. The runtime sends one frame before pulling again.
import Base
import ./chunked.bend as Chunked
import ./bytes.bend as Bytes

def chunk(bytes: List<&2, U32>) -> List<&2, U32>:
  Chunked.encode_chunk(bytes, [])

def end() -> List<&2, U32>:
  [48, 13, 10, 13, 10]

# The sequence of writes, independently of how TCP partitions each write.
def wire(chunks: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match chunks:
    case Nil{}: end()
    case bytes <> rest: Chunked.encode_chunk(bytes, wire(rest))
