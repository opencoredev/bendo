#!/usr/bin/env python3
"""Generate proof/json-surrogate.bend: surrogate-pair escape inversion.

A supplementary-plane scalar c has bits 21..31 clear and a plane 1..16 in bits
16..20. For each plane the generated lemmas keep the sixteen low bits symbolic:
the writer's high and low surrogate units become code16 words, the parser's
reconstruction arithmetic returns c, and the twelve-character spelling parses
in fourteen transitions. A dispatcher splits an arbitrary U32 into the planes.

Run from the repository root: python3 scripts/json-proofs/gen-surrogate.py
"""

from pathlib import Path

T, F = "True{}", "False{}"
B = [f"b{i}" for i in range(16)]
R = "Result<&2, &2, J.Error, J.Json>"
HI_HIGH = 0xD800 >> 10  # 0b110110
LO_HIGH = 0xDC00 >> 10  # 0b110111
BACKSLASH_U = '"\\\\u"'


def word(bits):
    s = "WNil{}"
    for b in reversed(bits):
        s = f"WCon{{{b}, {s}}}"
    return s


def bits_of(v, n):
    return [T if (v >> i) & 1 else F for i in range(n)]


def bit_params(bits=B):
    return ", ".join(f"+{b}: Bool" for b in bits)


def bit_args(bits=B):
    return ", ".join(bits)


def hi_expr(c):
    return f"(55296 + (({c} - 65536 : U32) >> 10n : U32) : U32)"


def lo_expr(c):
    return f"(56320 + (({c} - 65536 : U32) .&. 1023 : U32) : U32)"


def dec_expr(hi, lo):
    return f"(65536 + (({hi} - 55296 : U32) << 10n : U32) + {lo} - 56320 : U32)"


def machine(mode, inp):
    return f"J.Machine{{{mode}, {inp}, stack, depth}}"


def pg(fuel, mach):
    return f"J.parse_go({fuel}, {mach})"


def rewrite(ty, a, b, proof, motive):
    """Replace a by b in the goal, given proof : {a == b}."""
    return f"%Equal.sym({ty}, {a}, {b}, {proof}) : {motive}"


def gen_plane(p):
    q = p - 1
    qh = bits_of(q, 4)
    c = f"U32{{{word(B + bits_of(p, 5) + [F] * 11)}}}"
    x16, ph, one16 = word(B), word(bits_of(p, 5) + [F] * 11), word(bits_of(1, 16))
    x10h, a22 = word(B[10:16] + qh), word(bits_of(HI_HIGH, 22))
    whi_w = word(B[10:16] + qh + bits_of(HI_HIGH, 6))
    x10, u22, l22 = word(B[0:10]), word(B[10:16] + qh + [F] * 12), word(bits_of(LO_HIGH, 22))
    wlo_w = word(B[0:10] + bits_of(LO_HIGH, 6))
    x6, x16t, q16 = word(B[10:16]), word([F] * 10 + B[10:16]), word(qh + [F] * 12)
    t22 = word(B[10:16] + bits_of(p, 5) + [F] * 11)
    whi, wlo = f"E.code16({whi_w})", f"E.code16({wlo_w})"
    zero10, zero16, zero22 = "Word.zero(10n)", "Word.zero(16n)", "Word.zero(22n)"

    def sub_low(k, m, x, a, b):
        lhs = f"Word.adc(Nat.add({k}, {m}), U.join({k}, {m}, {x}, {a}), U.join({k}, {m}, Word.zero({k}), {b}), True{{}}, True{{}})"
        rhs = f"U.join({k}, {m}, {x}, Word.adc({m}, {a}, {b}, True{{}}, True{{}}))"
        return lhs, rhs, f"W.sub_low_zero({k}, {m}, {x}, {a}, {b})"

    def add_low(k, m, x, a, b):
        lhs = f"Word.adc(Nat.add({k}, {m}), U.join({k}, {m}, Word.zero({k}), {a}), U.join({k}, {m}, {x}, {b}), False{{}}, False{{}})"
        rhs = f"U.join({k}, {m}, {x}, Word.adc({m}, {a}, {b}, False{{}}, False{{}}))"
        return lhs, rhs, f"W.add_low_zero({k}, {m}, {x}, {a}, {b})"

    out = []
    s16 = sub_low("16n", "16n", x16, ph, one16)
    # High surrogate unit.
    out.append(f"def hi_eq_{p}({bit_params()}) -> {{{hi_expr(c)} == {whi} : U32}}:")
    out.append("  " + rewrite("Word(32n)", *s16, f"{{(55296 + (U32{{_}} >> 10n : U32) : U32) == {whi} : U32}}"))
    out.append("  " + rewrite("Word(32n)", *add_low("10n", "22n", x10h, a22, zero22), f"{{U32{{_}} == {whi} : U32}}"))
    out.append("  {==}")
    out.append("")
    # Low surrogate unit.
    out.append(f"def lo_eq_{p}({bit_params()}) -> {{{lo_expr(c)} == {wlo} : U32}}:")
    out.append("  " + rewrite("Word(32n)", *s16, f"{{(56320 + (U32{{_}} .&. 1023 : U32) : U32) == {wlo} : U32}}"))
    mask = (
        f"Word.and(Nat.add(10n, 22n), U.join(10n, 22n, {x10}, {u22}), U.join(10n, 22n, W.ones(10n), {zero22}))",
        f"U.join(10n, 22n, {x10}, {zero22})",
        f"W.and_low_ones(10n, 22n, {x10}, {u22})",
    )
    out.append("  " + rewrite("Word(32n)", *mask, f"{{(56320 + U32{{_}} : U32) == {wlo} : U32}}"))
    out.append("  " + rewrite("Word(32n)", *add_low("10n", "22n", x10, l22, zero22), f"{{U32{{_}} == {wlo} : U32}}"))
    out.append("  {==}")
    out.append("")
    # Parser reconstruction of the scalar.
    inner = f"Word.adc(22n, {t22}, {l22}, False{{}}, False{{}})"
    out.append(f"def dec_eq_{p}({bit_params()}) -> {{{dec_expr(whi, wlo)} == {c} : U32}}:")
    out.append("  " + rewrite("Word(32n)", *sub_low("10n", "22n", x10h, a22, a22), f"{{(65536 + (U32{{_}} << 10n : U32) + {wlo} - 56320 : U32) == {c} : U32}}"))
    out.append("  " + rewrite("Word(32n)", *add_low("16n", "16n", x16t, one16, q16), f"{{(U32{{_}} + {wlo} - 56320 : U32) == {c} : U32}}"))
    out.append("  " + rewrite("Word(32n)", *add_low("10n", "22n", x10, t22, l22), f"{{(U32{{_}} - 56320 : U32) == {c} : U32}}"))
    out.append("  " + rewrite("Word(32n)", *sub_low("10n", "22n", x10, inner, l22), f"{{U32{{_}} == {c} : U32}}"))
    cancel = (
        f"Word.adc(22n, {inner}, {l22}, True{{}}, Bool.not(False{{}}))",
        t22,
        f"W.add_sub_cancel(22n, {t22}, {l22}, False{{}})",
    )
    out.append("  " + rewrite("Word(22n)", *cancel, f"{{U32{{U.join(10n, 22n, {x10}, _)}} == {c} : U32}}"))
    out.append("  {==}")
    out.append("")
    # The high unit is a high surrogate, including at the plane extremes.
    slash = f"J.MLowSlash{{{whi}, rev, key}}"
    out.append(f"def hi_single_{p}({bit_params()}, +rev: String, +key: Bool) -> {{J.unicode_done({whi}, 0, rev, key) == {slash} : J.Mode}}:")
    if p == 1:
        out.append("  " + rewrite(
            "Bool", f"Cmp.is_ge(Word.cmp(6n, {x6}, Word.zero(6n)))", "True{}", f"E.cmp_ge_zero(6n, {x6})",
            f"{{J.unicode_single({whi}, rev, key, _ && ({whi} <= 56319 : U32)) == {slash} : J.Mode}}"))
    elif p == 16:
        out.append("  " + rewrite(
            "Bool", f"Cmp.is_le(Word.cmp(6n, {x6}, E.ones(6n)))", "True{}", f"E.cmp_le_ones(6n, {x6})",
            f"{{J.unicode_single({whi}, rev, key, ({whi} >= 55296 : U32) && _) == {slash} : J.Mode}}"))
    out.append("  {==}")
    out.append("")
    # The parser tests the high unit against zero bit by bit.
    low_mode = f"J.unicode_low({wlo}, {whi}, rev, key, ({wlo} >= 56320 : U32) && ({wlo} <= 57343 : U32))"
    out.append(
        f"def low_dispatch_{p}({bit_params(B[10:16])}, {bit_params(B[0:10])}, +rev: String, +key: Bool) -> "
        f"{{J.unicode_done({wlo}, {whi}, rev, key) == {low_mode} : J.Mode}}:"
    )

    def chain(i, indent):
        pad = "  " * indent
        if i == 16:
            out.append(f"{pad}{{==}}")
            return
        out.append(f"{pad}match b{i}:")
        out.append(f"{pad}  case True{{}}: {{==}}")
        out.append(f"{pad}  case False{{}}:")
        chain(i + 1, indent + 2)

    chain(10, 1)
    out.append("")
    text = f"J.MText{{SCon{{Chr{{{c}}}, rev}}, key}}"
    out.append(f"def low_cond_{p}({bit_params()}, +rev: String, +key: Bool) -> {{{low_mode} == {text} : J.Mode}}:")
    out.append("  " + rewrite(
        "Bool", f"Cmp.is_ge(Word.cmp(10n, {x10}, {zero10}))", "True{}", f"E.cmp_ge_zero(10n, {x10})",
        f"{{J.unicode_low({wlo}, {whi}, rev, key, _ && ({wlo} <= 57343 : U32)) == {text} : J.Mode}}"))
    out.append("  " + rewrite(
        "Bool", f"Cmp.is_le(Word.cmp(10n, {x10}, E.ones(10n)))", "True{}", f"E.cmp_le_ones(10n, {x10})",
        f"{{J.unicode_low({wlo}, {whi}, rev, key, True{{}} && _) == {text} : J.Mode}}"))
    out.append("  " + rewrite(
        "U32", dec_expr(whi, wlo), c, f"dec_eq_{p}({bit_args()})",
        f"{{J.MText{{SCon{{Chr{{_}}, rev}}, key}} == {text} : J.Mode}}"))
    out.append("  {==}")
    out.append("")
    out.append(f"def low_text_{p}({bit_params()}, +rev: String, +key: Bool) -> {{J.unicode_done({wlo}, {whi}, rev, key) == {text} : J.Mode}}:")
    out.append(
        f"  Equal.trans(J.Mode, J.unicode_done({wlo}, {whi}, rev, key), {low_mode}, {text}, "
        f"low_dispatch_{p}({bit_args(B[10:16])}, {bit_args(B[0:10])}, rev, key), low_cond_{p}({bit_args()}, rev, key))"
    )
    out.append("")
    # Fourteen transitions for the twelve-character spelling.
    final = pg("fuel", machine(text, "suffix"))
    r1 = f"SCon{{Chr{{92}}, SCon{{'u', E.hex_digits({wlo_w}) ++ suffix}}}}"
    start = lambda inp: pg("Nat.add(14n, fuel)", machine("J.MText{rev, key}", inp))
    goal = f"{{{start(f'J.unicode_escape({c}, False{{}}) ++ suffix')} == {final} : {R}}}"
    out.append(
        f"def pair_parse_{p}({bit_params()}, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +fuel: Nat) -> {goal}:"
    )
    he, le = hi_expr(c), lo_expr(c)
    out.append("  " + rewrite("U32", he, whi, f"hi_eq_{p}({bit_args()})", f"{{{start(f'(J.hex4(_) ++ J.hex4({le})) ++ suffix')} == {final} : {R}}}"))
    out.append("  " + rewrite("U32", le, wlo, f"lo_eq_{p}({bit_args()})", f"{{{start(f'(J.hex4({whi}) ++ J.hex4(_)) ++ suffix')} == {final} : {R}}}"))
    hd_hi, hd_lo = f"E.hex_digits({whi_w})", f"E.hex_digits({wlo_w})"
    out.append("  " + rewrite("String", f"J.hex4({whi})", f"{BACKSLASH_U} ++ {hd_hi}", f"E.hex4_shape({whi_w})",
                              f"{{{start(f'(_ ++ J.hex4({wlo})) ++ suffix')} == {final} : {R}}}"))
    out.append("  " + rewrite("String", f"J.hex4({wlo})", f"{BACKSLASH_U} ++ {hd_lo}", f"E.hex4_shape({wlo_w})",
                              f"{{{start(f'(({BACKSLASH_U} ++ {hd_hi}) ++ _) ++ suffix')} == {final} : {R}}}"))
    s0 = start(f"(({BACKSLASH_U} ++ {hd_hi}) ++ ({BACKSLASH_U} ++ {hd_lo})) ++ suffix")
    s1 = pg("12n+fuel", machine("J.MHex{4n, 0, 0, rev, key}", f"{hd_hi} ++ {r1}"))
    s2 = pg("8n+fuel", machine(f"J.MHex{{0n, {whi}, 0, rev, key}}", r1))
    s3 = pg("7n+fuel", machine(f"J.unicode_done({whi}, 0, rev, key)", r1))
    s4 = pg("7n+fuel", machine(slash, r1))
    s5 = pg("5n+fuel", machine(f"J.MHex{{4n, 0, {whi}, rev, key}}", f"{hd_lo} ++ suffix"))
    s6 = pg("1n+fuel", machine(f"J.MHex{{0n, {wlo}, {whi}, rev, key}}", "suffix"))
    s7 = pg("fuel", machine(f"J.unicode_done({wlo}, {whi}, rev, key)", "suffix"))
    links = [
        (s0, s1, "{==}"),
        (s1, s2, f"E.hex4_continuation({whi_w}, 0, rev, key, {r1}, stack, depth, 8n+fuel)"),
        (s2, s3, f"E.hex_complete({whi}, 0, rev, key, {r1}, stack, depth, 7n+fuel)"),
        (s3, s4, f"Equal.cong(J.Mode, {R}, mode => {pg('7n+fuel', machine('mode', r1))}, J.unicode_done({whi}, 0, rev, key), {slash}, hi_single_{p}({bit_args()}, rev, key))"),
        (s4, s5, "{==}"),
        (s5, s6, f"E.hex4_continuation({wlo_w}, {whi}, rev, key, suffix, stack, depth, 1n+fuel)"),
        (s6, s7, f"E.hex_complete({wlo}, {whi}, rev, key, suffix, stack, depth, fuel)"),
        (s7, final, f"Equal.cong(J.Mode, {R}, mode => {pg('fuel', machine('mode', 'suffix'))}, J.unicode_done({wlo}, {whi}, rev, key), {text}, low_text_{p}({bit_args()}, rev, key))"),
    ]

    def fold(i):
        a, b, pf = links[i]
        if i == len(links) - 1:
            return pf
        return f"Equal.trans({R}, {a}, {b}, {final}, {pf}, {fold(i + 1)})"

    out.append("  " + fold(0))
    out.append("")
    # The spelling is valid text, followed by any valid text.
    out.append(
        f"def pair_valid_{p}({bit_params()}, +tail: String, ok: {{U.valid(tail) == True{{}} : Bool}}) -> "
        f"{{U.valid(J.unicode_escape({c}, False{{}}) ++ tail) == True{{}} : Bool}}:"
    )
    out.append("  " + rewrite("U32", he, whi, f"hi_eq_{p}({bit_args()})", f"{{U.valid((J.hex4(_) ++ J.hex4({le})) ++ tail) == True{{}} : Bool}}"))
    out.append("  " + rewrite("U32", le, wlo, f"lo_eq_{p}({bit_args()})", f"{{U.valid((J.hex4({whi}) ++ J.hex4(_)) ++ tail) == True{{}} : Bool}}"))
    out.append(f"  V.valid_cat3(J.hex4({whi}), J.hex4({wlo}), tail, E.hex4_valid({whi_w}), E.hex4_valid({wlo_w}), ok)")
    out.append("")
    return "\n".join(out)


def gen_dispatch():
    """Reduce an arbitrary scalar U32 to a 21-bit word, then split its plane.

    P.fits clears bits 21..31, so only the five plane bits are split: plane 0
    contradicts the supplementary bound, planes 17..31 exceed U+10FFFF.
    """
    out = []
    P = ["p0", "p1", "p2", "p3", "p4"]
    goal_parse = (
        "{J.parse_go(Nat.add(14n, fuel), J.Machine{J.MText{rev, key}, J.unicode_escape(@C@, False{}) ++ suffix, stack, depth}) == "
        "J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{@C@}, rev}, key}, suffix, stack, depth}) : " + R + "}"
    )
    goal_valid = "{U.valid(J.unicode_escape(@C@, False{}) ++ tail) == True{} : Bool}"
    specs = [
        ("pair_parse", goal_parse,
         "+rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +fuel: Nat",
         "rev, key, suffix, stack, depth, fuel",
         lambda p: f"pair_parse_{p}({bit_args()}, rev, key, suffix, stack, depth, fuel)"),
        ("pair_valid", goal_valid,
         "+tail: String, ok: {U.valid(tail) == True{} : Bool}",
         "tail, ok",
         lambda p: f"pair_valid_{p}({bit_args()}, tail, ok)"),
    ]
    for name, goal, params, args, call in specs:
        # Plane split over symbolic low bits.
        cw = f"U32{{{word(B + P + [F] * 11)}}}"
        out.append(
            f"def {name}_plane({bit_params()}, {bit_params(P)}, {params}, scalar: {{U.scalar({cw}) == True{{}} : Bool}}, "
            f"large: {{({cw} <= 65535 : U32) == False{{}} : Bool}}) -> {goal.replace('@C@', cw)}:"
        )

        def tree(i, fixed, indent):
            pad = "  " * indent
            if i == 5:
                plane = sum(1 << k for k, b in enumerate(fixed) if b == T)
                leaf = f"U32{{{word(B + fixed + [F] * 11)}}}"
                if 1 <= plane <= 16:
                    out.append(f"{pad}{call(plane)}")
                elif plane == 0:
                    bound = (
                        f"Equal.trans(Bool, False{{}}, ({leaf} <= 65535 : U32), True{{}}, "
                        f"Equal.sym(Bool, ({leaf} <= 65535 : U32), False{{}}, large), E.cmp_le_ones(16n, {word(B)}))"
                    )
                    out.append(f"{pad}P.absurd({goal.replace('@C@', leaf)}, P.false_true({bound}))")
                else:
                    out.append(f"{pad}P.absurd({goal.replace('@C@', leaf)}, P.false_true(scalar))")
                return
            out.append(f"{pad}match {P[i]}:")
            for b in (T, F):
                out.append(f"{pad}  case {b}:")
                tree(i + 1, fixed + [b], indent + 2)

        tree(0, [], 1)
        out.append("")
        # A 21-bit word padded with zero high bits.
        xw = "U32{U.join(21n, 11n, x, Word.zero(11n))}"
        out.append(
            f"def {name}_word(+x: Word(21n), {params}, scalar: {{U.scalar({xw}) == True{{}} : Bool}}, "
            f"large: {{({xw} <= 65535 : U32) == False{{}} : Bool}}) -> {goal.replace('@C@', xw)}:"
        )
        out.append("  match x:")
        out.append(f"    case {word(B + P)}:")
        out.append(f"      {name}_plane({bit_args()}, {bit_args(P)}, {args}, scalar, large)")
        out.append("")
        # Any scalar U32: its high eleven bits are zero.
        out.append(
            f"def {name}(+c: U32, {params}, +scalar: {{U.scalar(c) == True{{}} : Bool}}, "
            f"+large: {{(c <= 65535 : U32) == False{{}} : Bool}}) -> {goal.replace('@C@', 'c')}:"
        )
        out.append("  match c:")
        out.append("    case U32{w}:")
        out.append("      +same = Equal.cong(Word(32n), U32, v => U32{v}, U.join(21n, 11n, U.low(21n, 11n, w), Word.zero(11n)), w, "
                   "P.pad_reconstruct(21n, 11n, w, P.zero_sound(11n, U.high(21n, 11n, w), P.fits(w, scalar))))")
        out.append("      %same : " + goal.replace('@C@', '_'))
        out.append(
            f"      {name}_word(U.low(21n, 11n, w), {args}, "
            "Equal.trans(Bool, U.scalar(U32{U.join(21n, 11n, U.low(21n, 11n, w), Word.zero(11n))}), U.scalar(U32{w}), True{}, "
            "Equal.cong(U32, Bool, v => U.scalar(v), U32{U.join(21n, 11n, U.low(21n, 11n, w), Word.zero(11n))}, U32{w}, same), scalar), "
            "Equal.trans(Bool, (U32{U.join(21n, 11n, U.low(21n, 11n, w), Word.zero(11n))} <= 65535 : U32), (U32{w} <= 65535 : U32), False{}, "
            "Equal.cong(U32, Bool, v => (v <= 65535 : U32), U32{U.join(21n, 11n, U.low(21n, 11n, w), Word.zero(11n))}, U32{w}, same), large))"
        )
        out.append("")
    return "\n".join(out)


HEAD = """# Surrogate-pair escape inversion over the actual parser, for every
# supplementary-plane scalar. Generated by scripts/json-proofs/gen-surrogate.py.
import Base
import ../src/data/json.bend as J
import ../src/data/utf8.bend as U
import ./utf8.bend as P
import ./json-escape.bend as E
import ./json-words.bend as W
import ./json-valid.bend as V
"""


def main():
    parts = [HEAD] + [gen_plane(p) for p in range(1, 17)] + [gen_dispatch()]
    Path("proof/json-surrogate.bend").write_text("\n".join(parts))


if __name__ == "__main__":
    main()
