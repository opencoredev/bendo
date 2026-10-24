# Whitespace consumes one transition per character only in token-gap modes.
import Base
import ../src/data/json.bend as J
import ./utf8.bend as P

def spaces(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: J.whitespace(c) && spaces(t)

def step_space(+mode: J.Mode, +c: U32, +tail: String, +stack: List<&2, J.Frame>, +depth: Nat, allowed: {J.allows_space(mode) == True{} : Bool}, space: {J.whitespace(c) == True{} : Bool}) -> {J.step(J.Machine{mode, SCon{Chr{c}, tail}, stack, depth}) == J.Machine{mode, tail, stack, depth} : J.Machine}:
  %Equal.sym(Bool, J.allows_space(mode), True{}, allowed) : {J.skip(mode, SCon{Chr{c}, tail}, tail, stack, depth, _ && J.whitespace(c)) == J.Machine{mode, tail, stack, depth} : J.Machine}
  %Equal.sym(Bool, J.whitespace(c), True{}, space) : {J.skip(mode, SCon{Chr{c}, tail}, tail, stack, depth, _) == J.Machine{mode, tail, stack, depth} : J.Machine}
  {==}

def after_space(+fuel: Nat, +mode: J.Mode, +c: U32, +tail: String, +stack: List<&2, J.Frame>, +depth: Nat, allowed: {J.allows_space(mode) == True{} : Bool}, space: {J.whitespace(c) == True{} : Bool}) -> {J.parse_go(fuel, J.step(J.Machine{mode, SCon{Chr{c}, tail}, stack, depth})) == J.parse_go(fuel, J.Machine{mode, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  Equal.cong(J.Machine, Result<&2, &2, J.Error, J.Json>, m => J.parse_go(fuel, m), J.step(J.Machine{mode, SCon{Chr{c}, tail}, stack, depth}), J.Machine{mode, tail, stack, depth}, step_space(mode, c, tail, stack, depth, allowed, space))

def parse_space(+fuel: Nat, +mode: J.Mode, +c: U32, +tail: String, +stack: List<&2, J.Frame>, +depth: Nat, +allowed: {J.allows_space(mode) == True{} : Bool}, +space: {J.whitespace(c) == True{} : Bool}) -> {J.parse_go(1n+fuel, J.Machine{mode, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{mode, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match mode:
    case J.MValue{}: after_space(fuel, J.MValue{}, c, tail, stack, depth, allowed, space)
    case J.MArrayFirst{}: after_space(fuel, J.MArrayFirst{}, c, tail, stack, depth, allowed, space)
    case J.MReadKey{k}: after_space(fuel, J.MReadKey{k}, c, tail, stack, depth, allowed, space)
    case J.MColon{k}: after_space(fuel, J.MColon{k}, c, tail, stack, depth, allowed, space)
    case J.MArrayAfter{r}: after_space(fuel, J.MArrayAfter{r}, c, tail, stack, depth, allowed, space)
    case J.MObjectAfter{r}: after_space(fuel, J.MObjectAfter{r}, c, tail, stack, depth, allowed, space)
    case J.MEnd{v}: after_space(fuel, J.MEnd{v}, c, tail, stack, depth, allowed, space)
    case J.MText{rev, key}: P.absurd({J.parse_go(1n+fuel, J.Machine{J.MText{rev, key}, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MText{rev, key}, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}, P.false_true(allowed))
    case J.MEscape{rev, key}: P.absurd({J.parse_go(1n+fuel, J.Machine{J.MEscape{rev, key}, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MEscape{rev, key}, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}, P.false_true(allowed))
    case J.MHex{n, code, high, rev, key}: P.absurd({J.parse_go(1n+fuel, J.Machine{J.MHex{n, code, high, rev, key}, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MHex{n, code, high, rev, key}, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}, P.false_true(allowed))
    case J.MLowSlash{high, rev, key}: P.absurd({J.parse_go(1n+fuel, J.Machine{J.MLowSlash{high, rev, key}, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MLowSlash{high, rev, key}, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}, P.false_true(allowed))
    case J.MLowU{high, rev, key}: P.absurd({J.parse_go(1n+fuel, J.Machine{J.MLowU{high, rev, key}, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MLowU{high, rev, key}, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}, P.false_true(allowed))
    case J.MLiteral{rest, v}: P.absurd({J.parse_go(1n+fuel, J.Machine{J.MLiteral{rest, v}, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MLiteral{rest, v}, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}, P.false_true(allowed))
    case J.MNumber{phase, rev}: P.absurd({J.parse_go(1n+fuel, J.Machine{J.MNumber{phase, rev}, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MNumber{phase, rev}, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}, P.false_true(allowed))
    case J.MEmit{v}: P.absurd({J.parse_go(1n+fuel, J.Machine{J.MEmit{v}, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MEmit{v}, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}, P.false_true(allowed))
    case J.MBad{e}: P.absurd({J.parse_go(1n+fuel, J.Machine{J.MBad{e}, SCon{Chr{c}, tail}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MBad{e}, tail, stack, depth}) : Result<&2, &2, J.Error, J.Json>}, P.false_true(allowed))

def skip_spaces(+text: String, +fuel: Nat, +mode: J.Mode, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +allowed: {J.allows_space(mode) == True{} : Bool}, +valid: {spaces(text) == True{} : Bool}) -> {J.parse_go(Nat.add(String.length(text), fuel), J.Machine{mode, text ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{mode, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match text:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      Equal.trans(Result<&2, &2, J.Error, J.Json>, J.parse_go(1n+Nat.add(String.length(t), fuel), J.Machine{mode, SCon{Chr{c}, t ++ suffix}, stack, depth}), J.parse_go(Nat.add(String.length(t), fuel), J.Machine{mode, t ++ suffix, stack, depth}), J.parse_go(fuel, J.Machine{mode, suffix, stack, depth}), parse_space(Nat.add(String.length(t), fuel), mode, c, t ++ suffix, stack, depth, allowed, P.and_left(J.whitespace(c), spaces(t), valid)), skip_spaces(t, fuel, mode, suffix, stack, depth, allowed, P.and_right(J.whitespace(c), spaces(t), valid)))

def indent_spaces(+n: Nat, +acc: String, valid: {spaces(acc) == True{} : Bool}) -> {spaces(J.indent(n, acc)) == True{} : Bool}:
  match n:
    case 0n: valid
    case 1n+p: indent_spaces(p, SCon{' ', SCon{' ', acc}}, valid)

def line_spaces(+pretty: Bool, +depth: Nat) -> {spaces(J.line(pretty, depth)) == True{} : Bool}:
  match pretty:
    case False{}: {==}
    case True{}: indent_spaces(depth, "", {==})

def parse_line(+pretty: Bool, +depth: Nat, +fuel: Nat, +mode: J.Mode, +suffix: String, +stack: List<&2, J.Frame>, +parser_depth: Nat, allowed: {J.allows_space(mode) == True{} : Bool}) -> {J.parse_go(Nat.add(String.length(J.line(pretty, depth)), fuel), J.Machine{mode, J.line(pretty, depth) ++ suffix, stack, parser_depth}) == J.parse_go(fuel, J.Machine{mode, suffix, stack, parser_depth}) : Result<&2, &2, J.Error, J.Json>}:
  skip_spaces(J.line(pretty, depth), fuel, mode, suffix, stack, parser_depth, allowed, line_spaces(pretty, depth))
