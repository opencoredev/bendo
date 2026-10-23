# Plugins are app-to-app functions over the same registration lists.
# Only identities and entries live in the app; no function is stored.
import Base
import ./table.bend as T
import ./scopes.bend as S
import ./compose.bend as C

# A named plugin's identity. Two identities are equal when both strings are.
type Identity is Data:
  Identity{name: String, seed: String}

type Builder<-Tag: Data> is Data:
  Builder{applied: List<&2, Identity>, entries: List<&2, T.Entry<Tag>>}

def same(a: Identity, b: Identity) -> Bool:
  Identity{an, aseed} = a
  Identity{bn, bseed} = b
  String.eq(an, bn) && String.eq(aseed, bseed)

def applied(+id: Identity, ids: List<&2, Identity>) -> Bool:
  match ids:
    case Nil{}: False{}
    case head <> tail: same(head, id) || applied(id, tail)

def register(-Tag: Data, app: Builder<Tag>, entries: List<&2, T.Entry<Tag>>) -> Builder<Tag>:
  Builder{ids, old} = app
  Builder{ids, List.append(&2, T.Entry<Tag>, old, entries)}

def use(-Tag: Data, app: Builder<Tag>, plugin: Builder<Tag> -> Builder<Tag>) -> Builder<Tag>:
  plugin(app)

# The identity is recorded before the body runs, so a body that uses its own
# plugin again skips it. A skipped body never runs and reserves nothing.
def entered(-Tag: Data, +id: Identity, ids: List<&2, Identity>, entries: List<&2, T.Entry<Tag>>, body: Builder<Tag> -> Builder<Tag>, seen: Bool) -> Builder<Tag>:
  match seen:
    case True{}: Builder{ids, entries}
    case False{}: body(Builder{id <> ids, entries})

def named(-Tag: Data, +id: Identity, app: Builder<Tag>, body: Builder<Tag> -> Builder<Tag>) -> Builder<Tag>:
  Builder{+ids, entries} = app
  entered(Tag, id, ids, entries, body, applied(id, ids))

def placed(-Tag: Data, entries: List<&2, T.Entry<Tag>>, wrap: List<&2, T.Entry<Tag>> -> List<&2, T.Entry<Tag>>, inner: Builder<Tag>) -> Builder<Tag>:
  Builder{ids, sub} = inner
  Builder{ids, List.append(&2, T.Entry<Tag>, entries, wrap(sub))}

# The body starts from an empty list but the shared identities. The scope's
# transform runs once, after the body returns, over only its contribution.
def within(-Tag: Data, app: Builder<Tag>, wrap: List<&2, T.Entry<Tag>> -> List<&2, T.Entry<Tag>>, body: Builder<Tag> -> Builder<Tag>) -> Builder<Tag>:
  Builder{ids, entries} = app
  placed(Tag, entries, wrap, body(Builder{ids, []}))

def mount(-Tag: Data, app: Builder<Tag>, prefix: String, body: Builder<Tag> -> Builder<Tag>) -> Builder<Tag>:
  within(Tag, app, sub => C.mount(Tag, prefix, sub), body)

def group(-Tag: Data, app: Builder<Tag>, prefix: String, hooks: List<&2, T.HookSpec<Tag>>, body: Builder<Tag> -> Builder<Tag>) -> Builder<Tag>:
  within(Tag, app, sub => C.group(Tag, prefix, hooks, sub), body)

def guard(-Tag: Data, app: Builder<Tag>, options: T.GuardOptions<Tag>, body: Builder<Tag> -> Builder<Tag>) -> Builder<Tag>:
  within(Tag, app, sub => S.guard(Tag, options, sub), body)

def entries(-Tag: Data, app: Builder<Tag>) -> List<&2, T.Entry<Tag>>:
  Builder{ids, xs} = app
  xs
