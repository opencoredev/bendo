# One def per ABI case in docs/shared.md. abi.test.ts compiles this with
# `bendo build --shared` and checks the declarations and the runtime values.
import Base
import ../lib/shapes.bend as Shapes
# Files named after reserved words become escaped namespaces (`default_`).
import ../lib/default.bend as Default
import ../lib/class.bend as Class
import ../lib/delete.bend as Delete
import ../lib/keyof.bend as Keyof

type Color is Data:
  Red{}
  Rgb{r: U32, g: U32, b: U32}

type Box<-A: Data> is Data:
  Box{value: A}

type Tree<-A: Data> is Data:
  Leaf{}
  Node{left: Tree<A>, value: A, right: Tree<A>}

# Quantity parameters, which a use may omit: `Bag<U32>` is `Bag<&1, U32>`.
type Bag<a, -A: Kind(a)> is Kind(a):
  Bag{items: List<a, A>}

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

# Shorthand generics omit the quantities; each must type like its full form.
def short_list() -> List<U32>:
  [4, 5]

def dup_list() -> +List<U32>:
  [6]

def short_maybe(s: String) -> Maybe<Char>:
  match s:
    case SCon{c, t}: Some{c}
    case SNil{}: None{}

def short_result(ok: Bool) -> Result<String, U32>:
  match ok:
    case True{}: Done{1}
    case False{}: Fail{"no"}

def bag_short(x: U32) -> Bag<U32>:
  Bag{[x]}

def bag_full(+x: U32) -> Bag<&2, U32>:
  Bag{[x, x]}

def pile_short(x: U32) -> Shapes.Pile<U32>:
  Shapes.Pile{Some{x}}

def pile_full(x: U32) -> Shapes.Pile<&2, U32>:
  Shapes.Pile{Some{x}}

def call_taken(x: U32, r: Array<(U32 -> U32)> & (U32 -> U32)) -> U32:
  match r:
    case (rest, f): f(x)

# An array of functions, not a function returning an array.
def first_fn(fs: Array<(U32 -> U32)>, x: U32) -> U32:
  call_taken(x, Array.swap(U32 -> U32, fs, 0, y => y))

def reserved(+n: Nat) -> Default.Thing & Class.Thing & Delete.Thing & Keyof.Thing:
  (Default.Default{n}, Class.Class{n}, Delete.Delete{n}, Keyof.Keyof{n})
