# Partial BND-28 proof infrastructure. The universal law remains open.
import Base
import ../src/data/json.bend as J
import ../src/data/utf8.bend as U

# Relate the writer's tail-recursive scalar check to the codec's spec
# predicate (Utf8.valid_spec; proof/utf8.bend equates it with Utf8.valid).
def scalar_go_false(+s: String) -> {J.scalar_go(s, False{}) == False{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: {==}

def scalar_go_equiv(+s: String, +ok: Bool) -> {J.scalar_go(s, ok) == ok && U.valid_spec(s) : Bool}:
  match s ok:
    case SNil{} False{}: {==}
    case SNil{} True{}: {==}
    case SCon{Chr{c}, t} False{}: {==}
    case SCon{Chr{c}, t} True{}: scalar_go_equiv(t, U.scalar(c))

def scalars_equiv(+s: String) -> {J.scalars(s) == U.valid_spec(s) : Bool}:
  scalar_go_equiv(s, True{})

# Exact parser continuation equations. Suffix, stack, depth, and remaining
# fuel are arbitrary; these are not closed runtime examples.
def parse_null_continuation(+fuel: Nat, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat) -> {J.parse_go(5n+fuel, J.Machine{J.MValue{}, "null" ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNull{}}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match suffix:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: {==}

def parse_true_continuation(+fuel: Nat, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat) -> {J.parse_go(5n+fuel, J.Machine{J.MValue{}, "true" ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JBool{True{}}}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match suffix:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: {==}

def parse_false_continuation(+fuel: Nat, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat) -> {J.parse_go(6n+fuel, J.Machine{J.MValue{}, "false" ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JBool{False{}}}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match suffix:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: {==}

def parse_array_return(+fuel: Nat, +value: J.Json, +rev: List<&2, J.Json>, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat) -> {J.parse_go(1n+fuel, J.Machine{J.MEmit{value}, suffix, J.ArrayFrame{rev} <> stack, depth}) == J.parse_go(fuel, J.Machine{J.MArrayAfter{value <> rev}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match suffix:
    case SNil{}: {==}
    case SCon{c, t}:
      match c:
        case Chr{n}: {==}

def parse_member_return(+fuel: Nat, +value: J.Json, +key: String, +rev: List<&2, J.Field>, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat) -> {J.parse_go(1n+fuel, J.Machine{J.MEmit{value}, suffix, J.MemberFrame{key, rev} <> stack, depth}) == J.parse_go(fuel, J.Machine{J.MObjectAfter{J.Field{key, value} <> rev}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match suffix:
    case SNil{}: {==}
    case SCon{c, t}:
      match c:
        case Chr{n}: {==}

# Exact writer continuation equations, with arbitrary pending work and
# output accumulator. They preserve the implementation's fuel accounting.
def write_null_continuation(+fuel: Nat, +rest: List<&2, J.Work>, +pretty: Bool, +ascii: Bool, +rev: String, +depth: Nat) -> {J.write_go(2n+fuel, J.WValue{J.JNull{}, depth} <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, String.reverse.go("null", rev)) : Result<&2, &2, J.Error, String>}:
  {==}

def boolean_text(value: Bool) -> String:
  match value:
    case True{}: "true"
    case False{}: "false"

def write_bool_continuation(+fuel: Nat, +value: Bool, +rest: List<&2, J.Work>, +pretty: Bool, +ascii: Bool, +rev: String, +depth: Nat) -> {J.write_go(2n+fuel, J.WValue{J.JBool{value}, depth} <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, String.reverse.go(boolean_text(value), rev)) : Result<&2, &2, J.Error, String>}:
  match value:
    case True{}: {==}
    case False{}: {==}

def write_number_continuation(+fuel: Nat, +number: String, +rest: List<&2, J.Work>, +pretty: Bool, +ascii: Bool, +rev: String, +depth: Nat) -> {J.write_go(2n+fuel, J.WValue{J.JNumber{number}, depth} <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, String.reverse.go(number, rev)) : Result<&2, &2, J.Error, String>}:
  {==}

def write_string_continuation(+fuel: Nat, +text: String, +rest: List<&2, J.Work>, +pretty: Bool, +ascii: Bool, +rev: String, +depth: Nat) -> {J.write_go(2n+fuel, J.WValue{J.JString{text}, depth} <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, String.reverse.go(J.quote(text, ascii), rev)) : Result<&2, &2, J.Error, String>}:
  {==}

def parse_root_return(+fuel: Nat, +value: J.Json) -> {J.parse_go(1n+fuel, J.Machine{J.MEmit{value}, "", [], 0n}) == Done{value} : Result<&2, &2, J.Error, J.Json>}:
  match fuel:
    case 0n: {==}
    case 1n+f: {==}

# Complete base cases, including public byte parsing and both options.
# These do not discharge the universal tree theorem.
def null_roundtrip(+pretty: Bool, +ascii: Bool) -> {J.write(J.JNull{}, pretty, ascii) == Done{"null"} : Result<&2, &2, J.Error, String>} & {J.parse(U.encode("null")) == Done{J.JNull{}} : Result<&2, &2, J.Error, J.Json>}:
  ({==}, {==})

def bool_roundtrip(+value: Bool, +pretty: Bool, +ascii: Bool) -> {J.write(J.JBool{value}, pretty, ascii) == Done{boolean_text(value)} : Result<&2, &2, J.Error, String>} & {J.parse(U.encode(boolean_text(value))) == Done{J.JBool{value}} : Result<&2, &2, J.Error, J.Json>}:
  match value:
    case True{}:
      ({==}, {==})
    case False{}:
      ({==}, {==})

def empty_array_roundtrip(+pretty: Bool, +ascii: Bool) -> {J.write(J.JArray{[]}, pretty, ascii) == Done{"[]"} : Result<&2, &2, J.Error, String>} & {J.parse(U.encode("[]")) == Done{J.JArray{[]}} : Result<&2, &2, J.Error, J.Json>}:
  ({==}, {==})

def empty_object_roundtrip(+pretty: Bool, +ascii: Bool) -> {J.write(J.JObject{[]}, pretty, ascii) == Done{"{}"} : Result<&2, &2, J.Error, String>} & {J.parse(U.encode("{}")) == Done{J.JObject{[]}} : Result<&2, &2, J.Error, J.Json>}:
  ({==}, {==})
