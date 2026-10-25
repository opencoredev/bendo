# BND-106: proofs of proof/write-progress-laws.bend.
import Base
import ../src/http/write_progress.bend as Progress
import ./write-progress-laws.bend as Laws

def lt_add(+n: Nat, +k: Nat) -> {Nat.is_lt(n, Nat.add(n, 1n+k)) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+p: lt_add(p, k)

def not_lt_add(+n: Nat, +k: Nat) -> {Nat.is_lt(Nat.add(n, k), n) == False{} : Bool}:
  match n k:
    case 0n 0n: {==}
    case 0n 1n+q: {==}
    case 1n+p _: not_lt_add(p, k)

def add_succ(+n: Nat, +m: Nat) -> {Nat.add(n, 1n+m) == 1n+Nat.add(n, m) : Nat}:
  match n:
    case 0n: {==}
    case 1n+p: Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, 1n+m), 1n+Nat.add(p, m), add_succ(p, m))

def unsent_add(+xs: List<&2, U32>, +acc: Nat) -> {Progress.unsent(xs, acc) == Nat.add(List.length(&2, U32, xs), acc) : Nat}:
  match xs:
    case Nil{}: {==}
    case c <> t:
      Equal.trans(Nat, Progress.unsent(t, 1n+acc), Nat.add(List.length(&2, U32, t), 1n+acc), 1n+Nat.add(List.length(&2, U32, t), acc), unsent_add(t, 1n+acc), add_succ(List.length(&2, U32, t), acc))

def add_zero(+n: Nat) -> {Nat.add(n, 0n) == n : Nat}:
  match n:
    case 0n: {==}
    case 1n+p: Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, 0n), p, add_zero(p))

def Laws.write_progress_continues(left, k): lt_add(left, k)
def Laws.write_stall_closes(before, k): not_lt_add(before, k)
def Laws.write_opening_continues(left): {==}
def Laws.write_timeout_default(): {==}
def Laws.write_unsent_length(xs): Equal.trans(Nat, Progress.unsent(xs, 0n), Nat.add(List.length(&2, U32, xs), 0n), List.length(&2, U32, xs), unsent_add(xs, 0n), add_zero(List.length(&2, U32, xs)))
