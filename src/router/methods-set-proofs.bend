# Independent token membership for the method set, including implicit HEAD.
import Base
import ./methods.bend as M
import ../http/request.bend as H
import ./equality-proofs.bend as Eq
import ./proofs.bend as B
import ./encoding.bend as E

def member(xs: List<&2, H.Method>, +q: H.Method) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> tail:
      String.eq(H.method_text(h), H.method_text(q)) || member(tail, q)

def list_valid(xs: List<&2, H.Method>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> tail:
      H.method_valid(h) && list_valid(tail)

# HEAD is identified by the same HTTP token equality as membership.
def is_head(q: H.Method) -> Bool:
  String.eq("HEAD", H.method_text(q))

def or_right_false(+a: Bool) -> {a || False{} == a : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def or_absorb(+a: Bool, +b: Bool) -> {a || b == a || (a || b) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def or_swap(+a: Bool, +b: Bool, +c: Bool) -> {a || (b || c) == b || (a || c) : Bool}:
  match a b:
    case False{} False{}: {==}
    case False{} True{}: {==}
    case True{} False{}: {==}
    case True{} True{}: {==}

def insert_tail(+m: H.Method, +h: H.Method, +tail: List<&2, H.Method>, +q: H.Method,
    +before: Bool, decision: {M.before(m, h) == before : Bool},
    rec: {member(M.insert_new(m, tail), q) == String.eq(H.method_text(m), H.method_text(q)) || member(tail, q) : Bool}) ->
    {member(E.choose(List<&2, H.Method>, M.before(m, h), u => m <> h <> tail, u => h <> M.insert_new(m, tail)), q) == String.eq(H.method_text(m), H.method_text(q)) || member(h <> tail, q) : Bool}:
  match before:
    case True{}:
    %Equal.sym(Bool, M.before(m, h), True{}, decision) : {member(E.choose(List<&2, H.Method>, _, u => m <> h <> tail, u => h <> M.insert_new(m, tail)), q) == String.eq(H.method_text(m), H.method_text(q)) || member(h <> tail, q) : Bool}
      {==}
    case False{}:
    %Equal.sym(Bool, M.before(m, h), False{}, decision) : {member(E.choose(List<&2, H.Method>, _, u => m <> h <> tail, u => h <> M.insert_new(m, tail)), q) == String.eq(H.method_text(m), H.method_text(q)) || member(h <> tail, q) : Bool}
      %Equal.sym(Bool, member(M.insert_new(m, tail), q), String.eq(H.method_text(m), H.method_text(q)) || member(tail, q), rec) : {String.eq(H.method_text(h), H.method_text(q)) || _ == String.eq(H.method_text(m), H.method_text(q)) || member(h <> tail, q) : Bool}
      or_swap(String.eq(H.method_text(h), H.method_text(q)), String.eq(H.method_text(m), H.method_text(q)), member(tail, q))

def insert_new_member(+xs: List<&2, H.Method>, +m: H.Method, +q: H.Method) ->
    {member(M.insert_new(m, xs), q) == String.eq(H.method_text(m), H.method_text(q)) || member(xs, q) : Bool}:
  match xs:
    case Nil{}: {==}
    case +h <> +tail:
      insert_tail(m, h, tail, q, M.before(m, h), {==}, insert_new_member(tail, m, q))

def absorb_step(+h: H.Method, +tail: List<&2, H.Method>, +m: H.Method, +q: H.Method,
    +same: Bool, +decision: {String.eq(H.method_text(h), H.method_text(m)) == same : Bool},
    yes: {same || M.contains(tail, m) == True{} : Bool},
    rest: {M.contains(tail, m) == True{} : Bool} -> {String.eq(H.method_text(m), H.method_text(q)) || member(tail, q) == member(tail, q) : Bool}) ->
    {String.eq(H.method_text(m), H.method_text(q)) || member(h <> tail, q) == member(h <> tail, q) : Bool}:
  match same:
    case True{}:
      %Equal.sym(String, H.method_text(h), H.method_text(m), Eq.string_eq_sound(H.method_text(h), H.method_text(m), decision)) : {String.eq(H.method_text(m), H.method_text(q)) || (String.eq(_, H.method_text(q)) || member(tail, q)) == String.eq(_, H.method_text(q)) || member(tail, q) : Bool}
      Equal.sym(Bool, String.eq(H.method_text(m), H.method_text(q)) || member(tail, q), String.eq(H.method_text(m), H.method_text(q)) || (String.eq(H.method_text(m), H.method_text(q)) || member(tail, q)), or_absorb(String.eq(H.method_text(m), H.method_text(q)), member(tail, q)))
    case False{}:
      Equal.trans(Bool, String.eq(H.method_text(m), H.method_text(q)) || member(h <> tail, q), String.eq(H.method_text(h), H.method_text(q)) || (String.eq(H.method_text(m), H.method_text(q)) || member(tail, q)), member(h <> tail, q), or_swap(String.eq(H.method_text(m), H.method_text(q)), String.eq(H.method_text(h), H.method_text(q)), member(tail, q)), Equal.cong(Bool, Bool, b => String.eq(H.method_text(h), H.method_text(q)) || b, String.eq(H.method_text(m), H.method_text(q)) || member(tail, q), member(tail, q), rest(yes)))

def member_absorb(+xs: List<&2, H.Method>, +m: H.Method, +q: H.Method, yes: {M.contains(xs, m) == True{} : Bool}) ->
    {String.eq(H.method_text(m), H.method_text(q)) || member(xs, q) == member(xs, q) : Bool}:
  match xs:
    case Nil{}:
      B.absurd({String.eq(H.method_text(m), H.method_text(q)) || False{} == False{} : Bool}, B.false_true(yes))
    case +h <> +tail:
      absorb_step(h, tail, m, q, String.eq(H.method_text(h), H.method_text(m)), {==}, yes, e => member_absorb(tail, m, q, e))

def insert_decision(+xs: List<&2, H.Method>, +m: H.Method, +q: H.Method,
    +has: Bool, +decision: {M.contains(xs, m) == has : Bool}) ->
    {member(M.insert(m, xs), q) == String.eq(H.method_text(m), H.method_text(q)) || member(xs, q) : Bool}:
  match has:
    case True{}:
      %Equal.sym(Bool, M.contains(xs, m), True{}, decision) : {member(E.choose(List<&2, H.Method>, _, u => xs, u => M.insert_new(m, xs)), q) == String.eq(H.method_text(m), H.method_text(q)) || member(xs, q) : Bool}
      Equal.sym(Bool, String.eq(H.method_text(m), H.method_text(q)) || member(xs, q), member(xs, q), member_absorb(xs, m, q, decision))
    case False{}:
      %Equal.sym(Bool, M.contains(xs, m), False{}, decision) : {member(E.choose(List<&2, H.Method>, _, u => xs, u => M.insert_new(m, xs)), q) == String.eq(H.method_text(m), H.method_text(q)) || member(xs, q) : Bool}
      insert_new_member(xs, m, q)

def insert_member(+xs: List<&2, H.Method>, +m: H.Method, +q: H.Method) ->
    {member(M.insert(m, xs), q) == String.eq(H.method_text(m), H.method_text(q)) || member(xs, q) : Bool}:
  insert_decision(xs, m, q, M.contains(xs, m), {==})

def canonical_algebra(+g: Bool, +a: Bool, +b: Bool, +c: Bool, +d: Bool) ->
    {E.choose(Bool, g, u => b || (a || (c || (b && d))), u => a || (c || (b && d))) == (a || c) || (b && (g || d)) : Bool}:
  match g a b c:
    case False{} False{} False{} False{}: {==}
    case False{} False{} False{} True{}: {==}
    case False{} False{} True{} False{}: {==}
    case False{} False{} True{} True{}: {==}
    case False{} True{} False{} False{}: {==}
    case False{} True{} False{} True{}: {==}
    case False{} True{} True{} False{}: {==}
    case False{} True{} True{} True{}: {==}
    case True{} False{} False{} False{}: {==}
    case True{} False{} False{} True{}: {==}
    case True{} False{} True{} False{}: {==}
    case True{} False{} True{} True{}: {==}
    case True{} True{} False{} False{}: {==}
    case True{} True{} False{} True{}: {==}
    case True{} True{} True{} False{}: {==}
    case True{} True{} True{} True{}: {==}

def canonical_step(+h: H.Method, +tail: List<&2, H.Method>, +q: H.Method,
    +g: Bool, decision: {String.eq(H.method_text(h), "GET") == g : Bool},
    +rec: {member(M.canonical(tail), q) == member(tail, q) || (is_head(q) && member(tail, H.Get{})) : Bool}) ->
    {member(M.canonical(h <> tail), q) == member(h <> tail, q) || (is_head(q) && member(h <> tail, H.Get{})) : Bool}:
  match g:
    case True{}:
      %Equal.sym(Bool, String.eq(H.method_text(h), "GET"), True{}, decision) : {member(E.choose(List<&2, H.Method>, _, u => M.insert(H.Head{}, M.insert(h, M.canonical(tail))), u => M.insert(h, M.canonical(tail))), q) == member(h <> tail, q) || (is_head(q) && (_ || member(tail, H.Get{}))) : Bool}
      %Equal.sym(Bool, member(M.insert(H.Head{}, M.insert(h, M.canonical(tail))), q), is_head(q) || member(M.insert(h, M.canonical(tail)), q), insert_member(M.insert(h, M.canonical(tail)), H.Head{}, q)) : {_ == member(h <> tail, q) || (is_head(q) && (True{} || member(tail, H.Get{}))) : Bool}
      %Equal.sym(Bool, member(M.insert(h, M.canonical(tail)), q), String.eq(H.method_text(h), H.method_text(q)) || member(M.canonical(tail), q), insert_member(M.canonical(tail), h, q)) : {is_head(q) || _ == member(h <> tail, q) || (is_head(q) && (True{} || member(tail, H.Get{}))) : Bool}
      %Equal.sym(Bool, member(M.canonical(tail), q), member(tail, q) || (is_head(q) && member(tail, H.Get{})), rec) : {is_head(q) || (String.eq(H.method_text(h), H.method_text(q)) || _) == member(h <> tail, q) || (is_head(q) && (True{} || member(tail, H.Get{}))) : Bool}
      canonical_algebra(True{}, String.eq(H.method_text(h), H.method_text(q)), is_head(q), member(tail, q), member(tail, H.Get{}))
    case False{}:
      %Equal.sym(Bool, String.eq(H.method_text(h), "GET"), False{}, decision) : {member(E.choose(List<&2, H.Method>, _, u => M.insert(H.Head{}, M.insert(h, M.canonical(tail))), u => M.insert(h, M.canonical(tail))), q) == member(h <> tail, q) || (is_head(q) && (_ || member(tail, H.Get{}))) : Bool}
      %Equal.sym(Bool, member(M.insert(h, M.canonical(tail)), q), String.eq(H.method_text(h), H.method_text(q)) || member(M.canonical(tail), q), insert_member(M.canonical(tail), h, q)) : {_ == member(h <> tail, q) || (is_head(q) && (False{} || member(tail, H.Get{}))) : Bool}
      %Equal.sym(Bool, member(M.canonical(tail), q), member(tail, q) || (is_head(q) && member(tail, H.Get{})), rec) : {String.eq(H.method_text(h), H.method_text(q)) || _ == member(h <> tail, q) || (is_head(q) && (False{} || member(tail, H.Get{}))) : Bool}
      canonical_algebra(False{}, String.eq(H.method_text(h), H.method_text(q)), is_head(q), member(tail, q), member(tail, H.Get{}))

def and_false(+b: Bool) -> {b && False{} == False{} : Bool}:
  match b:
    case False{}: {==}
    case True{}: {==}

# The token formulation holds even without admissibility assumptions.
def canonical_member(+xs: List<&2, H.Method>, +q: H.Method) ->
    {member(M.canonical(xs), q) == member(xs, q) || (is_head(q) && member(xs, H.Get{})) : Bool}:
  match xs:
    case Nil{}:
      Equal.sym(Bool, is_head(q) && False{}, False{}, and_false(is_head(q)))
    case +h <> +tail:
      canonical_step(h, tail, q, String.eq(H.method_text(h), "GET"), {==}, canonical_member(tail, q))
