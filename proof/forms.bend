# Independent ordered lookup specification: select whole entries, then map values.
import Base
import ../src/data/urlencoded.bend as F
import ./utf8.bend as UP

def select(e: F.Entry, rest: List<&2, F.Entry>, same: Bool) -> List<&2, F.Entry>:
  match same:
    case True{}:
      e <> rest
    case False{}:
      rest

def matching(ps: List<&2, F.Entry>, +key: String) -> List<&2, F.Entry>:
  match ps:
    case Nil{}:
      []
    case F.Entry{+k, v} <> t:
      select(F.Entry{k, v}, matching(t, key), String.eq(k, key))

def values(ps: List<&2, F.Entry>) -> List<&2, String>:
  match ps:
    case Nil{}:
      []
    case F.Entry{k, v} <> t:
      v <> values(t)

def spec(ps: List<&2, F.Entry>, key: String) -> List<&2, String>:
  values(matching(ps, key))

def selected(+k: String, +v: String, +ps: List<&2, F.Entry>, same: Bool) -> {F.select_value(v, values(ps), same) == values(select(F.Entry{k, v}, ps, same)) : List<&2, String>}:
  match same:
    case True{}:
      {==}
    case False{}:
      {==}

def ordered_spec(+ps: List<&2, F.Entry>, +key: String) -> {F.queries_spec(ps, key) == spec(ps, key) : List<&2, String>}:
  match ps:
    case Nil{}:
      {==}
    case F.Entry{k, v} <> t:
      %Equal.sym(List<&2, String>, F.queries_spec(t, key), spec(t, key), ordered_spec(t, key)) : {F.select_value(v, _, String.eq(k, key)) == spec(F.Entry{k, v} <> t, key) : List<&2, String>}
      selected(k, v, matching(t, key), String.eq(k, key))

def select_append(+v: String, +xs: List<&2, String>, +acc: List<&2, String>, same: Bool) -> {List.append(&2, String, F.select_value(v, xs, same), acc) == F.select_value(v, List.append(&2, String, xs, acc), same) : List<&2, String>}:
  match same:
    case False{}:
      {==}
    case True{}:
      {==}

def queries_reverse(+ps: List<&2, F.Entry>, +rev: List<&2, F.Entry>, +key: String, +acc: List<&2, String>) -> {F.queries_go(List.reverse.go(&2, F.Entry, ps, rev), key, acc) == F.queries_go(rev, key, List.append(&2, String, F.queries_spec(ps, key), acc)) : List<&2, String>}:
  match ps:
    case Nil{}:
      {==}
    case F.Entry{k, v} <> t:
      %Equal.sym(List<&2, String>, List.append(&2, String, F.select_value(v, F.queries_spec(t, key), String.eq(k, key)), acc), F.select_value(v, List.append(&2, String, F.queries_spec(t, key), acc), String.eq(k, key)), select_append(v, F.queries_spec(t, key), acc, String.eq(k, key))) : {F.queries_go(List.reverse.go(&2, F.Entry, t, F.Entry{k, v} <> rev), key, acc) == F.queries_go(rev, key, _) : List<&2, String>}
      queries_reverse(t, F.Entry{k, v} <> rev, key, acc)

def queries_equiv(+ps: List<&2, F.Entry>, +key: String) -> {F.queries(ps, key) == F.queries_spec(ps, key) : List<&2, String>}:
  Equal.trans(List<&2, String>, F.queries(ps, key), List.append(&2, String, F.queries_spec(ps, key), []), F.queries_spec(ps, key), queries_reverse(ps, [], key, []), UP.append_nil(String, F.queries_spec(ps, key)))

def ordered(+ps: List<&2, F.Entry>, +key: String) -> {F.queries(ps, key) == spec(ps, key) : List<&2, String>}:
  Equal.trans(List<&2, String>, F.queries(ps, key), F.queries_spec(ps, key), spec(ps, key), queries_equiv(ps, key), ordered_spec(ps, key))
