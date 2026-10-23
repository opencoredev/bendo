import Base
import ./plugin-laws.bend as L
import ./plugin-spec.bend as S
import ./compose-laws.bend as CL
import ./compose.bend as ComposeProof
import ./compose-spec.bend as ComposeSpec
import ./scoped-assembly.bend as Assembly
import ./scoped-assembly-spec.bend as AssemblySpec
import ../src/app/plugin.bend as P
import ../src/app/compose.bend as C
import ../src/app/scopes.bend as Scopes
import ../src/app/table.bend as T
import ../src/router/equality-proofs.bend as Eq

def append_nil(-Tag: Data, +xs: List<&2, T.Entry<Tag>>) -> {List.append(&2, T.Entry<Tag>, xs, []) == xs : List<&2, T.Entry<Tag>>}:
  match xs:
    case Nil{}: {==}
    case h <> t: Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, rest => h <> rest, List.append(&2, T.Entry<Tag>, t, []), t, append_nil(Tag, t))

def append_assoc(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +ys: List<&2, T.Entry<Tag>>, +zs: List<&2, T.Entry<Tag>>) -> {List.append(&2, T.Entry<Tag>, List.append(&2, T.Entry<Tag>, xs, ys), zs) == List.append(&2, T.Entry<Tag>, xs, List.append(&2, T.Entry<Tag>, ys, zs)) : List<&2, T.Entry<Tag>>}:
  match xs:
    case Nil{}: {==}
    case h <> t: Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, rest => h <> rest, List.append(&2, T.Entry<Tag>, List.append(&2, T.Entry<Tag>, t, ys), zs), List.append(&2, T.Entry<Tag>, t, List.append(&2, T.Entry<Tag>, ys, zs)), append_assoc(Tag, t, ys, zs))

def follow_assoc(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +ys: List<&2, T.Entry<Tag>>, +r: P.Builder<Tag>) -> {S.follow(Tag, List.append(&2, T.Entry<Tag>, xs, ys), r) == S.follow(Tag, xs, S.follow(Tag, ys, r)) : P.Builder<Tag>}:
  match r:
    case P.Builder{ids, zs}: Equal.cong(List<&2, T.Entry<Tag>>, P.Builder<Tag>, l => P.Builder{ids, l}, List.append(&2, T.Entry<Tag>, List.append(&2, T.Entry<Tag>, xs, ys), zs), List.append(&2, T.Entry<Tag>, xs, List.append(&2, T.Entry<Tag>, ys, zs)), append_assoc(Tag, xs, ys, zs))

# The runtime registry test agrees with the specification's own membership.
def known(+name: String, +seed: String, +ids: List<&2, P.Identity>) -> {P.applied(P.Identity{name, seed}, ids) == S.known(name, seed, ids) : Bool}:
  match ids:
    case Nil{}: {==}
    case P.Identity{n, s} <> tail: Equal.cong(Bool, Bool, b => (String.eq(n, name) && String.eq(s, seed)) || b, P.applied(P.Identity{name, seed}, tail), S.known(name, seed, tail), known(name, seed, tail))

# The tail induction hypothesis is passed in as a function over every start.
def continue(-Tag: Data, +tail: List<&2, S.Step<Tag>>, ih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, tail, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, tail, m)) : P.Builder<Tag>}, +es: List<&2, T.Entry<Tag>>, +r: P.Builder<Tag>) -> {S.run(Tag, tail, S.follow(Tag, es, r)) == S.follow(Tag, es, S.sequel(Tag, r, m => S.assemble(Tag, tail, m))) : P.Builder<Tag>}:
  match r:
    case P.Builder{m, rs}:
      Equal.trans(P.Builder<Tag>, S.run(Tag, tail, P.Builder{m, List.append(&2, T.Entry<Tag>, es, rs)}), S.follow(Tag, List.append(&2, T.Entry<Tag>, es, rs), S.assemble(Tag, tail, m)), S.follow(Tag, es, S.follow(Tag, rs, S.assemble(Tag, tail, m))), ih(m, List.append(&2, T.Entry<Tag>, es, rs)), follow_assoc(Tag, es, rs, S.assemble(Tag, tail, m)))

def nested(-Tag: Data, +body: List<&2, S.Step<Tag>>, +tail: List<&2, S.Step<Tag>>, bih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, body, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, body, m)) : P.Builder<Tag>}, tih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, tail, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, tail, m)) : P.Builder<Tag>}, +ids: List<&2, P.Identity>, +es: List<&2, T.Entry<Tag>>) -> {S.run(Tag, tail, S.run(Tag, body, P.Builder{ids, es})) == S.follow(Tag, es, S.sequel(Tag, S.assemble(Tag, body, ids), m => S.assemble(Tag, tail, m))) : P.Builder<Tag>}:
  Equal.trans(P.Builder<Tag>, S.run(Tag, tail, S.run(Tag, body, P.Builder{ids, es})), S.run(Tag, tail, S.follow(Tag, es, S.assemble(Tag, body, ids))), S.follow(Tag, es, S.sequel(Tag, S.assemble(Tag, body, ids), m => S.assemble(Tag, tail, m))), Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.run(Tag, tail, x), S.run(Tag, body, P.Builder{ids, es}), S.follow(Tag, es, S.assemble(Tag, body, ids)), bih(ids, es)), continue(Tag, tail, tih, es, S.assemble(Tag, body, ids)))

def decided(-Tag: Data, +name: String, +seed: String, +body: List<&2, S.Step<Tag>>, +tail: List<&2, S.Step<Tag>>, bih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, body, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, body, m)) : P.Builder<Tag>}, tih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, tail, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, tail, m)) : P.Builder<Tag>}, +ids: List<&2, P.Identity>, +es: List<&2, T.Entry<Tag>>, b: Bool) -> {S.run(Tag, tail, P.entered(Tag, P.Identity{name, seed}, ids, es, a => S.run(Tag, body, a), b)) == S.follow(Tag, es, S.choose(Tag, b, u => S.assemble(Tag, tail, ids), u => S.sequel(Tag, S.assemble(Tag, body, P.Identity{name, seed} <> ids), m => S.assemble(Tag, tail, m)))) : P.Builder<Tag>}:
  match b:
    case True{}: tih(ids, es)
    case False{}: nested(Tag, body, tail, bih, tih, P.Identity{name, seed} <> ids, es)

# A body contribution followed by a scope transform proven equal to its spec.
def placed(-Tag: Data, +tail: List<&2, S.Step<Tag>>, tih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, tail, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, tail, m)) : P.Builder<Tag>}, +es: List<&2, T.Entry<Tag>>, +m: List<&2, P.Identity>, +impl: List<&2, T.Entry<Tag>>, +spec: List<&2, T.Entry<Tag>>, same: {impl == spec : List<&2, T.Entry<Tag>>}) -> {S.run(Tag, tail, P.Builder{m, List.append(&2, T.Entry<Tag>, es, impl)}) == S.follow(Tag, es, S.follow(Tag, spec, S.assemble(Tag, tail, m))) : P.Builder<Tag>}:
  Equal.trans(P.Builder<Tag>, S.run(Tag, tail, P.Builder{m, List.append(&2, T.Entry<Tag>, es, impl)}), S.run(Tag, tail, P.Builder{m, List.append(&2, T.Entry<Tag>, es, spec)}), S.follow(Tag, es, S.follow(Tag, spec, S.assemble(Tag, tail, m))), Equal.cong(List<&2, T.Entry<Tag>>, P.Builder<Tag>, xs => S.run(Tag, tail, P.Builder{m, List.append(&2, T.Entry<Tag>, es, xs)}), impl, spec, same), Equal.trans(P.Builder<Tag>, S.run(Tag, tail, P.Builder{m, List.append(&2, T.Entry<Tag>, es, spec)}), S.follow(Tag, List.append(&2, T.Entry<Tag>, es, spec), S.assemble(Tag, tail, m)), S.follow(Tag, es, S.follow(Tag, spec, S.assemble(Tag, tail, m))), tih(m, List.append(&2, T.Entry<Tag>, es, spec)), follow_assoc(Tag, es, spec, S.assemble(Tag, tail, m))))

def placed_mount(-Tag: Data, +prefix: String, +tail: List<&2, S.Step<Tag>>, tih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, tail, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, tail, m)) : P.Builder<Tag>}, +es: List<&2, T.Entry<Tag>>, +r: P.Builder<Tag>) -> {S.run(Tag, tail, P.placed(Tag, es, sub => C.mount(Tag, prefix, sub), S.follow(Tag, [], r))) == S.follow(Tag, es, S.scoped(Tag, S.Mount{prefix}, r, m => S.assemble(Tag, tail, m))) : P.Builder<Tag>}:
  match r:
    case P.Builder{m, rs}: placed(Tag, tail, tih, es, m, C.mount(Tag, prefix, rs), ComposeSpec.mount(Tag, prefix, rs), CL.compose_mount(Tag, prefix, rs))

def placed_group(-Tag: Data, +prefix: String, +hooks: List<&2, T.HookSpec<Tag>>, +tail: List<&2, S.Step<Tag>>, tih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, tail, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, tail, m)) : P.Builder<Tag>}, +es: List<&2, T.Entry<Tag>>, +r: P.Builder<Tag>) -> {S.run(Tag, tail, P.placed(Tag, es, sub => C.group(Tag, prefix, hooks, sub), S.follow(Tag, [], r))) == S.follow(Tag, es, S.scoped(Tag, S.Group{prefix, hooks}, r, m => S.assemble(Tag, tail, m))) : P.Builder<Tag>}:
  match r:
    case P.Builder{m, rs}: placed(Tag, tail, tih, es, m, C.group(Tag, prefix, hooks, rs), ComposeSpec.group(Tag, prefix, hooks, rs), CL.compose_group(Tag, prefix, hooks, rs))

def placed_guard(-Tag: Data, +options: T.GuardOptions<Tag>, +tail: List<&2, S.Step<Tag>>, tih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, tail, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, tail, m)) : P.Builder<Tag>}, +es: List<&2, T.Entry<Tag>>, +r: P.Builder<Tag>) -> {S.run(Tag, tail, P.placed(Tag, es, sub => Scopes.guard(Tag, options, sub), S.follow(Tag, [], r))) == S.follow(Tag, es, S.scoped(Tag, S.Guard{options}, r, m => S.assemble(Tag, tail, m))) : P.Builder<Tag>}:
  match r:
    case P.Builder{m, rs}: placed(Tag, tail, tih, es, m, Scopes.guard(Tag, options, rs), AssemblySpec.guard(Tag, options, rs), Assembly.guard(Tag, options, rs))

def within(-Tag: Data, +scope: S.Scope<Tag>, +body: List<&2, S.Step<Tag>>, +tail: List<&2, S.Step<Tag>>, bih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, body, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, body, m)) : P.Builder<Tag>}, tih: @m: List<&2, P.Identity> -> @e: List<&2, T.Entry<Tag>> -> {S.run(Tag, tail, P.Builder{m, e}) == S.follow(Tag, e, S.assemble(Tag, tail, m)) : P.Builder<Tag>}, +ids: List<&2, P.Identity>, +es: List<&2, T.Entry<Tag>>) -> {S.run(Tag, tail, S.within(Tag, scope, P.Builder{ids, es}, a => S.run(Tag, body, a))) == S.follow(Tag, es, S.scoped(Tag, scope, S.assemble(Tag, body, ids), m => S.assemble(Tag, tail, m))) : P.Builder<Tag>}:
  match scope:
    case S.Mount{prefix}:
      Equal.trans(P.Builder<Tag>, S.run(Tag, tail, P.placed(Tag, es, sub => C.mount(Tag, prefix, sub), S.run(Tag, body, P.Builder{ids, []}))), S.run(Tag, tail, P.placed(Tag, es, sub => C.mount(Tag, prefix, sub), S.follow(Tag, [], S.assemble(Tag, body, ids)))), S.follow(Tag, es, S.scoped(Tag, S.Mount{prefix}, S.assemble(Tag, body, ids), m => S.assemble(Tag, tail, m))), Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.run(Tag, tail, P.placed(Tag, es, sub => C.mount(Tag, prefix, sub), x)), S.run(Tag, body, P.Builder{ids, []}), S.follow(Tag, [], S.assemble(Tag, body, ids)), bih(ids, [])), placed_mount(Tag, prefix, tail, tih, es, S.assemble(Tag, body, ids)))
    case S.Group{prefix, hooks}:
      Equal.trans(P.Builder<Tag>, S.run(Tag, tail, P.placed(Tag, es, sub => C.group(Tag, prefix, hooks, sub), S.run(Tag, body, P.Builder{ids, []}))), S.run(Tag, tail, P.placed(Tag, es, sub => C.group(Tag, prefix, hooks, sub), S.follow(Tag, [], S.assemble(Tag, body, ids)))), S.follow(Tag, es, S.scoped(Tag, S.Group{prefix, hooks}, S.assemble(Tag, body, ids), m => S.assemble(Tag, tail, m))), Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.run(Tag, tail, P.placed(Tag, es, sub => C.group(Tag, prefix, hooks, sub), x)), S.run(Tag, body, P.Builder{ids, []}), S.follow(Tag, [], S.assemble(Tag, body, ids)), bih(ids, [])), placed_group(Tag, prefix, hooks, tail, tih, es, S.assemble(Tag, body, ids)))
    case S.Guard{options}:
      Equal.trans(P.Builder<Tag>, S.run(Tag, tail, P.placed(Tag, es, sub => Scopes.guard(Tag, options, sub), S.run(Tag, body, P.Builder{ids, []}))), S.run(Tag, tail, P.placed(Tag, es, sub => Scopes.guard(Tag, options, sub), S.follow(Tag, [], S.assemble(Tag, body, ids)))), S.follow(Tag, es, S.scoped(Tag, S.Guard{options}, S.assemble(Tag, body, ids), m => S.assemble(Tag, tail, m))), Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.run(Tag, tail, P.placed(Tag, es, sub => Scopes.guard(Tag, options, sub), x)), S.run(Tag, body, P.Builder{ids, []}), S.follow(Tag, [], S.assemble(Tag, body, ids)), bih(ids, [])), placed_guard(Tag, options, tail, tih, es, S.assemble(Tag, body, ids)))

def L.plugin_first_use_assembly(Tag, steps, ids, entries):
  match steps:
    case Nil{}:
      Equal.cong(List<&2, T.Entry<Tag>>, P.Builder<Tag>, l => P.Builder{ids, l}, entries, List.append(&2, T.Entry<Tag>, entries, []), Equal.sym(List<&2, T.Entry<Tag>>, List.append(&2, T.Entry<Tag>, entries, []), entries, append_nil(Tag, entries)))
    case S.Add{xs} <> tail:
      Equal.trans(P.Builder<Tag>, S.run(Tag, tail, P.Builder{ids, List.append(&2, T.Entry<Tag>, entries, xs)}), S.follow(Tag, List.append(&2, T.Entry<Tag>, entries, xs), S.assemble(Tag, tail, ids)), S.follow(Tag, entries, S.follow(Tag, xs, S.assemble(Tag, tail, ids))), L.plugin_first_use_assembly(Tag, tail, ids, List.append(&2, T.Entry<Tag>, entries, xs)), follow_assoc(Tag, entries, xs, S.assemble(Tag, tail, ids)))
    case S.Plugin{None{}, body} <> tail:
      nested(Tag, body, tail, m => e => L.plugin_first_use_assembly(Tag, body, m, e), m => e => L.plugin_first_use_assembly(Tag, tail, m, e), ids, entries)
    case S.Plugin{Some{P.Identity{name, seed}}, body} <> tail:
      %known(name, seed, ids) : {S.run(Tag, tail, P.entered(Tag, P.Identity{name, seed}, ids, entries, a => S.run(Tag, body, a), P.applied(P.Identity{name, seed}, ids))) == S.follow(Tag, entries, S.choose(Tag, _, u => S.assemble(Tag, tail, ids), u => S.sequel(Tag, S.assemble(Tag, body, P.Identity{name, seed} <> ids), m => S.assemble(Tag, tail, m)))) : P.Builder<Tag>}
      decided(Tag, name, seed, body, tail, m => e => L.plugin_first_use_assembly(Tag, body, m, e), m => e => L.plugin_first_use_assembly(Tag, tail, m, e), ids, entries, P.applied(P.Identity{name, seed}, ids))
    case S.Within{scope, body} <> tail:
      within(Tag, scope, body, tail, m => e => L.plugin_first_use_assembly(Tag, body, m, e), m => e => L.plugin_first_use_assembly(Tag, tail, m, e), ids, entries)

# Erasing identities leaves plain preorder concatenation with fixed identities.
def flat(-Tag: Data, +steps: List<&2, S.Step<Tag>>, +ids: List<&2, P.Identity>) -> {S.assemble(Tag, S.erase(Tag, steps), ids) == P.Builder{ids, S.flatten(Tag, steps)} : P.Builder<Tag>}:
  match steps:
    case Nil{}: {==}
    case S.Add{xs} <> tail:
      Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.follow(Tag, xs, x), S.assemble(Tag, S.erase(Tag, tail), ids), P.Builder{ids, S.flatten(Tag, tail)}, flat(Tag, tail, ids))
    case S.Plugin{id, body} <> tail:
      Equal.trans(P.Builder<Tag>, S.sequel(Tag, S.assemble(Tag, S.erase(Tag, body), ids), m => S.assemble(Tag, S.erase(Tag, tail), m)), S.follow(Tag, S.flatten(Tag, body), S.assemble(Tag, S.erase(Tag, tail), ids)), P.Builder{ids, List.append(&2, T.Entry<Tag>, S.flatten(Tag, body), S.flatten(Tag, tail))}, Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.sequel(Tag, x, m => S.assemble(Tag, S.erase(Tag, tail), m)), S.assemble(Tag, S.erase(Tag, body), ids), P.Builder{ids, S.flatten(Tag, body)}, flat(Tag, body, ids)), Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.follow(Tag, S.flatten(Tag, body), x), S.assemble(Tag, S.erase(Tag, tail), ids), P.Builder{ids, S.flatten(Tag, tail)}, flat(Tag, tail, ids)))
    case S.Within{scope, body} <> tail:
      Equal.trans(P.Builder<Tag>, S.scoped(Tag, scope, S.assemble(Tag, S.erase(Tag, body), ids), m => S.assemble(Tag, S.erase(Tag, tail), m)), S.follow(Tag, S.wrap(Tag, scope, S.flatten(Tag, body)), S.assemble(Tag, S.erase(Tag, tail), ids)), P.Builder{ids, List.append(&2, T.Entry<Tag>, S.wrap(Tag, scope, S.flatten(Tag, body)), S.flatten(Tag, tail))}, Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.scoped(Tag, scope, x, m => S.assemble(Tag, S.erase(Tag, tail), m)), S.assemble(Tag, S.erase(Tag, body), ids), P.Builder{ids, S.flatten(Tag, body)}, flat(Tag, body, ids)), Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.follow(Tag, S.wrap(Tag, scope, S.flatten(Tag, body)), x), S.assemble(Tag, S.erase(Tag, tail), ids), P.Builder{ids, S.flatten(Tag, tail)}, flat(Tag, tail, ids)))

def L.plugin_anonymous_flatten(Tag, steps, ids, entries):
  Equal.trans(P.Builder<Tag>, S.run(Tag, S.erase(Tag, steps), P.Builder{ids, entries}), S.follow(Tag, entries, S.assemble(Tag, S.erase(Tag, steps), ids)), P.Builder{ids, List.append(&2, T.Entry<Tag>, entries, S.flatten(Tag, steps))}, L.plugin_first_use_assembly(Tag, S.erase(Tag, steps), ids, entries), Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.follow(Tag, entries, x), S.assemble(Tag, S.erase(Tag, steps), ids), P.Builder{ids, S.flatten(Tag, steps)}, flat(Tag, steps, ids)))

def ids_of(-Tag: Data, r: P.Builder<Tag>) -> List<&2, P.Identity>:
  P.Builder{ids, xs} = r
  ids

def ids_follow(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +r: P.Builder<Tag>) -> {ids_of(Tag, S.follow(Tag, xs, r)) == ids_of(Tag, r) : List<&2, P.Identity>}:
  match r:
    case P.Builder{ids, ys}: {==}

def or_true(+x: Bool) -> {x || True{} == True{} : Bool}:
  match x:
    case True{}: {==}
    case False{}: {==}

def mono_sequel(-Tag: Data, +tail: List<&2, S.Step<Tag>>, +name: String, +seed: String, tmono: @m: List<&2, P.Identity> -> @hm: {S.known(name, seed, m) == True{} : Bool} -> {S.known(name, seed, ids_of(Tag, S.assemble(Tag, tail, m))) == True{} : Bool}, +r: P.Builder<Tag>, hr: {S.known(name, seed, ids_of(Tag, r)) == True{} : Bool}) -> {S.known(name, seed, ids_of(Tag, S.sequel(Tag, r, m => S.assemble(Tag, tail, m)))) == True{} : Bool}:
  match r:
    case P.Builder{m, xs}:
      Equal.trans(Bool, S.known(name, seed, ids_of(Tag, S.follow(Tag, xs, S.assemble(Tag, tail, m)))), S.known(name, seed, ids_of(Tag, S.assemble(Tag, tail, m))), True{}, Equal.cong(List<&2, P.Identity>, Bool, l => S.known(name, seed, l), ids_of(Tag, S.follow(Tag, xs, S.assemble(Tag, tail, m))), ids_of(Tag, S.assemble(Tag, tail, m)), ids_follow(Tag, xs, S.assemble(Tag, tail, m))), tmono(m, hr))

def mono_scoped(-Tag: Data, +scope: S.Scope<Tag>, +tail: List<&2, S.Step<Tag>>, +name: String, +seed: String, tmono: @m: List<&2, P.Identity> -> @hm: {S.known(name, seed, m) == True{} : Bool} -> {S.known(name, seed, ids_of(Tag, S.assemble(Tag, tail, m))) == True{} : Bool}, +r: P.Builder<Tag>, hr: {S.known(name, seed, ids_of(Tag, r)) == True{} : Bool}) -> {S.known(name, seed, ids_of(Tag, S.scoped(Tag, scope, r, m => S.assemble(Tag, tail, m)))) == True{} : Bool}:
  match r:
    case P.Builder{m, xs}:
      Equal.trans(Bool, S.known(name, seed, ids_of(Tag, S.follow(Tag, S.wrap(Tag, scope, xs), S.assemble(Tag, tail, m)))), S.known(name, seed, ids_of(Tag, S.assemble(Tag, tail, m))), True{}, Equal.cong(List<&2, P.Identity>, Bool, l => S.known(name, seed, l), ids_of(Tag, S.follow(Tag, S.wrap(Tag, scope, xs), S.assemble(Tag, tail, m))), ids_of(Tag, S.assemble(Tag, tail, m)), ids_follow(Tag, S.wrap(Tag, scope, xs), S.assemble(Tag, tail, m))), tmono(m, hr))

# A known identity stays known after adding another in front.
def known_cons(+name: String, +seed: String, +n: String, +s: String, +ids: List<&2, P.Identity>, h: {S.known(name, seed, ids) == True{} : Bool}) -> {S.known(name, seed, P.Identity{n, s} <> ids) == True{} : Bool}:
  Equal.trans(Bool, (String.eq(n, name) && String.eq(s, seed)) || S.known(name, seed, ids), (String.eq(n, name) && String.eq(s, seed)) || True{}, True{}, Equal.cong(Bool, Bool, y => (String.eq(n, name) && String.eq(s, seed)) || y, S.known(name, seed, ids), True{}, h), or_true(String.eq(n, name) && String.eq(s, seed)))

def mono_decided(-Tag: Data, +n: String, +s: String, +body: List<&2, S.Step<Tag>>, +tail: List<&2, S.Step<Tag>>, +name: String, +seed: String, bmono: @m: List<&2, P.Identity> -> @hm: {S.known(name, seed, m) == True{} : Bool} -> {S.known(name, seed, ids_of(Tag, S.assemble(Tag, body, m))) == True{} : Bool}, tmono: @m: List<&2, P.Identity> -> @hm: {S.known(name, seed, m) == True{} : Bool} -> {S.known(name, seed, ids_of(Tag, S.assemble(Tag, tail, m))) == True{} : Bool}, +ids: List<&2, P.Identity>, +h: {S.known(name, seed, ids) == True{} : Bool}, b: Bool) -> {S.known(name, seed, ids_of(Tag, S.choose(Tag, b, u => S.assemble(Tag, tail, ids), u => S.sequel(Tag, S.assemble(Tag, body, P.Identity{n, s} <> ids), m => S.assemble(Tag, tail, m))))) == True{} : Bool}:
  match b:
    case True{}: tmono(ids, h)
    case False{}: mono_sequel(Tag, tail, name, seed, tmono, S.assemble(Tag, body, P.Identity{n, s} <> ids), bmono(P.Identity{n, s} <> ids, known_cons(name, seed, n, s, ids, h)))

# Assembly never forgets an identity it started with.
def mono(-Tag: Data, +steps: List<&2, S.Step<Tag>>, +name: String, +seed: String, +ids: List<&2, P.Identity>, +h: {S.known(name, seed, ids) == True{} : Bool}) -> {S.known(name, seed, ids_of(Tag, S.assemble(Tag, steps, ids))) == True{} : Bool}:
  match steps:
    case Nil{}: h
    case S.Add{xs} <> tail:
      Equal.trans(Bool, S.known(name, seed, ids_of(Tag, S.follow(Tag, xs, S.assemble(Tag, tail, ids)))), S.known(name, seed, ids_of(Tag, S.assemble(Tag, tail, ids))), True{}, Equal.cong(List<&2, P.Identity>, Bool, l => S.known(name, seed, l), ids_of(Tag, S.follow(Tag, xs, S.assemble(Tag, tail, ids))), ids_of(Tag, S.assemble(Tag, tail, ids)), ids_follow(Tag, xs, S.assemble(Tag, tail, ids))), mono(Tag, tail, name, seed, ids, h))
    case S.Plugin{None{}, body} <> tail:
      mono_sequel(Tag, tail, name, seed, m => hm => mono(Tag, tail, name, seed, m, hm), S.assemble(Tag, body, ids), mono(Tag, body, name, seed, ids, h))
    case S.Plugin{Some{P.Identity{n, s}}, body} <> tail:
      mono_decided(Tag, n, s, body, tail, name, seed, m => hm => mono(Tag, body, name, seed, m, hm), m => hm => mono(Tag, tail, name, seed, m, hm), ids, h, S.known(n, s, ids))
    case S.Within{scope, body} <> tail:
      mono_scoped(Tag, scope, tail, name, seed, m => hm => mono(Tag, tail, name, seed, m, hm), S.assemble(Tag, body, ids), mono(Tag, body, name, seed, ids, h))

def self_known(+name: String, +seed: String, +ids: List<&2, P.Identity>) -> {S.known(name, seed, P.Identity{name, seed} <> ids) == True{} : Bool}:
  Equal.cong(Bool, Bool, y => y || S.known(name, seed, ids), String.eq(name, name) && String.eq(seed, seed), True{}, Equal.trans(Bool, String.eq(name, name) && String.eq(seed, seed), True{} && String.eq(seed, seed), True{}, Equal.cong(Bool, Bool, y => y && String.eq(seed, seed), String.eq(name, name), True{}, Eq.string_eq_refl(name)), Eq.string_eq_refl(seed)))

def skip_known(-Tag: Data, +name: String, +seed: String, +second: List<&2, S.Step<Tag>>, +rest: List<&2, S.Step<Tag>>, +r: P.Builder<Tag>, hr: {S.known(name, seed, ids_of(Tag, r)) == True{} : Bool}) -> {S.sequel(Tag, r, m => S.assemble(Tag, S.Plugin{Some{P.Identity{name, seed}}, second} <> rest, m)) == S.sequel(Tag, r, m => S.assemble(Tag, rest, m)) : P.Builder<Tag>}:
  match r:
    case P.Builder{m, xs}:
      Equal.cong(Bool, P.Builder<Tag>, x => S.follow(Tag, xs, S.choose(Tag, x, u => S.assemble(Tag, rest, m), u => S.sequel(Tag, S.assemble(Tag, second, P.Identity{name, seed} <> m), k => S.assemble(Tag, rest, k)))), S.known(name, seed, m), True{}, hr)

def repeat_decided(-Tag: Data, +name: String, +seed: String, +first: List<&2, S.Step<Tag>>, +second: List<&2, S.Step<Tag>>, +rest: List<&2, S.Step<Tag>>, +ids: List<&2, P.Identity>, b: Bool, e: {S.known(name, seed, ids) == b : Bool}) -> {S.choose(Tag, b, u => S.assemble(Tag, S.Plugin{Some{P.Identity{name, seed}}, second} <> rest, ids), u => S.sequel(Tag, S.assemble(Tag, first, P.Identity{name, seed} <> ids), m => S.assemble(Tag, S.Plugin{Some{P.Identity{name, seed}}, second} <> rest, m))) == S.choose(Tag, b, u => S.assemble(Tag, rest, ids), u => S.sequel(Tag, S.assemble(Tag, first, P.Identity{name, seed} <> ids), m => S.assemble(Tag, rest, m))) : P.Builder<Tag>}:
  match b:
    case True{}:
      Equal.cong(Bool, P.Builder<Tag>, x => S.choose(Tag, x, u => S.assemble(Tag, rest, ids), u => S.sequel(Tag, S.assemble(Tag, second, P.Identity{name, seed} <> ids), m => S.assemble(Tag, rest, m))), S.known(name, seed, ids), True{}, e)
    case False{}:
      skip_known(Tag, name, seed, second, rest, S.assemble(Tag, first, P.Identity{name, seed} <> ids), mono(Tag, first, name, seed, P.Identity{name, seed} <> ids, self_known(name, seed, ids)))

def L.plugin_named_repeat(Tag, id, first, second, rest, app):
  match id:
    case P.Identity{name, seed}:
      match app:
        case P.Builder{ids, es}:
          Equal.trans(P.Builder<Tag>, S.run(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> S.Plugin{Some{P.Identity{name, seed}}, second} <> rest, P.Builder{ids, es}), S.follow(Tag, es, S.assemble(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> S.Plugin{Some{P.Identity{name, seed}}, second} <> rest, ids)), S.run(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> rest, P.Builder{ids, es}), L.plugin_first_use_assembly(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> S.Plugin{Some{P.Identity{name, seed}}, second} <> rest, ids, es), Equal.trans(P.Builder<Tag>, S.follow(Tag, es, S.assemble(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> S.Plugin{Some{P.Identity{name, seed}}, second} <> rest, ids)), S.follow(Tag, es, S.assemble(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> rest, ids)), S.run(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> rest, P.Builder{ids, es}), Equal.cong(P.Builder<Tag>, P.Builder<Tag>, x => S.follow(Tag, es, x), S.assemble(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> S.Plugin{Some{P.Identity{name, seed}}, second} <> rest, ids), S.assemble(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> rest, ids), repeat_decided(Tag, name, seed, first, second, rest, ids, S.known(name, seed, ids), {==})), Equal.sym(P.Builder<Tag>, S.run(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> rest, P.Builder{ids, es}), S.follow(Tag, es, S.assemble(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> rest, ids)), L.plugin_first_use_assembly(Tag, S.Plugin{Some{P.Identity{name, seed}}, first} <> rest, ids, es))))
