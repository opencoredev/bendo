# Expand @GO(t; a; m) and @M(mode; input) macros, nesting allowed.
import sys, re
R = "Result<&2, &2, J.Error, J.Json>"
def expand(s):
    out = []; i = 0
    while i < len(s):
        m = re.match(r"@(GO|M|PG)\(", s[i:])
        if not m:
            out.append(s[i]); i += 1; continue
        name = m.group(1); j = i + len(m.group(0)); depth = 1; args = []; cur = []
        while depth:
            ch = s[j]
            if ch in "([{": depth += 1
            if ch in ")]}": depth -= 1
            if depth == 0: break
            if ch == ";" and depth == 1:
                args.append("".join(cur).strip()); cur = []
            else: cur.append(ch)
            j += 1
        args.append("".join(cur).strip())
        args = [expand(a) for a in args]
        if name == "GO":
            t, a, mm = args; out.append(f"{{J.parse_go(J.fuel_go({t}, {a}), {mm}) == Done{{v}} : {R}}}")
        elif name == "PG":
            f, mm = args; out.append(f"J.parse_go({f}, {mm})")
        else:
            mode, inp = args; out.append(f"J.Machine{{{mode}, {inp}, stack, depth}}")
        i = j + 1
    return "".join(out).replace("@R", R)
sys.stdout.write(expand(sys.stdin.read()))
