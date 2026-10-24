# An imported module: its types reach the generated declarations as `shapes.*`.
import Base

type Shape is Data:
  Dot{}
  Line{length: Nat}

def Shapes() -> Data:
  List<&2, Shape>

def length(s: Shape) -> Nat:
  match s:
    case Dot{}: 0n
    case Line{n}: n
