# Bit-pattern case splits for "every U32 except these literals", LSB first,
# mirroring how Bend compiles literal U32/Char patterns to a bit trie.
def word(bits, rest):
    out = rest
    for b in reversed(bits):
        out = "WCon{%s, %s}" % ("True{}" if b else "False{}", out)
    return out

def lit_bits(n):
    return [(n >> i) & 1 for i in range(32)]

def others(lits, var="bits"):
    """Patterns (as U32{...} terms) covering every U32 not in lits."""
    pats = []
    def go(prefix):
        k = len(prefix)
        live = [l for l in lits if lit_bits(l)[:k] == prefix]
        if not live:
            pats.append("U32{%s}" % word(prefix, var))
            return
        if k == 32:
            return
        for b in (0, 1):
            go(prefix + [b])
    go([])
    return pats
