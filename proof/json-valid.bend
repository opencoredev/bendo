# Scalar validity of concatenated text.
import Base
import ../src/data/utf8.bend as U

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def valid_app(+x: String, +y: String) -> {U.valid(x ++ y) == U.valid(x) && U.valid(y) : Bool}:
  match x:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      %Equal.sym(Bool, U.valid(t ++ y), U.valid(t) && U.valid(y), valid_app(t, y)) : {U.scalar(c) && _ == (U.scalar(c) && U.valid(t)) && U.valid(y) : Bool}
      Equal.sym(Bool, (U.scalar(c) && U.valid(t)) && U.valid(y), U.scalar(c) && (U.valid(t) && U.valid(y)), and_assoc(U.scalar(c), U.valid(t), U.valid(y)))

def valid_cat(+x: String, +y: String, vx: {U.valid(x) == True{} : Bool}, vy: {U.valid(y) == True{} : Bool}) -> {U.valid(x ++ y) == True{} : Bool}:
  %Equal.sym(Bool, U.valid(x ++ y), U.valid(x) && U.valid(y), valid_app(x, y)) : {_ == True{} : Bool}
  %Equal.sym(Bool, U.valid(x), True{}, vx) : {_ && U.valid(y) == True{} : Bool}
  vy

def valid_cat3(+x: String, +y: String, +z: String, vx: {U.valid(x) == True{} : Bool}, vy: {U.valid(y) == True{} : Bool}, vz: {U.valid(z) == True{} : Bool}) -> {U.valid((x ++ y) ++ z) == True{} : Bool}:
  valid_cat(x ++ y, z, valid_cat(x, y, vx, vy), vz)
