import Base
import ./common.bend as C

type State is Data:
  State{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

def small0(+x: U32) -> U32:
  U32.xor(C.rotr(x, 7n), U32.xor(C.rotr(x, 18n), U32.shrn(x, 3n)))

def small1(+x: U32) -> U32:
  U32.xor(C.rotr(x, 17n), U32.xor(C.rotr(x, 19n), U32.shrn(x, 10n)))

def big0(+x: U32) -> U32:
  U32.xor(C.rotr(x, 2n), U32.xor(C.rotr(x, 13n), C.rotr(x, 22n)))

def big1(+x: U32) -> U32:
  U32.xor(C.rotr(x, 6n), U32.xor(C.rotr(x, 11n), C.rotr(x, 25n)))

def sched3(+i: U32, x0: U32, x1: U32, x2: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (w, x3) = r
  +x = U32.add(small1(x0), U32.add(x1, U32.add(small0(x2), x3)))
  w = w[U32.and(i, 15)] <- x
  (w, x)

def sched2(+i: U32, x0: U32, x1: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (w, x2) = r
  sched3(i, x0, x1, x2, w[U32.and(U32.sub(i, 16), 15)])

def sched1(+i: U32, x0: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (w, x1) = r
  sched2(i, x0, x1, w[U32.and(U32.sub(i, 15), 15)])

def sched0(+i: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (w, x0) = r
  sched1(i, x0, w[U32.and(U32.sub(i, 7), 15)])

def schedule(w: Array<U32>, +i: U32, first: Bool) -> Array<U32> & U32:
  match first:
    case True{}:
      w[i]
    case False{}:
      sched0(i, w[U32.and(U32.sub(i, 2), 15)])

def round_step(+i: U32, k: U32, state: State, r: Array<U32> & U32) -> Array<U32> & State:
  State{+a, +b, +c, +d, +e, +f, +g, +h} = state
  (w, x) = r
  +t1 = U32.add(h, U32.add(big1(e), U32.add(U32.xor(U32.and(e, f), U32.and(U32.not(e), g)), U32.add(k, x))))
  t2 = U32.add(big0(a), U32.xor(U32.and(a, b), U32.xor(U32.and(a, c), U32.and(b, c))))
  (w, State{U32.add(t1, t2), a, b, c, U32.add(d, t1), e, f, g})

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
  State{a, b, c, d, e, f, g, h} = state
  State{a1, b1, c1, d1, e1, f1, g1, h1} = result
  State{U32.add(a, a1), U32.add(b, b1), U32.add(c, c1), U32.add(d, d1), U32.add(e, e1), U32.add(f, f1), U32.add(g, g1), U32.add(h, h1)}

def compress(w: Array<U32>, +state: State) -> State:
  merge(state, rounds([1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221, 3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580, 3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986, 2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895, 666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037, 2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344, 430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779, 1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298], 0, (w, state)))

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
  State{a, b, c, d, e, f, g, h} = state
  List.append(&2, U32, C.bytes(a), List.append(&2, U32, C.bytes(b), List.append(&2, U32, C.bytes(c), List.append(&2, U32, C.bytes(d), List.append(&2, U32, C.bytes(e), List.append(&2, U32, C.bytes(f), List.append(&2, U32, C.bytes(g), List.append(&2, U32, C.bytes(h), []))))))))

# Pure FIPS 180-4 digest. Input is an octet list; output is big endian.
def hash(xs: List<&2, U32>) -> List<&2, U32>:
  output(blocks(C.pad(xs), 0, ([0 : U32^4n], State{1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225})))
