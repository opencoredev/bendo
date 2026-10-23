import Base
import ./common.bend as C

type State is Data:
  State{a: U32, b: U32, c: U32, d: U32, e: U32}

def sched3(+i: U32, x0: U32, x1: U32, x2: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (w, x3) = r
  +x = C.rotl(U32.xor(x0, U32.xor(x1, U32.xor(x2, x3))), 1n)
  w = w[U32.and(i, 15)] <- x
  (w, x)

def sched2(+i: U32, x0: U32, x1: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (w, x2) = r
  sched3(i, x0, x1, x2, w[U32.and(U32.sub(i, 16), 15)])

def sched1(+i: U32, x0: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (w, x1) = r
  sched2(i, x0, x1, w[U32.and(U32.sub(i, 14), 15)])

def sched0(+i: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (w, x0) = r
  sched1(i, x0, w[U32.and(U32.sub(i, 8), 15)])

def schedule(w: Array<U32>, +i: U32, first: Bool) -> Array<U32> & U32:
  match first:
    case True{}:
      w[i]
    case False{}:
      sched0(i, w[U32.and(U32.sub(i, 3), 15)])

def choose(+b: U32, +c: U32, +d: U32, phase: U32) -> U32:
  match phase:
    case 0:
      U32.or(U32.and(b, c), U32.and(U32.not(b), d))
    case 2:
      U32.or(U32.and(b, c), U32.or(U32.and(b, d), U32.and(c, d)))
    case _:
      U32.xor(b, U32.xor(c, d))

def round_step(+i: U32, k: U32, state: State, r: Array<U32> & U32) -> Array<U32> & State:
  State{+a, +b, +c, +d, +e} = state
  (w, x) = r
  t = U32.add(C.rotl(a, 5n), U32.add(choose(b, c, d, U32.div(i, 20)), U32.add(e, U32.add(k, x))))
  (w, State{t, a, C.rotl(b, 30n), c, d})

def step(+i: U32, k: U32, r: Array<U32> & State) -> Array<U32> & State:
  (w, state) = r
  round_step(i, k, state, schedule(w, i, U32.is_lt(i, 16)))

def rounds(ks: List<&2, U32>, +i: U32, r: Array<U32> & State) -> State:
  match ks:
    case Nil{}:
      (w, state) = r
      state
    case k <> rest:
      rounds(rest, U32.inc(i), step(i, k, r))

def merge(state: State, result: State) -> State:
  State{a, b, c, d, e} = state
  State{a1, b1, c1, d1, e1} = result
  State{U32.add(a, a1), U32.add(b, b1), U32.add(c, c1), U32.add(d, d1), U32.add(e, e1)}

def compress(w: Array<U32>, +state: State) -> State:
  merge(state, rounds([1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1518500249, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 1859775393, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 2400959708, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782, 3395469782], 0, (w, state)))

def block_step(+i: U32, w: Array<U32>, state: State) -> Array<U32> & State:
  match i:
    case 15:
      ([0 : U32^4n], compress(w, state))
    case _:
      (w, state)

def blocks(xs: List<&2, U32>, +i: U32, r: Array<U32> & State) -> State:
  match xs:
    case a <> b <> c <> d <> t:
      (w, state) = r
      blocks(t, U32.and(U32.inc(i), 15), block_step(i, Array.set(U32, w, i, C.word(a, b, c, d)), state))
    case _:
      (w, state) = r
      state

def output(state: State) -> List<&2, U32>:
  State{a, b, c, d, e} = state
  List.append(&2, U32, C.bytes(a), List.append(&2, U32, C.bytes(b), List.append(&2, U32, C.bytes(c), List.append(&2, U32, C.bytes(d), List.append(&2, U32, C.bytes(e), [])))))

# Pure FIPS 180-4 digest. Input is an octet list; output is big endian.
def hash(xs: List<&2, U32>) -> List<&2, U32>:
  output(blocks(C.pad(xs), 0, ([0 : U32^4n], State{1732584193, 4023233417, 2562383102, 271733878, 3285377520})))
