# Number scanner continuations preserve spelling and leave delimiters unread.
import Base
import ../src/data/json.bend as J
import ./utf8.bend as P
import ./json-support.bend as S

# Every suffix is either EOF or begins with a JSON token boundary.
type Boundary is Data:
  BEnd{}
  BSpace{tail: String}
  BTab{tail: String}
  BNewline{tail: String}
  BReturn{tail: String}
  BComma{tail: String}
  BArray{tail: String}
  BObject{tail: String}

def suffix(b: Boundary) -> String:
  match b:
    case BEnd{}: ""
    case BSpace{t}: SCon{' ', t}
    case BTab{t}: SCon{'\t', t}
    case BNewline{t}: SCon{'\n', t}
    case BReturn{t}: SCon{'\r', t}
    case BComma{t}: SCon{',', t}
    case BArray{t}: SCon{']', t}
    case BObject{t}: SCon{'}', t}

def first(b: Boundary) -> U32:
  match b:
    case BEnd{}: 0
    case BSpace{t}: 32
    case BTab{t}: 9
    case BNewline{t}: 10
    case BReturn{t}: 13
    case BComma{t}: 44
    case BArray{t}: 93
    case BObject{t}: 125

def invalid_step(+c: U32) -> {J.number_step(J.PInvalid{}, c) == J.PInvalid{} : J.Phase}:
  match c:
    case U32{w}: {==}

def invalid_go(+s: String) -> {J.number_valid_go(s, J.PInvalid{}) == False{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      %Equal.sym(J.Phase, J.number_step(J.PInvalid{}, c), J.PInvalid{}, invalid_step(c)) : {J.number_valid_go(t, _) == False{} : Bool}
      invalid_go(t)

def accepted_delimiter(+phase: J.Phase, +b: Boundary, end: {J.number_end(phase) == True{} : Bool}) -> {J.number_step(phase, first(b)) == J.PInvalid{} : J.Phase}:
  match phase:
    case J.PStart{}:
      P.absurd({J.number_step(J.PStart{}, first(b)) == J.PInvalid{} : J.Phase}, P.false_true(end))
    case J.PMinus{}:
      P.absurd({J.number_step(J.PMinus{}, first(b)) == J.PInvalid{} : J.Phase}, P.false_true(end))
    case J.PZero{}:
      match b:
        case BEnd{}: {==}
        case BSpace{t}: {==}
        case BTab{t}: {==}
        case BNewline{t}: {==}
        case BReturn{t}: {==}
        case BComma{t}: {==}
        case BArray{t}: {==}
        case BObject{t}: {==}
    case J.PInteger{}:
      match b:
        case BEnd{}: {==}
        case BSpace{t}: {==}
        case BTab{t}: {==}
        case BNewline{t}: {==}
        case BReturn{t}: {==}
        case BComma{t}: {==}
        case BArray{t}: {==}
        case BObject{t}: {==}
    case J.PDot{}:
      P.absurd({J.number_step(J.PDot{}, first(b)) == J.PInvalid{} : J.Phase}, P.false_true(end))
    case J.PFraction{}:
      match b:
        case BEnd{}: {==}
        case BSpace{t}: {==}
        case BTab{t}: {==}
        case BNewline{t}: {==}
        case BReturn{t}: {==}
        case BComma{t}: {==}
        case BArray{t}: {==}
        case BObject{t}: {==}
    case J.PExponent{}:
      P.absurd({J.number_step(J.PExponent{}, first(b)) == J.PInvalid{} : J.Phase}, P.false_true(end))
    case J.PSign{}:
      P.absurd({J.number_step(J.PSign{}, first(b)) == J.PInvalid{} : J.Phase}, P.false_true(end))
    case J.PDigits{}:
      match b:
        case BEnd{}: {==}
        case BSpace{t}: {==}
        case BTab{t}: {==}
        case BNewline{t}: {==}
        case BReturn{t}: {==}
        case BComma{t}: {==}
        case BArray{t}: {==}
        case BObject{t}: {==}
    case J.PInvalid{}:
      P.absurd({J.number_step(J.PInvalid{}, first(b)) == J.PInvalid{} : J.Phase}, P.false_true(end))

def finish_valid(+rev: String, +phase: J.Phase, end: {J.number_end(phase) == True{} : Bool}) -> {J.number_finish(rev, J.number_end(phase)) == J.MEmit{J.JNumber{String.reverse(rev)}} : J.Mode}:
  %Equal.sym(Bool, J.number_end(phase), True{}, end) : {J.number_finish(rev, _) == J.MEmit{J.JNumber{String.reverse(rev)}} : J.Mode}
  {==}

def parse_finish_byte(+fuel: Nat, +phase: J.Phase, +rev: String, +c: U32, +t: String, +stack: List<&2, J.Frame>, +depth: Nat, end: {J.number_end(phase) == True{} : Bool}, boundary: {J.number_step(phase, c) == J.PInvalid{} : J.Phase}) -> {J.parse_go(1n+fuel, J.Machine{J.MNumber{phase, rev}, SCon{Chr{c}, t}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNumber{String.reverse(rev)}}, SCon{Chr{c}, t}, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(J.Phase, J.number_step(phase, c), J.PInvalid{}, boundary) : {J.parse_go(fuel, J.number_next(_, phase, rev, c, t, stack, depth)) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNumber{String.reverse(rev)}}, SCon{Chr{c}, t}, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(J.Mode, J.number_finish(rev, J.number_end(phase)), J.MEmit{J.JNumber{String.reverse(rev)}}, finish_valid(rev, phase, end)) : {J.parse_go(fuel, J.Machine{_, SCon{Chr{c}, t}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNumber{String.reverse(rev)}}, SCon{Chr{c}, t}, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  {==}

def parse_finish(+fuel: Nat, +phase: J.Phase, +rev: String, +b: Boundary, +stack: List<&2, J.Frame>, +depth: Nat, +end: {J.number_end(phase) == True{} : Bool}) -> {J.parse_go(1n+fuel, J.Machine{J.MNumber{phase, rev}, suffix(b), stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNumber{String.reverse(rev)}}, suffix(b), stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match b:
    case BEnd{}:
      %Equal.sym(J.Mode, J.number_finish(rev, J.number_end(phase)), J.MEmit{J.JNumber{String.reverse(rev)}}, finish_valid(rev, phase, end)) : {J.parse_go(fuel, J.Machine{_, "", stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNumber{String.reverse(rev)}}, "", stack, depth}) : Result<&2, &2, J.Error, J.Json>}
      {==}
    case BSpace{t}: parse_finish_byte(fuel, phase, rev, 32, t, stack, depth, end, accepted_delimiter(phase, BSpace{t}, end))
    case BTab{t}: parse_finish_byte(fuel, phase, rev, 9, t, stack, depth, end, accepted_delimiter(phase, BTab{t}, end))
    case BNewline{t}: parse_finish_byte(fuel, phase, rev, 10, t, stack, depth, end, accepted_delimiter(phase, BNewline{t}, end))
    case BReturn{t}: parse_finish_byte(fuel, phase, rev, 13, t, stack, depth, end, accepted_delimiter(phase, BReturn{t}, end))
    case BComma{t}: parse_finish_byte(fuel, phase, rev, 44, t, stack, depth, end, accepted_delimiter(phase, BComma{t}, end))
    case BArray{t}: parse_finish_byte(fuel, phase, rev, 93, t, stack, depth, end, accepted_delimiter(phase, BArray{t}, end))
    case BObject{t}: parse_finish_byte(fuel, phase, rev, 125, t, stack, depth, end, accepted_delimiter(phase, BObject{t}, end))

# The validity of the rest excludes the scanner's failure sentinel.
def next_valid(+next: J.Phase, +phase: J.Phase, +rev: String, +c: U32, +t: String, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, valid: {J.number_valid_go(t, next) == True{} : Bool}) -> {J.number_next(next, phase, rev, c, t ++ suffix, stack, depth) == J.Machine{J.MNumber{next, SCon{Chr{c}, rev}}, t ++ suffix, stack, depth} : J.Machine}:
  match next:
    case J.PInvalid{}:
      clash = Equal.trans(Bool, False{}, J.number_valid_go(t, J.PInvalid{}), True{}, Equal.sym(Bool, J.number_valid_go(t, J.PInvalid{}), False{}, invalid_go(t)), valid)
      P.absurd({J.number_next(J.PInvalid{}, phase, rev, c, t ++ suffix, stack, depth) == J.Machine{J.MNumber{J.PInvalid{}, SCon{Chr{c}, rev}}, t ++ suffix, stack, depth} : J.Machine}, P.false_true(clash))
    case J.PStart{}: {==}
    case J.PMinus{}: {==}
    case J.PZero{}: {==}
    case J.PInteger{}: {==}
    case J.PDot{}: {==}
    case J.PFraction{}: {==}
    case J.PExponent{}: {==}
    case J.PSign{}: {==}
    case J.PDigits{}: {==}

def scan_continuation(+s: String, +phase: J.Phase, +rev: String, +fuel: Nat, +b: Boundary, +stack: List<&2, J.Frame>, +depth: Nat, +valid: {J.number_valid_go(s, phase) == True{} : Bool}) -> {J.parse_go(Nat.add(String.length(s), 1n+fuel), J.Machine{J.MNumber{phase, rev}, s ++ suffix(b), stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNumber{String.reverse(String.reverse.go(s, rev))}}, suffix(b), stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match s:
    case SNil{}: parse_finish(fuel, phase, rev, b, stack, depth, valid)
    case SCon{Chr{c}, t}:
      %Equal.sym(J.Machine, J.number_next(J.number_step(phase, c), phase, rev, c, t ++ suffix(b), stack, depth), J.Machine{J.MNumber{J.number_step(phase, c), SCon{Chr{c}, rev}}, t ++ suffix(b), stack, depth}, next_valid(J.number_step(phase, c), phase, rev, c, t, suffix(b), stack, depth, valid)) : {J.parse_go(Nat.add(String.length(t), 1n+fuel), _) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNumber{String.reverse(String.reverse.go(t, SCon{Chr{c}, rev}))}}, suffix(b), stack, depth}) : Result<&2, &2, J.Error, J.Json>}
      scan_continuation(t, J.number_step(phase, c), SCon{Chr{c}, rev}, fuel, b, stack, depth, valid)

# At an empty accumulator the accepted spelling is returned exactly.
def spelling_continuation(+s: String, +fuel: Nat, +b: Boundary, +stack: List<&2, J.Frame>, +depth: Nat, +valid: {J.number_valid(s) == True{} : Bool}) -> {J.parse_go(Nat.add(String.length(s), 1n+fuel), J.Machine{J.MNumber{J.PStart{}, ""}, s ++ suffix(b), stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNumber{s}}, suffix(b), stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  %S.reverse_twice(s) : {J.parse_go(Nat.add(String.length(s), 1n+fuel), J.Machine{J.MNumber{J.PStart{}, ""}, s ++ suffix(b), stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{J.JNumber{_}}, suffix(b), stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  scan_continuation(s, J.PStart{}, "", fuel, b, stack, depth, valid)
