import Base
import ../src/data/cookie.bend as C
import ./cookie-serialization-spec.bend as Independent

# Every finite mixture of SP and HTAB, chosen independently for each side.
type Padding is Data:
  Empty{}
  Space{tail: Padding}
  Tab{tail: Padding}

def prefix(p: Padding, s: String) -> String:
  match p:
    case Empty{}: s
    case Space{t}: SCon{' ', prefix(t, s)}
    case Tab{t}: SCon{'\t', prefix(t, s)}

type PaddedEntry is Data:
  PaddedEntry{before: Padding, name: String, value: String, after: Padding}

def pair(entry: PaddedEntry) -> String:
  match entry:
    case PaddedEntry{before, name, value, after}:
      prefix(before, (name ++ "=" ++ value) ++ prefix(after, ""))

def entries_valid(xs: List<&2, C.Entry>) -> Bool:
  match xs:
    case Nil{}: True{}
    case C.Entry{+name, +value} <> t:
      Independent.name_valid(name) && Independent.value_valid(value) && entries_valid(t)

def pairs(xs: List<&2, C.Entry>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case C.Entry{name, value} <> t: (name ++ "=" ++ value) <> pairs(t)

def padded_valid(xs: List<&2, PaddedEntry>) -> Bool:
  match xs:
    case Nil{}: True{}
    case PaddedEntry{before, +name, +value, after} <> t:
      Independent.name_valid(name) && Independent.value_valid(value) && padded_valid(t)

def padded_pairs(xs: List<&2, PaddedEntry>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case h <> t: pair(h) <> padded_pairs(t)

def unpad(xs: List<&2, PaddedEntry>) -> List<&2, C.Entry>:
  match xs:
    case Nil{}: []
    case PaddedEntry{before, name, value, after} <> t:
      C.Entry{name, value} <> unpad(t)
