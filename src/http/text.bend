# Stack-safe replacements for Base string and list helpers on request-sized
# input. Base String.split, String.to_lower, String.to_upper and List.append
# recurse once per element outside tail position, which overflows the
# JavaScript stack near 64 KiB. (String ++ compiles to native concatenation.) Every loop here is a tail call
# over reversed accumulators. LAWS.bend states each one equal to Base.
import Base

def bytes_append(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.reverse.go(&2, U32, List.reverse(&2, U32, xs), ys)

def lower_go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      acc
    case SCon{h, t}:
      lower_go(t, SCon{Char.to_lower(h), acc})

def lower(s: String) -> String:
  lower_go(String.reverse(s), "")

def upper_go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      acc
    case SCon{h, t}:
      upper_go(t, SCon{Char.to_upper(h), acc})

def upper(s: String) -> String:
  upper_go(String.reverse(s), "")

# The part being read, reversed, and the finished parts, in reverse order.
type Split is Data:
  Split{current: String, parts: List<&2, String>}

def split_step(h: Char, st: Split, cut: Bool) -> Split:
  match st cut:
    case Split{cur, ps} True{}:
      Split{"", String.reverse(cur) <> ps}
    case Split{cur, ps} False{}:
      Split{SCon{h, cur}, ps}

def split_done(st: Split) -> List<&2, String>:
  match st:
    case Split{cur, ps}:
      List.reverse(&2, String, String.reverse(cur) <> ps)

def split_go(s: String, +sep: Char, st: Split) -> List<&2, String>:
  match s:
    case SNil{}:
      split_done(st)
    case SCon{+h, t}:
      split_go(t, sep, split_step(h, st, Char.is_eq(h, sep)))

# Every part, empty ones included, exactly as Base String.split.
def split(s: String, +sep: Char) -> List<&2, String>:
  split_go(s, sep, Split{"", []})

def length_go(-A: Data, xs: List<&2, A>, n: Nat) -> Nat:
  match xs:
    case Nil{}:
      n
    case _ <> t:
      length_go(A, t, 1n+n)

def length(-A: Data, xs: List<&2, A>) -> Nat:
  length_go(A, xs, 0n)

# ---- cut: split at the first occurrence of sep ----

type Cut is Data:
  Cut{left: String, right: String}

def cut_prepend(c: Char, r: Maybe<&2, Cut>) -> Maybe<&2, Cut>:
  match r:
    case None{}: None{}
    case Some{Cut{a, b}}: Some{Cut{SCon{c, a}, b}}

def cut_pick(c: Char, t: String, rest: Maybe<&2, Cut>, here: Bool) -> Maybe<&2, Cut>:
  match here:
    case True{}: Some{Cut{"", t}}
    case False{}: cut_prepend(c, rest)

def cut_spec(s: String, +sep: Char) -> Maybe<&2, Cut>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: cut_pick(c, t, cut_spec(t, sep), Char.is_eq(c, sep))

# Right folds run as left loops over the reversed input: the accumulator
# holds the suffix read so far and the spec's answer for it.
type Folded is Data:
  Folded{rest: String, cut: Maybe<&2, Cut>}

def cut_fold(+c: Char, acc: Folded, +sep: Char) -> Folded:
  match acc:
    case Folded{+t, res}: Folded{SCon{c, t}, cut_pick(c, t, res, Char.is_eq(c, sep))}

def cut_answer(acc: Folded) -> Maybe<&2, Cut>:
  match acc:
    case Folded{t, res}: res

def cut_go(s: String, +sep: Char, acc: Folded) -> Maybe<&2, Cut>:
  match s:
    case SNil{}: cut_answer(acc)
    case SCon{+c, r}: cut_go(r, sep, cut_fold(c, acc, sep))

def cut(s: String, +sep: Char) -> Maybe<&2, Cut>:
  cut_go(String.reverse(s), sep, Folded{"", None{}})

def list_append(-A: Data, xs: List<&2, A>, ys: List<&2, A>) -> List<&2, A>:
  List.reverse.go(&2, A, List.reverse(&2, A, xs), ys)

# String.join's recursion is not a tail call; this one appends on the left
# (String ++ is native concatenation in the JavaScript target).
def join_go(xs: List<&2, String>, +sep: String, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      join_go(t, sep, String.append(acc, String.append(sep, h)))

# Prepend each piece so native String.append only traverses that piece,
# rather than the entire accumulated prefix.
def join_rev_go(xs: List<&2, String>, +sep: String, acc: String) -> String:
  match xs:
    case Nil{}: acc
    case h <> t: join_rev_go(t, sep, h ++ (sep ++ acc))

def join_reversed(xs: List<&2, String>, +sep: String) -> String:
  match xs:
    case Nil{}: ""
    case h <> t: join_rev_go(t, sep, h)

def join(xs: List<&2, String>, +sep: String) -> String:
  join_reversed(List.reverse(&2, String, xs), sep)
