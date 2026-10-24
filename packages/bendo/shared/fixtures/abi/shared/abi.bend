# One def per ABI case in docs/shared.md. abi.test.ts compiles this with
# `bendo build --shared` and checks the declarations and the runtime values.
import Base
import ../lib/shapes.bend as Shapes

type Color is Data:
  Red{}
  Rgb{r: U32, g: U32, b: U32}

type Box<-A: Data> is Data:
  Box{value: A}

type Tree<-A: Data> is Data:
  Leaf{}
  Node{left: Tree<A>, value: A, right: Tree<A>}

def Names() -> Data:
  List<&2, String>

def next_nat(n: Nat) -> Nat:
  (1n + n : Nat)

def add_u32(a: U32, b: U32) -> U32:
  (a + b : U32)

def half(x: F32) -> F32:
  (x / 2.0 : F32)

def negate(b: Bool) -> Bool:
  match b:
    case True{}: False{}
    case False{}: True{}

def greet(name: String) -> String:
  "hello " ++ name

def initial(s: String) -> Maybe<&2, Char>:
  match s:
    case SCon{c, t}: Some{c}
    case SNil{}: None{}

def letter() -> Char:
  'b'

def counts() -> List<&2, U32>:
  [1, 2, 3]

def total(xs: List<&2, Nat>, acc: Nat) -> Nat:
  match xs:
    case Nil{}: acc
    case h <> t: total(t, (h + acc : Nat))

def parse_flag(s: String) -> Result<&2, &2, String, Bool>:
  match s:
    case "yes": Done{True{}}
    case "no": Done{False{}}
    case _: Fail{"expected yes or no"}

def color(dark: Bool) -> Color:
  match dark:
    case True{}: Red{}
    case False{}: Rgb{1, 2, 3}

def brightness(c: Color) -> U32:
  match c:
    case Red{}: 255
    case Rgb{r, g, b}: (r + g + b : U32)

def boxed(-A: Data, x: A) -> Box<A>:
  Box{x}

def unbox(-A: Data, b: Box<A>) -> A:
  match b:
    case Box{x}: x

def singleton(-A: Data, x: A) -> Tree<A>:
  Node{Leaf{}, x, Leaf{}}

def pair(n: U32, s: String) -> U32 & String:
  (n, s)

def side(left: Bool) -> Either<&2, &2, U32, String>:
  match left:
    case True{}: Inl{1}
    case False{}: Inr{"right"}

def order(a: U32, b: U32) -> Cmp:
  U32.cmp(a, b)

def nothing() -> Unit:
  Unit{}

def names() -> Names():
  ["ada", "grace"]

def shape(long: Bool) -> Shapes.Shape:
  match long:
    case True{}: Shapes.Line{7n}
    case False{}: Shapes.Dot{}

def shapes() -> Shapes.Shapes():
  [Shapes.Dot{}, Shapes.Line{2n}]

def measure(s: Shapes.Shape) -> Nat:
  Shapes.length(s)

def adder(n: Nat) -> Nat -> Nat:
  m => (n + m : Nat)

def apply(f: Nat -> Nat, n: Nat) -> Nat:
  f(n)

def filled(+d: Nat, +v: U32) -> Array<U32>:
  Array.new(U32, d, v)

def lookup(key: String) -> Map<&2, U32> & U32:
  Map.get(U32, 0, Map.set(&2, U32, Map.new(&2, U32), "a", 1), key)
