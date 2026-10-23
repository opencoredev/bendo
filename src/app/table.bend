import Base
import ../router/methods.bend as Methods

# Keep exact source spellings for the manifest beside the compiled route data.
# The compiled index holds the validated table and its trie, built once.
type Table<-Tag: Data> is Data:
  Table{entries: List<&2, Methods.Registration(Tag)>, compiled: Methods.Index<Tag>}

def built(-Tag: Data, entries: List<&2, Methods.Registration(Tag)>, result: Result<&2, &2, Methods.BuildError, Methods.Valid<Tag>>) -> Result<&2, &2, Methods.BuildError, Table<Tag>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{table}: Done{Table{entries, Methods.prepare(Tag, table)}}

def build(-Tag: Data, +entries: List<&2, Methods.Registration(Tag)>) -> Result<&2, &2, Methods.BuildError, Table<Tag>>:
  built(Tag, entries, Methods.build_table(Tag, entries))
