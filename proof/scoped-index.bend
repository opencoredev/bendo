# BND-82: selection through the scoped-hook index equals selection over the
# whole layer list, for every list, route and stage. The trie lemma is stated
# over abstract keys and depths, so slot_key's arithmetic is never computed:
# the only fact about keys used is that equal identities give equal keys.
import Base
import ../src/app/table.bend as T
import ../src/app/validate.bend as V
import ../src/router/pattern.bend as P
import ../src/router/methods.bend as M
import ./scoped-index-laws.bend as Laws
import ./scoped-selection.bend as Sel
import ./scoped-selection-spec.bend as S

def true_type(b: Bool) -> Type:
  match b:
    case True{}: Unit
    case False{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, e) : true_type(_)
  Unit{}

def true_false(e: {True{} == False{} : Bool}) -> Empty:
  false_true(Equal.sym(Bool, True{}, False{}, e))

def absurd(-A: Type, impossible: Empty) -> A:
  match impossible:

def append_nil(-A: Data, xs: List<&2, A>) -> {List.append(&2, A, xs, []) == xs : List<&2, A>}:
  match xs:
    case Nil{}: {==}
    case h <> t: Equal.cong(List<&2, A>, List<&2, A>, ys => h <> ys, List.append(&2, A, t, []), t, append_nil(A, t))

def nat_eq_sound(i: Nat, n: Nat, e: {Nat.is_eq(i, n) == True{} : Bool}) -> {i == n : Nat}:
  match i n:
    case 0n 0n: {==}
    case 0n 1n+b: absurd({0n == 1n+b : Nat}, false_true(e))
    case 1n+a 0n: absurd({1n+a == 0n : Nat}, false_true(e))
    case 1n+a 1n+b: Equal.cong(Nat, Nat, x => 1n+x, a, b, nat_eq_sound(a, b, e))

# Whether two keys share a trie path of depth d, bit by bit.
def agree(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}: True{}
    case False{} False{}: True{}
    case True{} False{}: False{}
    case False{} True{}: False{}

def same(d: Nat, +k: U32, +k2: U32) -> Bool:
  match d:
    case 0n: True{}
    case 1n+(+p): agree(T.slot_bit(k), T.slot_bit(k2)) && same(p, T.slot_rest(k), T.slot_rest(k2))

def pre(-Tag: Data, layer: T.Middleware<Tag>, c: Bool, xs: List<&2, T.Middleware<Tag>>) -> List<&2, T.Middleware<Tag>>:
  match c:
    case True{}: layer <> xs
    case False{}: xs

def same_bits(p: Nat, +k: U32, b: Bool, ih: {same(p, T.slot_rest(k), T.slot_rest(k)) == True{} : Bool}) -> {agree(b, b) && same(p, T.slot_rest(k), T.slot_rest(k)) == True{} : Bool}:
  match b:
    case True{}: ih
    case False{}: ih

def same_refl(d: Nat, +k: U32) -> {same(d, k, k) == True{} : Bool}:
  match d:
    case 0n: {==}
    case 1n+(+p): same_bits(p, k, T.slot_bit(k), same_refl(p, T.slot_rest(k)))

def same_of_eq(d: Nat, i: Nat, n: Nat, eq: {i == n : Nat}) -> {same(d, T.slot_key(i), T.slot_key(n)) == True{} : Bool}:
  %eq : {same(d, T.slot_key(i), T.slot_key(_)) == True{} : Bool}
  same_refl(d, T.slot_key(i))

# Two layers with equal identities never land in different buckets.
def apart(-A: Type, d: Nat, +i: Nat, +n: Nat, hit: {Nat.is_eq(i, n) == True{} : Bool}, miss: {same(d, T.slot_key(i), T.slot_key(n)) == False{} : Bool}) -> A:
  absurd(A, true_false(Equal.trans(Bool, True{}, same(d, T.slot_key(i), T.slot_key(n)), False{}, Equal.sym(Bool, same(d, T.slot_key(i), T.slot_key(n)), True{}, same_of_eq(d, i, n, nat_eq_sound(i, n, hit))), miss)))

def find_vacant(-Tag: Data, d: Nat, k: U32) -> {T.trie_find(Tag, d, T.HookVacant{}, k) == [] : List<&2, T.Middleware<Tag>>}:
  match d:
    case 0n: {==}
    case 1n+(+p): {==}

# The trie lemma, for a fork: each bit of the two keys either follows the
# filed layer's branch or leaves the other branch untouched.
def fork_true(-Tag: Data, p: Nat, z: T.HookTrie<Tag>, o: T.HookTrie<Tag>, +k: U32, +k2: U32, layer: T.Middleware<Tag>, b2: Bool, ih: {T.trie_find(Tag, p, T.trie_put(Tag, p, o, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, o, T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}) -> {T.trie_find(Tag, p, T.trie_pick(Tag, b2, z, T.trie_put(Tag, p, o, T.slot_rest(k), layer)), T.slot_rest(k2)) == pre(Tag, layer, agree(True{}, b2) && same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, T.trie_pick(Tag, b2, z, o), T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}:
  match b2:
    case True{}: ih
    case False{}: {==}

def fork_false(-Tag: Data, p: Nat, z: T.HookTrie<Tag>, o: T.HookTrie<Tag>, +k: U32, +k2: U32, layer: T.Middleware<Tag>, b2: Bool, ih: {T.trie_find(Tag, p, T.trie_put(Tag, p, z, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, z, T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}) -> {T.trie_find(Tag, p, T.trie_pick(Tag, b2, T.trie_put(Tag, p, z, T.slot_rest(k), layer), o), T.slot_rest(k2)) == pre(Tag, layer, agree(False{}, b2) && same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, T.trie_pick(Tag, b2, z, o), T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}:
  match b2:
    case True{}: {==}
    case False{}: ih

def fork_step(-Tag: Data, p: Nat, +z: T.HookTrie<Tag>, +o: T.HookTrie<Tag>, +k: U32, +k2: U32, +layer: T.Middleware<Tag>, b: Bool, ih_z: {T.trie_find(Tag, p, T.trie_put(Tag, p, z, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, z, T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}, ih_o: {T.trie_find(Tag, p, T.trie_put(Tag, p, o, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, o, T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}) -> {T.trie_find(Tag, 1n+p, T.trie_graft(Tag, b, z, o, T.trie_put(Tag, p, T.trie_pick(Tag, b, z, o), T.slot_rest(k), layer)), k2) == pre(Tag, layer, agree(b, T.slot_bit(k2)) && same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, T.trie_pick(Tag, T.slot_bit(k2), z, o), T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}:
  match b:
    case True{}: fork_true(Tag, p, z, o, k, k2, layer, T.slot_bit(k2), ih_o)
    case False{}: fork_false(Tag, p, z, o, k, k2, layer, T.slot_bit(k2), ih_z)

# The trie lemma below a vacant or misplaced node: a new path of forks.
def vacant_hit(-Tag: Data, p: Nat, +k: U32, +k2: U32, +layer: T.Middleware<Tag>, ih: {T.trie_find(Tag, p, T.trie_put(Tag, p, T.HookVacant{}, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, T.HookVacant{}, T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}) -> {T.trie_find(Tag, p, T.trie_put(Tag, p, T.HookVacant{}, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), []) : List<&2, T.Middleware<Tag>>}:
  %find_vacant(Tag, p, T.slot_rest(k2)) : {T.trie_find(Tag, p, T.trie_put(Tag, p, T.HookVacant{}, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), _) : List<&2, T.Middleware<Tag>>}
  ih

def vacant_true(-Tag: Data, p: Nat, +k: U32, +k2: U32, +layer: T.Middleware<Tag>, b2: Bool, ih: {T.trie_find(Tag, p, T.trie_put(Tag, p, T.HookVacant{}, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, T.HookVacant{}, T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}) -> {T.trie_find(Tag, p, T.trie_pick(Tag, b2, T.HookVacant{}, T.trie_put(Tag, p, T.HookVacant{}, T.slot_rest(k), layer)), T.slot_rest(k2)) == pre(Tag, layer, agree(True{}, b2) && same(p, T.slot_rest(k), T.slot_rest(k2)), []) : List<&2, T.Middleware<Tag>>}:
  match b2:
    case True{}: vacant_hit(Tag, p, k, k2, layer, ih)
    case False{}: find_vacant(Tag, p, T.slot_rest(k2))

def vacant_false(-Tag: Data, p: Nat, +k: U32, +k2: U32, +layer: T.Middleware<Tag>, b2: Bool, ih: {T.trie_find(Tag, p, T.trie_put(Tag, p, T.HookVacant{}, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, T.HookVacant{}, T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}) -> {T.trie_find(Tag, p, T.trie_pick(Tag, b2, T.trie_put(Tag, p, T.HookVacant{}, T.slot_rest(k), layer), T.HookVacant{}), T.slot_rest(k2)) == pre(Tag, layer, agree(False{}, b2) && same(p, T.slot_rest(k), T.slot_rest(k2)), []) : List<&2, T.Middleware<Tag>>}:
  match b2:
    case True{}: find_vacant(Tag, p, T.slot_rest(k2))
    case False{}: vacant_hit(Tag, p, k, k2, layer, ih)

def vacant_step(-Tag: Data, p: Nat, +k: U32, +k2: U32, +layer: T.Middleware<Tag>, b: Bool, ih: {T.trie_find(Tag, p, T.trie_put(Tag, p, T.HookVacant{}, T.slot_rest(k), layer), T.slot_rest(k2)) == pre(Tag, layer, same(p, T.slot_rest(k), T.slot_rest(k2)), T.trie_find(Tag, p, T.HookVacant{}, T.slot_rest(k2))) : List<&2, T.Middleware<Tag>>}) -> {T.trie_find(Tag, 1n+p, T.trie_graft(Tag, b, T.HookVacant{}, T.HookVacant{}, T.trie_put(Tag, p, T.trie_pick(Tag, b, T.HookVacant{}, T.HookVacant{}), T.slot_rest(k), layer)), k2) == pre(Tag, layer, agree(b, T.slot_bit(k2)) && same(p, T.slot_rest(k), T.slot_rest(k2)), []) : List<&2, T.Middleware<Tag>>}:
  match b:
    case True{}: vacant_true(Tag, p, k, k2, layer, T.slot_bit(k2), ih)
    case False{}: vacant_false(Tag, p, k, k2, layer, T.slot_bit(k2), ih)

# Filing a layer under key k puts it at the front of exactly the lookups that
# share k's path.
def put_find(-Tag: Data, d: Nat, +t: T.HookTrie<Tag>, +k: U32, +k2: U32, +layer: T.Middleware<Tag>) -> {T.trie_find(Tag, d, T.trie_put(Tag, d, t, k, layer), k2) == pre(Tag, layer, same(d, k, k2), T.trie_find(Tag, d, t, k2)) : List<&2, T.Middleware<Tag>>}:
  match d:
    case 0n: {==}
    case 1n+(+p):
      match t:
        case T.HookFork{+z, +o}: fork_step(Tag, p, z, o, k, k2, layer, T.slot_bit(k), put_find(Tag, p, z, T.slot_rest(k), T.slot_rest(k2), layer), put_find(Tag, p, o, T.slot_rest(k), T.slot_rest(k2), layer))
        case T.HookVacant{}: vacant_step(Tag, p, k, k2, layer, T.slot_bit(k), put_find(Tag, p, T.HookVacant{}, T.slot_rest(k), T.slot_rest(k2), layer))
        case T.HookBucket{xs}: vacant_step(Tag, p, k, k2, layer, T.slot_bit(k), put_find(Tag, p, T.HookVacant{}, T.slot_rest(k), T.slot_rest(k2), layer))

# The bucket a lookup reads: every Scoped layer whose key shares the path of
# key n, in layer order.
def keep(-Tag: Data, +d: Nat, layers: List<&2, T.Middleware<Tag>>, +n: Nat) -> List<&2, T.Middleware<Tag>>:
  match layers:
    case Nil{}: []
    case T.Scoped{+i, hooks} <> tail: pre(Tag, T.Scoped{i, hooks}, same(d, T.slot_key(i), T.slot_key(n)), keep(Tag, d, tail, n))
    case T.Staged{stage, tag} <> tail: keep(Tag, d, tail, n)
    case T.Middleware{pattern, tag} <> tail: keep(Tag, d, tail, n)

def find_keep(-Tag: Data, +d: Nat, +layers: List<&2, T.Middleware<Tag>>, +n: Nat) -> {T.trie_find(Tag, d, T.scoped_trie(Tag, d, layers), T.slot_key(n)) == keep(Tag, d, layers, n) : List<&2, T.Middleware<Tag>>}:
  match layers:
    case Nil{}: find_vacant(Tag, d, T.slot_key(n))
    case T.Scoped{+i, +hooks} <> +tail:
      Equal.trans(List<&2, T.Middleware<Tag>>, T.trie_find(Tag, d, T.trie_put(Tag, d, T.scoped_trie(Tag, d, tail), T.slot_key(i), T.Scoped{i, hooks}), T.slot_key(n)), pre(Tag, T.Scoped{i, hooks}, same(d, T.slot_key(i), T.slot_key(n)), T.trie_find(Tag, d, T.scoped_trie(Tag, d, tail), T.slot_key(n))), keep(Tag, d, T.Scoped{i, hooks} <> tail, n),
        put_find(Tag, d, T.scoped_trie(Tag, d, tail), T.slot_key(i), T.slot_key(n), T.Scoped{i, hooks}),
        Equal.cong(List<&2, T.Middleware<Tag>>, List<&2, T.Middleware<Tag>>, xs => pre(Tag, T.Scoped{i, hooks}, same(d, T.slot_key(i), T.slot_key(n)), xs), T.trie_find(Tag, d, T.scoped_trie(Tag, d, tail), T.slot_key(n)), keep(Tag, d, tail, n), find_keep(Tag, d, tail, n)))
    case T.Staged{stage, tag} <> tail: find_keep(Tag, d, tail, n)
    case T.Middleware{pattern, tag} <> tail: find_keep(Tag, d, tail, n)

def with_bucket_append(-Tag: Data, bucket: List<&2, T.Middleware<Tag>>, +globals: List<&2, T.Middleware<Tag>>) -> {T.with_bucket(Tag, bucket, globals) == List.append(&2, T.Middleware<Tag>, globals, bucket) : List<&2, T.Middleware<Tag>>}:
  match bucket:
    case Nil{}: Equal.sym(List<&2, T.Middleware<Tag>>, List.append(&2, T.Middleware<Tag>, globals, []), globals, append_nil(T.Middleware<Tag>, globals))
    case h <> t: {==}

# What a routed lookup returns: the globals, then the route's bucket.
def relevant_some(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +n: Nat) -> {T.relevant(Tag, T.index(Tag, layers), Some{n}) == List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)) : List<&2, T.Middleware<Tag>>}:
  Equal.trans(List<&2, T.Middleware<Tag>>, T.with_bucket(Tag, T.trie_find(Tag, T.slot_depth(), T.scoped_trie(Tag, T.slot_depth(), layers), T.slot_key(n)), T.global_layers(Tag, layers)), List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), T.trie_find(Tag, T.slot_depth(), T.scoped_trie(Tag, T.slot_depth(), layers), T.slot_key(n))), List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)),
    with_bucket_append(Tag, T.trie_find(Tag, T.slot_depth(), T.scoped_trie(Tag, T.slot_depth(), layers), T.slot_key(n)), T.global_layers(Tag, layers)),
    Equal.cong(List<&2, T.Middleware<Tag>>, List<&2, T.Middleware<Tag>>, xs => List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), xs), T.trie_find(Tag, T.slot_depth(), T.scoped_trie(Tag, T.slot_depth(), layers), T.slot_key(n)), keep(Tag, T.slot_depth(), layers, n), find_keep(Tag, T.slot_depth(), layers, n)))

# Global stage filters and path selection ignore Scoped layers.
def stage_globals(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +stage: T.Stage) -> {T.stage_ids(Tag, T.global_layers(Tag, layers), stage) == T.stage_ids(Tag, layers, stage) : List<&2, Tag>}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{i, hooks} <> tail: stage_globals(Tag, tail, stage)
    case T.Staged{+kind, +tag} <> tail:
      Equal.cong(List<&2, Tag>, List<&2, Tag>, xs => T.include(Tag, tag, xs, U32.is_eq(T.stage_number(kind), T.stage_number(stage))), T.stage_ids(Tag, T.global_layers(Tag, tail), stage), T.stage_ids(Tag, tail, stage), stage_globals(Tag, tail, stage))
    case T.Middleware{pattern, tag} <> tail: stage_globals(Tag, tail, stage)

def selected_globals(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +path: String) -> {T.selected(Tag, T.global_layers(Tag, layers), path) == T.selected(Tag, layers, path) : List<&2, Tag>}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{i, hooks} <> tail: selected_globals(Tag, tail, path)
    case T.Staged{kind, tag} <> tail: selected_globals(Tag, tail, path)
    case T.Middleware{None{}, +tag} <> tail:
      Equal.cong(List<&2, Tag>, List<&2, Tag>, xs => tag <> xs, T.selected(Tag, T.global_layers(Tag, tail), path), T.selected(Tag, tail, path), selected_globals(Tag, tail, path))
    case T.Middleware{Some{+p}, +tag} <> tail:
      Equal.cong(List<&2, Tag>, List<&2, Tag>, xs => T.include(Tag, tag, xs, Maybe.is_some(&2, P.Params, P.match_path(p, path))), T.selected(Tag, T.global_layers(Tag, tail), path), T.selected(Tag, tail, path), selected_globals(Tag, tail, path))

# Without a route no Scoped layer selects anything.
def route_none(-Tag: Data, layers: List<&2, T.Middleware<Tag>>, +stage: T.Stage) -> {T.route_stage_ids(Tag, layers, None{}, stage) == [] : List<&2, Tag>}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{i, hooks} <> tail: route_none(Tag, tail, stage)
    case T.Staged{kind, tag} <> tail: route_none(Tag, tail, stage)
    case T.Middleware{pattern, tag} <> tail: route_none(Tag, tail, stage)

def schemas_none(-Tag: Data, layers: List<&2, T.Middleware<Tag>>) -> {T.route_schemas(Tag, layers, None{}) == V.none() : V.Schemas}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{i, hooks} <> tail: {==}
    case T.Staged{kind, tag} <> tail: schemas_none(Tag, tail)
    case T.Middleware{pattern, tag} <> tail: schemas_none(Tag, tail)

# Route selection ignores the global layers in front of a bucket.
def route_skip(-Tag: Data, layers: List<&2, T.Middleware<Tag>>, +rest: List<&2, T.Middleware<Tag>>, +n: Nat, +stage: T.Stage) -> {T.route_stage_ids(Tag, List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), rest), Some{n}, stage) == T.route_stage_ids(Tag, rest, Some{n}, stage) : List<&2, Tag>}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{i, hooks} <> tail: route_skip(Tag, tail, rest, n, stage)
    case T.Staged{kind, tag} <> tail: route_skip(Tag, tail, rest, n, stage)
    case T.Middleware{pattern, tag} <> tail: route_skip(Tag, tail, rest, n, stage)

def schemas_skip(-Tag: Data, layers: List<&2, T.Middleware<Tag>>, +rest: List<&2, T.Middleware<Tag>>, +n: Nat) -> {T.route_schemas(Tag, List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), rest), Some{n}) == T.route_schemas(Tag, rest, Some{n}) : V.Schemas}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{i, hooks} <> tail: schemas_skip(Tag, tail, rest, n)
    case T.Staged{kind, tag} <> tail: schemas_skip(Tag, tail, rest, n)
    case T.Middleware{pattern, tag} <> tail: schemas_skip(Tag, tail, rest, n)

# A bucket holds only Scoped layers, so global selection behind it is empty.
def stage_pre(-Tag: Data, +i: Nat, +hooks: List<&2, T.Placement<Tag>>, c: Bool, +xs: List<&2, T.Middleware<Tag>>, +stage: T.Stage, ih: {T.stage_ids(Tag, xs, stage) == [] : List<&2, Tag>}) -> {T.stage_ids(Tag, pre(Tag, T.Scoped{i, hooks}, c, xs), stage) == [] : List<&2, Tag>}:
  match c:
    case True{}: ih
    case False{}: ih

def stage_keep(-Tag: Data, +d: Nat, layers: List<&2, T.Middleware<Tag>>, +n: Nat, +stage: T.Stage) -> {T.stage_ids(Tag, keep(Tag, d, layers, n), stage) == [] : List<&2, Tag>}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{+i, +hooks} <> +tail: stage_pre(Tag, i, hooks, same(d, T.slot_key(i), T.slot_key(n)), keep(Tag, d, tail, n), stage, stage_keep(Tag, d, tail, n, stage))
    case T.Staged{kind, tag} <> tail: stage_keep(Tag, d, tail, n, stage)
    case T.Middleware{pattern, tag} <> tail: stage_keep(Tag, d, tail, n, stage)

def selected_pre(-Tag: Data, +i: Nat, +hooks: List<&2, T.Placement<Tag>>, c: Bool, +xs: List<&2, T.Middleware<Tag>>, +path: String, ih: {T.selected(Tag, xs, path) == [] : List<&2, Tag>}) -> {T.selected(Tag, pre(Tag, T.Scoped{i, hooks}, c, xs), path) == [] : List<&2, Tag>}:
  match c:
    case True{}: ih
    case False{}: ih

def selected_keep(-Tag: Data, +d: Nat, layers: List<&2, T.Middleware<Tag>>, +n: Nat, +path: String) -> {T.selected(Tag, keep(Tag, d, layers, n), path) == [] : List<&2, Tag>}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{+i, +hooks} <> +tail: selected_pre(Tag, i, hooks, same(d, T.slot_key(i), T.slot_key(n)), keep(Tag, d, tail, n), path, selected_keep(Tag, d, tail, n, path))
    case T.Staged{kind, tag} <> tail: selected_keep(Tag, d, tail, n, path)
    case T.Middleware{pattern, tag} <> tail: selected_keep(Tag, d, tail, n, path)

def stage_bucket(-Tag: Data, xs: List<&2, T.Middleware<Tag>>, +d: Nat, +layers: List<&2, T.Middleware<Tag>>, +n: Nat, +stage: T.Stage) -> {T.stage_ids(Tag, List.append(&2, T.Middleware<Tag>, xs, keep(Tag, d, layers, n)), stage) == T.stage_ids(Tag, xs, stage) : List<&2, Tag>}:
  match xs:
    case Nil{}: stage_keep(Tag, d, layers, n, stage)
    case T.Scoped{i, hooks} <> tail: stage_bucket(Tag, tail, d, layers, n, stage)
    case T.Staged{+kind, +tag} <> tail:
      Equal.cong(List<&2, Tag>, List<&2, Tag>, ys => T.include(Tag, tag, ys, U32.is_eq(T.stage_number(kind), T.stage_number(stage))), T.stage_ids(Tag, List.append(&2, T.Middleware<Tag>, tail, keep(Tag, d, layers, n)), stage), T.stage_ids(Tag, tail, stage), stage_bucket(Tag, tail, d, layers, n, stage))
    case T.Middleware{pattern, tag} <> tail: stage_bucket(Tag, tail, d, layers, n, stage)

def selected_bucket(-Tag: Data, xs: List<&2, T.Middleware<Tag>>, +d: Nat, +layers: List<&2, T.Middleware<Tag>>, +n: Nat, +path: String) -> {T.selected(Tag, List.append(&2, T.Middleware<Tag>, xs, keep(Tag, d, layers, n)), path) == T.selected(Tag, xs, path) : List<&2, Tag>}:
  match xs:
    case Nil{}: selected_keep(Tag, d, layers, n, path)
    case T.Scoped{i, hooks} <> tail: selected_bucket(Tag, tail, d, layers, n, path)
    case T.Staged{kind, tag} <> tail: selected_bucket(Tag, tail, d, layers, n, path)
    case T.Middleware{None{}, +tag} <> tail:
      Equal.cong(List<&2, Tag>, List<&2, Tag>, ys => tag <> ys, T.selected(Tag, List.append(&2, T.Middleware<Tag>, tail, keep(Tag, d, layers, n)), path), T.selected(Tag, tail, path), selected_bucket(Tag, tail, d, layers, n, path))
    case T.Middleware{Some{+p}, +tag} <> tail:
      Equal.cong(List<&2, Tag>, List<&2, Tag>, ys => T.include(Tag, tag, ys, Maybe.is_some(&2, P.Params, P.match_path(p, path))), T.selected(Tag, List.append(&2, T.Middleware<Tag>, tail, keep(Tag, d, layers, n)), path), T.selected(Tag, tail, path), selected_bucket(Tag, tail, d, layers, n, path))

# A layer left out of the bucket belongs to another route, so it selected
# nothing for this one.
def route_miss(-Tag: Data, +d: Nat, +i: Nat, +n: Nat, +hooks: List<&2, T.Placement<Tag>>, +rest: List<&2, Tag>, +stage: T.Stage, m: Bool, hit: {Nat.is_eq(i, n) == m : Bool}, miss: {same(d, T.slot_key(i), T.slot_key(n)) == False{} : Bool}) -> {rest == List.append(&2, Tag, T.include_hooks(Tag, hooks, stage, m), rest) : List<&2, Tag>}:
  match m:
    case True{}: apart({rest == List.append(&2, Tag, T.hook_ids(Tag, hooks, stage), rest) : List<&2, Tag>}, d, i, n, hit, miss)
    case False{}: {==}

def route_pre(-Tag: Data, +d: Nat, +i: Nat, +n: Nat, +hooks: List<&2, T.Placement<Tag>>, +kept: List<&2, T.Middleware<Tag>>, +tail: List<&2, T.Middleware<Tag>>, +stage: T.Stage, c: Bool, e: {same(d, T.slot_key(i), T.slot_key(n)) == c : Bool}, ih: {T.route_stage_ids(Tag, kept, Some{n}, stage) == T.route_stage_ids(Tag, tail, Some{n}, stage) : List<&2, Tag>}) -> {T.route_stage_ids(Tag, pre(Tag, T.Scoped{i, hooks}, c, kept), Some{n}, stage) == List.append(&2, Tag, T.include_hooks(Tag, hooks, stage, Nat.is_eq(i, n)), T.route_stage_ids(Tag, tail, Some{n}, stage)) : List<&2, Tag>}:
  match c:
    case True{}:
      Equal.cong(List<&2, Tag>, List<&2, Tag>, ys => List.append(&2, Tag, T.include_hooks(Tag, hooks, stage, Nat.is_eq(i, n)), ys), T.route_stage_ids(Tag, kept, Some{n}, stage), T.route_stage_ids(Tag, tail, Some{n}, stage), ih)
    case False{}:
      Equal.trans(List<&2, Tag>, T.route_stage_ids(Tag, kept, Some{n}, stage), T.route_stage_ids(Tag, tail, Some{n}, stage), List.append(&2, Tag, T.include_hooks(Tag, hooks, stage, Nat.is_eq(i, n)), T.route_stage_ids(Tag, tail, Some{n}, stage)), ih,
        route_miss(Tag, d, i, n, hooks, T.route_stage_ids(Tag, tail, Some{n}, stage), stage, Nat.is_eq(i, n), {==}, e))

def route_keep(-Tag: Data, +d: Nat, +layers: List<&2, T.Middleware<Tag>>, +n: Nat, +stage: T.Stage) -> {T.route_stage_ids(Tag, keep(Tag, d, layers, n), Some{n}, stage) == T.route_stage_ids(Tag, layers, Some{n}, stage) : List<&2, Tag>}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{+i, +hooks} <> +tail: route_pre(Tag, d, i, n, hooks, keep(Tag, d, tail, n), tail, stage, same(d, T.slot_key(i), T.slot_key(n)), {==}, route_keep(Tag, d, tail, n, stage))
    case T.Staged{kind, tag} <> tail: route_keep(Tag, d, tail, n, stage)
    case T.Middleware{pattern, tag} <> tail: route_keep(Tag, d, tail, n, stage)

def override_none(set: V.Schemas) -> {V.override(set, V.none()) == set : V.Schemas}:
  match set:
    case V.Schemas{p, q, h, b, r}: {==}

def schemas_miss(-Tag: Data, +d: Nat, +i: Nat, +n: Nat, +hooks: List<&2, T.Placement<Tag>>, +rest: V.Schemas, m: Bool, hit: {Nat.is_eq(i, n) == m : Bool}, miss: {same(d, T.slot_key(i), T.slot_key(n)) == False{} : Bool}) -> {rest == V.override(rest, T.schemas_here(Tag, hooks, m)) : V.Schemas}:
  match m:
    case True{}: apart({rest == V.override(rest, T.placed_schemas(Tag, hooks, V.none())) : V.Schemas}, d, i, n, hit, miss)
    case False{}: Equal.sym(V.Schemas, V.override(rest, V.none()), rest, override_none(rest))

def schemas_pre(-Tag: Data, +d: Nat, +i: Nat, +n: Nat, +hooks: List<&2, T.Placement<Tag>>, +kept: List<&2, T.Middleware<Tag>>, +tail: List<&2, T.Middleware<Tag>>, c: Bool, e: {same(d, T.slot_key(i), T.slot_key(n)) == c : Bool}, ih: {T.route_schemas(Tag, kept, Some{n}) == T.route_schemas(Tag, tail, Some{n}) : V.Schemas}) -> {T.route_schemas(Tag, pre(Tag, T.Scoped{i, hooks}, c, kept), Some{n}) == V.override(T.route_schemas(Tag, tail, Some{n}), T.schemas_here(Tag, hooks, Nat.is_eq(i, n))) : V.Schemas}:
  match c:
    case True{}:
      Equal.cong(V.Schemas, V.Schemas, s => V.override(s, T.schemas_here(Tag, hooks, Nat.is_eq(i, n))), T.route_schemas(Tag, kept, Some{n}), T.route_schemas(Tag, tail, Some{n}), ih)
    case False{}:
      Equal.trans(V.Schemas, T.route_schemas(Tag, kept, Some{n}), T.route_schemas(Tag, tail, Some{n}), V.override(T.route_schemas(Tag, tail, Some{n}), T.schemas_here(Tag, hooks, Nat.is_eq(i, n))), ih,
        schemas_miss(Tag, d, i, n, hooks, T.route_schemas(Tag, tail, Some{n}), Nat.is_eq(i, n), {==}, e))

def schemas_keep(-Tag: Data, +d: Nat, +layers: List<&2, T.Middleware<Tag>>, +n: Nat) -> {T.route_schemas(Tag, keep(Tag, d, layers, n), Some{n}) == T.route_schemas(Tag, layers, Some{n}) : V.Schemas}:
  match layers:
    case Nil{}: {==}
    case T.Scoped{+i, +hooks} <> +tail: schemas_pre(Tag, d, i, n, hooks, keep(Tag, d, tail, n), tail, same(d, T.slot_key(i), T.slot_key(n)), {==}, schemas_keep(Tag, d, tail, n))
    case T.Staged{kind, tag} <> tail: schemas_keep(Tag, d, tail, n)
    case T.Middleware{pattern, tag} <> tail: schemas_keep(Tag, d, tail, n)

# The index lemmas: selection over relevant(index(layers), route) equals
# selection over layers.
def stage_selection(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +route: Maybe<&2, Nat>, +stage: T.Stage) -> {T.scoped_stage_ids(Tag, T.relevant(Tag, T.index(Tag, layers), route), route, stage) == T.scoped_stage_ids(Tag, layers, route, stage) : List<&2, Tag>}:
  match route:
    case None{}:
      %Equal.sym(List<&2, Tag>, T.stage_ids(Tag, T.global_layers(Tag, layers), stage), T.stage_ids(Tag, layers, stage), stage_globals(Tag, layers, stage)) : {List.append(&2, Tag, _, T.route_stage_ids(Tag, T.global_layers(Tag, layers), None{}, stage)) == T.scoped_stage_ids(Tag, layers, None{}, stage) : List<&2, Tag>}
      %Equal.sym(List<&2, Tag>, T.route_stage_ids(Tag, T.global_layers(Tag, layers), None{}, stage), [], route_none(Tag, T.global_layers(Tag, layers), stage)) : {List.append(&2, Tag, T.stage_ids(Tag, layers, stage), _) == T.scoped_stage_ids(Tag, layers, None{}, stage) : List<&2, Tag>}
      %Equal.sym(List<&2, Tag>, T.route_stage_ids(Tag, layers, None{}, stage), [], route_none(Tag, layers, stage)) : {List.append(&2, Tag, T.stage_ids(Tag, layers, stage), []) == List.append(&2, Tag, T.stage_ids(Tag, layers, stage), _) : List<&2, Tag>}
      {==}
    case Some{+n}:
      %Equal.sym(List<&2, T.Middleware<Tag>>, T.relevant(Tag, T.index(Tag, layers), Some{n}), List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)), relevant_some(Tag, layers, n)) : {T.scoped_stage_ids(Tag, _, Some{n}, stage) == T.scoped_stage_ids(Tag, layers, Some{n}, stage) : List<&2, Tag>}
      %Equal.sym(List<&2, Tag>, T.stage_ids(Tag, List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)), stage), T.stage_ids(Tag, T.global_layers(Tag, layers), stage), stage_bucket(Tag, T.global_layers(Tag, layers), T.slot_depth(), layers, n, stage)) : {List.append(&2, Tag, _, T.route_stage_ids(Tag, List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)), Some{n}, stage)) == T.scoped_stage_ids(Tag, layers, Some{n}, stage) : List<&2, Tag>}
      %Equal.sym(List<&2, Tag>, T.stage_ids(Tag, T.global_layers(Tag, layers), stage), T.stage_ids(Tag, layers, stage), stage_globals(Tag, layers, stage)) : {List.append(&2, Tag, _, T.route_stage_ids(Tag, List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)), Some{n}, stage)) == T.scoped_stage_ids(Tag, layers, Some{n}, stage) : List<&2, Tag>}
      %Equal.sym(List<&2, Tag>, T.route_stage_ids(Tag, List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)), Some{n}, stage), T.route_stage_ids(Tag, keep(Tag, T.slot_depth(), layers, n), Some{n}, stage), route_skip(Tag, layers, keep(Tag, T.slot_depth(), layers, n), n, stage)) : {List.append(&2, Tag, T.stage_ids(Tag, layers, stage), _) == T.scoped_stage_ids(Tag, layers, Some{n}, stage) : List<&2, Tag>}
      %Equal.sym(List<&2, Tag>, T.route_stage_ids(Tag, keep(Tag, T.slot_depth(), layers, n), Some{n}, stage), T.route_stage_ids(Tag, layers, Some{n}, stage), route_keep(Tag, T.slot_depth(), layers, n, stage)) : {List.append(&2, Tag, T.stage_ids(Tag, layers, stage), _) == T.scoped_stage_ids(Tag, layers, Some{n}, stage) : List<&2, Tag>}
      {==}

def selected_selection(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +route: Maybe<&2, Nat>, +path: String) -> {T.selected(Tag, T.relevant(Tag, T.index(Tag, layers), route), path) == T.selected(Tag, layers, path) : List<&2, Tag>}:
  match route:
    case None{}: selected_globals(Tag, layers, path)
    case Some{+n}:
      %Equal.sym(List<&2, T.Middleware<Tag>>, T.relevant(Tag, T.index(Tag, layers), Some{n}), List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)), relevant_some(Tag, layers, n)) : {T.selected(Tag, _, path) == T.selected(Tag, layers, path) : List<&2, Tag>}
      Equal.trans(List<&2, Tag>, T.selected(Tag, List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)), path), T.selected(Tag, T.global_layers(Tag, layers), path), T.selected(Tag, layers, path),
        selected_bucket(Tag, T.global_layers(Tag, layers), T.slot_depth(), layers, n, path), selected_globals(Tag, layers, path))

def schemas_selection(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +route: Maybe<&2, Nat>) -> {T.route_schemas(Tag, T.relevant(Tag, T.index(Tag, layers), route), route) == T.route_schemas(Tag, layers, route) : V.Schemas}:
  match route:
    case None{}:
      Equal.trans(V.Schemas, T.route_schemas(Tag, T.global_layers(Tag, layers), None{}), V.none(), T.route_schemas(Tag, layers, None{}), schemas_none(Tag, T.global_layers(Tag, layers)), Equal.sym(V.Schemas, T.route_schemas(Tag, layers, None{}), V.none(), schemas_none(Tag, layers)))
    case Some{+n}:
      %Equal.sym(List<&2, T.Middleware<Tag>>, T.relevant(Tag, T.index(Tag, layers), Some{n}), List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)), relevant_some(Tag, layers, n)) : {T.route_schemas(Tag, _, Some{n}) == T.route_schemas(Tag, layers, Some{n}) : V.Schemas}
      Equal.trans(V.Schemas, T.route_schemas(Tag, List.append(&2, T.Middleware<Tag>, T.global_layers(Tag, layers), keep(Tag, T.slot_depth(), layers, n)), Some{n}), T.route_schemas(Tag, keep(Tag, T.slot_depth(), layers, n), Some{n}), T.route_schemas(Tag, layers, Some{n}),
        schemas_skip(Tag, layers, keep(Tag, T.slot_depth(), layers, n), n), schemas_keep(Tag, T.slot_depth(), layers, n))

# Any two layer lists that agree on path selection and every scoped stage
# build the same lifecycle.
def lifecycle_of(-Tag: Data, +xs: List<&2, T.Middleware<Tag>>, +ys: List<&2, T.Middleware<Tag>>, +path: String, +route: Maybe<&2, Nat>, sel: {T.selected(Tag, xs, path) == T.selected(Tag, ys, path) : List<&2, Tag>}, request: {T.scoped_stage_ids(Tag, xs, route, T.Request{}) == T.scoped_stage_ids(Tag, ys, route, T.Request{}) : List<&2, Tag>}, parse: {T.scoped_stage_ids(Tag, xs, route, T.Parse{}) == T.scoped_stage_ids(Tag, ys, route, T.Parse{}) : List<&2, Tag>}, transform: {T.scoped_stage_ids(Tag, xs, route, T.Transform{}) == T.scoped_stage_ids(Tag, ys, route, T.Transform{}) : List<&2, Tag>}, before: {T.scoped_stage_ids(Tag, xs, route, T.BeforeHandle{}) == T.scoped_stage_ids(Tag, ys, route, T.BeforeHandle{}) : List<&2, Tag>}, after: {T.scoped_stage_ids(Tag, xs, route, T.AfterHandle{}) == T.scoped_stage_ids(Tag, ys, route, T.AfterHandle{}) : List<&2, Tag>}, map: {T.scoped_stage_ids(Tag, xs, route, T.MapResponse{}) == T.scoped_stage_ids(Tag, ys, route, T.MapResponse{}) : List<&2, Tag>}, errors: {T.scoped_stage_ids(Tag, xs, route, T.Error{}) == T.scoped_stage_ids(Tag, ys, route, T.Error{}) : List<&2, Tag>}, observers: {T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{}) == T.scoped_stage_ids(Tag, ys, route, T.AfterResponse{}) : List<&2, Tag>}) -> {T.scoped_lifecycle(Tag, xs, path, route) == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}:
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, xs, route, T.Request{}), T.scoped_stage_ids(Tag, ys, route, T.Request{}), request) : {T.Lifecycle{_, List.concat(&2, Tag, [T.selected(Tag, xs, path), T.scoped_stage_ids(Tag, xs, route, T.Parse{}), T.scoped_stage_ids(Tag, xs, route, T.Transform{}), T.scoped_stage_ids(Tag, xs, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, xs, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, xs, route, T.MapResponse{}), T.scoped_stage_ids(Tag, xs, route, T.Error{}), T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{})} == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.selected(Tag, xs, path), T.selected(Tag, ys, path), sel) : {T.Lifecycle{T.scoped_stage_ids(Tag, ys, route, T.Request{}), List.concat(&2, Tag, [_, T.scoped_stage_ids(Tag, xs, route, T.Parse{}), T.scoped_stage_ids(Tag, xs, route, T.Transform{}), T.scoped_stage_ids(Tag, xs, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, xs, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, xs, route, T.MapResponse{}), T.scoped_stage_ids(Tag, xs, route, T.Error{}), T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{})} == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, xs, route, T.Parse{}), T.scoped_stage_ids(Tag, ys, route, T.Parse{}), parse) : {T.Lifecycle{T.scoped_stage_ids(Tag, ys, route, T.Request{}), List.concat(&2, Tag, [T.selected(Tag, ys, path), _, T.scoped_stage_ids(Tag, xs, route, T.Transform{}), T.scoped_stage_ids(Tag, xs, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, xs, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, xs, route, T.MapResponse{}), T.scoped_stage_ids(Tag, xs, route, T.Error{}), T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{})} == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, xs, route, T.Transform{}), T.scoped_stage_ids(Tag, ys, route, T.Transform{}), transform) : {T.Lifecycle{T.scoped_stage_ids(Tag, ys, route, T.Request{}), List.concat(&2, Tag, [T.selected(Tag, ys, path), T.scoped_stage_ids(Tag, ys, route, T.Parse{}), _, T.scoped_stage_ids(Tag, xs, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, xs, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, xs, route, T.MapResponse{}), T.scoped_stage_ids(Tag, xs, route, T.Error{}), T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{})} == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, xs, route, T.BeforeHandle{}), T.scoped_stage_ids(Tag, ys, route, T.BeforeHandle{}), before) : {T.Lifecycle{T.scoped_stage_ids(Tag, ys, route, T.Request{}), List.concat(&2, Tag, [T.selected(Tag, ys, path), T.scoped_stage_ids(Tag, ys, route, T.Parse{}), T.scoped_stage_ids(Tag, ys, route, T.Transform{}), _]), T.scoped_stage_ids(Tag, xs, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, xs, route, T.MapResponse{}), T.scoped_stage_ids(Tag, xs, route, T.Error{}), T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{})} == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, xs, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, ys, route, T.AfterHandle{}), after) : {T.Lifecycle{T.scoped_stage_ids(Tag, ys, route, T.Request{}), List.concat(&2, Tag, [T.selected(Tag, ys, path), T.scoped_stage_ids(Tag, ys, route, T.Parse{}), T.scoped_stage_ids(Tag, ys, route, T.Transform{}), T.scoped_stage_ids(Tag, ys, route, T.BeforeHandle{})]), _, T.scoped_stage_ids(Tag, xs, route, T.MapResponse{}), T.scoped_stage_ids(Tag, xs, route, T.Error{}), T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{})} == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, xs, route, T.MapResponse{}), T.scoped_stage_ids(Tag, ys, route, T.MapResponse{}), map) : {T.Lifecycle{T.scoped_stage_ids(Tag, ys, route, T.Request{}), List.concat(&2, Tag, [T.selected(Tag, ys, path), T.scoped_stage_ids(Tag, ys, route, T.Parse{}), T.scoped_stage_ids(Tag, ys, route, T.Transform{}), T.scoped_stage_ids(Tag, ys, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, ys, route, T.AfterHandle{}), _, T.scoped_stage_ids(Tag, xs, route, T.Error{}), T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{})} == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, xs, route, T.Error{}), T.scoped_stage_ids(Tag, ys, route, T.Error{}), errors) : {T.Lifecycle{T.scoped_stage_ids(Tag, ys, route, T.Request{}), List.concat(&2, Tag, [T.selected(Tag, ys, path), T.scoped_stage_ids(Tag, ys, route, T.Parse{}), T.scoped_stage_ids(Tag, ys, route, T.Transform{}), T.scoped_stage_ids(Tag, ys, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, ys, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, ys, route, T.MapResponse{}), _, T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{})} == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, xs, route, T.AfterResponse{}), T.scoped_stage_ids(Tag, ys, route, T.AfterResponse{}), observers) : {T.Lifecycle{T.scoped_stage_ids(Tag, ys, route, T.Request{}), List.concat(&2, Tag, [T.selected(Tag, ys, path), T.scoped_stage_ids(Tag, ys, route, T.Parse{}), T.scoped_stage_ids(Tag, ys, route, T.Transform{}), T.scoped_stage_ids(Tag, ys, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, ys, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, ys, route, T.MapResponse{}), T.scoped_stage_ids(Tag, ys, route, T.Error{}), _} == T.scoped_lifecycle(Tag, ys, path, route) : T.Lifecycle<Tag>}
  {==}

def lifecycle_selection(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +path: String, +route: Maybe<&2, Nat>) -> {T.scoped_lifecycle(Tag, T.relevant(Tag, T.index(Tag, layers), route), path, route) == T.scoped_lifecycle(Tag, layers, path, route) : T.Lifecycle<Tag>}:
  lifecycle_of(Tag, T.relevant(Tag, T.index(Tag, layers), route), layers, path, route,
    selected_selection(Tag, layers, route, path),
    stage_selection(Tag, layers, route, T.Request{}),
    stage_selection(Tag, layers, route, T.Parse{}),
    stage_selection(Tag, layers, route, T.Transform{}),
    stage_selection(Tag, layers, route, T.BeforeHandle{}),
    stage_selection(Tag, layers, route, T.AfterHandle{}),
    stage_selection(Tag, layers, route, T.MapResponse{}),
    stage_selection(Tag, layers, route, T.Error{}),
    stage_selection(Tag, layers, route, T.AfterResponse{}))

def global_stages(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +stage: T.Stage) -> {T.stage_ids(Tag, T.index_globals(Tag, T.index(Tag, layers)), stage) == T.stage_ids(Tag, layers, stage) : List<&2, Tag>}:
  stage_globals(Tag, layers, stage)

def global_selected(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +path: String) -> {T.selected(Tag, T.index_globals(Tag, T.index(Tag, layers)), path) == T.selected(Tag, layers, path) : List<&2, Tag>}:
  selected_globals(Tag, layers, path)

def Laws.scoped_index_stage_selection(Tag, layers, route, stage): stage_selection(Tag, layers, route, stage)

def Laws.scoped_index_lifecycle_selection(Tag, layers, path, route): lifecycle_selection(Tag, layers, path, route)

def Laws.scoped_index_route_schemas(Tag, layers, route): schemas_selection(Tag, layers, route)

def Laws.scoped_index_global_stages(Tag, layers, stage): global_stages(Tag, layers, stage)

def Laws.scoped_index_global_selected(Tag, layers, path): global_selected(Tag, layers, path)

def Laws.scoped_index_spec_stage_selection(Tag, entries, routes, compiled, layers, count, route, stage, built):
  Equal.trans(List<&2, Tag>, T.scoped_stage_ids(Tag, T.relevant(Tag, T.index(Tag, layers), route), route, stage), T.scoped_stage_ids(Tag, layers, route, stage), S.stage_ids(Tag, entries, route, stage),
    stage_selection(Tag, layers, route, stage), Sel.stage_selection(Tag, entries, routes, compiled, layers, count, route, stage, built))

def Laws.scoped_index_spec_lifecycle_selection(Tag, entries, routes, compiled, layers, count, path, route, built):
  Equal.trans(T.Lifecycle<Tag>, T.scoped_lifecycle(Tag, T.relevant(Tag, T.index(Tag, layers), route), path, route), T.scoped_lifecycle(Tag, layers, path, route), S.lifecycle(Tag, entries, path, route),
    lifecycle_selection(Tag, layers, path, route), Sel.lifecycle_selection(Tag, entries, routes, compiled, layers, count, path, route, built))
