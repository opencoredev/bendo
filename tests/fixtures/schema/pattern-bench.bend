# Times the pattern matchers on the worst valid shapes. Not part of the suite.
import Base
import ../../../src/data/schema-pattern.bend as P
import ../../../src/data/schema-pattern-automaton.bend as A

def az() -> P.Pattern:
  P.Class{[P.Range{97, 122}]}

def upto(+r: P.Pattern, n: Nat) -> P.Pattern:
  P.Repeat{r, 0n, Some{n}}

def copies(k: Nat, +r: P.Pattern) -> List<&2, P.Pattern>:
  match k:
    case 0n: []
    case 1n+j: r <> copies(j, r)

def star(r: P.Pattern) -> P.Pattern:
  P.Repeat{r, 0n, None{}}

# 0: (?:[a-z]{0,2}){32}*  1: (?:[a-z]{0,6}){16}*  2: (?:[a-z]?){42}*
# 3: (?:a{0,10}){0,11}  4: that, starred  5: ((a{0,4}){0,4}){0,5}*
def shape(k: Nat) -> P.Pattern:
  match k:
    case 0n: star(P.seq(copies(32n, upto(az(), 2n))))
    case 1n: star(P.seq(copies(16n, upto(az(), 6n))))
    case 2n: star(P.seq(copies(42n, upto(az(), 1n))))
    case 3n: upto(upto(P.Class{[P.Range{97, 97}]}, 10n), 11n)
    case 4n: star(upto(upto(P.Class{[P.Range{97, 97}]}, 10n), 11n))
    case _: star(upto(upto(upto(P.Class{[P.Range{97, 97}]}, 4n), 4n), 5n))

def digits(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}: acc
    case SCon{Chr{c}, t}: digits(t, Nat.add(Nat.mul(acc, 10n), U32.to_nat((c - 48 : U32))))

def text(n: Nat, acc: String) -> String:
  match n:
    case 0n: acc
    case 1n+k: text(k, SCon{'a', acc})

def show(b: Bool) -> String:
  match b:
    case True{}: "true"
    case False{}: "false"

def nodes(+bs: List<&2, List<&2, A.Node>>) -> String:
  show(A.check(bs, bs)) ++ " nodes=" ++ Nat.show(List.length(&2, A.Node, List.concat(&2, A.Node, bs)))

# 0: derivative matcher  1: automaton  2: table info
def go(mode: Nat, +p: P.Pattern, s: String) -> String:
  match mode:
    case 0n: show(P.matches(p, s))
    case 1n: show(A.matches(p, s))
    case _: nodes(A.table_blocks(p)) ++ " size=" ++ Nat.show(P.size(p)) ++ " valid=" ++ show(P.valid(p))

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case exe <> mode <> name <> n <> Nil{}: IO.print(go(digits(mode, 0n), shape(digits(name, 0n)), text(digits(n, 0n), "")))
    case _: IO.print("usage: bench old|new|info shape n")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
