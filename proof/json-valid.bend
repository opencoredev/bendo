# Scalar validity of concatenated text.
import Base
import ../src/data/utf8.bend as U

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def valid_app(+x: String, +y: String) -> {U.valid_spec(x ++ y) == U.valid_spec(x) && U.valid_spec(y) : Bool}:
  match x:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      %Equal.sym(Bool, U.valid_spec(t ++ y), U.valid_spec(t) && U.valid_spec(y), valid_app(t, y)) : {U.scalar(c) && _ == (U.scalar(c) && U.valid_spec(t)) && U.valid_spec(y) : Bool}
      Equal.sym(Bool, (U.scalar(c) && U.valid_spec(t)) && U.valid_spec(y), U.scalar(c) && (U.valid_spec(t) && U.valid_spec(y)), and_assoc(U.scalar(c), U.valid_spec(t), U.valid_spec(y)))

def valid_cat(+x: String, +y: String, vx: {U.valid_spec(x) == True{} : Bool}, vy: {U.valid_spec(y) == True{} : Bool}) -> {U.valid_spec(x ++ y) == True{} : Bool}:
  %Equal.sym(Bool, U.valid_spec(x ++ y), U.valid_spec(x) && U.valid_spec(y), valid_app(x, y)) : {_ == True{} : Bool}
  %Equal.sym(Bool, U.valid_spec(x), True{}, vx) : {_ && U.valid_spec(y) == True{} : Bool}
  vy

def valid_cat3(+x: String, +y: String, +z: String, vx: {U.valid_spec(x) == True{} : Bool}, vy: {U.valid_spec(y) == True{} : Bool}, vz: {U.valid_spec(z) == True{} : Bool}) -> {U.valid_spec((x ++ y) ++ z) == True{} : Bool}:
  valid_cat(x ++ y, z, valid_cat(x, y, vx, vy), vz)
