"""Bit-level case rows for a String's first character (BND-86).

Bend elaborates a literal-character pattern into a trie over the character's
32 bits, least significant first. A proof that cases on a string's first
character against literal rows must list every way the bits can leave the
trie. rows(targets) yields (pattern, code): pattern binds `remaining` and
`tail` on a mismatch row (code None), or spells all 32 bits and binds `tail`
for a target's row.
"""


def bits(code):
    return [bool((code >> i) & 1) for i in range(32)]


def word(prefix, end):
    out = end
    for b in reversed(prefix):
        out = "WCon{%s, %s}" % ("True{}" if b else "False{}", out)
    return out


def rows(targets, tail="tail"):
    out = []

    def go(prefix, live):
        depth = len(prefix)
        if depth == 32:
            (code,) = live
            out.append(("SCon{Chr{U32{%s}}, %s}" % (word(prefix, "WNil{}"), tail), code))
            return
        for b in (False, True):
            nxt = [c for c in live if bits(c)[depth] == b]
            if nxt:
                go(prefix + [b], nxt)
            else:
                out.append(("SCon{Chr{U32{%s}}, %s}" % (word(prefix + [b], "remaining"), tail), None))

    go([], list(targets))
    return out
