# Independent order/set predicates and canonical insertion proofs for BND-18.
import Base
import ./methods.bend as M
import ../http/request.bend as H
import ./encoding.bend as E
import ./proofs.bend as C
import ./equality-proofs.bend as Eq
import ./methods-set-proofs.bend as Set

def flip(c: Cmp) -> Cmp:
  match c:
    case LT{}: GT{}
    case EQ{}: EQ{}
    case GT{}: LT{}

def bool_flip(+a: Bool, +b: Bool) -> {Bool.cmp(a, b) == flip(Bool.cmp(b, a)) : Cmp}:
  match a b:
    case False{} False{}: {==}
    case False{} True{}: {==}
    case True{} False{}: {==}
    case True{} True{}: {==}

def fin_flip(+a: Bool, +b: Bool, c: Cmp) ->
    {Word.cmp.fin(a, b, flip(c)) == flip(Word.cmp.fin(b, a, c)) : Cmp}:
  match c:
    case LT{}: {==}
    case GT{}: {==}
    case EQ{}: bool_flip(a, b)

def word_flip(+n: Nat, +a: Word(n), +b: Word(n)) -> {Word.cmp(n, a, b) == flip(Word.cmp(n, b, a)) : Cmp}:
  match n a b:
    case 0n WNil{} WNil{}: {==}
    case 1n+k WCon{+ah, +at} WCon{+bh, +bt}:
      %Equal.sym(Cmp, Word.cmp(k, at, bt), flip(Word.cmp(k, bt, at)), word_flip(k, at, bt)) : {Word.cmp.fin(ah, bh, _) == flip(Word.cmp.fin(bh, ah, Word.cmp(k, bt, at))) : Cmp}
      fin_flip(ah, bh, Word.cmp(k, bt, at))

def u32_flip(+a: U32, +b: U32) -> {U32.cmp(a, b) == flip(U32.cmp(b, a)) : Cmp}:
  match a b:
    case U32{+aw} U32{+bw}: word_flip(32n, aw, bw)

def string_flip_go(+a: String, +b: String, c: Cmp,
    recur: {String.order(a, b) == flip(String.order(b, a)) : Cmp}) ->
    {String.order.go(a, b, flip(c)) == flip(String.order.go(b, a, c)) : Cmp}:
  match a b c:
    case SNil{} SNil{} LT{}: {==}
    case SNil{} SNil{} GT{}: {==}
    case SNil{} SNil{} EQ{}: recur
    case SNil{} SCon{Chr{k}, u} LT{}: {==}
    case SNil{} SCon{Chr{k}, u} GT{}: {==}
    case SNil{} SCon{Chr{k}, u} EQ{}: recur
    case SCon{Chr{h}, t} SNil{} LT{}: {==}
    case SCon{Chr{h}, t} SNil{} GT{}: {==}
    case SCon{Chr{h}, t} SNil{} EQ{}: recur
    case SCon{Chr{h}, t} SCon{Chr{k}, u} LT{}: {==}
    case SCon{Chr{h}, t} SCon{Chr{k}, u} GT{}: {==}
    case SCon{Chr{h}, t} SCon{Chr{k}, u} EQ{}: recur

def string_flip(+a: String, +b: String) -> {String.order(a, b) == flip(String.order(b, a)) : Cmp}:
  match a b:
    case SNil{} SNil{}: {==}
    case SNil{} SCon{Chr{h}, t}: {==}
    case SCon{Chr{h}, t} SNil{}: {==}
    case SCon{Chr{+n}, +t} SCon{Chr{+m}, +u}:
      %Equal.sym(Cmp, U32.cmp(n, m), flip(U32.cmp(m, n)), u32_flip(n, m)) : {String.order.go(t, u, _) == flip(String.order.go(u, t, U32.cmp(m, n))) : Cmp}
      string_flip_go(t, u, U32.cmp(m, n), string_flip(t, u))

def cmp_total(c: Cmp, neq: {Cmp.is_eq(c) == False{} : Bool}, reverse: {Cmp.is_lt(flip(c)) == False{} : Bool}) -> {Cmp.is_lt(c) == True{} : Bool}:
  match c:
    case LT{}: {==}
    case EQ{}: C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case GT{}: C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))

def string_total(+a: String, +b: String, neq: {String.eq(a, b) == False{} : Bool}, reverse: {String.is_lt(b, a) == False{} : Bool}) -> {String.is_lt(a, b) == True{} : Bool}:
  cmp_total(String.order(a, b), neq, (
    %string_flip(b, a) : {Cmp.is_lt(_) == False{} : Bool}
    reverse))

# Canonical order: standard ranks GET HEAD POST PUT DELETE CONNECT OPTIONS
# TRACE PATCH, then extension tokens in lexicographic order.
def rank(m: H.Method) -> U32:
  match m:
    case H.Get{}: 0
    case H.Head{}: 1
    case H.Post{}: 2
    case H.Put{}: 3
    case H.Delete{}: 4
    case H.Connect{}: 5
    case H.Options{}: 6
    case H.Trace{}: 7
    case H.Patch{}: 8
    case H.Extension{token}: 9

def rank_equal(+m: H.Method) -> {M.rank(m) == rank(m) : U32}:
  match m:
    case H.Get{}: {==}
    case H.Head{}: {==}
    case H.Post{}: {==}
    case H.Put{}: {==}
    case H.Delete{}: {==}
    case H.Connect{}: {==}
    case H.Options{}: {==}
    case H.Trace{}: {==}
    case H.Patch{}: {==}
    case H.Extension{token}: {==}

def precedes(+a: H.Method, +b: H.Method) -> Bool:
  (rank(a) < rank(b) : U32) || (U32.is_eq(rank(a), rank(b)) && String.is_lt(H.method_text(a), H.method_text(b)))

def before_equal(+a: H.Method, +b: H.Method) -> {M.before(a, b) == precedes(a, b) : Bool}:
  %Equal.sym(U32, M.rank(a), rank(a), rank_equal(a)) : {( _ < M.rank(b) : U32) || (U32.is_eq(_, M.rank(b)) && String.is_lt(H.method_text(a), H.method_text(b))) == precedes(a, b) : Bool}
  %Equal.sym(U32, M.rank(b), rank(b), rank_equal(b)) : {(rank(a) < _ : U32) || (U32.is_eq(rank(a), _) && String.is_lt(H.method_text(a), H.method_text(b))) == precedes(a, b) : Bool}
  {==}

def member(xs: List<&2, H.Method>, +m: H.Method) -> Bool:
  match xs:
    case Nil{}: False{}
    case h <> tail: String.eq(H.method_text(h), H.method_text(m)) || member(tail, m)

def ordered(xs: List<&2, H.Method>) -> Bool:
  match xs:
    case Nil{}: True{}
    case h <> Nil{}: True{}
    case +a <> +b <> +tail: precedes(a, b) && ordered(b <> tail)

def unique(xs: List<&2, H.Method>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +h <> +tail: Bool.not(member(tail, h)) && unique(tail)

def total(+a: H.Method, +b: H.Method, neq: {String.eq(H.method_text(a), H.method_text(b)) == False{} : Bool}, reverse: {precedes(b, a) == False{} : Bool}) -> {precedes(a, b) == True{} : Bool}:
  match a b:
    case H.Get{} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case H.Get{} H.Head{}:
      {==}
    case H.Get{} H.Post{}:
      {==}
    case H.Get{} H.Put{}:
      {==}
    case H.Get{} H.Delete{}:
      {==}
    case H.Get{} H.Connect{}:
      {==}
    case H.Get{} H.Options{}:
      {==}
    case H.Get{} H.Trace{}:
      {==}
    case H.Get{} H.Patch{}:
      {==}
    case H.Get{} H.Extension{+y}:
      {==}
    case H.Head{} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Head{} H.Head{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case H.Head{} H.Post{}:
      {==}
    case H.Head{} H.Put{}:
      {==}
    case H.Head{} H.Delete{}:
      {==}
    case H.Head{} H.Connect{}:
      {==}
    case H.Head{} H.Options{}:
      {==}
    case H.Head{} H.Trace{}:
      {==}
    case H.Head{} H.Patch{}:
      {==}
    case H.Head{} H.Extension{+y}:
      {==}
    case H.Post{} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Post{} H.Head{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Post{} H.Post{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case H.Post{} H.Put{}:
      {==}
    case H.Post{} H.Delete{}:
      {==}
    case H.Post{} H.Connect{}:
      {==}
    case H.Post{} H.Options{}:
      {==}
    case H.Post{} H.Trace{}:
      {==}
    case H.Post{} H.Patch{}:
      {==}
    case H.Post{} H.Extension{+y}:
      {==}
    case H.Put{} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Put{} H.Head{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Put{} H.Post{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Put{} H.Put{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case H.Put{} H.Delete{}:
      {==}
    case H.Put{} H.Connect{}:
      {==}
    case H.Put{} H.Options{}:
      {==}
    case H.Put{} H.Trace{}:
      {==}
    case H.Put{} H.Patch{}:
      {==}
    case H.Put{} H.Extension{+y}:
      {==}
    case H.Delete{} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Delete{} H.Head{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Delete{} H.Post{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Delete{} H.Put{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Delete{} H.Delete{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case H.Delete{} H.Connect{}:
      {==}
    case H.Delete{} H.Options{}:
      {==}
    case H.Delete{} H.Trace{}:
      {==}
    case H.Delete{} H.Patch{}:
      {==}
    case H.Delete{} H.Extension{+y}:
      {==}
    case H.Connect{} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Connect{} H.Head{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Connect{} H.Post{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Connect{} H.Put{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Connect{} H.Delete{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Connect{} H.Connect{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case H.Connect{} H.Options{}:
      {==}
    case H.Connect{} H.Trace{}:
      {==}
    case H.Connect{} H.Patch{}:
      {==}
    case H.Connect{} H.Extension{+y}:
      {==}
    case H.Options{} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Options{} H.Head{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Options{} H.Post{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Options{} H.Put{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Options{} H.Delete{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Options{} H.Connect{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Options{} H.Options{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case H.Options{} H.Trace{}:
      {==}
    case H.Options{} H.Patch{}:
      {==}
    case H.Options{} H.Extension{+y}:
      {==}
    case H.Trace{} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Trace{} H.Head{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Trace{} H.Post{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Trace{} H.Put{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Trace{} H.Delete{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Trace{} H.Connect{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Trace{} H.Options{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Trace{} H.Trace{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case H.Trace{} H.Patch{}:
      {==}
    case H.Trace{} H.Extension{+y}:
      {==}
    case H.Patch{} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Patch{} H.Head{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Patch{} H.Post{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Patch{} H.Put{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Patch{} H.Delete{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Patch{} H.Connect{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Patch{} H.Options{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Patch{} H.Trace{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Patch{} H.Patch{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, neq)))
    case H.Patch{} H.Extension{+y}:
      {==}
    case H.Extension{+x} H.Get{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Extension{+x} H.Head{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Extension{+x} H.Post{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Extension{+x} H.Put{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Extension{+x} H.Delete{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Extension{+x} H.Connect{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Extension{+x} H.Options{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Extension{+x} H.Trace{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Extension{+x} H.Patch{}:
      C.absurd({False{} == True{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, reverse)))
    case H.Extension{+x} H.Extension{+y}:
      string_total(x, y, neq, reverse)
def flip_eq(c: Cmp) -> {Cmp.is_eq(flip(c)) == Cmp.is_eq(c) : Bool}:
  match c:
    case EQ{}: {==}
    case LT{}: {==}
    case GT{}: {==}

def eq_sym(+a: String, +b: String) -> {String.eq(a, b) == String.eq(b, a) : Bool}:
  Equal.trans(Bool, String.eq(a, b), Cmp.is_eq(flip(String.order(b, a))), String.eq(b, a), Equal.cong(Cmp, Bool, x => Cmp.is_eq(x), String.order(a, b), flip(String.order(b, a)), string_flip(a, b)), flip_eq(String.order(b, a)))

def or_repeat(+a: Bool, +b: Bool) -> {a || (a || b) == a || b : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_swap(+a: Bool, +b: Bool, +c: Bool) -> {a || (b || c) == b || (a || c) : Bool}:
  match a b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def or_left_false(+a: Bool, +b: Bool, no: {a || b == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: C.absurd({True{} == False{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, no)))

def or_right_false(+a: Bool, +b: Bool, no: {a || b == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case False{}: no
    case True{}: C.absurd({b == False{} : Bool}, C.false_true(Equal.sym(Bool, True{}, False{}, no)))

def not_false(+a: Bool, no: {a == False{} : Bool}) -> {Bool.not(a) == True{} : Bool}:
  Equal.cong(Bool, Bool, x => Bool.not(x), a, False{}, no)

def false_not(+a: Bool, no: {Bool.not(a) == True{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: C.absurd({True{} == False{} : Bool}, C.false_true(no))

def and_true(+a: Bool, +b: Bool, left: {a == True{} : Bool}, right: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, left) : {_ && b == True{} : Bool}
  right

def member_contains(+xs: List<&2, H.Method>, +m: H.Method) -> {M.contains(xs, m) == member(xs, m) : Bool}:
  match xs:
    case Nil{}: {==}
    case +h <> +tail:
      Equal.cong(Bool, Bool, x => String.eq(H.method_text(h), H.method_text(m)) || x, M.contains(tail, m), member(tail, m), member_contains(tail, m))

def new_absent_step(+m: H.Method, +h: H.Method, +tail: List<&2, H.Method>, +q: H.Method, before: Bool,
    neq: {String.eq(H.method_text(m), H.method_text(q)) == False{} : Bool},
    +absent: {member(h <> tail, q) == False{} : Bool},
    rec: {member(M.insert_new(m, tail), q) == False{} : Bool}) ->
    {member(E.choose(List<&2, H.Method>, before, u => m <> h <> tail, u => h <> M.insert_new(m, tail)), q) == False{} : Bool}:
  match before:
    case True{}:
      %Equal.sym(Bool, String.eq(H.method_text(m), H.method_text(q)), False{}, neq) : {_ || member(h <> tail, q) == False{} : Bool}
      absent
    case False{}:
      %Equal.sym(Bool, String.eq(H.method_text(h), H.method_text(q)), False{}, or_left_false(String.eq(H.method_text(h), H.method_text(q)), member(tail, q), absent)) : {_ || member(M.insert_new(m, tail), q) == False{} : Bool}
      rec

def new_absent(+m: H.Method, +xs: List<&2, H.Method>, +q: H.Method,
    +neq: {String.eq(H.method_text(m), H.method_text(q)) == False{} : Bool}, +absent: {member(xs, q) == False{} : Bool}) ->
    {member(M.insert_new(m, xs), q) == False{} : Bool}:
  match xs:
    case Nil{}:
      %Equal.sym(Bool, String.eq(H.method_text(m), H.method_text(q)), False{}, neq) : {_ || False{} == False{} : Bool}
      {==}
    case +h <> +tail:
      new_absent_step(m, h, tail, q, M.before(m, h), neq, absent, new_absent(m, tail, q, neq, or_right_false(String.eq(H.method_text(h), H.method_text(q)), member(tail, q), absent)))

def unique_new_step(+m: H.Method, +h: H.Method, +tail: List<&2, H.Method>, before: Bool,
    +absent: {member(h <> tail, m) == False{} : Bool}, +good: {unique(h <> tail) == True{} : Bool},
    rec: {unique(M.insert_new(m, tail)) == True{} : Bool}) ->
    {unique(E.choose(List<&2, H.Method>, before, u => m <> h <> tail, u => h <> M.insert_new(m, tail))) == True{} : Bool}:
  match before:
    case True{}:
      and_true(Bool.not(member(h <> tail, m)), unique(h <> tail), not_false(member(h <> tail, m), absent), good)
    case False{}:
      +head_absent = false_not(member(tail, h), C.and_left(Bool.not(member(tail, h)), unique(tail), good))
      mh = Equal.trans(Bool, String.eq(H.method_text(m), H.method_text(h)), String.eq(H.method_text(h), H.method_text(m)), False{}, eq_sym(H.method_text(m), H.method_text(h)), or_left_false(String.eq(H.method_text(h), H.method_text(m)), member(tail, m), absent))
      and_true(Bool.not(member(M.insert_new(m, tail), h)), unique(M.insert_new(m, tail)), not_false(member(M.insert_new(m, tail), h), new_absent(m, tail, h, mh, head_absent)), rec)

def unique_new(+m: H.Method, +xs: List<&2, H.Method>, +absent: {member(xs, m) == False{} : Bool}, +good: {unique(xs) == True{} : Bool}) ->
    {unique(M.insert_new(m, xs)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +h <> +tail:
      unique_new_step(m, h, tail, M.before(m, h), absent, good, unique_new(m, tail, or_right_false(String.eq(H.method_text(h), H.method_text(m)), member(tail, m), absent), C.and_right(Bool.not(member(tail, h)), unique(tail), good)))

def unique_insert_step(+m: H.Method, +xs: List<&2, H.Method>, test: Bool,
    eq: {M.contains(xs, m) == test : Bool}, good: {unique(xs) == True{} : Bool}) ->
    {unique(E.choose(List<&2, H.Method>, test, u => xs, u => M.insert_new(m, xs))) == True{} : Bool}:
  match test:
    case True{}: good
    case False{}:
      unique_new(m, xs, Equal.trans(Bool, member(xs, m), M.contains(xs, m), False{}, Equal.sym(Bool, M.contains(xs, m), member(xs, m), member_contains(xs, m)), eq), good)

def unique_insert(+m: H.Method, +xs: List<&2, H.Method>, good: {unique(xs) == True{} : Bool}) -> {unique(M.insert(m, xs)) == True{} : Bool}:
  unique_insert_step(m, xs, M.contains(xs, m), {==}, good)
def prepend_step(+h: H.Method, +m: H.Method, +k: H.Method, +tail: List<&2, H.Method>, before: Bool,
    hm: {precedes(h, m) == True{} : Bool}, hk: {precedes(h, k) == True{} : Bool},
    result: {ordered(E.choose(List<&2, H.Method>, before, u => m <> k <> tail, u => k <> M.insert_new(m, tail))) == True{} : Bool}) ->
    {ordered(h <> E.choose(List<&2, H.Method>, before, u => m <> k <> tail, u => k <> M.insert_new(m, tail))) == True{} : Bool}:
  match before:
    case True{}: and_true(precedes(h, m), ordered(m <> k <> tail), hm, result)
    case False{}: and_true(precedes(h, k), ordered(k <> M.insert_new(m, tail)), hk, result)

def prepend_position(+h: H.Method, +m: H.Method, +xs: List<&2, H.Method>,
    hm: {precedes(h, m) == True{} : Bool}, old: {ordered(h <> xs) == True{} : Bool},
    result: {ordered(M.insert_new(m, xs)) == True{} : Bool}) ->
    {ordered(h <> M.insert_new(m, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      and_true(precedes(h, m), True{}, hm, {==})
    case +k <> +tail:
      prepend_step(h, m, k, tail, M.before(m, k), hm, C.and_left(precedes(h, k), ordered(k <> tail), old), result)

def tail_ordered(+h: H.Method, +xs: List<&2, H.Method>, old: {ordered(h <> xs) == True{} : Bool}) -> {ordered(xs) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +k <> +tail: C.and_right(precedes(h, k), ordered(k <> tail), old)

def ordered_new_step(+m: H.Method, +h: H.Method, +tail: List<&2, H.Method>, before: Bool,
    eq: {M.before(m, h) == before : Bool}, absent: {member(h <> tail, m) == False{} : Bool},
    old: {ordered(h <> tail) == True{} : Bool}, result: {ordered(M.insert_new(m, tail)) == True{} : Bool}) ->
    {ordered(E.choose(List<&2, H.Method>, before, u => m <> h <> tail, u => h <> M.insert_new(m, tail))) == True{} : Bool}:
  match before:
    case True{}:
      and_true(precedes(m, h), ordered(h <> tail), Equal.trans(Bool, precedes(m, h), M.before(m, h), True{}, Equal.sym(Bool, M.before(m, h), precedes(m, h), before_equal(m, h)), eq), old)
    case False{}:
      neq = or_left_false(String.eq(H.method_text(h), H.method_text(m)), member(tail, m), absent)
      prepend_position(h, m, tail, total(h, m, neq, Equal.trans(Bool, precedes(m, h), M.before(m, h), False{}, Equal.sym(Bool, M.before(m, h), precedes(m, h), before_equal(m, h)), eq)), old, result)

def ordered_new(+m: H.Method, +xs: List<&2, H.Method>, +absent: {member(xs, m) == False{} : Bool}, +old: {ordered(xs) == True{} : Bool}) ->
    {ordered(M.insert_new(m, xs)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +h <> +tail:
      ordered_new_step(m, h, tail, M.before(m, h), {==}, absent, old, ordered_new(m, tail, or_right_false(String.eq(H.method_text(h), H.method_text(m)), member(tail, m), absent), tail_ordered(h, tail, old)))

def ordered_insert_step(+m: H.Method, +xs: List<&2, H.Method>, test: Bool,
    eq: {M.contains(xs, m) == test : Bool}, old: {ordered(xs) == True{} : Bool}) ->
    {ordered(E.choose(List<&2, H.Method>, test, u => xs, u => M.insert_new(m, xs))) == True{} : Bool}:
  match test:
    case True{}: old
    case False{}:
      ordered_new(m, xs, Equal.trans(Bool, member(xs, m), M.contains(xs, m), False{}, Equal.sym(Bool, M.contains(xs, m), member(xs, m), member_contains(xs, m)), eq), old)

def ordered_insert(+m: H.Method, +xs: List<&2, H.Method>, old: {ordered(xs) == True{} : Bool}) -> {ordered(M.insert(m, xs)) == True{} : Bool}:
  ordered_insert_step(m, xs, M.contains(xs, m), {==}, old)

def canonical_order_step(+h: H.Method, +tail: List<&2, H.Method>, test: Bool,
    old: {ordered(M.insert(h, M.canonical(tail))) == True{} : Bool}) ->
    {ordered(E.choose(List<&2, H.Method>, test, u => M.insert(H.Head{}, M.insert(h, M.canonical(tail))), u => M.insert(h, M.canonical(tail)))) == True{} : Bool}:
  match test:
    case True{}: ordered_insert(H.Head{}, M.insert(h, M.canonical(tail)), old)
    case False{}: old

def canonical_order(+xs: List<&2, H.Method>) -> {ordered(M.canonical(xs)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +h <> +tail:
      canonical_order_step(h, tail, String.eq(H.method_text(h), "GET"), ordered_insert(h, M.canonical(tail), canonical_order(tail)))

def canonical_unique_step(+h: H.Method, +tail: List<&2, H.Method>, test: Bool,
    old: {unique(M.insert(h, M.canonical(tail))) == True{} : Bool}) ->
    {unique(E.choose(List<&2, H.Method>, test, u => M.insert(H.Head{}, M.insert(h, M.canonical(tail))), u => M.insert(h, M.canonical(tail)))) == True{} : Bool}:
  match test:
    case True{}: unique_insert(H.Head{}, M.insert(h, M.canonical(tail)), old)
    case False{}: old

def canonical_unique(+xs: List<&2, H.Method>) -> {unique(M.canonical(xs)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +h <> +tail:
      canonical_unique_step(h, tail, String.eq(H.method_text(h), "GET"), unique_insert(h, M.canonical(tail), canonical_unique(tail)))
def or_assoc(+a: Bool, +b: Bool, +c: Bool) -> {a || (b || c) == (a || b) || c : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

# Membership distributes over the independent matching-registration union.
def member_append(+xs: List<&2, H.Method>, +ys: List<&2, H.Method>, +m: H.Method) ->
    {member(List.append(&2, H.Method, xs, ys), m) == member(xs, m) || member(ys, m) : Bool}:
  match xs:
    case Nil{}: {==}
    case +h <> +tail:
      %Equal.sym(Bool, member(List.append(&2, H.Method, tail, ys), m), member(tail, m) || member(ys, m), member_append(tail, ys, m)) : {String.eq(H.method_text(h), H.method_text(m)) || _ == (String.eq(H.method_text(h), H.method_text(m)) || member(tail, m)) || member(ys, m) : Bool}
      or_assoc(String.eq(H.method_text(h), H.method_text(m)), member(tail, m), member(ys, m))
# Valid constructors make rank ordering coincide with HTTP-token ordering.

def valid_new_step(+m: H.Method, +h: H.Method, +tail: List<&2, H.Method>, test: Bool,
    +mv: {H.method_valid(m) == True{} : Bool}, +old: {Set.list_valid(h <> tail) == True{} : Bool},
    rec: {Set.list_valid(M.insert_new(m, tail)) == True{} : Bool}) ->
    {Set.list_valid(E.choose(List<&2, H.Method>, test, u => m <> h <> tail, u => h <> M.insert_new(m, tail))) == True{} : Bool}:
  match test:
    case True{}: and_true(H.method_valid(m), Set.list_valid(h <> tail), mv, old)
    case False{}: and_true(H.method_valid(h), Set.list_valid(M.insert_new(m, tail)), C.and_left(H.method_valid(h), Set.list_valid(tail), old), rec)

def valid_new(+m: H.Method, +xs: List<&2, H.Method>, +mv: {H.method_valid(m) == True{} : Bool}, +old: {Set.list_valid(xs) == True{} : Bool}) ->
    {Set.list_valid(M.insert_new(m, xs)) == True{} : Bool}:
  match xs:
    case Nil{}: and_true(H.method_valid(m), True{}, mv, {==})
    case +h <> +tail:
      valid_new_step(m, h, tail, M.before(m, h), mv, old, valid_new(m, tail, mv, C.and_right(H.method_valid(h), Set.list_valid(tail), old)))

def valid_insert_step(+m: H.Method, +xs: List<&2, H.Method>, test: Bool,
    mv: {H.method_valid(m) == True{} : Bool}, old: {Set.list_valid(xs) == True{} : Bool}) ->
    {Set.list_valid(E.choose(List<&2, H.Method>, test, u => xs, u => M.insert_new(m, xs))) == True{} : Bool}:
  match test:
    case True{}: old
    case False{}: valid_new(m, xs, mv, old)

def valid_insert(+m: H.Method, +xs: List<&2, H.Method>, mv: {H.method_valid(m) == True{} : Bool}, old: {Set.list_valid(xs) == True{} : Bool}) ->
    {Set.list_valid(M.insert(m, xs)) == True{} : Bool}:
  valid_insert_step(m, xs, M.contains(xs, m), mv, old)

def canonical_valid_step(+h: H.Method, +tail: List<&2, H.Method>, test: Bool,
    old: {Set.list_valid(M.insert(h, M.canonical(tail))) == True{} : Bool}) ->
    {Set.list_valid(E.choose(List<&2, H.Method>, test, u => M.insert(H.Head{}, M.insert(h, M.canonical(tail))), u => M.insert(h, M.canonical(tail)))) == True{} : Bool}:
  match test:
    case True{}: valid_insert(H.Head{}, M.insert(h, M.canonical(tail)), {==}, old)
    case False{}: old

def canonical_valid(+xs: List<&2, H.Method>, +old: {Set.list_valid(xs) == True{} : Bool}) -> {Set.list_valid(M.canonical(xs)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +h <> +tail:
      canonical_valid_step(h, tail, String.eq(H.method_text(h), "GET"), valid_insert(h, M.canonical(tail), C.and_left(H.method_valid(h), Set.list_valid(tail), old), canonical_valid(tail, C.and_right(H.method_valid(h), Set.list_valid(tail), old))))

def valid_append(+xs: List<&2, H.Method>, +ys: List<&2, H.Method>, +xv: {Set.list_valid(xs) == True{} : Bool}, yv: {Set.list_valid(ys) == True{} : Bool}) ->
    {Set.list_valid(List.append(&2, H.Method, xs, ys)) == True{} : Bool}:
  match xs:
    case Nil{}: yv
    case +h <> +tail:
      and_true(H.method_valid(h), Set.list_valid(List.append(&2, H.Method, tail, ys)), C.and_left(H.method_valid(h), Set.list_valid(tail), xv), valid_append(tail, ys, C.and_right(H.method_valid(h), Set.list_valid(tail), xv), yv))
