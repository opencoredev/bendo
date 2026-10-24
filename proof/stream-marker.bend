# BND-96: the fused marker-name test equals the lowered-name comparison it
# replaced. This module deliberately does not import LAWS.
import Base
import ../src/http/stream_marker.bend as Marker
import ../src/http/bytes.bend as B
import ./bytes-tail.bend as BT

# named_go walks the name and the literal together, lowering one character at
# a time, exactly as String.order.go walks the lowered name.
def named_go_lower(+name: String, +lit: String, +c: Cmp) -> {Marker.named_go(name, lit, c) == Cmp.is_eq(String.order.go(String.to_lower(name), lit, c)) : Bool}:
  match name lit c:
    case SNil{} SNil{} LT{}: {==}
    case SNil{} SNil{} EQ{}: {==}
    case SNil{} SNil{} GT{}: {==}
    case SNil{} SCon{y, u} LT{}: {==}
    case SNil{} SCon{y, u} EQ{}: {==}
    case SNil{} SCon{y, u} GT{}: {==}
    case SCon{Chr{+x}, t} SNil{} LT{}: {==}
    case SCon{Chr{+x}, t} SNil{} EQ{}: {==}
    case SCon{Chr{+x}, t} SNil{} GT{}: {==}
    case SCon{Chr{+x}, t} SCon{Chr{y}, u} LT{}: {==}
    case SCon{Chr{+x}, t} SCon{Chr{y}, u} EQ{}: named_go_lower(t, u, U32.cmp(U32.add(x, U32.mul(Bool.to_u32(Char.is_upper(Chr{x})), 32)), y))
    case SCon{Chr{+x}, t} SCon{Chr{y}, u} GT{}: {==}

def named_equiv(+name: String) -> {Marker.named(name) == Marker.named_spec(name) : Bool}:
  Equal.trans(Bool, Marker.named(name), Cmp.is_eq(String.order.go(String.to_lower(name), Marker.marker(), EQ{})), Marker.named_spec(name),
    named_go_lower(name, Marker.marker(), EQ{}),
    Equal.cong(String, Bool, s => Cmp.is_eq(String.order.go(s, Marker.marker(), EQ{})), String.to_lower(name), B.fold(name), Equal.sym(String, B.fold(name), String.to_lower(name), BT.fold_equiv(name))))
