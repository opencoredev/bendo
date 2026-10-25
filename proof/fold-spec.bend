# BND-92: an independent ASCII case fold for header names.
#
# Bytes.fold, Text.lower and Base's String.to_lower all lower a character
# through Base's Char.to_lower, which adds 32 inside a numeric range. This
# specification does not use that range or any arithmetic: it lists the 26
# capital letters with their small letters and replaces a character only
# when it is one of them. Every other character, including every non-ASCII
# one, is kept.
import Base

type Letter is Data:
  Letter{capital: Char, small: Char}

def letters() -> List<&2, Letter>:
  [Letter{'A', 'a'}, Letter{'B', 'b'}, Letter{'C', 'c'}, Letter{'D', 'd'}, Letter{'E', 'e'}, Letter{'F', 'f'}, Letter{'G', 'g'}, Letter{'H', 'h'}, Letter{'I', 'i'}, Letter{'J', 'j'}, Letter{'K', 'k'}, Letter{'L', 'l'}, Letter{'M', 'm'}, Letter{'N', 'n'}, Letter{'O', 'o'}, Letter{'P', 'p'}, Letter{'Q', 'q'}, Letter{'R', 'r'}, Letter{'S', 's'}, Letter{'T', 't'}, Letter{'U', 'u'}, Letter{'V', 'v'}, Letter{'W', 'w'}, Letter{'X', 'x'}, Letter{'Y', 'y'}, Letter{'Z', 'z'}]

def small_pick(small: Char, rest: Char, same: Bool) -> Char:
  match same:
    case True{}: small
    case False{}: rest

# The small letter for a capital in the table, or the character itself.
def small(+c: Char, table: List<&2, Letter>) -> Char:
  match table:
    case Nil{}: c
    case Letter{capital, l} <> t: small_pick(l, small(c, t), Char.is_eq(capital, c))

# Character by character, in order.
def fold(s: String) -> String:
  match s:
    case SNil{}: SNil{}
    case SCon{c, t}: SCon{small(c, letters()), fold(t)}
