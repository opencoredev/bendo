import Base
import ./spec.bend as S
import ./trie.bend as T

type RouterKind is Data:
  Spec{}
  Trie{}

# Prepare once from one table; keep both engines available for config dispatch.
type Prepared<-Tag: Data> is Data:
  Prepared{table: S.Table(Tag), trie: T.Trie<Tag>}

# BND-17 proved the trie equivalent to the reference router (LAWS.bend).
def default_kind() -> RouterKind:
  Trie{}

def prepare(-Tag: Data, +table: S.Table(Tag)) -> Prepared<Tag>:
  Prepared{table, T.build_trie(Tag, table)}

def route(-Tag: Data, kind: RouterKind, router: Prepared<Tag>, path: String) -> Maybe<&2, S.Match<Tag>>:
  match kind router:
    case Spec{} Prepared{table, trie}:
      S.route(Tag, table, path)
    case Trie{} Prepared{table, trie}:
      T.trie_route(Tag, trie, path)
