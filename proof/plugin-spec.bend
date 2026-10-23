# BND-26 independent first-use specification of plugin assembly. Membership
# and traversal are decided here, without the runtime registry helpers; scopes
# use the source specifications of mount, group and guard.
import Base
import ../src/app/table.bend as T
import ../src/app/plugin.bend as P
import ./compose-spec.bend as ComposeSpec
import ./scoped-assembly-spec.bend as AssemblySpec

# A plugin program as data, so laws can quantify over every use sequence.
type Scope<-Tag: Data> is Data:
  Mount{prefix: String}
  Group{prefix: String, hooks: List<&2, T.HookSpec<Tag>>}
  Guard{options: T.GuardOptions<Tag>}

type Step<-Tag: Data> is Data:
  Add{entries: List<&2, T.Entry<Tag>>}
  Plugin{id: Maybe<&2, P.Identity>, body: List<&2, Step<Tag>>}
  Within{scope: Scope<Tag>, body: List<&2, Step<Tag>>}

def known(+name: String, +seed: String, ids: List<&2, P.Identity>) -> Bool:
  match ids:
    case Nil{}: False{}
    case P.Identity{n, s} <> tail: (String.eq(n, name) && String.eq(s, seed)) || known(name, seed, tail)

def wrap(-Tag: Data, scope: Scope<Tag>, entries: List<&2, T.Entry<Tag>>) -> List<&2, T.Entry<Tag>>:
  match scope:
    case Mount{prefix}: ComposeSpec.mount(Tag, prefix, entries)
    case Group{prefix, hooks}: ComposeSpec.group(Tag, prefix, hooks, entries)
    case Guard{options}: AssemblySpec.guard(Tag, options, entries)

# Entries before a contribution stay first; identities are the contribution's.
def follow(-Tag: Data, entries: List<&2, T.Entry<Tag>>, result: P.Builder<Tag>) -> P.Builder<Tag>:
  P.Builder{ids, xs} = result
  P.Builder{ids, List.append(&2, T.Entry<Tag>, entries, xs)}

def sequel(-Tag: Data, first: P.Builder<Tag>, rest: List<&2, P.Identity> -> P.Builder<Tag>) -> P.Builder<Tag>:
  P.Builder{ids, xs} = first
  follow(Tag, xs, rest(ids))

def scoped(-Tag: Data, scope: Scope<Tag>, first: P.Builder<Tag>, rest: List<&2, P.Identity> -> P.Builder<Tag>) -> P.Builder<Tag>:
  P.Builder{ids, xs} = first
  follow(Tag, wrap(Tag, scope, xs), rest(ids))

def choose(-Tag: Data, seen: Bool, skip: Unit -> P.Builder<Tag>, take: Unit -> P.Builder<Tag>) -> P.Builder<Tag>:
  match seen:
    case True{}: skip(Unit{})
    case False{}: take(Unit{})

# The contribution of a program started with identities ids: its own entries
# in order, the body of each named plugin at its first use (that identity is
# reserved before its body), nothing from a repeat or anything inside one,
# and each scope applied to exactly its body's contribution.
def assemble(-Tag: Data, steps: List<&2, Step<Tag>>, +ids: List<&2, P.Identity>) -> P.Builder<Tag>:
  match steps:
    case Nil{}: P.Builder{ids, []}
    case Add{xs} <> tail: follow(Tag, xs, assemble(Tag, tail, ids))
    case Plugin{None{}, body} <> tail: sequel(Tag, assemble(Tag, body, ids), m => assemble(Tag, tail, m))
    case Plugin{Some{P.Identity{+name, +seed}}, body} <> +tail:
      choose(Tag, known(name, seed, ids), u => assemble(Tag, tail, ids), u => sequel(Tag, assemble(Tag, body, P.Identity{name, seed} <> ids), m => assemble(Tag, tail, m)))
    case Within{scope, body} <> tail: scoped(Tag, scope, assemble(Tag, body, ids), m => assemble(Tag, tail, m))

# Anonymous composition: every identity removed, and plain preorder lists.
def erase(-Tag: Data, steps: List<&2, Step<Tag>>) -> List<&2, Step<Tag>>:
  match steps:
    case Nil{}: []
    case Add{xs} <> tail: Add{xs} <> erase(Tag, tail)
    case Plugin{id, body} <> tail: Plugin{None{}, erase(Tag, body)} <> erase(Tag, tail)
    case Within{scope, body} <> tail: Within{scope, erase(Tag, body)} <> erase(Tag, tail)

def flatten(-Tag: Data, steps: List<&2, Step<Tag>>) -> List<&2, T.Entry<Tag>>:
  match steps:
    case Nil{}: []
    case Add{xs} <> tail: List.append(&2, T.Entry<Tag>, xs, flatten(Tag, tail))
    case Plugin{id, body} <> tail: List.append(&2, T.Entry<Tag>, flatten(Tag, body), flatten(Tag, tail))
    case Within{scope, body} <> tail: List.append(&2, T.Entry<Tag>, wrap(Tag, scope, flatten(Tag, body)), flatten(Tag, tail))

# The interpreter runs a program only through the public plugin combinators.
def within(-Tag: Data, scope: Scope<Tag>, app: P.Builder<Tag>, body: P.Builder<Tag> -> P.Builder<Tag>) -> P.Builder<Tag>:
  match scope:
    case Mount{prefix}: P.mount(Tag, app, prefix, body)
    case Group{prefix, hooks}: P.group(Tag, app, prefix, hooks, body)
    case Guard{options}: P.guard(Tag, app, options, body)

def run(-Tag: Data, steps: List<&2, Step<Tag>>, app: P.Builder<Tag>) -> P.Builder<Tag>:
  match steps:
    case Nil{}: app
    case Add{xs} <> tail: run(Tag, tail, P.register(Tag, app, xs))
    case Plugin{None{}, body} <> tail: run(Tag, tail, P.use(Tag, app, a => run(Tag, body, a)))
    case Plugin{Some{id}, body} <> tail: run(Tag, tail, P.named(Tag, id, app, a => run(Tag, body, a)))
    case Within{scope, body} <> tail: run(Tag, tail, within(Tag, scope, app, a => run(Tag, body, a)))
