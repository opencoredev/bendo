# Structural scan facts and a budget for the writer's work queue.
import Base
import ../src/data/json.bend as J
import ./utf8.bend as P

def add_assoc(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}:
  match a:
    case 0n: {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(Nat.add(p, b), c) == 1n+_ : Nat}
      {==}

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def and_true(+a: Bool) -> {a && True{} == a : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def valid_at(capacity: Nat, value: J.Json) -> Bool:
  match capacity value:
    case _ J.JNull{}: True{}
    case _ J.JBool{b}: True{}
    case _ J.JNumber{s}: J.number_valid(s)
    case _ J.JString{s}: J.scalars(s)
    case 0n _: False{}
    case 1n++r J.JArray{Nil{}}: True{}
    case 1n++r J.JArray{h <> t}: valid_at(r, h) && valid_at(1n+r, J.JArray{t})
    case 1n++r J.JObject{Nil{}}: True{}
    case 1n++r J.JObject{J.Field{k, h} <> t}: J.scalars(k) && (valid_at(r, h) && valid_at(1n+r, J.JObject{t}))

def budget(capacity: Nat, value: J.Json) -> Nat:
  match capacity value:
    case _ J.JNull{}: 16n
    case _ J.JBool{b}: 16n
    case _ J.JNumber{s}: 16n
    case _ J.JString{s}: 16n
    case 0n _: 16n
    case 1n++r J.JArray{Nil{}}: 16n
    case 1n++r J.JArray{h <> t}: Nat.add(budget(1n+r, J.JArray{t}), Nat.add(budget(r, h), 16n))
    case 1n++r J.JObject{Nil{}}: 16n
    case 1n++r J.JObject{J.Field{k, h} <> t}: Nat.add(budget(1n+r, J.JObject{t}), Nat.add(budget(r, h), 16n))

def merge_scan(+a: Nat, +b: Nat, +n: Nat, +ok: Bool, +key: Bool, +child: Bool, +tail: Bool) -> {J.Scan{Nat.add(a, Nat.add(b, 16n+n)), ((ok && key) && child) && tail} == J.Scan{Nat.add(Nat.add(a, Nat.add(b, 16n)), n), ok && (key && (child && tail))} : J.Scan}:
  %Equal.sym(Nat, Nat.add(Nat.add(a, Nat.add(b, 16n)), n), Nat.add(a, Nat.add(Nat.add(b, 16n), n)), add_assoc(a, Nat.add(b, 16n), n)) : {J.Scan{Nat.add(a, Nat.add(b, 16n+n)), ((ok && key) && child) && tail} == J.Scan{_, ok && (key && (child && tail))} : J.Scan}
  %Equal.sym(Nat, Nat.add(Nat.add(b, 16n), n), Nat.add(b, 16n+n), add_assoc(b, 16n, n)) : {J.Scan{Nat.add(a, Nat.add(b, 16n+n)), ((ok && key) && child) && tail} == J.Scan{Nat.add(a, _), ok && (key && (child && tail))} : J.Scan}
  %and_assoc(ok, key, child && tail) : {J.Scan{Nat.add(a, Nat.add(b, 16n+n)), ((ok && key) && child) && tail} == J.Scan{Nat.add(a, Nat.add(b, 16n+n)), _} : J.Scan}
  %and_assoc(ok && key, child, tail) : {J.Scan{Nat.add(a, Nat.add(b, 16n+n)), ((ok && key) && child) && tail} == J.Scan{Nat.add(a, Nat.add(b, 16n+n)), _} : J.Scan}
  {==}

def scan_equiv(+capacity: Nat, +value: J.Json, +n: Nat, +ok: Bool) -> {J.scan(capacity, value, J.Scan{n, ok}) == J.Scan{Nat.add(budget(capacity, value), n), ok && valid_at(capacity, value)} : J.Scan}:
  match capacity value:
    case _ J.JNull{}: {==}
    case _ J.JBool{b}: {==}
    case _ J.JNumber{s}: {==}
    case _ J.JString{s}: {==}
    case 0n J.JArray{xs}: {==}
    case 0n J.JObject{xs}: {==}
    case 1n++r J.JArray{Nil{}}: {==}
    case 1n++r J.JObject{Nil{}}: {==}
    case 1n++r J.JArray{h <> t}:
      %Equal.sym(J.Scan, J.scan(r, h, J.Scan{16n+n, ok && True{}}), J.Scan{Nat.add(budget(r, h), 16n+n), (ok && True{}) && valid_at(r, h)}, scan_equiv(r, h, 16n+n, ok && True{})) : {J.scan(1n+r, J.JArray{t}, _) == J.Scan{Nat.add(budget(1n+r, J.JArray{h <> t}), n), ok && valid_at(1n+r, J.JArray{h <> t})} : J.Scan}
      %Equal.sym(J.Scan, J.scan(1n+r, J.JArray{t}, J.Scan{Nat.add(budget(r, h), 16n+n), (ok && True{}) && valid_at(r, h)}), J.Scan{Nat.add(budget(1n+r, J.JArray{t}), Nat.add(budget(r, h), 16n+n)), ((ok && True{}) && valid_at(r, h)) && valid_at(1n+r, J.JArray{t})}, scan_equiv(1n+r, J.JArray{t}, Nat.add(budget(r, h), 16n+n), (ok && True{}) && valid_at(r, h))) : {_ == J.Scan{Nat.add(budget(1n+r, J.JArray{h <> t}), n), ok && valid_at(1n+r, J.JArray{h <> t})} : J.Scan}
      merge_scan(budget(1n+r, J.JArray{t}), budget(r, h), n, ok, True{}, valid_at(r, h), valid_at(1n+r, J.JArray{t}))
    case 1n++r J.JObject{J.Field{k, h} <> t}:
      %Equal.sym(J.Scan, J.scan(r, h, J.Scan{16n+n, ok && J.scalars(k)}), J.Scan{Nat.add(budget(r, h), 16n+n), (ok && J.scalars(k)) && valid_at(r, h)}, scan_equiv(r, h, 16n+n, ok && J.scalars(k))) : {J.scan(1n+r, J.JObject{t}, _) == J.Scan{Nat.add(budget(1n+r, J.JObject{J.Field{k, h} <> t}), n), ok && valid_at(1n+r, J.JObject{J.Field{k, h} <> t})} : J.Scan}
      %Equal.sym(J.Scan, J.scan(1n+r, J.JObject{t}, J.Scan{Nat.add(budget(r, h), 16n+n), (ok && J.scalars(k)) && valid_at(r, h)}), J.Scan{Nat.add(budget(1n+r, J.JObject{t}), Nat.add(budget(r, h), 16n+n)), ((ok && J.scalars(k)) && valid_at(r, h)) && valid_at(1n+r, J.JObject{t})}, scan_equiv(1n+r, J.JObject{t}, Nat.add(budget(r, h), 16n+n), (ok && J.scalars(k)) && valid_at(r, h))) : {_ == J.Scan{Nat.add(budget(1n+r, J.JObject{J.Field{k, h} <> t}), n), ok && valid_at(1n+r, J.JObject{J.Field{k, h} <> t})} : J.Scan}
      merge_scan(budget(1n+r, J.JObject{t}), budget(r, h), n, ok, J.scalars(k), valid_at(r, h), valid_at(1n+r, J.JObject{t}))

def admissible_equiv(+value: J.Json) -> {J.admissible(value) == valid_at(512n, value) : Bool}:
  Equal.cong(J.Scan, Bool, s => J.scan_valid(s), J.scan(512n, value, J.Scan{0n, True{}}), J.Scan{Nat.add(budget(512n, value), 0n), True{} && valid_at(512n, value)}, scan_equiv(512n, value, 0n, True{}))

def add_nil(+a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n: {==}
    case 1n+p:
      %add_nil(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

def add_succ(+a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n: {==}
    case 1n+p:
      %add_succ(p, b) : {1n+Nat.add(p, 1n+b) == 1n+_ : Nat}
      {==}

def add_comm(+a: Nat, +b: Nat) -> {Nat.add(a, b) == Nat.add(b, a) : Nat}:
  match a:
    case 0n: Equal.sym(Nat, Nat.add(b, 0n), b, add_nil(b))
    case 1n+p:
      %Equal.sym(Nat, Nat.add(b, 1n+p), 1n+Nat.add(b, p), add_succ(b, p)) : {1n+Nat.add(p, b) == _ : Nat}
      %add_comm(p, b) : {1n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

def add_swap(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(b, Nat.add(a, c)) : Nat}:
  %add_assoc(b, a, c) : {Nat.add(a, Nat.add(b, c)) == _ : Nat}
  %add_comm(a, b) : {Nat.add(a, Nat.add(b, c)) == Nat.add(_, c) : Nat}
  Equal.sym(Nat, Nat.add(Nat.add(a, b), c), Nat.add(a, Nat.add(b, c)), add_assoc(a, b, c))

# Reserve k transitions and retain x units of slack per container member.
def allocation(+a: Nat, +b: Nat, +sa: Nat, +sb: Nat, +k: Nat, +x: Nat) -> {Nat.add(Nat.add(Nat.add(1n, a), sa), Nat.add(Nat.add(b, sb), Nat.add(k, x))) == Nat.add(Nat.add(Nat.add(1n, k), Nat.add(b, a)), Nat.add(sa, Nat.add(sb, x))) : Nat}:
  %Equal.sym(Nat, Nat.add(Nat.add(Nat.add(1n, a), sa), Nat.add(Nat.add(b, sb), Nat.add(k, x))), Nat.add(Nat.add(1n, a), Nat.add(sa, Nat.add(Nat.add(b, sb), Nat.add(k, x)))), add_assoc(Nat.add(1n, a), sa, Nat.add(Nat.add(b, sb), Nat.add(k, x)))) : {_ == Nat.add(Nat.add(Nat.add(1n, k), Nat.add(b, a)), Nat.add(sa, Nat.add(sb, x))) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(1n, a), Nat.add(sa, Nat.add(Nat.add(b, sb), Nat.add(k, x)))), Nat.add(1n, Nat.add(a, Nat.add(sa, Nat.add(Nat.add(b, sb), Nat.add(k, x))))), add_assoc(1n, a, Nat.add(sa, Nat.add(Nat.add(b, sb), Nat.add(k, x))))) : {_ == Nat.add(Nat.add(Nat.add(1n, k), Nat.add(b, a)), Nat.add(sa, Nat.add(sb, x))) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(b, sb), Nat.add(k, x)), Nat.add(b, Nat.add(sb, Nat.add(k, x))), add_assoc(b, sb, Nat.add(k, x))) : {Nat.add(1n, Nat.add(a, Nat.add(sa, _))) == Nat.add(Nat.add(Nat.add(1n, k), Nat.add(b, a)), Nat.add(sa, Nat.add(sb, x))) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(Nat.add(1n, k), Nat.add(b, a)), Nat.add(sa, Nat.add(sb, x))), Nat.add(Nat.add(1n, k), Nat.add(Nat.add(b, a), Nat.add(sa, Nat.add(sb, x)))), add_assoc(Nat.add(1n, k), Nat.add(b, a), Nat.add(sa, Nat.add(sb, x)))) : {Nat.add(1n, Nat.add(a, Nat.add(sa, Nat.add(b, Nat.add(sb, Nat.add(k, x)))))) == _ : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(1n, k), Nat.add(Nat.add(b, a), Nat.add(sa, Nat.add(sb, x)))), Nat.add(1n, Nat.add(k, Nat.add(Nat.add(b, a), Nat.add(sa, Nat.add(sb, x))))), add_assoc(1n, k, Nat.add(Nat.add(b, a), Nat.add(sa, Nat.add(sb, x))))) : {Nat.add(1n, Nat.add(a, Nat.add(sa, Nat.add(b, Nat.add(sb, Nat.add(k, x)))))) == _ : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(b, a), Nat.add(sa, Nat.add(sb, x))), Nat.add(b, Nat.add(a, Nat.add(sa, Nat.add(sb, x)))), add_assoc(b, a, Nat.add(sa, Nat.add(sb, x)))) : {Nat.add(1n, Nat.add(a, Nat.add(sa, Nat.add(b, Nat.add(sb, Nat.add(k, x)))))) == Nat.add(1n, Nat.add(k, _)) : Nat}
  %Equal.sym(Nat, Nat.add(sb, Nat.add(k, x)), Nat.add(k, Nat.add(sb, x)), add_swap(sb, k, x)) : {Nat.add(1n, Nat.add(a, Nat.add(sa, Nat.add(b, _)))) == Nat.add(1n, Nat.add(k, Nat.add(b, Nat.add(a, Nat.add(sa, Nat.add(sb, x)))))) : Nat}
  %Equal.sym(Nat, Nat.add(b, Nat.add(k, Nat.add(sb, x))), Nat.add(k, Nat.add(b, Nat.add(sb, x))), add_swap(b, k, Nat.add(sb, x))) : {Nat.add(1n, Nat.add(a, Nat.add(sa, _))) == Nat.add(1n, Nat.add(k, Nat.add(b, Nat.add(a, Nat.add(sa, Nat.add(sb, x)))))) : Nat}
  %Equal.sym(Nat, Nat.add(sa, Nat.add(k, Nat.add(b, Nat.add(sb, x)))), Nat.add(k, Nat.add(sa, Nat.add(b, Nat.add(sb, x)))), add_swap(sa, k, Nat.add(b, Nat.add(sb, x)))) : {Nat.add(1n, Nat.add(a, _)) == Nat.add(1n, Nat.add(k, Nat.add(b, Nat.add(a, Nat.add(sa, Nat.add(sb, x)))))) : Nat}
  %Equal.sym(Nat, Nat.add(a, Nat.add(k, Nat.add(sa, Nat.add(b, Nat.add(sb, x))))), Nat.add(k, Nat.add(a, Nat.add(sa, Nat.add(b, Nat.add(sb, x))))), add_swap(a, k, Nat.add(sa, Nat.add(b, Nat.add(sb, x))))) : {Nat.add(1n, _) == Nat.add(1n, Nat.add(k, Nat.add(b, Nat.add(a, Nat.add(sa, Nat.add(sb, x)))))) : Nat}
  %Equal.sym(Nat, Nat.add(sa, Nat.add(b, Nat.add(sb, x))), Nat.add(b, Nat.add(sa, Nat.add(sb, x))), add_swap(sa, b, Nat.add(sb, x))) : {Nat.add(1n, Nat.add(k, Nat.add(a, _))) == Nat.add(1n, Nat.add(k, Nat.add(b, Nat.add(a, Nat.add(sa, Nat.add(sb, x)))))) : Nat}
  %Equal.sym(Nat, Nat.add(a, Nat.add(b, Nat.add(sa, Nat.add(sb, x)))), Nat.add(b, Nat.add(a, Nat.add(sa, Nat.add(sb, x)))), add_swap(a, b, Nat.add(sa, Nat.add(sb, x)))) : {Nat.add(1n, Nat.add(k, _)) == Nat.add(1n, Nat.add(k, Nat.add(b, Nat.add(a, Nat.add(sa, Nat.add(sb, x)))))) : Nat}
  {==}
