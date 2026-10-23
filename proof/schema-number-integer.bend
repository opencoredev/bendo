# Lexical integer acceptance agrees with the independent scalar specification.
import Base
import ../src/data/decimal.bend as D
import ../src/data/json.bend as J
import ../src/data/schema-spec.bend as Spec
import ./utf8.bend as UP

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def and_comm(+a: Bool, +b: Bool) -> {a && b == b && a : Bool}:
  match a b:
    case False{} False{}: {==}
    case False{} True{}: {==}
    case True{} False{}: {==}
    case True{} True{}: {==}

def integer_go_equiv(+s: String, +ok: Bool) -> {D.integer_go(s, ok) == ok && Spec.digits(s) : Bool}:
  match s:
    case SNil{}:
      match ok:
        case False{}: {==}
        case True{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, D.integer_go(t, ok && J.digit(c)), (ok && J.digit(c)) && Spec.digits(t), integer_go_equiv(t, ok && J.digit(c))) : {_ == ok && Spec.digits(SCon{Chr{c}, t}) : Bool}
      and_assoc(ok, J.digit(c), Spec.digits(t))

def integer_digits(+s: String) -> {D.integer(s) == Spec.digits(s) : Bool}:
  integer_go_equiv(s, True{})

def invalid(+s: String) -> {J.number_valid_go(s, J.PInvalid{}) == False{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: invalid(t)

# Enumerate ASCII digits and the complement by its highest set bit. Every
# non-digit branch short-circuits before inspecting the arbitrary suffix.
def digit_step_bits(+b31: Bool, +b30: Bool, +b29: Bool, +b28: Bool, +b27: Bool, +b26: Bool, +b25: Bool, +b24: Bool, +b23: Bool, +b22: Bool, +b21: Bool, +b20: Bool, +b19: Bool, +b18: Bool, +b17: Bool, +b16: Bool, +b15: Bool, +b14: Bool, +b13: Bool, +b12: Bool, +b11: Bool, +b10: Bool, +b9: Bool, +b8: Bool, +b7: Bool, +b6: Bool, +b5: Bool, +b4: Bool, +b3: Bool, +b2: Bool, +b1: Bool, +b0: Bool, +t: String) -> {Spec.digit(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) && J.number_valid_go(t, J.number_step(J.PInteger{}, U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}})) == Spec.digit(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) && J.number_valid_go(t, J.PInteger{}) : Bool}:
  match b31:
    case True{}: {==}
    case False{}:
      match b30:
        case True{}: {==}
        case False{}:
          match b29:
            case True{}: {==}
            case False{}:
              match b28:
                case True{}: {==}
                case False{}:
                  match b27:
                    case True{}: {==}
                    case False{}:
                      match b26:
                        case True{}: {==}
                        case False{}:
                          match b25:
                            case True{}: {==}
                            case False{}:
                              match b24:
                                case True{}: {==}
                                case False{}:
                                  match b23:
                                    case True{}: {==}
                                    case False{}:
                                      match b22:
                                        case True{}: {==}
                                        case False{}:
                                          match b21:
                                            case True{}: {==}
                                            case False{}:
                                              match b20:
                                                case True{}: {==}
                                                case False{}:
                                                  match b19:
                                                    case True{}: {==}
                                                    case False{}:
                                                      match b18:
                                                        case True{}: {==}
                                                        case False{}:
                                                          match b17:
                                                            case True{}: {==}
                                                            case False{}:
                                                              match b16:
                                                                case True{}: {==}
                                                                case False{}:
                                                                  match b15:
                                                                    case True{}: {==}
                                                                    case False{}:
                                                                      match b14:
                                                                        case True{}: {==}
                                                                        case False{}:
                                                                          match b13:
                                                                            case True{}: {==}
                                                                            case False{}:
                                                                              match b12:
                                                                                case True{}: {==}
                                                                                case False{}:
                                                                                  match b11:
                                                                                    case True{}: {==}
                                                                                    case False{}:
                                                                                      match b10:
                                                                                        case True{}: {==}
                                                                                        case False{}:
                                                                                          match b9:
                                                                                            case True{}: {==}
                                                                                            case False{}:
                                                                                              match b8:
                                                                                                case True{}: {==}
                                                                                                case False{}:
                                                                                                  match b7:
                                                                                                    case True{}: {==}
                                                                                                    case False{}:
                                                                                                      match b6:
                                                                                                        case True{}: {==}
                                                                                                        case False{}:
                                                                                                          match b5 b4 b3 b2 b1 b0:
                                                                                                            case False{} False{} False{} False{} False{} False{}: {==}
                                                                                                            case False{} False{} False{} False{} False{} True{}: {==}
                                                                                                            case False{} False{} False{} False{} True{} False{}: {==}
                                                                                                            case False{} False{} False{} False{} True{} True{}: {==}
                                                                                                            case False{} False{} False{} True{} False{} False{}: {==}
                                                                                                            case False{} False{} False{} True{} False{} True{}: {==}
                                                                                                            case False{} False{} False{} True{} True{} False{}: {==}
                                                                                                            case False{} False{} False{} True{} True{} True{}: {==}
                                                                                                            case False{} False{} True{} False{} False{} False{}: {==}
                                                                                                            case False{} False{} True{} False{} False{} True{}: {==}
                                                                                                            case False{} False{} True{} False{} True{} False{}: {==}
                                                                                                            case False{} False{} True{} False{} True{} True{}: {==}
                                                                                                            case False{} False{} True{} True{} False{} False{}: {==}
                                                                                                            case False{} False{} True{} True{} False{} True{}: {==}
                                                                                                            case False{} False{} True{} True{} True{} False{}: {==}
                                                                                                            case False{} False{} True{} True{} True{} True{}: {==}
                                                                                                            case False{} True{} False{} False{} False{} False{}: {==}
                                                                                                            case False{} True{} False{} False{} False{} True{}: {==}
                                                                                                            case False{} True{} False{} False{} True{} False{}: {==}
                                                                                                            case False{} True{} False{} False{} True{} True{}: {==}
                                                                                                            case False{} True{} False{} True{} False{} False{}: {==}
                                                                                                            case False{} True{} False{} True{} False{} True{}: {==}
                                                                                                            case False{} True{} False{} True{} True{} False{}: {==}
                                                                                                            case False{} True{} False{} True{} True{} True{}: {==}
                                                                                                            case False{} True{} True{} False{} False{} False{}: {==}
                                                                                                            case False{} True{} True{} False{} False{} True{}: {==}
                                                                                                            case False{} True{} True{} False{} True{} False{}: {==}
                                                                                                            case False{} True{} True{} False{} True{} True{}: {==}
                                                                                                            case False{} True{} True{} True{} False{} False{}: {==}
                                                                                                            case False{} True{} True{} True{} False{} True{}: {==}
                                                                                                            case False{} True{} True{} True{} True{} False{}: {==}
                                                                                                            case False{} True{} True{} True{} True{} True{}: {==}
                                                                                                            case True{} False{} False{} False{} False{} False{}: {==}
                                                                                                            case True{} False{} False{} False{} False{} True{}: {==}
                                                                                                            case True{} False{} False{} False{} True{} False{}: {==}
                                                                                                            case True{} False{} False{} False{} True{} True{}: {==}
                                                                                                            case True{} False{} False{} True{} False{} False{}: {==}
                                                                                                            case True{} False{} False{} True{} False{} True{}: {==}
                                                                                                            case True{} False{} False{} True{} True{} False{}: {==}
                                                                                                            case True{} False{} False{} True{} True{} True{}: {==}
                                                                                                            case True{} False{} True{} False{} False{} False{}: {==}
                                                                                                            case True{} False{} True{} False{} False{} True{}: {==}
                                                                                                            case True{} False{} True{} False{} True{} False{}: {==}
                                                                                                            case True{} False{} True{} False{} True{} True{}: {==}
                                                                                                            case True{} False{} True{} True{} False{} False{}: {==}
                                                                                                            case True{} False{} True{} True{} False{} True{}: {==}
                                                                                                            case True{} False{} True{} True{} True{} False{}: {==}
                                                                                                            case True{} False{} True{} True{} True{} True{}: {==}
                                                                                                            case True{} True{} False{} False{} False{} False{}: {==}
                                                                                                            case True{} True{} False{} False{} False{} True{}: {==}
                                                                                                            case True{} True{} False{} False{} True{} False{}: {==}
                                                                                                            case True{} True{} False{} False{} True{} True{}: {==}
                                                                                                            case True{} True{} False{} True{} False{} False{}: {==}
                                                                                                            case True{} True{} False{} True{} False{} True{}: {==}
                                                                                                            case True{} True{} False{} True{} True{} False{}: {==}
                                                                                                            case True{} True{} False{} True{} True{} True{}: {==}
                                                                                                            case True{} True{} True{} False{} False{} False{}: {==}
                                                                                                            case True{} True{} True{} False{} False{} True{}: {==}
                                                                                                            case True{} True{} True{} False{} True{} False{}: {==}
                                                                                                            case True{} True{} True{} False{} True{} True{}: {==}
                                                                                                            case True{} True{} True{} True{} False{} False{}: {==}
                                                                                                            case True{} True{} True{} True{} False{} True{}: {==}
                                                                                                            case True{} True{} True{} True{} True{} False{}: {==}
                                                                                                            case True{} True{} True{} True{} True{} True{}: {==}


def digit_step(+c: U32, +t: String) -> {Spec.digit(c) && J.number_valid_go(t, J.number_step(J.PInteger{}, c)) == Spec.digit(c) && J.number_valid_go(t, J.PInteger{}) : Bool}:
  match c:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      digit_step_bits(b31, b30, b29, b28, b27, b26, b25, b24, b23, b22, b21, b20, b19, b18, b17, b16, b15, b14, b13, b12, b11, b10, b9, b8, b7, b6, b5, b4, b3, b2, b1, b0, t)


def restrict_cons(+d: Bool, +rest: Bool, +next: Bool, +loop: Bool, step: {d && next == d && loop : Bool}, ih: {rest && loop == rest : Bool}) -> {(d && rest) && next == d && rest : Bool}:
  match d rest:
    case False{} _: {==}
    case True{} False{}: {==}
    case True{} True{}: Equal.trans(Bool, next, loop, True{}, step, ih)

def digits_accept(+s: String) -> {Spec.digits(s) && J.number_valid_go(s, J.PInteger{}) == Spec.digits(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      restrict_cons(Spec.digit(c), Spec.digits(t), J.number_valid_go(t, J.number_step(J.PInteger{}, c)), J.number_valid_go(t, J.PInteger{}), digit_step(c, t), digits_accept(t))

def restrict_false(+d: Bool, +rest: Bool, +next: Bool, step: {d && next == False{} : Bool}) -> {(d && rest) && next == False{} : Bool}:
  match d rest:
    case False{} _: {==}
    case True{} False{}: {==}
    case True{} True{}: step

def zero_step_bits(+b31: Bool, +b30: Bool, +b29: Bool, +b28: Bool, +b27: Bool, +b26: Bool, +b25: Bool, +b24: Bool, +b23: Bool, +b22: Bool, +b21: Bool, +b20: Bool, +b19: Bool, +b18: Bool, +b17: Bool, +b16: Bool, +b15: Bool, +b14: Bool, +b13: Bool, +b12: Bool, +b11: Bool, +b10: Bool, +b9: Bool, +b8: Bool, +b7: Bool, +b6: Bool, +b5: Bool, +b4: Bool, +b3: Bool, +b2: Bool, +b1: Bool, +b0: Bool, +t: String) -> {Spec.digit(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) && J.number_valid_go(t, J.number_step(J.PZero{}, U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}})) == False{} : Bool}:
  match b31:
    case True{}: {==}
    case False{}:
      match b30:
        case True{}: {==}
        case False{}:
          match b29:
            case True{}: {==}
            case False{}:
              match b28:
                case True{}: {==}
                case False{}:
                  match b27:
                    case True{}: {==}
                    case False{}:
                      match b26:
                        case True{}: {==}
                        case False{}:
                          match b25:
                            case True{}: {==}
                            case False{}:
                              match b24:
                                case True{}: {==}
                                case False{}:
                                  match b23:
                                    case True{}: {==}
                                    case False{}:
                                      match b22:
                                        case True{}: {==}
                                        case False{}:
                                          match b21:
                                            case True{}: {==}
                                            case False{}:
                                              match b20:
                                                case True{}: {==}
                                                case False{}:
                                                  match b19:
                                                    case True{}: {==}
                                                    case False{}:
                                                      match b18:
                                                        case True{}: {==}
                                                        case False{}:
                                                          match b17:
                                                            case True{}: {==}
                                                            case False{}:
                                                              match b16:
                                                                case True{}: {==}
                                                                case False{}:
                                                                  match b15:
                                                                    case True{}: {==}
                                                                    case False{}:
                                                                      match b14:
                                                                        case True{}: {==}
                                                                        case False{}:
                                                                          match b13:
                                                                            case True{}: {==}
                                                                            case False{}:
                                                                              match b12:
                                                                                case True{}: {==}
                                                                                case False{}:
                                                                                  match b11:
                                                                                    case True{}: {==}
                                                                                    case False{}:
                                                                                      match b10:
                                                                                        case True{}: {==}
                                                                                        case False{}:
                                                                                          match b9:
                                                                                            case True{}: {==}
                                                                                            case False{}:
                                                                                              match b8:
                                                                                                case True{}: {==}
                                                                                                case False{}:
                                                                                                  match b7:
                                                                                                    case True{}: {==}
                                                                                                    case False{}:
                                                                                                      match b6:
                                                                                                        case True{}: {==}
                                                                                                        case False{}:
                                                                                                          match b5 b4 b3 b2 b1 b0:
                                                                                                            case False{} False{} False{} False{} False{} False{}: {==}
                                                                                                            case False{} False{} False{} False{} False{} True{}: {==}
                                                                                                            case False{} False{} False{} False{} True{} False{}: {==}
                                                                                                            case False{} False{} False{} False{} True{} True{}: {==}
                                                                                                            case False{} False{} False{} True{} False{} False{}: {==}
                                                                                                            case False{} False{} False{} True{} False{} True{}: {==}
                                                                                                            case False{} False{} False{} True{} True{} False{}: {==}
                                                                                                            case False{} False{} False{} True{} True{} True{}: {==}
                                                                                                            case False{} False{} True{} False{} False{} False{}: {==}
                                                                                                            case False{} False{} True{} False{} False{} True{}: {==}
                                                                                                            case False{} False{} True{} False{} True{} False{}: {==}
                                                                                                            case False{} False{} True{} False{} True{} True{}: {==}
                                                                                                            case False{} False{} True{} True{} False{} False{}: {==}
                                                                                                            case False{} False{} True{} True{} False{} True{}: {==}
                                                                                                            case False{} False{} True{} True{} True{} False{}: {==}
                                                                                                            case False{} False{} True{} True{} True{} True{}: {==}
                                                                                                            case False{} True{} False{} False{} False{} False{}: {==}
                                                                                                            case False{} True{} False{} False{} False{} True{}: {==}
                                                                                                            case False{} True{} False{} False{} True{} False{}: {==}
                                                                                                            case False{} True{} False{} False{} True{} True{}: {==}
                                                                                                            case False{} True{} False{} True{} False{} False{}: {==}
                                                                                                            case False{} True{} False{} True{} False{} True{}: {==}
                                                                                                            case False{} True{} False{} True{} True{} False{}: {==}
                                                                                                            case False{} True{} False{} True{} True{} True{}: {==}
                                                                                                            case False{} True{} True{} False{} False{} False{}: {==}
                                                                                                            case False{} True{} True{} False{} False{} True{}: {==}
                                                                                                            case False{} True{} True{} False{} True{} False{}: {==}
                                                                                                            case False{} True{} True{} False{} True{} True{}: {==}
                                                                                                            case False{} True{} True{} True{} False{} False{}: {==}
                                                                                                            case False{} True{} True{} True{} False{} True{}: {==}
                                                                                                            case False{} True{} True{} True{} True{} False{}: {==}
                                                                                                            case False{} True{} True{} True{} True{} True{}: {==}
                                                                                                            case True{} False{} False{} False{} False{} False{}: {==}
                                                                                                            case True{} False{} False{} False{} False{} True{}: {==}
                                                                                                            case True{} False{} False{} False{} True{} False{}: {==}
                                                                                                            case True{} False{} False{} False{} True{} True{}: {==}
                                                                                                            case True{} False{} False{} True{} False{} False{}: {==}
                                                                                                            case True{} False{} False{} True{} False{} True{}: {==}
                                                                                                            case True{} False{} False{} True{} True{} False{}: {==}
                                                                                                            case True{} False{} False{} True{} True{} True{}: {==}
                                                                                                            case True{} False{} True{} False{} False{} False{}: {==}
                                                                                                            case True{} False{} True{} False{} False{} True{}: {==}
                                                                                                            case True{} False{} True{} False{} True{} False{}: {==}
                                                                                                            case True{} False{} True{} False{} True{} True{}: {==}
                                                                                                            case True{} False{} True{} True{} False{} False{}: {==}
                                                                                                            case True{} False{} True{} True{} False{} True{}: {==}
                                                                                                            case True{} False{} True{} True{} True{} False{}: {==}
                                                                                                            case True{} False{} True{} True{} True{} True{}: {==}
                                                                                                            case True{} True{} False{} False{} False{} False{}: invalid(t)
                                                                                                            case True{} True{} False{} False{} False{} True{}: invalid(t)
                                                                                                            case True{} True{} False{} False{} True{} False{}: invalid(t)
                                                                                                            case True{} True{} False{} False{} True{} True{}: invalid(t)
                                                                                                            case True{} True{} False{} True{} False{} False{}: invalid(t)
                                                                                                            case True{} True{} False{} True{} False{} True{}: invalid(t)
                                                                                                            case True{} True{} False{} True{} True{} False{}: invalid(t)
                                                                                                            case True{} True{} False{} True{} True{} True{}: invalid(t)
                                                                                                            case True{} True{} True{} False{} False{} False{}: invalid(t)
                                                                                                            case True{} True{} True{} False{} False{} True{}: invalid(t)
                                                                                                            case True{} True{} True{} False{} True{} False{}: {==}
                                                                                                            case True{} True{} True{} False{} True{} True{}: {==}
                                                                                                            case True{} True{} True{} True{} False{} False{}: {==}
                                                                                                            case True{} True{} True{} True{} False{} True{}: {==}
                                                                                                            case True{} True{} True{} True{} True{} False{}: {==}
                                                                                                            case True{} True{} True{} True{} True{} True{}: {==}


def zero_step(+c: U32, +t: String) -> {Spec.digit(c) && J.number_valid_go(t, J.number_step(J.PZero{}, c)) == False{} : Bool}:
  match c:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      zero_step_bits(b31, b30, b29, b28, b27, b26, b25, b24, b23, b22, b21, b20, b19, b18, b17, b16, b15, b14, b13, b12, b11, b10, b9, b8, b7, b6, b5, b4, b3, b2, b1, b0, t)


def zero_accept(+s: String) -> {Spec.digits(s) && J.number_valid_go(s, J.PZero{}) == String.is_empty(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      restrict_false(Spec.digit(c), Spec.digits(t), J.number_valid_go(t, J.number_step(J.PZero{}, c)), zero_step(c, t))

def unsigned_step_bits(+b31: Bool, +b30: Bool, +b29: Bool, +b28: Bool, +b27: Bool, +b26: Bool, +b25: Bool, +b24: Bool, +b23: Bool, +b22: Bool, +b21: Bool, +b20: Bool, +b19: Bool, +b18: Bool, +b17: Bool, +b16: Bool, +b15: Bool, +b14: Bool, +b13: Bool, +b12: Bool, +b11: Bool, +b10: Bool, +b9: Bool, +b8: Bool, +b7: Bool, +b6: Bool, +b5: Bool, +b4: Bool, +b3: Bool, +b2: Bool, +b1: Bool, +b0: Bool, +t: String) -> {(Spec.digit(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) && Spec.digits(t)) && J.number_valid_go(t, J.number_step(J.PMinus{}, U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}})) == Spec.unsigned_integer(SCon{Chr{U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}) : Bool}:
  match b31:
    case True{}: {==}
    case False{}:
      match b30:
        case True{}: {==}
        case False{}:
          match b29:
            case True{}: {==}
            case False{}:
              match b28:
                case True{}: {==}
                case False{}:
                  match b27:
                    case True{}: {==}
                    case False{}:
                      match b26:
                        case True{}: {==}
                        case False{}:
                          match b25:
                            case True{}: {==}
                            case False{}:
                              match b24:
                                case True{}: {==}
                                case False{}:
                                  match b23:
                                    case True{}: {==}
                                    case False{}:
                                      match b22:
                                        case True{}: {==}
                                        case False{}:
                                          match b21:
                                            case True{}: {==}
                                            case False{}:
                                              match b20:
                                                case True{}: {==}
                                                case False{}:
                                                  match b19:
                                                    case True{}: {==}
                                                    case False{}:
                                                      match b18:
                                                        case True{}: {==}
                                                        case False{}:
                                                          match b17:
                                                            case True{}: {==}
                                                            case False{}:
                                                              match b16:
                                                                case True{}: {==}
                                                                case False{}:
                                                                  match b15:
                                                                    case True{}: {==}
                                                                    case False{}:
                                                                      match b14:
                                                                        case True{}: {==}
                                                                        case False{}:
                                                                          match b13:
                                                                            case True{}: {==}
                                                                            case False{}:
                                                                              match b12:
                                                                                case True{}: {==}
                                                                                case False{}:
                                                                                  match b11:
                                                                                    case True{}: {==}
                                                                                    case False{}:
                                                                                      match b10:
                                                                                        case True{}: {==}
                                                                                        case False{}:
                                                                                          match b9:
                                                                                            case True{}: {==}
                                                                                            case False{}:
                                                                                              match b8:
                                                                                                case True{}: {==}
                                                                                                case False{}:
                                                                                                  match b7:
                                                                                                    case True{}: {==}
                                                                                                    case False{}:
                                                                                                      match b6:
                                                                                                        case True{}: {==}
                                                                                                        case False{}:
                                                                                                          match b5 b4 b3 b2 b1 b0:
                                                                                                            case False{} False{} False{} False{} False{} False{}: {==}
                                                                                                            case False{} False{} False{} False{} False{} True{}: {==}
                                                                                                            case False{} False{} False{} False{} True{} False{}: {==}
                                                                                                            case False{} False{} False{} False{} True{} True{}: {==}
                                                                                                            case False{} False{} False{} True{} False{} False{}: {==}
                                                                                                            case False{} False{} False{} True{} False{} True{}: {==}
                                                                                                            case False{} False{} False{} True{} True{} False{}: {==}
                                                                                                            case False{} False{} False{} True{} True{} True{}: {==}
                                                                                                            case False{} False{} True{} False{} False{} False{}: {==}
                                                                                                            case False{} False{} True{} False{} False{} True{}: {==}
                                                                                                            case False{} False{} True{} False{} True{} False{}: {==}
                                                                                                            case False{} False{} True{} False{} True{} True{}: {==}
                                                                                                            case False{} False{} True{} True{} False{} False{}: {==}
                                                                                                            case False{} False{} True{} True{} False{} True{}: {==}
                                                                                                            case False{} False{} True{} True{} True{} False{}: {==}
                                                                                                            case False{} False{} True{} True{} True{} True{}: {==}
                                                                                                            case False{} True{} False{} False{} False{} False{}: {==}
                                                                                                            case False{} True{} False{} False{} False{} True{}: {==}
                                                                                                            case False{} True{} False{} False{} True{} False{}: {==}
                                                                                                            case False{} True{} False{} False{} True{} True{}: {==}
                                                                                                            case False{} True{} False{} True{} False{} False{}: {==}
                                                                                                            case False{} True{} False{} True{} False{} True{}: {==}
                                                                                                            case False{} True{} False{} True{} True{} False{}: {==}
                                                                                                            case False{} True{} False{} True{} True{} True{}: {==}
                                                                                                            case False{} True{} True{} False{} False{} False{}: {==}
                                                                                                            case False{} True{} True{} False{} False{} True{}: {==}
                                                                                                            case False{} True{} True{} False{} True{} False{}: {==}
                                                                                                            case False{} True{} True{} False{} True{} True{}: {==}
                                                                                                            case False{} True{} True{} True{} False{} False{}: {==}
                                                                                                            case False{} True{} True{} True{} False{} True{}: {==}
                                                                                                            case False{} True{} True{} True{} True{} False{}: {==}
                                                                                                            case False{} True{} True{} True{} True{} True{}: {==}
                                                                                                            case True{} False{} False{} False{} False{} False{}: {==}
                                                                                                            case True{} False{} False{} False{} False{} True{}: {==}
                                                                                                            case True{} False{} False{} False{} True{} False{}: {==}
                                                                                                            case True{} False{} False{} False{} True{} True{}: {==}
                                                                                                            case True{} False{} False{} True{} False{} False{}: {==}
                                                                                                            case True{} False{} False{} True{} False{} True{}: {==}
                                                                                                            case True{} False{} False{} True{} True{} False{}: {==}
                                                                                                            case True{} False{} False{} True{} True{} True{}: {==}
                                                                                                            case True{} False{} True{} False{} False{} False{}: {==}
                                                                                                            case True{} False{} True{} False{} False{} True{}: {==}
                                                                                                            case True{} False{} True{} False{} True{} False{}: {==}
                                                                                                            case True{} False{} True{} False{} True{} True{}: {==}
                                                                                                            case True{} False{} True{} True{} False{} False{}: {==}
                                                                                                            case True{} False{} True{} True{} False{} True{}: {==}
                                                                                                            case True{} False{} True{} True{} True{} False{}: {==}
                                                                                                            case True{} False{} True{} True{} True{} True{}: {==}
                                                                                                            case True{} True{} False{} False{} False{} False{}: zero_accept(t)
                                                                                                            case True{} True{} False{} False{} False{} True{}: digits_accept(t)
                                                                                                            case True{} True{} False{} False{} True{} False{}: digits_accept(t)
                                                                                                            case True{} True{} False{} False{} True{} True{}: digits_accept(t)
                                                                                                            case True{} True{} False{} True{} False{} False{}: digits_accept(t)
                                                                                                            case True{} True{} False{} True{} False{} True{}: digits_accept(t)
                                                                                                            case True{} True{} False{} True{} True{} False{}: digits_accept(t)
                                                                                                            case True{} True{} False{} True{} True{} True{}: digits_accept(t)
                                                                                                            case True{} True{} True{} False{} False{} False{}: digits_accept(t)
                                                                                                            case True{} True{} True{} False{} False{} True{}: digits_accept(t)
                                                                                                            case True{} True{} True{} False{} True{} False{}: {==}
                                                                                                            case True{} True{} True{} False{} True{} True{}: {==}
                                                                                                            case True{} True{} True{} True{} False{} False{}: {==}
                                                                                                            case True{} True{} True{} True{} False{} True{}: {==}
                                                                                                            case True{} True{} True{} True{} True{} False{}: {==}
                                                                                                            case True{} True{} True{} True{} True{} True{}: {==}


def unsigned_step(+c: U32, +t: String) -> {(Spec.digit(c) && Spec.digits(t)) && J.number_valid_go(t, J.number_step(J.PMinus{}, c)) == Spec.unsigned_integer(SCon{Chr{c}, t}) : Bool}:
  match c:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      unsigned_step_bits(b31, b30, b29, b28, b27, b26, b25, b24, b23, b22, b21, b20, b19, b18, b17, b16, b15, b14, b13, b12, b11, b10, b9, b8, b7, b6, b5, b4, b3, b2, b1, b0, t)


def unsigned_restrict(+s: String) -> {Spec.digits(s) && J.number_valid_go(s, J.PMinus{}) == Spec.unsigned_integer(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: unsigned_step(c, t)

def start_step_bits(+b31: Bool, +b30: Bool, +b29: Bool, +b28: Bool, +b27: Bool, +b26: Bool, +b25: Bool, +b24: Bool, +b23: Bool, +b22: Bool, +b21: Bool, +b20: Bool, +b19: Bool, +b18: Bool, +b17: Bool, +b16: Bool, +b15: Bool, +b14: Bool, +b13: Bool, +b12: Bool, +b11: Bool, +b10: Bool, +b9: Bool, +b8: Bool, +b7: Bool, +b6: Bool, +b5: Bool, +b4: Bool, +b3: Bool, +b2: Bool, +b1: Bool, +b0: Bool, +t: String) -> {(Spec.digit(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) && Spec.digits(t)) && J.number_valid_go(t, J.number_step(J.PStart{}, U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}})) == Spec.unsigned_integer(SCon{Chr{U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}) : Bool}:
  match b31:
    case True{}: {==}
    case False{}:
      match b30:
        case True{}: {==}
        case False{}:
          match b29:
            case True{}: {==}
            case False{}:
              match b28:
                case True{}: {==}
                case False{}:
                  match b27:
                    case True{}: {==}
                    case False{}:
                      match b26:
                        case True{}: {==}
                        case False{}:
                          match b25:
                            case True{}: {==}
                            case False{}:
                              match b24:
                                case True{}: {==}
                                case False{}:
                                  match b23:
                                    case True{}: {==}
                                    case False{}:
                                      match b22:
                                        case True{}: {==}
                                        case False{}:
                                          match b21:
                                            case True{}: {==}
                                            case False{}:
                                              match b20:
                                                case True{}: {==}
                                                case False{}:
                                                  match b19:
                                                    case True{}: {==}
                                                    case False{}:
                                                      match b18:
                                                        case True{}: {==}
                                                        case False{}:
                                                          match b17:
                                                            case True{}: {==}
                                                            case False{}:
                                                              match b16:
                                                                case True{}: {==}
                                                                case False{}:
                                                                  match b15:
                                                                    case True{}: {==}
                                                                    case False{}:
                                                                      match b14:
                                                                        case True{}: {==}
                                                                        case False{}:
                                                                          match b13:
                                                                            case True{}: {==}
                                                                            case False{}:
                                                                              match b12:
                                                                                case True{}: {==}
                                                                                case False{}:
                                                                                  match b11:
                                                                                    case True{}: {==}
                                                                                    case False{}:
                                                                                      match b10:
                                                                                        case True{}: {==}
                                                                                        case False{}:
                                                                                          match b9:
                                                                                            case True{}: {==}
                                                                                            case False{}:
                                                                                              match b8:
                                                                                                case True{}: {==}
                                                                                                case False{}:
                                                                                                  match b7:
                                                                                                    case True{}: {==}
                                                                                                    case False{}:
                                                                                                      match b6:
                                                                                                        case True{}: {==}
                                                                                                        case False{}:
                                                                                                          match b5 b4 b3 b2 b1 b0:
                                                                                                            case False{} False{} False{} False{} False{} False{}: {==}
                                                                                                            case False{} False{} False{} False{} False{} True{}: {==}
                                                                                                            case False{} False{} False{} False{} True{} False{}: {==}
                                                                                                            case False{} False{} False{} False{} True{} True{}: {==}
                                                                                                            case False{} False{} False{} True{} False{} False{}: {==}
                                                                                                            case False{} False{} False{} True{} False{} True{}: {==}
                                                                                                            case False{} False{} False{} True{} True{} False{}: {==}
                                                                                                            case False{} False{} False{} True{} True{} True{}: {==}
                                                                                                            case False{} False{} True{} False{} False{} False{}: {==}
                                                                                                            case False{} False{} True{} False{} False{} True{}: {==}
                                                                                                            case False{} False{} True{} False{} True{} False{}: {==}
                                                                                                            case False{} False{} True{} False{} True{} True{}: {==}
                                                                                                            case False{} False{} True{} True{} False{} False{}: {==}
                                                                                                            case False{} False{} True{} True{} False{} True{}: {==}
                                                                                                            case False{} False{} True{} True{} True{} False{}: {==}
                                                                                                            case False{} False{} True{} True{} True{} True{}: {==}
                                                                                                            case False{} True{} False{} False{} False{} False{}: {==}
                                                                                                            case False{} True{} False{} False{} False{} True{}: {==}
                                                                                                            case False{} True{} False{} False{} True{} False{}: {==}
                                                                                                            case False{} True{} False{} False{} True{} True{}: {==}
                                                                                                            case False{} True{} False{} True{} False{} False{}: {==}
                                                                                                            case False{} True{} False{} True{} False{} True{}: {==}
                                                                                                            case False{} True{} False{} True{} True{} False{}: {==}
                                                                                                            case False{} True{} False{} True{} True{} True{}: {==}
                                                                                                            case False{} True{} True{} False{} False{} False{}: {==}
                                                                                                            case False{} True{} True{} False{} False{} True{}: {==}
                                                                                                            case False{} True{} True{} False{} True{} False{}: {==}
                                                                                                            case False{} True{} True{} False{} True{} True{}: {==}
                                                                                                            case False{} True{} True{} True{} False{} False{}: {==}
                                                                                                            case False{} True{} True{} True{} False{} True{}: {==}
                                                                                                            case False{} True{} True{} True{} True{} False{}: {==}
                                                                                                            case False{} True{} True{} True{} True{} True{}: {==}
                                                                                                            case True{} False{} False{} False{} False{} False{}: {==}
                                                                                                            case True{} False{} False{} False{} False{} True{}: {==}
                                                                                                            case True{} False{} False{} False{} True{} False{}: {==}
                                                                                                            case True{} False{} False{} False{} True{} True{}: {==}
                                                                                                            case True{} False{} False{} True{} False{} False{}: {==}
                                                                                                            case True{} False{} False{} True{} False{} True{}: {==}
                                                                                                            case True{} False{} False{} True{} True{} False{}: {==}
                                                                                                            case True{} False{} False{} True{} True{} True{}: {==}
                                                                                                            case True{} False{} True{} False{} False{} False{}: {==}
                                                                                                            case True{} False{} True{} False{} False{} True{}: {==}
                                                                                                            case True{} False{} True{} False{} True{} False{}: {==}
                                                                                                            case True{} False{} True{} False{} True{} True{}: {==}
                                                                                                            case True{} False{} True{} True{} False{} False{}: {==}
                                                                                                            case True{} False{} True{} True{} False{} True{}: {==}
                                                                                                            case True{} False{} True{} True{} True{} False{}: {==}
                                                                                                            case True{} False{} True{} True{} True{} True{}: {==}
                                                                                                            case True{} True{} False{} False{} False{} False{}: zero_accept(t)
                                                                                                            case True{} True{} False{} False{} False{} True{}: digits_accept(t)
                                                                                                            case True{} True{} False{} False{} True{} False{}: digits_accept(t)
                                                                                                            case True{} True{} False{} False{} True{} True{}: digits_accept(t)
                                                                                                            case True{} True{} False{} True{} False{} False{}: digits_accept(t)
                                                                                                            case True{} True{} False{} True{} False{} True{}: digits_accept(t)
                                                                                                            case True{} True{} False{} True{} True{} False{}: digits_accept(t)
                                                                                                            case True{} True{} False{} True{} True{} True{}: digits_accept(t)
                                                                                                            case True{} True{} True{} False{} False{} False{}: digits_accept(t)
                                                                                                            case True{} True{} True{} False{} False{} True{}: digits_accept(t)
                                                                                                            case True{} True{} True{} False{} True{} False{}: {==}
                                                                                                            case True{} True{} True{} False{} True{} True{}: {==}
                                                                                                            case True{} True{} True{} True{} False{} False{}: {==}
                                                                                                            case True{} True{} True{} True{} False{} True{}: {==}
                                                                                                            case True{} True{} True{} True{} True{} False{}: {==}
                                                                                                            case True{} True{} True{} True{} True{} True{}: {==}


def start_step(+c: U32, +t: String) -> {(Spec.digit(c) && Spec.digits(t)) && J.number_valid_go(t, J.number_step(J.PStart{}, c)) == Spec.unsigned_integer(SCon{Chr{c}, t}) : Bool}:
  match c:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      start_step_bits(b31, b30, b29, b28, b27, b26, b25, b24, b23, b22, b21, b20, b19, b18, b17, b16, b15, b14, b13, b12, b11, b10, b9, b8, b7, b6, b5, b4, b3, b2, b1, b0, t)



def start_restrict(+s: String) -> {Spec.digits(s) && J.number_valid(s) == Spec.unsigned_integer(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: start_step(c, t)

def bit_same(+a: Bool, b: Bool) -> Bool:
  match a b:
    case False{} False{}: True{}
    case True{} True{}: True{}
    case _ _: False{}

def word_same(+n: Nat, a: Word(n), b: Word(n)) -> Bool:
  match n:
    case 0n: True{}
    case 1n+p:
      match a b:
        case WCon{h, t} WCon{k, u}: bit_same(h, k) && word_same(p, t, u)

def cmp_same_fin(+a: Bool, +b: Bool, +c: Cmp) -> {Cmp.is_eq(Word.cmp.fin(a, b, c)) == bit_same(a, b) && Cmp.is_eq(c) : Bool}:
  match a b c:
    case False{} False{} LT{}: {==}
    case False{} False{} EQ{}: {==}
    case False{} False{} GT{}: {==}
    case False{} True{} LT{}: {==}
    case False{} True{} EQ{}: {==}
    case False{} True{} GT{}: {==}
    case True{} False{} LT{}: {==}
    case True{} False{} EQ{}: {==}
    case True{} False{} GT{}: {==}
    case True{} True{} LT{}: {==}
    case True{} True{} EQ{}: {==}
    case True{} True{} GT{}: {==}

def cmp_same(+n: Nat, +a: Word(n), +b: Word(n)) -> {Cmp.is_eq(Word.cmp(n, a, b)) == word_same(n, a, b) : Bool}:
  match n:
    case 0n: {==}
    case 1n+p:
      match a b:
        case WCon{+h, +t} WCon{+k, +u}:
          %Equal.sym(Bool, Cmp.is_eq(Word.cmp.fin(h, k, Word.cmp(p, t, u))), bit_same(h, k) && Cmp.is_eq(Word.cmp(p, t, u)), cmp_same_fin(h, k, Word.cmp(p, t, u))) : {_ == bit_same(h, k) && word_same(p, t, u) : Bool}
          Equal.cong(Bool, Bool, x => bit_same(h, k) && x, Cmp.is_eq(Word.cmp(p, t, u)), word_same(p, t, u), cmp_same(p, t, u))

def sign(+c: U32) -> Bool:
  match c:
    case U32{w}: word_same(32n, w, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}})

def sign_equiv(+c: U32) -> {Spec.same(c, 45) == sign(c) : Bool}:
  match c:
    case U32{w}: cmp_same(32n, w, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}})

def lexical_integer(s: String) -> Bool:
  match s:
    case SCon{'-', t}: Spec.unsigned_integer(t)
    case t: Spec.unsigned_integer(t)

def spec_sign(+c: U32, +t: String) -> {Spec.integer(SCon{Chr{c}, t}) == Bool.pick(Bool, sign(c), Spec.unsigned_integer(t), Spec.unsigned_integer(SCon{Chr{c}, t})) : Bool}:
  Equal.cong(Bool, Bool, b => Bool.pick(Bool, b, Spec.unsigned_integer(t), Spec.unsigned_integer(SCon{Chr{c}, t})), Spec.same(c, 45), sign(c), sign_equiv(c))

def spec_lexical(+s: String) -> {Spec.integer(s) == lexical_integer(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{U32{WCon{False{}, hi}}}, t}: spec_sign(U32{WCon{False{}, hi}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, hi}}}}, t}: spec_sign(U32{WCon{True{}, WCon{True{}, hi}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, hi}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, hi}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, hi}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, hi}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, hi}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, hi}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: spec_sign(U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t)
    case SCon{Chr{45}, t}: spec_sign(45, t)

def unsigned_guard(+s: String) -> {J.number_valid(s) && D.integer(s) == Spec.unsigned_integer(s) : Bool}:
  %Equal.sym(Bool, D.integer(s), Spec.digits(s), integer_digits(s)) : {J.number_valid(s) && _ == Spec.unsigned_integer(s) : Bool}
  Equal.trans(Bool, J.number_valid(s) && Spec.digits(s), Spec.digits(s) && J.number_valid(s), Spec.unsigned_integer(s), and_comm(J.number_valid(s), Spec.digits(s)), start_restrict(s))

def signed_guard(+s: String) -> {J.number_valid_go(s, J.PMinus{}) && D.integer(s) == Spec.unsigned_integer(s) : Bool}:
  %Equal.sym(Bool, D.integer(s), Spec.digits(s), integer_digits(s)) : {J.number_valid_go(s, J.PMinus{}) && _ == Spec.unsigned_integer(s) : Bool}
  Equal.trans(Bool, J.number_valid_go(s, J.PMinus{}) && Spec.digits(s), Spec.digits(s) && J.number_valid_go(s, J.PMinus{}), Spec.unsigned_integer(s), and_comm(J.number_valid_go(s, J.PMinus{}), Spec.digits(s)), unsigned_restrict(s))

def implementation_lexical(+s: String) -> {D.is_integer(s) == lexical_integer(s) : Bool}:
  match s:
    case SNil{}: unsigned_guard(s)
    case SCon{Chr{U32{WCon{False{}, hi}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{False{}, hi}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, hi}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{True{}, hi}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, hi}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, hi}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, hi}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, hi}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, hi}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, hi}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: unsigned_guard(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t})
    case SCon{Chr{45}, t}: signed_guard(t)

def integer_equiv(+s: String) -> {D.is_integer(s) == Spec.integer(s) : Bool}:
  Equal.trans(Bool, D.is_integer(s), lexical_integer(s), Spec.integer(s), implementation_lexical(s), Equal.sym(Bool, Spec.integer(s), lexical_integer(s), spec_lexical(s)))

# The runtime validity gate proves every accepted lexical integer is a number.
def integer_number(+s: String, e: {D.is_integer(s) == True{} : Bool}) -> {J.number_valid(s) == True{} : Bool}:
  match s:
    case SNil{}: UP.and_left(J.number_valid(s), D.integer(s), e)
    case SCon{Chr{U32{WCon{False{}, hi}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{False{}, hi}}}, t}), D.integer(SCon{Chr{U32{WCon{False{}, hi}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, hi}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{True{}, hi}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{True{}, hi}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, hi}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, hi}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, hi}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, hi}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, hi}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, hi}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, hi}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, hi}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, hi}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, hi}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}: UP.and_left(J.number_valid(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), D.integer(SCon{Chr{U32{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, hi}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, t}), e)
    case SCon{'-', t}: UP.and_left(J.number_valid(s), D.integer(t), e)
