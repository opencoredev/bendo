# A proof-only writer specification, with exact transition counts.
import Base
import ../src/data/json.bend as J
import ./json-tree.bend as T
import ./utf8.bend as P

def opening(include: Bool) -> Nat:
  match include:
    case True{}: 1n
    case False{}: 0n

def open_rev(include: Bool, c: Char, rev: String) -> String:
  match include:
    case True{}: SCon{c, rev}
    case False{}: rev

def task_impl(include: Bool, value: J.Json, depth: Nat, first: Bool) -> J.Work:
  match include value:
    case True{} v: J.WValue{v, depth}
    case False{} J.JArray{xs}: J.WArray{xs, depth, first}
    case False{} J.JObject{xs}: J.WObject{xs, depth, first}
    case False{} v: J.WValue{v, depth}

def task(value: J.Json, include: Bool, depth: Nat, first: Bool) -> J.Work:
  task_impl(include, value, depth, first)

def initial(include: Bool, first: Bool) -> Bool:
  match include:
    case True{}: True{}
    case False{}: first

def level(include: Bool, depth: Nat) -> Nat:
  match include:
    case True{}: 1n+depth
    case False{}: depth

def cost(capacity: Nat, value: J.Json, include: Bool) -> Nat:
  match capacity value:
    case _ J.JNull{}: 2n
    case _ J.JBool{b}: 2n
    case _ J.JNumber{s}: 2n
    case _ J.JString{s}: 2n
    case 0n _: 0n
    case 1n++r J.JArray{Nil{}}: Nat.add(opening(include), 2n)
    case 1n++r J.JArray{h <> t}: Nat.add(opening(include), Nat.add(2n+cost(r, h, True{}), cost(1n+r, J.JArray{t}, False{})))
    case 1n++r J.JObject{Nil{}}: Nat.add(opening(include), 2n)
    case 1n++r J.JObject{J.Field{k, h} <> t}: Nat.add(opening(include), Nat.add(4n+cost(r, h, True{}), cost(1n+r, J.JObject{t}, False{})))

def render_acc(capacity: Nat, value: J.Json, +include: Bool, +pretty: Bool, +ascii: Bool, depth: Nat, first: Bool, rev: String) -> String:
  match capacity value:
    case _ J.JNull{}: String.reverse.go("null", rev)
    case _ J.JBool{True{}}: String.reverse.go("true", rev)
    case _ J.JBool{False{}}: String.reverse.go("false", rev)
    case _ J.JNumber{s}: String.reverse.go(s, rev)
    case _ J.JString{s}: String.reverse.go(J.quote(s, ascii), rev)
    case 0n _: rev
    case 1n++r J.JArray{Nil{}}: String.reverse.go(J.close(initial(include, first), pretty, level(include, depth), ']'), open_rev(include, '[', rev))
    case 1n++r J.JArray{h <> t}:
      +d = level(include, depth)
      render_acc(1n+r, J.JArray{t}, False{}, pretty, ascii, d, False{}, render_acc(r, h, True{}, pretty, ascii, d, True{}, String.reverse.go(J.prefix(initial(include, first), pretty, d), open_rev(include, '[', rev))))
    case 1n++r J.JObject{Nil{}}: String.reverse.go(J.close(initial(include, first), pretty, level(include, depth), '}'), open_rev(include, '{', rev))
    case 1n++r J.JObject{J.Field{k, h} <> t}:
      +d = level(include, depth)
      render_acc(1n+r, J.JObject{t}, False{}, pretty, ascii, d, False{}, render_acc(r, h, True{}, pretty, ascii, d, True{}, String.reverse.go(J.colon(pretty), String.reverse.go(J.quote(k, ascii), String.reverse.go(J.prefix(initial(include, first), pretty, d), open_rev(include, '{', rev))))))

def continuation(+capacity: Nat, +value: J.Json, +include: Bool, +pretty: Bool, +ascii: Bool, +depth: Nat, +first: Bool, +rev: String, +rest: List<&2, J.Work>, +fuel: Nat, +valid: {T.valid_at(capacity, value) == True{} : Bool}) -> {J.write_go(Nat.add(cost(capacity, value, include), fuel), task(value, include, depth, first) <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, render_acc(capacity, value, include, pretty, ascii, depth, first, rev)) : Result<&2, &2, J.Error, String>}:
  match capacity value include:
    case _ J.JNull{} True{}: {==}
    case _ J.JNull{} False{}: {==}
    case _ J.JBool{True{}} True{}: {==}
    case _ J.JBool{True{}} False{}: {==}
    case _ J.JBool{False{}} True{}: {==}
    case _ J.JBool{False{}} False{}: {==}
    case _ J.JNumber{s} True{}: {==}
    case _ J.JNumber{s} False{}: {==}
    case _ J.JString{s} True{}: {==}
    case _ J.JString{s} False{}: {==}
    case 0n J.JArray{xs} _: P.absurd({J.write_go(Nat.add(cost(0n, J.JArray{xs}, include), fuel), task(J.JArray{xs}, include, depth, first) <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, render_acc(0n, J.JArray{xs}, include, pretty, ascii, depth, first, rev)) : Result<&2, &2, J.Error, String>}, P.false_true(valid))
    case 0n J.JObject{xs} _: P.absurd({J.write_go(Nat.add(cost(0n, J.JObject{xs}, include), fuel), task(J.JObject{xs}, include, depth, first) <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, render_acc(0n, J.JObject{xs}, include, pretty, ascii, depth, first, rev)) : Result<&2, &2, J.Error, String>}, P.false_true(valid))
    case 1n++r J.JArray{Nil{}} True{}: {==}
    case 1n++r J.JArray{Nil{}} False{}: {==}
    case 1n++r J.JObject{Nil{}} True{}: {==}
    case 1n++r J.JObject{Nil{}} False{}: {==}
    case 1n++r J.JArray{h <> t} True{}:
      +d = {1n+depth : Nat}
      +child_cost = cost(r, h, True{})
      +tail_cost = cost(1n+r, J.JArray{t}, False{})
      +before = String.reverse.go(J.prefix(True{}, pretty, d), SCon{'[', rev})
      +after = render_acc(r, h, True{}, pretty, ascii, d, True{}, before)
      +final = render_acc(1n+r, J.JArray{t}, False{}, pretty, ascii, d, False{}, after)
      %Equal.sym(Nat, Nat.add(Nat.add(child_cost, tail_cost), fuel), Nat.add(child_cost, Nat.add(tail_cost, fuel)), T.add_assoc(child_cost, tail_cost, fuel)) : {J.write_go(3n+_, task(J.JArray{h <> t}, True{}, depth, first) <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, final) : Result<&2, &2, J.Error, String>}
      Equal.trans(Result<&2, &2, J.Error, String>, J.write_go(Nat.add(child_cost, Nat.add(tail_cost, fuel)), task(h, True{}, d, True{}) <> task(J.JArray{t}, False{}, d, False{}) <> rest, pretty, ascii, before), J.write_go(Nat.add(tail_cost, fuel), task(J.JArray{t}, False{}, d, False{}) <> rest, pretty, ascii, after), J.write_go(fuel, rest, pretty, ascii, final), continuation(r, h, True{}, pretty, ascii, d, True{}, before, task(J.JArray{t}, False{}, d, False{}) <> rest, Nat.add(tail_cost, fuel), P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), valid)), continuation(1n+r, J.JArray{t}, False{}, pretty, ascii, d, False{}, after, rest, fuel, P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), valid)))
    case 1n++r J.JArray{h <> t} False{}:
      +d = depth
      +child_cost = cost(r, h, True{})
      +tail_cost = cost(1n+r, J.JArray{t}, False{})
      +before = String.reverse.go(J.prefix(first, pretty, d), rev)
      +after = render_acc(r, h, True{}, pretty, ascii, d, True{}, before)
      +final = render_acc(1n+r, J.JArray{t}, False{}, pretty, ascii, d, False{}, after)
      %Equal.sym(Nat, Nat.add(Nat.add(child_cost, tail_cost), fuel), Nat.add(child_cost, Nat.add(tail_cost, fuel)), T.add_assoc(child_cost, tail_cost, fuel)) : {J.write_go(2n+_, task(J.JArray{h <> t}, False{}, depth, first) <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, final) : Result<&2, &2, J.Error, String>}
      Equal.trans(Result<&2, &2, J.Error, String>, J.write_go(Nat.add(child_cost, Nat.add(tail_cost, fuel)), task(h, True{}, d, True{}) <> task(J.JArray{t}, False{}, d, False{}) <> rest, pretty, ascii, before), J.write_go(Nat.add(tail_cost, fuel), task(J.JArray{t}, False{}, d, False{}) <> rest, pretty, ascii, after), J.write_go(fuel, rest, pretty, ascii, final), continuation(r, h, True{}, pretty, ascii, d, True{}, before, task(J.JArray{t}, False{}, d, False{}) <> rest, Nat.add(tail_cost, fuel), P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), valid)), continuation(1n+r, J.JArray{t}, False{}, pretty, ascii, d, False{}, after, rest, fuel, P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), valid)))
    case 1n++r J.JObject{J.Field{k, h} <> t} True{}:
      +d = {1n+depth : Nat}
      +child_cost = cost(r, h, True{})
      +tail_cost = cost(1n+r, J.JObject{t}, False{})
      +before = String.reverse.go(J.colon(pretty), String.reverse.go(J.quote(k, ascii), String.reverse.go(J.prefix(True{}, pretty, d), SCon{'{', rev})))
      +after = render_acc(r, h, True{}, pretty, ascii, d, True{}, before)
      +final = render_acc(1n+r, J.JObject{t}, False{}, pretty, ascii, d, False{}, after)
      %Equal.sym(Nat, Nat.add(Nat.add(child_cost, tail_cost), fuel), Nat.add(child_cost, Nat.add(tail_cost, fuel)), T.add_assoc(child_cost, tail_cost, fuel)) : {J.write_go(5n+_, task(J.JObject{J.Field{k, h} <> t}, True{}, depth, first) <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, final) : Result<&2, &2, J.Error, String>}
      Equal.trans(Result<&2, &2, J.Error, String>, J.write_go(Nat.add(child_cost, Nat.add(tail_cost, fuel)), task(h, True{}, d, True{}) <> task(J.JObject{t}, False{}, d, False{}) <> rest, pretty, ascii, before), J.write_go(Nat.add(tail_cost, fuel), task(J.JObject{t}, False{}, d, False{}) <> rest, pretty, ascii, after), J.write_go(fuel, rest, pretty, ascii, final), continuation(r, h, True{}, pretty, ascii, d, True{}, before, task(J.JObject{t}, False{}, d, False{}) <> rest, Nat.add(tail_cost, fuel), P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{t}), P.and_right(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), valid))), continuation(1n+r, J.JObject{t}, False{}, pretty, ascii, d, False{}, after, rest, fuel, P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{t}), P.and_right(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), valid))))
    case 1n++r J.JObject{J.Field{k, h} <> t} False{}:
      +d = depth
      +child_cost = cost(r, h, True{})
      +tail_cost = cost(1n+r, J.JObject{t}, False{})
      +before = String.reverse.go(J.colon(pretty), String.reverse.go(J.quote(k, ascii), String.reverse.go(J.prefix(first, pretty, d), rev)))
      +after = render_acc(r, h, True{}, pretty, ascii, d, True{}, before)
      +final = render_acc(1n+r, J.JObject{t}, False{}, pretty, ascii, d, False{}, after)
      %Equal.sym(Nat, Nat.add(Nat.add(child_cost, tail_cost), fuel), Nat.add(child_cost, Nat.add(tail_cost, fuel)), T.add_assoc(child_cost, tail_cost, fuel)) : {J.write_go(4n+_, task(J.JObject{J.Field{k, h} <> t}, False{}, depth, first) <> rest, pretty, ascii, rev) == J.write_go(fuel, rest, pretty, ascii, final) : Result<&2, &2, J.Error, String>}
      Equal.trans(Result<&2, &2, J.Error, String>, J.write_go(Nat.add(child_cost, Nat.add(tail_cost, fuel)), task(h, True{}, d, True{}) <> task(J.JObject{t}, False{}, d, False{}) <> rest, pretty, ascii, before), J.write_go(Nat.add(tail_cost, fuel), task(J.JObject{t}, False{}, d, False{}) <> rest, pretty, ascii, after), J.write_go(fuel, rest, pretty, ascii, final), continuation(r, h, True{}, pretty, ascii, d, True{}, before, task(J.JObject{t}, False{}, d, False{}) <> rest, Nat.add(tail_cost, fuel), P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{t}), P.and_right(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), valid))), continuation(1n+r, J.JObject{t}, False{}, pretty, ascii, d, False{}, after, rest, fuel, P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{t}), P.and_right(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), valid))))

def surplus(capacity: Nat, value: J.Json) -> Nat:
  match capacity value:
    case _ J.JNull{}: 14n
    case _ J.JBool{b}: 14n
    case _ J.JNumber{s}: 14n
    case _ J.JString{s}: 14n
    case 0n _: 16n
    case 1n++r J.JArray{Nil{}}: 13n
    case 1n++r J.JArray{h <> t}: Nat.add(surplus(1n+r, J.JArray{t}), Nat.add(surplus(r, h), 14n))
    case 1n++r J.JObject{Nil{}}: 13n
    case 1n++r J.JObject{J.Field{k, h} <> t}: Nat.add(surplus(1n+r, J.JObject{t}), Nat.add(surplus(r, h), 12n))

def array_cost(+r: Nat, +xs: List<&2, J.Json>) -> {cost(1n+r, J.JArray{xs}, True{}) == 1n+cost(1n+r, J.JArray{xs}, False{}) : Nat}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def object_cost(+r: Nat, +xs: List<&2, J.Field>) -> {cost(1n+r, J.JObject{xs}, True{}) == 1n+cost(1n+r, J.JObject{xs}, False{}) : Nat}:
  match xs:
    case Nil{}: {==}
    case J.Field{k, h} <> t: {==}

def budget_split(+capacity: Nat, +value: J.Json) -> {T.budget(capacity, value) == Nat.add(cost(capacity, value, True{}), surplus(capacity, value)) : Nat}:
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
      +a = cost(1n+r, J.JArray{t}, False{})
      +b = cost(r, h, True{})
      +sa = surplus(1n+r, J.JArray{t})
      +sb = surplus(r, h)
      %Equal.sym(Nat, T.budget(1n+r, J.JArray{t}), Nat.add(cost(1n+r, J.JArray{t}, True{}), sa), budget_split(1n+r, J.JArray{t})) : {Nat.add(_, Nat.add(T.budget(r, h), 16n)) == Nat.add(cost(1n+r, J.JArray{h <> t}, True{}), surplus(1n+r, J.JArray{h <> t})) : Nat}
      %Equal.sym(Nat, T.budget(r, h), Nat.add(b, sb), budget_split(r, h)) : {Nat.add(Nat.add(cost(1n+r, J.JArray{t}, True{}), sa), Nat.add(_, 16n)) == Nat.add(cost(1n+r, J.JArray{h <> t}, True{}), surplus(1n+r, J.JArray{h <> t})) : Nat}
      %Equal.sym(Nat, cost(1n+r, J.JArray{t}, True{}), 1n+a, array_cost(r, t)) : {Nat.add(Nat.add(_, sa), Nat.add(Nat.add(b, sb), 16n)) == Nat.add(cost(1n+r, J.JArray{h <> t}, True{}), surplus(1n+r, J.JArray{h <> t})) : Nat}
      T.allocation(a, b, sa, sb, 2n, 14n)
    case 1n++r J.JObject{J.Field{k, h} <> t}:
      +a = cost(1n+r, J.JObject{t}, False{})
      +b = cost(r, h, True{})
      +sa = surplus(1n+r, J.JObject{t})
      +sb = surplus(r, h)
      %Equal.sym(Nat, T.budget(1n+r, J.JObject{t}), Nat.add(cost(1n+r, J.JObject{t}, True{}), sa), budget_split(1n+r, J.JObject{t})) : {Nat.add(_, Nat.add(T.budget(r, h), 16n)) == Nat.add(cost(1n+r, J.JObject{J.Field{k, h} <> t}, True{}), surplus(1n+r, J.JObject{J.Field{k, h} <> t})) : Nat}
      %Equal.sym(Nat, T.budget(r, h), Nat.add(b, sb), budget_split(r, h)) : {Nat.add(Nat.add(cost(1n+r, J.JObject{t}, True{}), sa), Nat.add(_, 16n)) == Nat.add(cost(1n+r, J.JObject{J.Field{k, h} <> t}, True{}), surplus(1n+r, J.JObject{J.Field{k, h} <> t})) : Nat}
      %Equal.sym(Nat, cost(1n+r, J.JObject{t}, True{}), 1n+a, object_cost(r, t)) : {Nat.add(Nat.add(_, sa), Nat.add(Nat.add(b, sb), 16n)) == Nat.add(cost(1n+r, J.JObject{J.Field{k, h} <> t}, True{}), surplus(1n+r, J.JObject{J.Field{k, h} <> t})) : Nat}
      T.allocation(a, b, sa, sb, 4n, 12n)

def write_empty(+fuel: Nat, +pretty: Bool, +ascii: Bool, +rev: String) -> {J.write_go(fuel, [], pretty, ascii, rev) == Done{String.reverse(rev)} : Result<&2, &2, J.Error, String>}:
  match fuel:
    case 0n: {==}
    case 1n+f: {==}

# The public writer succeeds on every admissible tree, for both options.
def write_output(+value: J.Json, +pretty: Bool, +ascii: Bool, +valid: {J.admissible(value) == True{} : Bool}) -> {J.write(value, pretty, ascii) == Done{String.reverse(render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, ""))} : Result<&2, &2, J.Error, String>}:
  +output = String.reverse(render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, ""))
  +tree_valid = Equal.trans(Bool, T.valid_at(512n, value), J.admissible(value), True{}, Equal.sym(Bool, J.admissible(value), T.valid_at(512n, value), T.admissible_equiv(value)), valid)
  (
    %Equal.sym(J.Scan, J.scan(512n, value, J.Scan{0n, True{}}), J.Scan{Nat.add(T.budget(512n, value), 0n), T.valid_at(512n, value)}, T.scan_equiv(512n, value, 0n, True{})) : {J.write_checked(value, pretty, ascii, _) == Done{output} : Result<&2, &2, J.Error, String>}
    %Equal.sym(Bool, T.valid_at(512n, value), True{}, tree_valid) : {J.write_checked(value, pretty, ascii, J.Scan{Nat.add(T.budget(512n, value), 0n), _}) == Done{output} : Result<&2, &2, J.Error, String>}
    %Equal.sym(Nat, Nat.add(T.budget(512n, value), 0n), T.budget(512n, value), T.add_nil(T.budget(512n, value))) : {J.write_go(_, [J.WValue{value, 0n}], pretty, ascii, "") == Done{output} : Result<&2, &2, J.Error, String>}
    %Equal.sym(Nat, T.budget(512n, value), Nat.add(cost(512n, value, True{}), surplus(512n, value)), budget_split(512n, value)) : {J.write_go(_, [J.WValue{value, 0n}], pretty, ascii, "") == Done{output} : Result<&2, &2, J.Error, String>}
    Equal.trans(Result<&2, &2, J.Error, String>, J.write_go(Nat.add(cost(512n, value, True{}), surplus(512n, value)), [J.WValue{value, 0n}], pretty, ascii, ""), J.write_go(surplus(512n, value), [], pretty, ascii, render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, "")), Done{output}, continuation(512n, value, True{}, pretty, ascii, 0n, True{}, "", [], surplus(512n, value), tree_valid), write_empty(surplus(512n, value), pretty, ascii, render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, ""))))

def write_success(+value: J.Json, +pretty: Bool, +ascii: Bool, +valid: {J.admissible(value) == True{} : Bool}) -> &output: String -> {J.write(value, pretty, ascii) == Done{output} : Result<&2, &2, J.Error, String>}:
  (String.reverse(render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, "")), write_output(value, pretty, ascii, valid))
