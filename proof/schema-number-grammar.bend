# The independent grammar remaining after each JSON number phase.
import Base
import ../src/data/json.bend as J
import ../src/data/schema-spec.bend as Spec

def residual(p: J.Phase, +s: String) -> Bool:
  match p:
    case J.PStart{}: Spec.number(s)
    case J.PMinus{}: Spec.unsigned(s)
    case J.PZero{}: Spec.after_int(s)
    case J.PInteger{}: Spec.after_int(Spec.skip_digits(s))
    case J.PDot{}: Spec.fraction(s)
    case J.PFraction{}: Spec.optional_exponent(Spec.skip_digits(s))
    case J.PExponent{}: Spec.exponent_body(s)
    case J.PSign{}: Spec.exponent_digits(s)
    case J.PDigits{}: Spec.digits(s)
    case J.PInvalid{}: False{}

# A character is either ASCII, or has a highest set bit above bit six.
# The latter cases keep every lower bit arbitrary.
def impossible(-P: Type, e: Empty) -> P:
  match e:

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def code(b0: Bool, b1: Bool, b2: Bool, b3: Bool, b4: Bool, b5: Bool, b6: Bool, b7: Bool, b8: Bool, b9: Bool, b10: Bool, b11: Bool, b12: Bool, b13: Bool, b14: Bool, b15: Bool, b16: Bool, b17: Bool, b18: Bool, b19: Bool, b20: Bool, b21: Bool, b22: Bool, b23: Bool, b24: Bool, b25: Bool, b26: Bool, b27: Bool, b28: Bool, b29: Bool, b30: Bool, b31: Bool) -> U32:
  U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

# Only these six literal characters can change a phase when digit is false.
def reject_bits(+b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +b6: Bool, +b7: Bool, +b8: Bool, +b9: Bool, +b10: Bool, +b11: Bool, +b12: Bool, +b13: Bool, +b14: Bool, +b15: Bool, +b16: Bool, +b17: Bool, +b18: Bool, +b19: Bool, +b20: Bool, +b21: Bool, +b22: Bool, +b23: Bool, +b24: Bool, +b25: Bool, +b26: Bool, +b27: Bool, +b28: Bool, +b29: Bool, +b30: Bool, +b31: Bool, +p: J.Phase, e: {U32.is_gt(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), 127) == True{} : Bool}) -> {J.number_digit(p, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), False{}) == J.PInvalid{} : J.Phase}:
  match b0:
    case False{}:
      match b1:
        case False{}:
          match b2:
            case False{}:
              match b3:
                case False{}:
                  match b4:
                    case False{}:
                      match p:
                        case J.PStart{}: {==}
                        case J.PMinus{}: {==}
                        case J.PZero{}: {==}
                        case J.PInteger{}: {==}
                        case J.PDot{}: {==}
                        case J.PFraction{}: {==}
                        case J.PExponent{}: {==}
                        case J.PSign{}: {==}
                        case J.PDigits{}: {==}
                        case J.PInvalid{}: {==}
                    case True{}:
                      match b5:
                        case False{}:
                          match p:
                            case J.PStart{}: {==}
                            case J.PMinus{}: {==}
                            case J.PZero{}: {==}
                            case J.PInteger{}: {==}
                            case J.PDot{}: {==}
                            case J.PFraction{}: {==}
                            case J.PExponent{}: {==}
                            case J.PSign{}: {==}
                            case J.PDigits{}: {==}
                            case J.PInvalid{}: {==}
                        case True{}:
                          match b6:
                            case False{}:
                              match b7:
                                case False{}:
                                  match b8:
                                    case False{}:
                                      match b9:
                                        case False{}:
                                          match b10:
                                            case False{}:
                                              match b11:
                                                case False{}:
                                                  match b12:
                                                    case False{}:
                                                      match b13:
                                                        case False{}:
                                                          match b14:
                                                            case False{}:
                                                              match b15:
                                                                case False{}:
                                                                  match b16:
                                                                    case False{}:
                                                                      match b17:
                                                                        case False{}:
                                                                          match b18:
                                                                            case False{}:
                                                                              match b19:
                                                                                case False{}:
                                                                                  match b20:
                                                                                    case False{}:
                                                                                      match b21:
                                                                                        case False{}:
                                                                                          match b22:
                                                                                            case False{}:
                                                                                              match b23:
                                                                                                case False{}:
                                                                                                  match b24:
                                                                                                    case False{}:
                                                                                                      match b25:
                                                                                                        case False{}:
                                                                                                          match b26:
                                                                                                            case False{}:
                                                                                                              match b27:
                                                                                                                case False{}:
                                                                                                                  match b28:
                                                                                                                    case False{}:
                                                                                                                      match b29:
                                                                                                                        case False{}:
                                                                                                                          match b30:
                                                                                                                            case False{}:
                                                                                                                              match b31:
                                                                                                                                case False{}:
                                                                                                                                  impossible({J.number_digit(p, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), False{}) == J.PInvalid{} : J.Phase}, false_true(e))
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case True{}:
                                                                                                                              match p:
                                                                                                                                case J.PStart{}: {==}
                                                                                                                                case J.PMinus{}: {==}
                                                                                                                                case J.PZero{}: {==}
                                                                                                                                case J.PInteger{}: {==}
                                                                                                                                case J.PDot{}: {==}
                                                                                                                                case J.PFraction{}: {==}
                                                                                                                                case J.PExponent{}: {==}
                                                                                                                                case J.PSign{}: {==}
                                                                                                                                case J.PDigits{}: {==}
                                                                                                                                case J.PInvalid{}: {==}
                                                                                                                        case True{}:
                                                                                                                          match p:
                                                                                                                            case J.PStart{}: {==}
                                                                                                                            case J.PMinus{}: {==}
                                                                                                                            case J.PZero{}: {==}
                                                                                                                            case J.PInteger{}: {==}
                                                                                                                            case J.PDot{}: {==}
                                                                                                                            case J.PFraction{}: {==}
                                                                                                                            case J.PExponent{}: {==}
                                                                                                                            case J.PSign{}: {==}
                                                                                                                            case J.PDigits{}: {==}
                                                                                                                            case J.PInvalid{}: {==}
                                                                                                                    case True{}:
                                                                                                                      match p:
                                                                                                                        case J.PStart{}: {==}
                                                                                                                        case J.PMinus{}: {==}
                                                                                                                        case J.PZero{}: {==}
                                                                                                                        case J.PInteger{}: {==}
                                                                                                                        case J.PDot{}: {==}
                                                                                                                        case J.PFraction{}: {==}
                                                                                                                        case J.PExponent{}: {==}
                                                                                                                        case J.PSign{}: {==}
                                                                                                                        case J.PDigits{}: {==}
                                                                                                                        case J.PInvalid{}: {==}
                                                                                                                case True{}:
                                                                                                                  match p:
                                                                                                                    case J.PStart{}: {==}
                                                                                                                    case J.PMinus{}: {==}
                                                                                                                    case J.PZero{}: {==}
                                                                                                                    case J.PInteger{}: {==}
                                                                                                                    case J.PDot{}: {==}
                                                                                                                    case J.PFraction{}: {==}
                                                                                                                    case J.PExponent{}: {==}
                                                                                                                    case J.PSign{}: {==}
                                                                                                                    case J.PDigits{}: {==}
                                                                                                                    case J.PInvalid{}: {==}
                                                                                                            case True{}:
                                                                                                              match p:
                                                                                                                case J.PStart{}: {==}
                                                                                                                case J.PMinus{}: {==}
                                                                                                                case J.PZero{}: {==}
                                                                                                                case J.PInteger{}: {==}
                                                                                                                case J.PDot{}: {==}
                                                                                                                case J.PFraction{}: {==}
                                                                                                                case J.PExponent{}: {==}
                                                                                                                case J.PSign{}: {==}
                                                                                                                case J.PDigits{}: {==}
                                                                                                                case J.PInvalid{}: {==}
                                                                                                        case True{}:
                                                                                                          match p:
                                                                                                            case J.PStart{}: {==}
                                                                                                            case J.PMinus{}: {==}
                                                                                                            case J.PZero{}: {==}
                                                                                                            case J.PInteger{}: {==}
                                                                                                            case J.PDot{}: {==}
                                                                                                            case J.PFraction{}: {==}
                                                                                                            case J.PExponent{}: {==}
                                                                                                            case J.PSign{}: {==}
                                                                                                            case J.PDigits{}: {==}
                                                                                                            case J.PInvalid{}: {==}
                                                                                                    case True{}:
                                                                                                      match p:
                                                                                                        case J.PStart{}: {==}
                                                                                                        case J.PMinus{}: {==}
                                                                                                        case J.PZero{}: {==}
                                                                                                        case J.PInteger{}: {==}
                                                                                                        case J.PDot{}: {==}
                                                                                                        case J.PFraction{}: {==}
                                                                                                        case J.PExponent{}: {==}
                                                                                                        case J.PSign{}: {==}
                                                                                                        case J.PDigits{}: {==}
                                                                                                        case J.PInvalid{}: {==}
                                                                                                case True{}:
                                                                                                  match p:
                                                                                                    case J.PStart{}: {==}
                                                                                                    case J.PMinus{}: {==}
                                                                                                    case J.PZero{}: {==}
                                                                                                    case J.PInteger{}: {==}
                                                                                                    case J.PDot{}: {==}
                                                                                                    case J.PFraction{}: {==}
                                                                                                    case J.PExponent{}: {==}
                                                                                                    case J.PSign{}: {==}
                                                                                                    case J.PDigits{}: {==}
                                                                                                    case J.PInvalid{}: {==}
                                                                                            case True{}:
                                                                                              match p:
                                                                                                case J.PStart{}: {==}
                                                                                                case J.PMinus{}: {==}
                                                                                                case J.PZero{}: {==}
                                                                                                case J.PInteger{}: {==}
                                                                                                case J.PDot{}: {==}
                                                                                                case J.PFraction{}: {==}
                                                                                                case J.PExponent{}: {==}
                                                                                                case J.PSign{}: {==}
                                                                                                case J.PDigits{}: {==}
                                                                                                case J.PInvalid{}: {==}
                                                                                        case True{}:
                                                                                          match p:
                                                                                            case J.PStart{}: {==}
                                                                                            case J.PMinus{}: {==}
                                                                                            case J.PZero{}: {==}
                                                                                            case J.PInteger{}: {==}
                                                                                            case J.PDot{}: {==}
                                                                                            case J.PFraction{}: {==}
                                                                                            case J.PExponent{}: {==}
                                                                                            case J.PSign{}: {==}
                                                                                            case J.PDigits{}: {==}
                                                                                            case J.PInvalid{}: {==}
                                                                                    case True{}:
                                                                                      match p:
                                                                                        case J.PStart{}: {==}
                                                                                        case J.PMinus{}: {==}
                                                                                        case J.PZero{}: {==}
                                                                                        case J.PInteger{}: {==}
                                                                                        case J.PDot{}: {==}
                                                                                        case J.PFraction{}: {==}
                                                                                        case J.PExponent{}: {==}
                                                                                        case J.PSign{}: {==}
                                                                                        case J.PDigits{}: {==}
                                                                                        case J.PInvalid{}: {==}
                                                                                case True{}:
                                                                                  match p:
                                                                                    case J.PStart{}: {==}
                                                                                    case J.PMinus{}: {==}
                                                                                    case J.PZero{}: {==}
                                                                                    case J.PInteger{}: {==}
                                                                                    case J.PDot{}: {==}
                                                                                    case J.PFraction{}: {==}
                                                                                    case J.PExponent{}: {==}
                                                                                    case J.PSign{}: {==}
                                                                                    case J.PDigits{}: {==}
                                                                                    case J.PInvalid{}: {==}
                                                                            case True{}:
                                                                              match p:
                                                                                case J.PStart{}: {==}
                                                                                case J.PMinus{}: {==}
                                                                                case J.PZero{}: {==}
                                                                                case J.PInteger{}: {==}
                                                                                case J.PDot{}: {==}
                                                                                case J.PFraction{}: {==}
                                                                                case J.PExponent{}: {==}
                                                                                case J.PSign{}: {==}
                                                                                case J.PDigits{}: {==}
                                                                                case J.PInvalid{}: {==}
                                                                        case True{}:
                                                                          match p:
                                                                            case J.PStart{}: {==}
                                                                            case J.PMinus{}: {==}
                                                                            case J.PZero{}: {==}
                                                                            case J.PInteger{}: {==}
                                                                            case J.PDot{}: {==}
                                                                            case J.PFraction{}: {==}
                                                                            case J.PExponent{}: {==}
                                                                            case J.PSign{}: {==}
                                                                            case J.PDigits{}: {==}
                                                                            case J.PInvalid{}: {==}
                                                                    case True{}:
                                                                      match p:
                                                                        case J.PStart{}: {==}
                                                                        case J.PMinus{}: {==}
                                                                        case J.PZero{}: {==}
                                                                        case J.PInteger{}: {==}
                                                                        case J.PDot{}: {==}
                                                                        case J.PFraction{}: {==}
                                                                        case J.PExponent{}: {==}
                                                                        case J.PSign{}: {==}
                                                                        case J.PDigits{}: {==}
                                                                        case J.PInvalid{}: {==}
                                                                case True{}:
                                                                  match p:
                                                                    case J.PStart{}: {==}
                                                                    case J.PMinus{}: {==}
                                                                    case J.PZero{}: {==}
                                                                    case J.PInteger{}: {==}
                                                                    case J.PDot{}: {==}
                                                                    case J.PFraction{}: {==}
                                                                    case J.PExponent{}: {==}
                                                                    case J.PSign{}: {==}
                                                                    case J.PDigits{}: {==}
                                                                    case J.PInvalid{}: {==}
                                                            case True{}:
                                                              match p:
                                                                case J.PStart{}: {==}
                                                                case J.PMinus{}: {==}
                                                                case J.PZero{}: {==}
                                                                case J.PInteger{}: {==}
                                                                case J.PDot{}: {==}
                                                                case J.PFraction{}: {==}
                                                                case J.PExponent{}: {==}
                                                                case J.PSign{}: {==}
                                                                case J.PDigits{}: {==}
                                                                case J.PInvalid{}: {==}
                                                        case True{}:
                                                          match p:
                                                            case J.PStart{}: {==}
                                                            case J.PMinus{}: {==}
                                                            case J.PZero{}: {==}
                                                            case J.PInteger{}: {==}
                                                            case J.PDot{}: {==}
                                                            case J.PFraction{}: {==}
                                                            case J.PExponent{}: {==}
                                                            case J.PSign{}: {==}
                                                            case J.PDigits{}: {==}
                                                            case J.PInvalid{}: {==}
                                                    case True{}:
                                                      match p:
                                                        case J.PStart{}: {==}
                                                        case J.PMinus{}: {==}
                                                        case J.PZero{}: {==}
                                                        case J.PInteger{}: {==}
                                                        case J.PDot{}: {==}
                                                        case J.PFraction{}: {==}
                                                        case J.PExponent{}: {==}
                                                        case J.PSign{}: {==}
                                                        case J.PDigits{}: {==}
                                                        case J.PInvalid{}: {==}
                                                case True{}:
                                                  match p:
                                                    case J.PStart{}: {==}
                                                    case J.PMinus{}: {==}
                                                    case J.PZero{}: {==}
                                                    case J.PInteger{}: {==}
                                                    case J.PDot{}: {==}
                                                    case J.PFraction{}: {==}
                                                    case J.PExponent{}: {==}
                                                    case J.PSign{}: {==}
                                                    case J.PDigits{}: {==}
                                                    case J.PInvalid{}: {==}
                                            case True{}:
                                              match p:
                                                case J.PStart{}: {==}
                                                case J.PMinus{}: {==}
                                                case J.PZero{}: {==}
                                                case J.PInteger{}: {==}
                                                case J.PDot{}: {==}
                                                case J.PFraction{}: {==}
                                                case J.PExponent{}: {==}
                                                case J.PSign{}: {==}
                                                case J.PDigits{}: {==}
                                                case J.PInvalid{}: {==}
                                        case True{}:
                                          match p:
                                            case J.PStart{}: {==}
                                            case J.PMinus{}: {==}
                                            case J.PZero{}: {==}
                                            case J.PInteger{}: {==}
                                            case J.PDot{}: {==}
                                            case J.PFraction{}: {==}
                                            case J.PExponent{}: {==}
                                            case J.PSign{}: {==}
                                            case J.PDigits{}: {==}
                                            case J.PInvalid{}: {==}
                                    case True{}:
                                      match p:
                                        case J.PStart{}: {==}
                                        case J.PMinus{}: {==}
                                        case J.PZero{}: {==}
                                        case J.PInteger{}: {==}
                                        case J.PDot{}: {==}
                                        case J.PFraction{}: {==}
                                        case J.PExponent{}: {==}
                                        case J.PSign{}: {==}
                                        case J.PDigits{}: {==}
                                        case J.PInvalid{}: {==}
                                case True{}:
                                  match p:
                                    case J.PStart{}: {==}
                                    case J.PMinus{}: {==}
                                    case J.PZero{}: {==}
                                    case J.PInteger{}: {==}
                                    case J.PDot{}: {==}
                                    case J.PFraction{}: {==}
                                    case J.PExponent{}: {==}
                                    case J.PSign{}: {==}
                                    case J.PDigits{}: {==}
                                    case J.PInvalid{}: {==}
                            case True{}:
                              match p:
                                case J.PStart{}: {==}
                                case J.PMinus{}: {==}
                                case J.PZero{}: {==}
                                case J.PInteger{}: {==}
                                case J.PDot{}: {==}
                                case J.PFraction{}: {==}
                                case J.PExponent{}: {==}
                                case J.PSign{}: {==}
                                case J.PDigits{}: {==}
                                case J.PInvalid{}: {==}
                case True{}:
                  match p:
                    case J.PStart{}: {==}
                    case J.PMinus{}: {==}
                    case J.PZero{}: {==}
                    case J.PInteger{}: {==}
                    case J.PDot{}: {==}
                    case J.PFraction{}: {==}
                    case J.PExponent{}: {==}
                    case J.PSign{}: {==}
                    case J.PDigits{}: {==}
                    case J.PInvalid{}: {==}
            case True{}:
              match p:
                case J.PStart{}: {==}
                case J.PMinus{}: {==}
                case J.PZero{}: {==}
                case J.PInteger{}: {==}
                case J.PDot{}: {==}
                case J.PFraction{}: {==}
                case J.PExponent{}: {==}
                case J.PSign{}: {==}
                case J.PDigits{}: {==}
                case J.PInvalid{}: {==}
        case True{}:
          match b2:
            case False{}:
              match p:
                case J.PStart{}: {==}
                case J.PMinus{}: {==}
                case J.PZero{}: {==}
                case J.PInteger{}: {==}
                case J.PDot{}: {==}
                case J.PFraction{}: {==}
                case J.PExponent{}: {==}
                case J.PSign{}: {==}
                case J.PDigits{}: {==}
                case J.PInvalid{}: {==}
            case True{}:
              match b3:
                case False{}:
                  match p:
                    case J.PStart{}: {==}
                    case J.PMinus{}: {==}
                    case J.PZero{}: {==}
                    case J.PInteger{}: {==}
                    case J.PDot{}: {==}
                    case J.PFraction{}: {==}
                    case J.PExponent{}: {==}
                    case J.PSign{}: {==}
                    case J.PDigits{}: {==}
                    case J.PInvalid{}: {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          match p:
                            case J.PStart{}: {==}
                            case J.PMinus{}: {==}
                            case J.PZero{}: {==}
                            case J.PInteger{}: {==}
                            case J.PDot{}: {==}
                            case J.PFraction{}: {==}
                            case J.PExponent{}: {==}
                            case J.PSign{}: {==}
                            case J.PDigits{}: {==}
                            case J.PInvalid{}: {==}
                        case True{}:
                          match b6:
                            case False{}:
                              match b7:
                                case False{}:
                                  match b8:
                                    case False{}:
                                      match b9:
                                        case False{}:
                                          match b10:
                                            case False{}:
                                              match b11:
                                                case False{}:
                                                  match b12:
                                                    case False{}:
                                                      match b13:
                                                        case False{}:
                                                          match b14:
                                                            case False{}:
                                                              match b15:
                                                                case False{}:
                                                                  match b16:
                                                                    case False{}:
                                                                      match b17:
                                                                        case False{}:
                                                                          match b18:
                                                                            case False{}:
                                                                              match b19:
                                                                                case False{}:
                                                                                  match b20:
                                                                                    case False{}:
                                                                                      match b21:
                                                                                        case False{}:
                                                                                          match b22:
                                                                                            case False{}:
                                                                                              match b23:
                                                                                                case False{}:
                                                                                                  match b24:
                                                                                                    case False{}:
                                                                                                      match b25:
                                                                                                        case False{}:
                                                                                                          match b26:
                                                                                                            case False{}:
                                                                                                              match b27:
                                                                                                                case False{}:
                                                                                                                  match b28:
                                                                                                                    case False{}:
                                                                                                                      match b29:
                                                                                                                        case False{}:
                                                                                                                          match b30:
                                                                                                                            case False{}:
                                                                                                                              match b31:
                                                                                                                                case False{}:
                                                                                                                                  impossible({J.number_digit(p, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), False{}) == J.PInvalid{} : J.Phase}, false_true(e))
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case True{}:
                                                                                                                              match p:
                                                                                                                                case J.PStart{}: {==}
                                                                                                                                case J.PMinus{}: {==}
                                                                                                                                case J.PZero{}: {==}
                                                                                                                                case J.PInteger{}: {==}
                                                                                                                                case J.PDot{}: {==}
                                                                                                                                case J.PFraction{}: {==}
                                                                                                                                case J.PExponent{}: {==}
                                                                                                                                case J.PSign{}: {==}
                                                                                                                                case J.PDigits{}: {==}
                                                                                                                                case J.PInvalid{}: {==}
                                                                                                                        case True{}:
                                                                                                                          match p:
                                                                                                                            case J.PStart{}: {==}
                                                                                                                            case J.PMinus{}: {==}
                                                                                                                            case J.PZero{}: {==}
                                                                                                                            case J.PInteger{}: {==}
                                                                                                                            case J.PDot{}: {==}
                                                                                                                            case J.PFraction{}: {==}
                                                                                                                            case J.PExponent{}: {==}
                                                                                                                            case J.PSign{}: {==}
                                                                                                                            case J.PDigits{}: {==}
                                                                                                                            case J.PInvalid{}: {==}
                                                                                                                    case True{}:
                                                                                                                      match p:
                                                                                                                        case J.PStart{}: {==}
                                                                                                                        case J.PMinus{}: {==}
                                                                                                                        case J.PZero{}: {==}
                                                                                                                        case J.PInteger{}: {==}
                                                                                                                        case J.PDot{}: {==}
                                                                                                                        case J.PFraction{}: {==}
                                                                                                                        case J.PExponent{}: {==}
                                                                                                                        case J.PSign{}: {==}
                                                                                                                        case J.PDigits{}: {==}
                                                                                                                        case J.PInvalid{}: {==}
                                                                                                                case True{}:
                                                                                                                  match p:
                                                                                                                    case J.PStart{}: {==}
                                                                                                                    case J.PMinus{}: {==}
                                                                                                                    case J.PZero{}: {==}
                                                                                                                    case J.PInteger{}: {==}
                                                                                                                    case J.PDot{}: {==}
                                                                                                                    case J.PFraction{}: {==}
                                                                                                                    case J.PExponent{}: {==}
                                                                                                                    case J.PSign{}: {==}
                                                                                                                    case J.PDigits{}: {==}
                                                                                                                    case J.PInvalid{}: {==}
                                                                                                            case True{}:
                                                                                                              match p:
                                                                                                                case J.PStart{}: {==}
                                                                                                                case J.PMinus{}: {==}
                                                                                                                case J.PZero{}: {==}
                                                                                                                case J.PInteger{}: {==}
                                                                                                                case J.PDot{}: {==}
                                                                                                                case J.PFraction{}: {==}
                                                                                                                case J.PExponent{}: {==}
                                                                                                                case J.PSign{}: {==}
                                                                                                                case J.PDigits{}: {==}
                                                                                                                case J.PInvalid{}: {==}
                                                                                                        case True{}:
                                                                                                          match p:
                                                                                                            case J.PStart{}: {==}
                                                                                                            case J.PMinus{}: {==}
                                                                                                            case J.PZero{}: {==}
                                                                                                            case J.PInteger{}: {==}
                                                                                                            case J.PDot{}: {==}
                                                                                                            case J.PFraction{}: {==}
                                                                                                            case J.PExponent{}: {==}
                                                                                                            case J.PSign{}: {==}
                                                                                                            case J.PDigits{}: {==}
                                                                                                            case J.PInvalid{}: {==}
                                                                                                    case True{}:
                                                                                                      match p:
                                                                                                        case J.PStart{}: {==}
                                                                                                        case J.PMinus{}: {==}
                                                                                                        case J.PZero{}: {==}
                                                                                                        case J.PInteger{}: {==}
                                                                                                        case J.PDot{}: {==}
                                                                                                        case J.PFraction{}: {==}
                                                                                                        case J.PExponent{}: {==}
                                                                                                        case J.PSign{}: {==}
                                                                                                        case J.PDigits{}: {==}
                                                                                                        case J.PInvalid{}: {==}
                                                                                                case True{}:
                                                                                                  match p:
                                                                                                    case J.PStart{}: {==}
                                                                                                    case J.PMinus{}: {==}
                                                                                                    case J.PZero{}: {==}
                                                                                                    case J.PInteger{}: {==}
                                                                                                    case J.PDot{}: {==}
                                                                                                    case J.PFraction{}: {==}
                                                                                                    case J.PExponent{}: {==}
                                                                                                    case J.PSign{}: {==}
                                                                                                    case J.PDigits{}: {==}
                                                                                                    case J.PInvalid{}: {==}
                                                                                            case True{}:
                                                                                              match p:
                                                                                                case J.PStart{}: {==}
                                                                                                case J.PMinus{}: {==}
                                                                                                case J.PZero{}: {==}
                                                                                                case J.PInteger{}: {==}
                                                                                                case J.PDot{}: {==}
                                                                                                case J.PFraction{}: {==}
                                                                                                case J.PExponent{}: {==}
                                                                                                case J.PSign{}: {==}
                                                                                                case J.PDigits{}: {==}
                                                                                                case J.PInvalid{}: {==}
                                                                                        case True{}:
                                                                                          match p:
                                                                                            case J.PStart{}: {==}
                                                                                            case J.PMinus{}: {==}
                                                                                            case J.PZero{}: {==}
                                                                                            case J.PInteger{}: {==}
                                                                                            case J.PDot{}: {==}
                                                                                            case J.PFraction{}: {==}
                                                                                            case J.PExponent{}: {==}
                                                                                            case J.PSign{}: {==}
                                                                                            case J.PDigits{}: {==}
                                                                                            case J.PInvalid{}: {==}
                                                                                    case True{}:
                                                                                      match p:
                                                                                        case J.PStart{}: {==}
                                                                                        case J.PMinus{}: {==}
                                                                                        case J.PZero{}: {==}
                                                                                        case J.PInteger{}: {==}
                                                                                        case J.PDot{}: {==}
                                                                                        case J.PFraction{}: {==}
                                                                                        case J.PExponent{}: {==}
                                                                                        case J.PSign{}: {==}
                                                                                        case J.PDigits{}: {==}
                                                                                        case J.PInvalid{}: {==}
                                                                                case True{}:
                                                                                  match p:
                                                                                    case J.PStart{}: {==}
                                                                                    case J.PMinus{}: {==}
                                                                                    case J.PZero{}: {==}
                                                                                    case J.PInteger{}: {==}
                                                                                    case J.PDot{}: {==}
                                                                                    case J.PFraction{}: {==}
                                                                                    case J.PExponent{}: {==}
                                                                                    case J.PSign{}: {==}
                                                                                    case J.PDigits{}: {==}
                                                                                    case J.PInvalid{}: {==}
                                                                            case True{}:
                                                                              match p:
                                                                                case J.PStart{}: {==}
                                                                                case J.PMinus{}: {==}
                                                                                case J.PZero{}: {==}
                                                                                case J.PInteger{}: {==}
                                                                                case J.PDot{}: {==}
                                                                                case J.PFraction{}: {==}
                                                                                case J.PExponent{}: {==}
                                                                                case J.PSign{}: {==}
                                                                                case J.PDigits{}: {==}
                                                                                case J.PInvalid{}: {==}
                                                                        case True{}:
                                                                          match p:
                                                                            case J.PStart{}: {==}
                                                                            case J.PMinus{}: {==}
                                                                            case J.PZero{}: {==}
                                                                            case J.PInteger{}: {==}
                                                                            case J.PDot{}: {==}
                                                                            case J.PFraction{}: {==}
                                                                            case J.PExponent{}: {==}
                                                                            case J.PSign{}: {==}
                                                                            case J.PDigits{}: {==}
                                                                            case J.PInvalid{}: {==}
                                                                    case True{}:
                                                                      match p:
                                                                        case J.PStart{}: {==}
                                                                        case J.PMinus{}: {==}
                                                                        case J.PZero{}: {==}
                                                                        case J.PInteger{}: {==}
                                                                        case J.PDot{}: {==}
                                                                        case J.PFraction{}: {==}
                                                                        case J.PExponent{}: {==}
                                                                        case J.PSign{}: {==}
                                                                        case J.PDigits{}: {==}
                                                                        case J.PInvalid{}: {==}
                                                                case True{}:
                                                                  match p:
                                                                    case J.PStart{}: {==}
                                                                    case J.PMinus{}: {==}
                                                                    case J.PZero{}: {==}
                                                                    case J.PInteger{}: {==}
                                                                    case J.PDot{}: {==}
                                                                    case J.PFraction{}: {==}
                                                                    case J.PExponent{}: {==}
                                                                    case J.PSign{}: {==}
                                                                    case J.PDigits{}: {==}
                                                                    case J.PInvalid{}: {==}
                                                            case True{}:
                                                              match p:
                                                                case J.PStart{}: {==}
                                                                case J.PMinus{}: {==}
                                                                case J.PZero{}: {==}
                                                                case J.PInteger{}: {==}
                                                                case J.PDot{}: {==}
                                                                case J.PFraction{}: {==}
                                                                case J.PExponent{}: {==}
                                                                case J.PSign{}: {==}
                                                                case J.PDigits{}: {==}
                                                                case J.PInvalid{}: {==}
                                                        case True{}:
                                                          match p:
                                                            case J.PStart{}: {==}
                                                            case J.PMinus{}: {==}
                                                            case J.PZero{}: {==}
                                                            case J.PInteger{}: {==}
                                                            case J.PDot{}: {==}
                                                            case J.PFraction{}: {==}
                                                            case J.PExponent{}: {==}
                                                            case J.PSign{}: {==}
                                                            case J.PDigits{}: {==}
                                                            case J.PInvalid{}: {==}
                                                    case True{}:
                                                      match p:
                                                        case J.PStart{}: {==}
                                                        case J.PMinus{}: {==}
                                                        case J.PZero{}: {==}
                                                        case J.PInteger{}: {==}
                                                        case J.PDot{}: {==}
                                                        case J.PFraction{}: {==}
                                                        case J.PExponent{}: {==}
                                                        case J.PSign{}: {==}
                                                        case J.PDigits{}: {==}
                                                        case J.PInvalid{}: {==}
                                                case True{}:
                                                  match p:
                                                    case J.PStart{}: {==}
                                                    case J.PMinus{}: {==}
                                                    case J.PZero{}: {==}
                                                    case J.PInteger{}: {==}
                                                    case J.PDot{}: {==}
                                                    case J.PFraction{}: {==}
                                                    case J.PExponent{}: {==}
                                                    case J.PSign{}: {==}
                                                    case J.PDigits{}: {==}
                                                    case J.PInvalid{}: {==}
                                            case True{}:
                                              match p:
                                                case J.PStart{}: {==}
                                                case J.PMinus{}: {==}
                                                case J.PZero{}: {==}
                                                case J.PInteger{}: {==}
                                                case J.PDot{}: {==}
                                                case J.PFraction{}: {==}
                                                case J.PExponent{}: {==}
                                                case J.PSign{}: {==}
                                                case J.PDigits{}: {==}
                                                case J.PInvalid{}: {==}
                                        case True{}:
                                          match p:
                                            case J.PStart{}: {==}
                                            case J.PMinus{}: {==}
                                            case J.PZero{}: {==}
                                            case J.PInteger{}: {==}
                                            case J.PDot{}: {==}
                                            case J.PFraction{}: {==}
                                            case J.PExponent{}: {==}
                                            case J.PSign{}: {==}
                                            case J.PDigits{}: {==}
                                            case J.PInvalid{}: {==}
                                    case True{}:
                                      match p:
                                        case J.PStart{}: {==}
                                        case J.PMinus{}: {==}
                                        case J.PZero{}: {==}
                                        case J.PInteger{}: {==}
                                        case J.PDot{}: {==}
                                        case J.PFraction{}: {==}
                                        case J.PExponent{}: {==}
                                        case J.PSign{}: {==}
                                        case J.PDigits{}: {==}
                                        case J.PInvalid{}: {==}
                                case True{}:
                                  match p:
                                    case J.PStart{}: {==}
                                    case J.PMinus{}: {==}
                                    case J.PZero{}: {==}
                                    case J.PInteger{}: {==}
                                    case J.PDot{}: {==}
                                    case J.PFraction{}: {==}
                                    case J.PExponent{}: {==}
                                    case J.PSign{}: {==}
                                    case J.PDigits{}: {==}
                                    case J.PInvalid{}: {==}
                            case True{}:
                              match p:
                                case J.PStart{}: {==}
                                case J.PMinus{}: {==}
                                case J.PZero{}: {==}
                                case J.PInteger{}: {==}
                                case J.PDot{}: {==}
                                case J.PFraction{}: {==}
                                case J.PExponent{}: {==}
                                case J.PSign{}: {==}
                                case J.PDigits{}: {==}
                                case J.PInvalid{}: {==}
                    case True{}:
                      match p:
                        case J.PStart{}: {==}
                        case J.PMinus{}: {==}
                        case J.PZero{}: {==}
                        case J.PInteger{}: {==}
                        case J.PDot{}: {==}
                        case J.PFraction{}: {==}
                        case J.PExponent{}: {==}
                        case J.PSign{}: {==}
                        case J.PDigits{}: {==}
                        case J.PInvalid{}: {==}
    case True{}:
      match b1:
        case False{}:
          match b2:
            case False{}:
              match p:
                case J.PStart{}: {==}
                case J.PMinus{}: {==}
                case J.PZero{}: {==}
                case J.PInteger{}: {==}
                case J.PDot{}: {==}
                case J.PFraction{}: {==}
                case J.PExponent{}: {==}
                case J.PSign{}: {==}
                case J.PDigits{}: {==}
                case J.PInvalid{}: {==}
            case True{}:
              match b3:
                case False{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          match b6:
                            case False{}:
                              match p:
                                case J.PStart{}: {==}
                                case J.PMinus{}: {==}
                                case J.PZero{}: {==}
                                case J.PInteger{}: {==}
                                case J.PDot{}: {==}
                                case J.PFraction{}: {==}
                                case J.PExponent{}: {==}
                                case J.PSign{}: {==}
                                case J.PDigits{}: {==}
                                case J.PInvalid{}: {==}
                            case True{}:
                              match b7:
                                case False{}:
                                  match b8:
                                    case False{}:
                                      match b9:
                                        case False{}:
                                          match b10:
                                            case False{}:
                                              match b11:
                                                case False{}:
                                                  match b12:
                                                    case False{}:
                                                      match b13:
                                                        case False{}:
                                                          match b14:
                                                            case False{}:
                                                              match b15:
                                                                case False{}:
                                                                  match b16:
                                                                    case False{}:
                                                                      match b17:
                                                                        case False{}:
                                                                          match b18:
                                                                            case False{}:
                                                                              match b19:
                                                                                case False{}:
                                                                                  match b20:
                                                                                    case False{}:
                                                                                      match b21:
                                                                                        case False{}:
                                                                                          match b22:
                                                                                            case False{}:
                                                                                              match b23:
                                                                                                case False{}:
                                                                                                  match b24:
                                                                                                    case False{}:
                                                                                                      match b25:
                                                                                                        case False{}:
                                                                                                          match b26:
                                                                                                            case False{}:
                                                                                                              match b27:
                                                                                                                case False{}:
                                                                                                                  match b28:
                                                                                                                    case False{}:
                                                                                                                      match b29:
                                                                                                                        case False{}:
                                                                                                                          match b30:
                                                                                                                            case False{}:
                                                                                                                              match b31:
                                                                                                                                case False{}:
                                                                                                                                  impossible({J.number_digit(p, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), False{}) == J.PInvalid{} : J.Phase}, false_true(e))
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case True{}:
                                                                                                                              match p:
                                                                                                                                case J.PStart{}: {==}
                                                                                                                                case J.PMinus{}: {==}
                                                                                                                                case J.PZero{}: {==}
                                                                                                                                case J.PInteger{}: {==}
                                                                                                                                case J.PDot{}: {==}
                                                                                                                                case J.PFraction{}: {==}
                                                                                                                                case J.PExponent{}: {==}
                                                                                                                                case J.PSign{}: {==}
                                                                                                                                case J.PDigits{}: {==}
                                                                                                                                case J.PInvalid{}: {==}
                                                                                                                        case True{}:
                                                                                                                          match p:
                                                                                                                            case J.PStart{}: {==}
                                                                                                                            case J.PMinus{}: {==}
                                                                                                                            case J.PZero{}: {==}
                                                                                                                            case J.PInteger{}: {==}
                                                                                                                            case J.PDot{}: {==}
                                                                                                                            case J.PFraction{}: {==}
                                                                                                                            case J.PExponent{}: {==}
                                                                                                                            case J.PSign{}: {==}
                                                                                                                            case J.PDigits{}: {==}
                                                                                                                            case J.PInvalid{}: {==}
                                                                                                                    case True{}:
                                                                                                                      match p:
                                                                                                                        case J.PStart{}: {==}
                                                                                                                        case J.PMinus{}: {==}
                                                                                                                        case J.PZero{}: {==}
                                                                                                                        case J.PInteger{}: {==}
                                                                                                                        case J.PDot{}: {==}
                                                                                                                        case J.PFraction{}: {==}
                                                                                                                        case J.PExponent{}: {==}
                                                                                                                        case J.PSign{}: {==}
                                                                                                                        case J.PDigits{}: {==}
                                                                                                                        case J.PInvalid{}: {==}
                                                                                                                case True{}:
                                                                                                                  match p:
                                                                                                                    case J.PStart{}: {==}
                                                                                                                    case J.PMinus{}: {==}
                                                                                                                    case J.PZero{}: {==}
                                                                                                                    case J.PInteger{}: {==}
                                                                                                                    case J.PDot{}: {==}
                                                                                                                    case J.PFraction{}: {==}
                                                                                                                    case J.PExponent{}: {==}
                                                                                                                    case J.PSign{}: {==}
                                                                                                                    case J.PDigits{}: {==}
                                                                                                                    case J.PInvalid{}: {==}
                                                                                                            case True{}:
                                                                                                              match p:
                                                                                                                case J.PStart{}: {==}
                                                                                                                case J.PMinus{}: {==}
                                                                                                                case J.PZero{}: {==}
                                                                                                                case J.PInteger{}: {==}
                                                                                                                case J.PDot{}: {==}
                                                                                                                case J.PFraction{}: {==}
                                                                                                                case J.PExponent{}: {==}
                                                                                                                case J.PSign{}: {==}
                                                                                                                case J.PDigits{}: {==}
                                                                                                                case J.PInvalid{}: {==}
                                                                                                        case True{}:
                                                                                                          match p:
                                                                                                            case J.PStart{}: {==}
                                                                                                            case J.PMinus{}: {==}
                                                                                                            case J.PZero{}: {==}
                                                                                                            case J.PInteger{}: {==}
                                                                                                            case J.PDot{}: {==}
                                                                                                            case J.PFraction{}: {==}
                                                                                                            case J.PExponent{}: {==}
                                                                                                            case J.PSign{}: {==}
                                                                                                            case J.PDigits{}: {==}
                                                                                                            case J.PInvalid{}: {==}
                                                                                                    case True{}:
                                                                                                      match p:
                                                                                                        case J.PStart{}: {==}
                                                                                                        case J.PMinus{}: {==}
                                                                                                        case J.PZero{}: {==}
                                                                                                        case J.PInteger{}: {==}
                                                                                                        case J.PDot{}: {==}
                                                                                                        case J.PFraction{}: {==}
                                                                                                        case J.PExponent{}: {==}
                                                                                                        case J.PSign{}: {==}
                                                                                                        case J.PDigits{}: {==}
                                                                                                        case J.PInvalid{}: {==}
                                                                                                case True{}:
                                                                                                  match p:
                                                                                                    case J.PStart{}: {==}
                                                                                                    case J.PMinus{}: {==}
                                                                                                    case J.PZero{}: {==}
                                                                                                    case J.PInteger{}: {==}
                                                                                                    case J.PDot{}: {==}
                                                                                                    case J.PFraction{}: {==}
                                                                                                    case J.PExponent{}: {==}
                                                                                                    case J.PSign{}: {==}
                                                                                                    case J.PDigits{}: {==}
                                                                                                    case J.PInvalid{}: {==}
                                                                                            case True{}:
                                                                                              match p:
                                                                                                case J.PStart{}: {==}
                                                                                                case J.PMinus{}: {==}
                                                                                                case J.PZero{}: {==}
                                                                                                case J.PInteger{}: {==}
                                                                                                case J.PDot{}: {==}
                                                                                                case J.PFraction{}: {==}
                                                                                                case J.PExponent{}: {==}
                                                                                                case J.PSign{}: {==}
                                                                                                case J.PDigits{}: {==}
                                                                                                case J.PInvalid{}: {==}
                                                                                        case True{}:
                                                                                          match p:
                                                                                            case J.PStart{}: {==}
                                                                                            case J.PMinus{}: {==}
                                                                                            case J.PZero{}: {==}
                                                                                            case J.PInteger{}: {==}
                                                                                            case J.PDot{}: {==}
                                                                                            case J.PFraction{}: {==}
                                                                                            case J.PExponent{}: {==}
                                                                                            case J.PSign{}: {==}
                                                                                            case J.PDigits{}: {==}
                                                                                            case J.PInvalid{}: {==}
                                                                                    case True{}:
                                                                                      match p:
                                                                                        case J.PStart{}: {==}
                                                                                        case J.PMinus{}: {==}
                                                                                        case J.PZero{}: {==}
                                                                                        case J.PInteger{}: {==}
                                                                                        case J.PDot{}: {==}
                                                                                        case J.PFraction{}: {==}
                                                                                        case J.PExponent{}: {==}
                                                                                        case J.PSign{}: {==}
                                                                                        case J.PDigits{}: {==}
                                                                                        case J.PInvalid{}: {==}
                                                                                case True{}:
                                                                                  match p:
                                                                                    case J.PStart{}: {==}
                                                                                    case J.PMinus{}: {==}
                                                                                    case J.PZero{}: {==}
                                                                                    case J.PInteger{}: {==}
                                                                                    case J.PDot{}: {==}
                                                                                    case J.PFraction{}: {==}
                                                                                    case J.PExponent{}: {==}
                                                                                    case J.PSign{}: {==}
                                                                                    case J.PDigits{}: {==}
                                                                                    case J.PInvalid{}: {==}
                                                                            case True{}:
                                                                              match p:
                                                                                case J.PStart{}: {==}
                                                                                case J.PMinus{}: {==}
                                                                                case J.PZero{}: {==}
                                                                                case J.PInteger{}: {==}
                                                                                case J.PDot{}: {==}
                                                                                case J.PFraction{}: {==}
                                                                                case J.PExponent{}: {==}
                                                                                case J.PSign{}: {==}
                                                                                case J.PDigits{}: {==}
                                                                                case J.PInvalid{}: {==}
                                                                        case True{}:
                                                                          match p:
                                                                            case J.PStart{}: {==}
                                                                            case J.PMinus{}: {==}
                                                                            case J.PZero{}: {==}
                                                                            case J.PInteger{}: {==}
                                                                            case J.PDot{}: {==}
                                                                            case J.PFraction{}: {==}
                                                                            case J.PExponent{}: {==}
                                                                            case J.PSign{}: {==}
                                                                            case J.PDigits{}: {==}
                                                                            case J.PInvalid{}: {==}
                                                                    case True{}:
                                                                      match p:
                                                                        case J.PStart{}: {==}
                                                                        case J.PMinus{}: {==}
                                                                        case J.PZero{}: {==}
                                                                        case J.PInteger{}: {==}
                                                                        case J.PDot{}: {==}
                                                                        case J.PFraction{}: {==}
                                                                        case J.PExponent{}: {==}
                                                                        case J.PSign{}: {==}
                                                                        case J.PDigits{}: {==}
                                                                        case J.PInvalid{}: {==}
                                                                case True{}:
                                                                  match p:
                                                                    case J.PStart{}: {==}
                                                                    case J.PMinus{}: {==}
                                                                    case J.PZero{}: {==}
                                                                    case J.PInteger{}: {==}
                                                                    case J.PDot{}: {==}
                                                                    case J.PFraction{}: {==}
                                                                    case J.PExponent{}: {==}
                                                                    case J.PSign{}: {==}
                                                                    case J.PDigits{}: {==}
                                                                    case J.PInvalid{}: {==}
                                                            case True{}:
                                                              match p:
                                                                case J.PStart{}: {==}
                                                                case J.PMinus{}: {==}
                                                                case J.PZero{}: {==}
                                                                case J.PInteger{}: {==}
                                                                case J.PDot{}: {==}
                                                                case J.PFraction{}: {==}
                                                                case J.PExponent{}: {==}
                                                                case J.PSign{}: {==}
                                                                case J.PDigits{}: {==}
                                                                case J.PInvalid{}: {==}
                                                        case True{}:
                                                          match p:
                                                            case J.PStart{}: {==}
                                                            case J.PMinus{}: {==}
                                                            case J.PZero{}: {==}
                                                            case J.PInteger{}: {==}
                                                            case J.PDot{}: {==}
                                                            case J.PFraction{}: {==}
                                                            case J.PExponent{}: {==}
                                                            case J.PSign{}: {==}
                                                            case J.PDigits{}: {==}
                                                            case J.PInvalid{}: {==}
                                                    case True{}:
                                                      match p:
                                                        case J.PStart{}: {==}
                                                        case J.PMinus{}: {==}
                                                        case J.PZero{}: {==}
                                                        case J.PInteger{}: {==}
                                                        case J.PDot{}: {==}
                                                        case J.PFraction{}: {==}
                                                        case J.PExponent{}: {==}
                                                        case J.PSign{}: {==}
                                                        case J.PDigits{}: {==}
                                                        case J.PInvalid{}: {==}
                                                case True{}:
                                                  match p:
                                                    case J.PStart{}: {==}
                                                    case J.PMinus{}: {==}
                                                    case J.PZero{}: {==}
                                                    case J.PInteger{}: {==}
                                                    case J.PDot{}: {==}
                                                    case J.PFraction{}: {==}
                                                    case J.PExponent{}: {==}
                                                    case J.PSign{}: {==}
                                                    case J.PDigits{}: {==}
                                                    case J.PInvalid{}: {==}
                                            case True{}:
                                              match p:
                                                case J.PStart{}: {==}
                                                case J.PMinus{}: {==}
                                                case J.PZero{}: {==}
                                                case J.PInteger{}: {==}
                                                case J.PDot{}: {==}
                                                case J.PFraction{}: {==}
                                                case J.PExponent{}: {==}
                                                case J.PSign{}: {==}
                                                case J.PDigits{}: {==}
                                                case J.PInvalid{}: {==}
                                        case True{}:
                                          match p:
                                            case J.PStart{}: {==}
                                            case J.PMinus{}: {==}
                                            case J.PZero{}: {==}
                                            case J.PInteger{}: {==}
                                            case J.PDot{}: {==}
                                            case J.PFraction{}: {==}
                                            case J.PExponent{}: {==}
                                            case J.PSign{}: {==}
                                            case J.PDigits{}: {==}
                                            case J.PInvalid{}: {==}
                                    case True{}:
                                      match p:
                                        case J.PStart{}: {==}
                                        case J.PMinus{}: {==}
                                        case J.PZero{}: {==}
                                        case J.PInteger{}: {==}
                                        case J.PDot{}: {==}
                                        case J.PFraction{}: {==}
                                        case J.PExponent{}: {==}
                                        case J.PSign{}: {==}
                                        case J.PDigits{}: {==}
                                        case J.PInvalid{}: {==}
                                case True{}:
                                  match p:
                                    case J.PStart{}: {==}
                                    case J.PMinus{}: {==}
                                    case J.PZero{}: {==}
                                    case J.PInteger{}: {==}
                                    case J.PDot{}: {==}
                                    case J.PFraction{}: {==}
                                    case J.PExponent{}: {==}
                                    case J.PSign{}: {==}
                                    case J.PDigits{}: {==}
                                    case J.PInvalid{}: {==}
                        case True{}:
                          match b6:
                            case False{}:
                              match p:
                                case J.PStart{}: {==}
                                case J.PMinus{}: {==}
                                case J.PZero{}: {==}
                                case J.PInteger{}: {==}
                                case J.PDot{}: {==}
                                case J.PFraction{}: {==}
                                case J.PExponent{}: {==}
                                case J.PSign{}: {==}
                                case J.PDigits{}: {==}
                                case J.PInvalid{}: {==}
                            case True{}:
                              match b7:
                                case False{}:
                                  match b8:
                                    case False{}:
                                      match b9:
                                        case False{}:
                                          match b10:
                                            case False{}:
                                              match b11:
                                                case False{}:
                                                  match b12:
                                                    case False{}:
                                                      match b13:
                                                        case False{}:
                                                          match b14:
                                                            case False{}:
                                                              match b15:
                                                                case False{}:
                                                                  match b16:
                                                                    case False{}:
                                                                      match b17:
                                                                        case False{}:
                                                                          match b18:
                                                                            case False{}:
                                                                              match b19:
                                                                                case False{}:
                                                                                  match b20:
                                                                                    case False{}:
                                                                                      match b21:
                                                                                        case False{}:
                                                                                          match b22:
                                                                                            case False{}:
                                                                                              match b23:
                                                                                                case False{}:
                                                                                                  match b24:
                                                                                                    case False{}:
                                                                                                      match b25:
                                                                                                        case False{}:
                                                                                                          match b26:
                                                                                                            case False{}:
                                                                                                              match b27:
                                                                                                                case False{}:
                                                                                                                  match b28:
                                                                                                                    case False{}:
                                                                                                                      match b29:
                                                                                                                        case False{}:
                                                                                                                          match b30:
                                                                                                                            case False{}:
                                                                                                                              match b31:
                                                                                                                                case False{}:
                                                                                                                                  impossible({J.number_digit(p, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), False{}) == J.PInvalid{} : J.Phase}, false_true(e))
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case True{}:
                                                                                                                              match p:
                                                                                                                                case J.PStart{}: {==}
                                                                                                                                case J.PMinus{}: {==}
                                                                                                                                case J.PZero{}: {==}
                                                                                                                                case J.PInteger{}: {==}
                                                                                                                                case J.PDot{}: {==}
                                                                                                                                case J.PFraction{}: {==}
                                                                                                                                case J.PExponent{}: {==}
                                                                                                                                case J.PSign{}: {==}
                                                                                                                                case J.PDigits{}: {==}
                                                                                                                                case J.PInvalid{}: {==}
                                                                                                                        case True{}:
                                                                                                                          match p:
                                                                                                                            case J.PStart{}: {==}
                                                                                                                            case J.PMinus{}: {==}
                                                                                                                            case J.PZero{}: {==}
                                                                                                                            case J.PInteger{}: {==}
                                                                                                                            case J.PDot{}: {==}
                                                                                                                            case J.PFraction{}: {==}
                                                                                                                            case J.PExponent{}: {==}
                                                                                                                            case J.PSign{}: {==}
                                                                                                                            case J.PDigits{}: {==}
                                                                                                                            case J.PInvalid{}: {==}
                                                                                                                    case True{}:
                                                                                                                      match p:
                                                                                                                        case J.PStart{}: {==}
                                                                                                                        case J.PMinus{}: {==}
                                                                                                                        case J.PZero{}: {==}
                                                                                                                        case J.PInteger{}: {==}
                                                                                                                        case J.PDot{}: {==}
                                                                                                                        case J.PFraction{}: {==}
                                                                                                                        case J.PExponent{}: {==}
                                                                                                                        case J.PSign{}: {==}
                                                                                                                        case J.PDigits{}: {==}
                                                                                                                        case J.PInvalid{}: {==}
                                                                                                                case True{}:
                                                                                                                  match p:
                                                                                                                    case J.PStart{}: {==}
                                                                                                                    case J.PMinus{}: {==}
                                                                                                                    case J.PZero{}: {==}
                                                                                                                    case J.PInteger{}: {==}
                                                                                                                    case J.PDot{}: {==}
                                                                                                                    case J.PFraction{}: {==}
                                                                                                                    case J.PExponent{}: {==}
                                                                                                                    case J.PSign{}: {==}
                                                                                                                    case J.PDigits{}: {==}
                                                                                                                    case J.PInvalid{}: {==}
                                                                                                            case True{}:
                                                                                                              match p:
                                                                                                                case J.PStart{}: {==}
                                                                                                                case J.PMinus{}: {==}
                                                                                                                case J.PZero{}: {==}
                                                                                                                case J.PInteger{}: {==}
                                                                                                                case J.PDot{}: {==}
                                                                                                                case J.PFraction{}: {==}
                                                                                                                case J.PExponent{}: {==}
                                                                                                                case J.PSign{}: {==}
                                                                                                                case J.PDigits{}: {==}
                                                                                                                case J.PInvalid{}: {==}
                                                                                                        case True{}:
                                                                                                          match p:
                                                                                                            case J.PStart{}: {==}
                                                                                                            case J.PMinus{}: {==}
                                                                                                            case J.PZero{}: {==}
                                                                                                            case J.PInteger{}: {==}
                                                                                                            case J.PDot{}: {==}
                                                                                                            case J.PFraction{}: {==}
                                                                                                            case J.PExponent{}: {==}
                                                                                                            case J.PSign{}: {==}
                                                                                                            case J.PDigits{}: {==}
                                                                                                            case J.PInvalid{}: {==}
                                                                                                    case True{}:
                                                                                                      match p:
                                                                                                        case J.PStart{}: {==}
                                                                                                        case J.PMinus{}: {==}
                                                                                                        case J.PZero{}: {==}
                                                                                                        case J.PInteger{}: {==}
                                                                                                        case J.PDot{}: {==}
                                                                                                        case J.PFraction{}: {==}
                                                                                                        case J.PExponent{}: {==}
                                                                                                        case J.PSign{}: {==}
                                                                                                        case J.PDigits{}: {==}
                                                                                                        case J.PInvalid{}: {==}
                                                                                                case True{}:
                                                                                                  match p:
                                                                                                    case J.PStart{}: {==}
                                                                                                    case J.PMinus{}: {==}
                                                                                                    case J.PZero{}: {==}
                                                                                                    case J.PInteger{}: {==}
                                                                                                    case J.PDot{}: {==}
                                                                                                    case J.PFraction{}: {==}
                                                                                                    case J.PExponent{}: {==}
                                                                                                    case J.PSign{}: {==}
                                                                                                    case J.PDigits{}: {==}
                                                                                                    case J.PInvalid{}: {==}
                                                                                            case True{}:
                                                                                              match p:
                                                                                                case J.PStart{}: {==}
                                                                                                case J.PMinus{}: {==}
                                                                                                case J.PZero{}: {==}
                                                                                                case J.PInteger{}: {==}
                                                                                                case J.PDot{}: {==}
                                                                                                case J.PFraction{}: {==}
                                                                                                case J.PExponent{}: {==}
                                                                                                case J.PSign{}: {==}
                                                                                                case J.PDigits{}: {==}
                                                                                                case J.PInvalid{}: {==}
                                                                                        case True{}:
                                                                                          match p:
                                                                                            case J.PStart{}: {==}
                                                                                            case J.PMinus{}: {==}
                                                                                            case J.PZero{}: {==}
                                                                                            case J.PInteger{}: {==}
                                                                                            case J.PDot{}: {==}
                                                                                            case J.PFraction{}: {==}
                                                                                            case J.PExponent{}: {==}
                                                                                            case J.PSign{}: {==}
                                                                                            case J.PDigits{}: {==}
                                                                                            case J.PInvalid{}: {==}
                                                                                    case True{}:
                                                                                      match p:
                                                                                        case J.PStart{}: {==}
                                                                                        case J.PMinus{}: {==}
                                                                                        case J.PZero{}: {==}
                                                                                        case J.PInteger{}: {==}
                                                                                        case J.PDot{}: {==}
                                                                                        case J.PFraction{}: {==}
                                                                                        case J.PExponent{}: {==}
                                                                                        case J.PSign{}: {==}
                                                                                        case J.PDigits{}: {==}
                                                                                        case J.PInvalid{}: {==}
                                                                                case True{}:
                                                                                  match p:
                                                                                    case J.PStart{}: {==}
                                                                                    case J.PMinus{}: {==}
                                                                                    case J.PZero{}: {==}
                                                                                    case J.PInteger{}: {==}
                                                                                    case J.PDot{}: {==}
                                                                                    case J.PFraction{}: {==}
                                                                                    case J.PExponent{}: {==}
                                                                                    case J.PSign{}: {==}
                                                                                    case J.PDigits{}: {==}
                                                                                    case J.PInvalid{}: {==}
                                                                            case True{}:
                                                                              match p:
                                                                                case J.PStart{}: {==}
                                                                                case J.PMinus{}: {==}
                                                                                case J.PZero{}: {==}
                                                                                case J.PInteger{}: {==}
                                                                                case J.PDot{}: {==}
                                                                                case J.PFraction{}: {==}
                                                                                case J.PExponent{}: {==}
                                                                                case J.PSign{}: {==}
                                                                                case J.PDigits{}: {==}
                                                                                case J.PInvalid{}: {==}
                                                                        case True{}:
                                                                          match p:
                                                                            case J.PStart{}: {==}
                                                                            case J.PMinus{}: {==}
                                                                            case J.PZero{}: {==}
                                                                            case J.PInteger{}: {==}
                                                                            case J.PDot{}: {==}
                                                                            case J.PFraction{}: {==}
                                                                            case J.PExponent{}: {==}
                                                                            case J.PSign{}: {==}
                                                                            case J.PDigits{}: {==}
                                                                            case J.PInvalid{}: {==}
                                                                    case True{}:
                                                                      match p:
                                                                        case J.PStart{}: {==}
                                                                        case J.PMinus{}: {==}
                                                                        case J.PZero{}: {==}
                                                                        case J.PInteger{}: {==}
                                                                        case J.PDot{}: {==}
                                                                        case J.PFraction{}: {==}
                                                                        case J.PExponent{}: {==}
                                                                        case J.PSign{}: {==}
                                                                        case J.PDigits{}: {==}
                                                                        case J.PInvalid{}: {==}
                                                                case True{}:
                                                                  match p:
                                                                    case J.PStart{}: {==}
                                                                    case J.PMinus{}: {==}
                                                                    case J.PZero{}: {==}
                                                                    case J.PInteger{}: {==}
                                                                    case J.PDot{}: {==}
                                                                    case J.PFraction{}: {==}
                                                                    case J.PExponent{}: {==}
                                                                    case J.PSign{}: {==}
                                                                    case J.PDigits{}: {==}
                                                                    case J.PInvalid{}: {==}
                                                            case True{}:
                                                              match p:
                                                                case J.PStart{}: {==}
                                                                case J.PMinus{}: {==}
                                                                case J.PZero{}: {==}
                                                                case J.PInteger{}: {==}
                                                                case J.PDot{}: {==}
                                                                case J.PFraction{}: {==}
                                                                case J.PExponent{}: {==}
                                                                case J.PSign{}: {==}
                                                                case J.PDigits{}: {==}
                                                                case J.PInvalid{}: {==}
                                                        case True{}:
                                                          match p:
                                                            case J.PStart{}: {==}
                                                            case J.PMinus{}: {==}
                                                            case J.PZero{}: {==}
                                                            case J.PInteger{}: {==}
                                                            case J.PDot{}: {==}
                                                            case J.PFraction{}: {==}
                                                            case J.PExponent{}: {==}
                                                            case J.PSign{}: {==}
                                                            case J.PDigits{}: {==}
                                                            case J.PInvalid{}: {==}
                                                    case True{}:
                                                      match p:
                                                        case J.PStart{}: {==}
                                                        case J.PMinus{}: {==}
                                                        case J.PZero{}: {==}
                                                        case J.PInteger{}: {==}
                                                        case J.PDot{}: {==}
                                                        case J.PFraction{}: {==}
                                                        case J.PExponent{}: {==}
                                                        case J.PSign{}: {==}
                                                        case J.PDigits{}: {==}
                                                        case J.PInvalid{}: {==}
                                                case True{}:
                                                  match p:
                                                    case J.PStart{}: {==}
                                                    case J.PMinus{}: {==}
                                                    case J.PZero{}: {==}
                                                    case J.PInteger{}: {==}
                                                    case J.PDot{}: {==}
                                                    case J.PFraction{}: {==}
                                                    case J.PExponent{}: {==}
                                                    case J.PSign{}: {==}
                                                    case J.PDigits{}: {==}
                                                    case J.PInvalid{}: {==}
                                            case True{}:
                                              match p:
                                                case J.PStart{}: {==}
                                                case J.PMinus{}: {==}
                                                case J.PZero{}: {==}
                                                case J.PInteger{}: {==}
                                                case J.PDot{}: {==}
                                                case J.PFraction{}: {==}
                                                case J.PExponent{}: {==}
                                                case J.PSign{}: {==}
                                                case J.PDigits{}: {==}
                                                case J.PInvalid{}: {==}
                                        case True{}:
                                          match p:
                                            case J.PStart{}: {==}
                                            case J.PMinus{}: {==}
                                            case J.PZero{}: {==}
                                            case J.PInteger{}: {==}
                                            case J.PDot{}: {==}
                                            case J.PFraction{}: {==}
                                            case J.PExponent{}: {==}
                                            case J.PSign{}: {==}
                                            case J.PDigits{}: {==}
                                            case J.PInvalid{}: {==}
                                    case True{}:
                                      match p:
                                        case J.PStart{}: {==}
                                        case J.PMinus{}: {==}
                                        case J.PZero{}: {==}
                                        case J.PInteger{}: {==}
                                        case J.PDot{}: {==}
                                        case J.PFraction{}: {==}
                                        case J.PExponent{}: {==}
                                        case J.PSign{}: {==}
                                        case J.PDigits{}: {==}
                                        case J.PInvalid{}: {==}
                                case True{}:
                                  match p:
                                    case J.PStart{}: {==}
                                    case J.PMinus{}: {==}
                                    case J.PZero{}: {==}
                                    case J.PInteger{}: {==}
                                    case J.PDot{}: {==}
                                    case J.PFraction{}: {==}
                                    case J.PExponent{}: {==}
                                    case J.PSign{}: {==}
                                    case J.PDigits{}: {==}
                                    case J.PInvalid{}: {==}
                    case True{}:
                      match p:
                        case J.PStart{}: {==}
                        case J.PMinus{}: {==}
                        case J.PZero{}: {==}
                        case J.PInteger{}: {==}
                        case J.PDot{}: {==}
                        case J.PFraction{}: {==}
                        case J.PExponent{}: {==}
                        case J.PSign{}: {==}
                        case J.PDigits{}: {==}
                        case J.PInvalid{}: {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          match p:
                            case J.PStart{}: {==}
                            case J.PMinus{}: {==}
                            case J.PZero{}: {==}
                            case J.PInteger{}: {==}
                            case J.PDot{}: {==}
                            case J.PFraction{}: {==}
                            case J.PExponent{}: {==}
                            case J.PSign{}: {==}
                            case J.PDigits{}: {==}
                            case J.PInvalid{}: {==}
                        case True{}:
                          match b6:
                            case False{}:
                              match b7:
                                case False{}:
                                  match b8:
                                    case False{}:
                                      match b9:
                                        case False{}:
                                          match b10:
                                            case False{}:
                                              match b11:
                                                case False{}:
                                                  match b12:
                                                    case False{}:
                                                      match b13:
                                                        case False{}:
                                                          match b14:
                                                            case False{}:
                                                              match b15:
                                                                case False{}:
                                                                  match b16:
                                                                    case False{}:
                                                                      match b17:
                                                                        case False{}:
                                                                          match b18:
                                                                            case False{}:
                                                                              match b19:
                                                                                case False{}:
                                                                                  match b20:
                                                                                    case False{}:
                                                                                      match b21:
                                                                                        case False{}:
                                                                                          match b22:
                                                                                            case False{}:
                                                                                              match b23:
                                                                                                case False{}:
                                                                                                  match b24:
                                                                                                    case False{}:
                                                                                                      match b25:
                                                                                                        case False{}:
                                                                                                          match b26:
                                                                                                            case False{}:
                                                                                                              match b27:
                                                                                                                case False{}:
                                                                                                                  match b28:
                                                                                                                    case False{}:
                                                                                                                      match b29:
                                                                                                                        case False{}:
                                                                                                                          match b30:
                                                                                                                            case False{}:
                                                                                                                              match b31:
                                                                                                                                case False{}:
                                                                                                                                  impossible({J.number_digit(p, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), False{}) == J.PInvalid{} : J.Phase}, false_true(e))
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case True{}:
                                                                                                                              match p:
                                                                                                                                case J.PStart{}: {==}
                                                                                                                                case J.PMinus{}: {==}
                                                                                                                                case J.PZero{}: {==}
                                                                                                                                case J.PInteger{}: {==}
                                                                                                                                case J.PDot{}: {==}
                                                                                                                                case J.PFraction{}: {==}
                                                                                                                                case J.PExponent{}: {==}
                                                                                                                                case J.PSign{}: {==}
                                                                                                                                case J.PDigits{}: {==}
                                                                                                                                case J.PInvalid{}: {==}
                                                                                                                        case True{}:
                                                                                                                          match p:
                                                                                                                            case J.PStart{}: {==}
                                                                                                                            case J.PMinus{}: {==}
                                                                                                                            case J.PZero{}: {==}
                                                                                                                            case J.PInteger{}: {==}
                                                                                                                            case J.PDot{}: {==}
                                                                                                                            case J.PFraction{}: {==}
                                                                                                                            case J.PExponent{}: {==}
                                                                                                                            case J.PSign{}: {==}
                                                                                                                            case J.PDigits{}: {==}
                                                                                                                            case J.PInvalid{}: {==}
                                                                                                                    case True{}:
                                                                                                                      match p:
                                                                                                                        case J.PStart{}: {==}
                                                                                                                        case J.PMinus{}: {==}
                                                                                                                        case J.PZero{}: {==}
                                                                                                                        case J.PInteger{}: {==}
                                                                                                                        case J.PDot{}: {==}
                                                                                                                        case J.PFraction{}: {==}
                                                                                                                        case J.PExponent{}: {==}
                                                                                                                        case J.PSign{}: {==}
                                                                                                                        case J.PDigits{}: {==}
                                                                                                                        case J.PInvalid{}: {==}
                                                                                                                case True{}:
                                                                                                                  match p:
                                                                                                                    case J.PStart{}: {==}
                                                                                                                    case J.PMinus{}: {==}
                                                                                                                    case J.PZero{}: {==}
                                                                                                                    case J.PInteger{}: {==}
                                                                                                                    case J.PDot{}: {==}
                                                                                                                    case J.PFraction{}: {==}
                                                                                                                    case J.PExponent{}: {==}
                                                                                                                    case J.PSign{}: {==}
                                                                                                                    case J.PDigits{}: {==}
                                                                                                                    case J.PInvalid{}: {==}
                                                                                                            case True{}:
                                                                                                              match p:
                                                                                                                case J.PStart{}: {==}
                                                                                                                case J.PMinus{}: {==}
                                                                                                                case J.PZero{}: {==}
                                                                                                                case J.PInteger{}: {==}
                                                                                                                case J.PDot{}: {==}
                                                                                                                case J.PFraction{}: {==}
                                                                                                                case J.PExponent{}: {==}
                                                                                                                case J.PSign{}: {==}
                                                                                                                case J.PDigits{}: {==}
                                                                                                                case J.PInvalid{}: {==}
                                                                                                        case True{}:
                                                                                                          match p:
                                                                                                            case J.PStart{}: {==}
                                                                                                            case J.PMinus{}: {==}
                                                                                                            case J.PZero{}: {==}
                                                                                                            case J.PInteger{}: {==}
                                                                                                            case J.PDot{}: {==}
                                                                                                            case J.PFraction{}: {==}
                                                                                                            case J.PExponent{}: {==}
                                                                                                            case J.PSign{}: {==}
                                                                                                            case J.PDigits{}: {==}
                                                                                                            case J.PInvalid{}: {==}
                                                                                                    case True{}:
                                                                                                      match p:
                                                                                                        case J.PStart{}: {==}
                                                                                                        case J.PMinus{}: {==}
                                                                                                        case J.PZero{}: {==}
                                                                                                        case J.PInteger{}: {==}
                                                                                                        case J.PDot{}: {==}
                                                                                                        case J.PFraction{}: {==}
                                                                                                        case J.PExponent{}: {==}
                                                                                                        case J.PSign{}: {==}
                                                                                                        case J.PDigits{}: {==}
                                                                                                        case J.PInvalid{}: {==}
                                                                                                case True{}:
                                                                                                  match p:
                                                                                                    case J.PStart{}: {==}
                                                                                                    case J.PMinus{}: {==}
                                                                                                    case J.PZero{}: {==}
                                                                                                    case J.PInteger{}: {==}
                                                                                                    case J.PDot{}: {==}
                                                                                                    case J.PFraction{}: {==}
                                                                                                    case J.PExponent{}: {==}
                                                                                                    case J.PSign{}: {==}
                                                                                                    case J.PDigits{}: {==}
                                                                                                    case J.PInvalid{}: {==}
                                                                                            case True{}:
                                                                                              match p:
                                                                                                case J.PStart{}: {==}
                                                                                                case J.PMinus{}: {==}
                                                                                                case J.PZero{}: {==}
                                                                                                case J.PInteger{}: {==}
                                                                                                case J.PDot{}: {==}
                                                                                                case J.PFraction{}: {==}
                                                                                                case J.PExponent{}: {==}
                                                                                                case J.PSign{}: {==}
                                                                                                case J.PDigits{}: {==}
                                                                                                case J.PInvalid{}: {==}
                                                                                        case True{}:
                                                                                          match p:
                                                                                            case J.PStart{}: {==}
                                                                                            case J.PMinus{}: {==}
                                                                                            case J.PZero{}: {==}
                                                                                            case J.PInteger{}: {==}
                                                                                            case J.PDot{}: {==}
                                                                                            case J.PFraction{}: {==}
                                                                                            case J.PExponent{}: {==}
                                                                                            case J.PSign{}: {==}
                                                                                            case J.PDigits{}: {==}
                                                                                            case J.PInvalid{}: {==}
                                                                                    case True{}:
                                                                                      match p:
                                                                                        case J.PStart{}: {==}
                                                                                        case J.PMinus{}: {==}
                                                                                        case J.PZero{}: {==}
                                                                                        case J.PInteger{}: {==}
                                                                                        case J.PDot{}: {==}
                                                                                        case J.PFraction{}: {==}
                                                                                        case J.PExponent{}: {==}
                                                                                        case J.PSign{}: {==}
                                                                                        case J.PDigits{}: {==}
                                                                                        case J.PInvalid{}: {==}
                                                                                case True{}:
                                                                                  match p:
                                                                                    case J.PStart{}: {==}
                                                                                    case J.PMinus{}: {==}
                                                                                    case J.PZero{}: {==}
                                                                                    case J.PInteger{}: {==}
                                                                                    case J.PDot{}: {==}
                                                                                    case J.PFraction{}: {==}
                                                                                    case J.PExponent{}: {==}
                                                                                    case J.PSign{}: {==}
                                                                                    case J.PDigits{}: {==}
                                                                                    case J.PInvalid{}: {==}
                                                                            case True{}:
                                                                              match p:
                                                                                case J.PStart{}: {==}
                                                                                case J.PMinus{}: {==}
                                                                                case J.PZero{}: {==}
                                                                                case J.PInteger{}: {==}
                                                                                case J.PDot{}: {==}
                                                                                case J.PFraction{}: {==}
                                                                                case J.PExponent{}: {==}
                                                                                case J.PSign{}: {==}
                                                                                case J.PDigits{}: {==}
                                                                                case J.PInvalid{}: {==}
                                                                        case True{}:
                                                                          match p:
                                                                            case J.PStart{}: {==}
                                                                            case J.PMinus{}: {==}
                                                                            case J.PZero{}: {==}
                                                                            case J.PInteger{}: {==}
                                                                            case J.PDot{}: {==}
                                                                            case J.PFraction{}: {==}
                                                                            case J.PExponent{}: {==}
                                                                            case J.PSign{}: {==}
                                                                            case J.PDigits{}: {==}
                                                                            case J.PInvalid{}: {==}
                                                                    case True{}:
                                                                      match p:
                                                                        case J.PStart{}: {==}
                                                                        case J.PMinus{}: {==}
                                                                        case J.PZero{}: {==}
                                                                        case J.PInteger{}: {==}
                                                                        case J.PDot{}: {==}
                                                                        case J.PFraction{}: {==}
                                                                        case J.PExponent{}: {==}
                                                                        case J.PSign{}: {==}
                                                                        case J.PDigits{}: {==}
                                                                        case J.PInvalid{}: {==}
                                                                case True{}:
                                                                  match p:
                                                                    case J.PStart{}: {==}
                                                                    case J.PMinus{}: {==}
                                                                    case J.PZero{}: {==}
                                                                    case J.PInteger{}: {==}
                                                                    case J.PDot{}: {==}
                                                                    case J.PFraction{}: {==}
                                                                    case J.PExponent{}: {==}
                                                                    case J.PSign{}: {==}
                                                                    case J.PDigits{}: {==}
                                                                    case J.PInvalid{}: {==}
                                                            case True{}:
                                                              match p:
                                                                case J.PStart{}: {==}
                                                                case J.PMinus{}: {==}
                                                                case J.PZero{}: {==}
                                                                case J.PInteger{}: {==}
                                                                case J.PDot{}: {==}
                                                                case J.PFraction{}: {==}
                                                                case J.PExponent{}: {==}
                                                                case J.PSign{}: {==}
                                                                case J.PDigits{}: {==}
                                                                case J.PInvalid{}: {==}
                                                        case True{}:
                                                          match p:
                                                            case J.PStart{}: {==}
                                                            case J.PMinus{}: {==}
                                                            case J.PZero{}: {==}
                                                            case J.PInteger{}: {==}
                                                            case J.PDot{}: {==}
                                                            case J.PFraction{}: {==}
                                                            case J.PExponent{}: {==}
                                                            case J.PSign{}: {==}
                                                            case J.PDigits{}: {==}
                                                            case J.PInvalid{}: {==}
                                                    case True{}:
                                                      match p:
                                                        case J.PStart{}: {==}
                                                        case J.PMinus{}: {==}
                                                        case J.PZero{}: {==}
                                                        case J.PInteger{}: {==}
                                                        case J.PDot{}: {==}
                                                        case J.PFraction{}: {==}
                                                        case J.PExponent{}: {==}
                                                        case J.PSign{}: {==}
                                                        case J.PDigits{}: {==}
                                                        case J.PInvalid{}: {==}
                                                case True{}:
                                                  match p:
                                                    case J.PStart{}: {==}
                                                    case J.PMinus{}: {==}
                                                    case J.PZero{}: {==}
                                                    case J.PInteger{}: {==}
                                                    case J.PDot{}: {==}
                                                    case J.PFraction{}: {==}
                                                    case J.PExponent{}: {==}
                                                    case J.PSign{}: {==}
                                                    case J.PDigits{}: {==}
                                                    case J.PInvalid{}: {==}
                                            case True{}:
                                              match p:
                                                case J.PStart{}: {==}
                                                case J.PMinus{}: {==}
                                                case J.PZero{}: {==}
                                                case J.PInteger{}: {==}
                                                case J.PDot{}: {==}
                                                case J.PFraction{}: {==}
                                                case J.PExponent{}: {==}
                                                case J.PSign{}: {==}
                                                case J.PDigits{}: {==}
                                                case J.PInvalid{}: {==}
                                        case True{}:
                                          match p:
                                            case J.PStart{}: {==}
                                            case J.PMinus{}: {==}
                                            case J.PZero{}: {==}
                                            case J.PInteger{}: {==}
                                            case J.PDot{}: {==}
                                            case J.PFraction{}: {==}
                                            case J.PExponent{}: {==}
                                            case J.PSign{}: {==}
                                            case J.PDigits{}: {==}
                                            case J.PInvalid{}: {==}
                                    case True{}:
                                      match p:
                                        case J.PStart{}: {==}
                                        case J.PMinus{}: {==}
                                        case J.PZero{}: {==}
                                        case J.PInteger{}: {==}
                                        case J.PDot{}: {==}
                                        case J.PFraction{}: {==}
                                        case J.PExponent{}: {==}
                                        case J.PSign{}: {==}
                                        case J.PDigits{}: {==}
                                        case J.PInvalid{}: {==}
                                case True{}:
                                  match p:
                                    case J.PStart{}: {==}
                                    case J.PMinus{}: {==}
                                    case J.PZero{}: {==}
                                    case J.PInteger{}: {==}
                                    case J.PDot{}: {==}
                                    case J.PFraction{}: {==}
                                    case J.PExponent{}: {==}
                                    case J.PSign{}: {==}
                                    case J.PDigits{}: {==}
                                    case J.PInvalid{}: {==}
                            case True{}:
                              match p:
                                case J.PStart{}: {==}
                                case J.PMinus{}: {==}
                                case J.PZero{}: {==}
                                case J.PInteger{}: {==}
                                case J.PDot{}: {==}
                                case J.PFraction{}: {==}
                                case J.PExponent{}: {==}
                                case J.PSign{}: {==}
                                case J.PDigits{}: {==}
                                case J.PInvalid{}: {==}
                    case True{}:
                      match p:
                        case J.PStart{}: {==}
                        case J.PMinus{}: {==}
                        case J.PZero{}: {==}
                        case J.PInteger{}: {==}
                        case J.PDot{}: {==}
                        case J.PFraction{}: {==}
                        case J.PExponent{}: {==}
                        case J.PSign{}: {==}
                        case J.PDigits{}: {==}
                        case J.PInvalid{}: {==}
        case True{}:
          match b2:
            case False{}:
              match b3:
                case False{}:
                  match p:
                    case J.PStart{}: {==}
                    case J.PMinus{}: {==}
                    case J.PZero{}: {==}
                    case J.PInteger{}: {==}
                    case J.PDot{}: {==}
                    case J.PFraction{}: {==}
                    case J.PExponent{}: {==}
                    case J.PSign{}: {==}
                    case J.PDigits{}: {==}
                    case J.PInvalid{}: {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          match p:
                            case J.PStart{}: {==}
                            case J.PMinus{}: {==}
                            case J.PZero{}: {==}
                            case J.PInteger{}: {==}
                            case J.PDot{}: {==}
                            case J.PFraction{}: {==}
                            case J.PExponent{}: {==}
                            case J.PSign{}: {==}
                            case J.PDigits{}: {==}
                            case J.PInvalid{}: {==}
                        case True{}:
                          match b6:
                            case False{}:
                              match b7:
                                case False{}:
                                  match b8:
                                    case False{}:
                                      match b9:
                                        case False{}:
                                          match b10:
                                            case False{}:
                                              match b11:
                                                case False{}:
                                                  match b12:
                                                    case False{}:
                                                      match b13:
                                                        case False{}:
                                                          match b14:
                                                            case False{}:
                                                              match b15:
                                                                case False{}:
                                                                  match b16:
                                                                    case False{}:
                                                                      match b17:
                                                                        case False{}:
                                                                          match b18:
                                                                            case False{}:
                                                                              match b19:
                                                                                case False{}:
                                                                                  match b20:
                                                                                    case False{}:
                                                                                      match b21:
                                                                                        case False{}:
                                                                                          match b22:
                                                                                            case False{}:
                                                                                              match b23:
                                                                                                case False{}:
                                                                                                  match b24:
                                                                                                    case False{}:
                                                                                                      match b25:
                                                                                                        case False{}:
                                                                                                          match b26:
                                                                                                            case False{}:
                                                                                                              match b27:
                                                                                                                case False{}:
                                                                                                                  match b28:
                                                                                                                    case False{}:
                                                                                                                      match b29:
                                                                                                                        case False{}:
                                                                                                                          match b30:
                                                                                                                            case False{}:
                                                                                                                              match b31:
                                                                                                                                case False{}:
                                                                                                                                  impossible({J.number_digit(p, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), False{}) == J.PInvalid{} : J.Phase}, false_true(e))
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case True{}:
                                                                                                                              match p:
                                                                                                                                case J.PStart{}: {==}
                                                                                                                                case J.PMinus{}: {==}
                                                                                                                                case J.PZero{}: {==}
                                                                                                                                case J.PInteger{}: {==}
                                                                                                                                case J.PDot{}: {==}
                                                                                                                                case J.PFraction{}: {==}
                                                                                                                                case J.PExponent{}: {==}
                                                                                                                                case J.PSign{}: {==}
                                                                                                                                case J.PDigits{}: {==}
                                                                                                                                case J.PInvalid{}: {==}
                                                                                                                        case True{}:
                                                                                                                          match p:
                                                                                                                            case J.PStart{}: {==}
                                                                                                                            case J.PMinus{}: {==}
                                                                                                                            case J.PZero{}: {==}
                                                                                                                            case J.PInteger{}: {==}
                                                                                                                            case J.PDot{}: {==}
                                                                                                                            case J.PFraction{}: {==}
                                                                                                                            case J.PExponent{}: {==}
                                                                                                                            case J.PSign{}: {==}
                                                                                                                            case J.PDigits{}: {==}
                                                                                                                            case J.PInvalid{}: {==}
                                                                                                                    case True{}:
                                                                                                                      match p:
                                                                                                                        case J.PStart{}: {==}
                                                                                                                        case J.PMinus{}: {==}
                                                                                                                        case J.PZero{}: {==}
                                                                                                                        case J.PInteger{}: {==}
                                                                                                                        case J.PDot{}: {==}
                                                                                                                        case J.PFraction{}: {==}
                                                                                                                        case J.PExponent{}: {==}
                                                                                                                        case J.PSign{}: {==}
                                                                                                                        case J.PDigits{}: {==}
                                                                                                                        case J.PInvalid{}: {==}
                                                                                                                case True{}:
                                                                                                                  match p:
                                                                                                                    case J.PStart{}: {==}
                                                                                                                    case J.PMinus{}: {==}
                                                                                                                    case J.PZero{}: {==}
                                                                                                                    case J.PInteger{}: {==}
                                                                                                                    case J.PDot{}: {==}
                                                                                                                    case J.PFraction{}: {==}
                                                                                                                    case J.PExponent{}: {==}
                                                                                                                    case J.PSign{}: {==}
                                                                                                                    case J.PDigits{}: {==}
                                                                                                                    case J.PInvalid{}: {==}
                                                                                                            case True{}:
                                                                                                              match p:
                                                                                                                case J.PStart{}: {==}
                                                                                                                case J.PMinus{}: {==}
                                                                                                                case J.PZero{}: {==}
                                                                                                                case J.PInteger{}: {==}
                                                                                                                case J.PDot{}: {==}
                                                                                                                case J.PFraction{}: {==}
                                                                                                                case J.PExponent{}: {==}
                                                                                                                case J.PSign{}: {==}
                                                                                                                case J.PDigits{}: {==}
                                                                                                                case J.PInvalid{}: {==}
                                                                                                        case True{}:
                                                                                                          match p:
                                                                                                            case J.PStart{}: {==}
                                                                                                            case J.PMinus{}: {==}
                                                                                                            case J.PZero{}: {==}
                                                                                                            case J.PInteger{}: {==}
                                                                                                            case J.PDot{}: {==}
                                                                                                            case J.PFraction{}: {==}
                                                                                                            case J.PExponent{}: {==}
                                                                                                            case J.PSign{}: {==}
                                                                                                            case J.PDigits{}: {==}
                                                                                                            case J.PInvalid{}: {==}
                                                                                                    case True{}:
                                                                                                      match p:
                                                                                                        case J.PStart{}: {==}
                                                                                                        case J.PMinus{}: {==}
                                                                                                        case J.PZero{}: {==}
                                                                                                        case J.PInteger{}: {==}
                                                                                                        case J.PDot{}: {==}
                                                                                                        case J.PFraction{}: {==}
                                                                                                        case J.PExponent{}: {==}
                                                                                                        case J.PSign{}: {==}
                                                                                                        case J.PDigits{}: {==}
                                                                                                        case J.PInvalid{}: {==}
                                                                                                case True{}:
                                                                                                  match p:
                                                                                                    case J.PStart{}: {==}
                                                                                                    case J.PMinus{}: {==}
                                                                                                    case J.PZero{}: {==}
                                                                                                    case J.PInteger{}: {==}
                                                                                                    case J.PDot{}: {==}
                                                                                                    case J.PFraction{}: {==}
                                                                                                    case J.PExponent{}: {==}
                                                                                                    case J.PSign{}: {==}
                                                                                                    case J.PDigits{}: {==}
                                                                                                    case J.PInvalid{}: {==}
                                                                                            case True{}:
                                                                                              match p:
                                                                                                case J.PStart{}: {==}
                                                                                                case J.PMinus{}: {==}
                                                                                                case J.PZero{}: {==}
                                                                                                case J.PInteger{}: {==}
                                                                                                case J.PDot{}: {==}
                                                                                                case J.PFraction{}: {==}
                                                                                                case J.PExponent{}: {==}
                                                                                                case J.PSign{}: {==}
                                                                                                case J.PDigits{}: {==}
                                                                                                case J.PInvalid{}: {==}
                                                                                        case True{}:
                                                                                          match p:
                                                                                            case J.PStart{}: {==}
                                                                                            case J.PMinus{}: {==}
                                                                                            case J.PZero{}: {==}
                                                                                            case J.PInteger{}: {==}
                                                                                            case J.PDot{}: {==}
                                                                                            case J.PFraction{}: {==}
                                                                                            case J.PExponent{}: {==}
                                                                                            case J.PSign{}: {==}
                                                                                            case J.PDigits{}: {==}
                                                                                            case J.PInvalid{}: {==}
                                                                                    case True{}:
                                                                                      match p:
                                                                                        case J.PStart{}: {==}
                                                                                        case J.PMinus{}: {==}
                                                                                        case J.PZero{}: {==}
                                                                                        case J.PInteger{}: {==}
                                                                                        case J.PDot{}: {==}
                                                                                        case J.PFraction{}: {==}
                                                                                        case J.PExponent{}: {==}
                                                                                        case J.PSign{}: {==}
                                                                                        case J.PDigits{}: {==}
                                                                                        case J.PInvalid{}: {==}
                                                                                case True{}:
                                                                                  match p:
                                                                                    case J.PStart{}: {==}
                                                                                    case J.PMinus{}: {==}
                                                                                    case J.PZero{}: {==}
                                                                                    case J.PInteger{}: {==}
                                                                                    case J.PDot{}: {==}
                                                                                    case J.PFraction{}: {==}
                                                                                    case J.PExponent{}: {==}
                                                                                    case J.PSign{}: {==}
                                                                                    case J.PDigits{}: {==}
                                                                                    case J.PInvalid{}: {==}
                                                                            case True{}:
                                                                              match p:
                                                                                case J.PStart{}: {==}
                                                                                case J.PMinus{}: {==}
                                                                                case J.PZero{}: {==}
                                                                                case J.PInteger{}: {==}
                                                                                case J.PDot{}: {==}
                                                                                case J.PFraction{}: {==}
                                                                                case J.PExponent{}: {==}
                                                                                case J.PSign{}: {==}
                                                                                case J.PDigits{}: {==}
                                                                                case J.PInvalid{}: {==}
                                                                        case True{}:
                                                                          match p:
                                                                            case J.PStart{}: {==}
                                                                            case J.PMinus{}: {==}
                                                                            case J.PZero{}: {==}
                                                                            case J.PInteger{}: {==}
                                                                            case J.PDot{}: {==}
                                                                            case J.PFraction{}: {==}
                                                                            case J.PExponent{}: {==}
                                                                            case J.PSign{}: {==}
                                                                            case J.PDigits{}: {==}
                                                                            case J.PInvalid{}: {==}
                                                                    case True{}:
                                                                      match p:
                                                                        case J.PStart{}: {==}
                                                                        case J.PMinus{}: {==}
                                                                        case J.PZero{}: {==}
                                                                        case J.PInteger{}: {==}
                                                                        case J.PDot{}: {==}
                                                                        case J.PFraction{}: {==}
                                                                        case J.PExponent{}: {==}
                                                                        case J.PSign{}: {==}
                                                                        case J.PDigits{}: {==}
                                                                        case J.PInvalid{}: {==}
                                                                case True{}:
                                                                  match p:
                                                                    case J.PStart{}: {==}
                                                                    case J.PMinus{}: {==}
                                                                    case J.PZero{}: {==}
                                                                    case J.PInteger{}: {==}
                                                                    case J.PDot{}: {==}
                                                                    case J.PFraction{}: {==}
                                                                    case J.PExponent{}: {==}
                                                                    case J.PSign{}: {==}
                                                                    case J.PDigits{}: {==}
                                                                    case J.PInvalid{}: {==}
                                                            case True{}:
                                                              match p:
                                                                case J.PStart{}: {==}
                                                                case J.PMinus{}: {==}
                                                                case J.PZero{}: {==}
                                                                case J.PInteger{}: {==}
                                                                case J.PDot{}: {==}
                                                                case J.PFraction{}: {==}
                                                                case J.PExponent{}: {==}
                                                                case J.PSign{}: {==}
                                                                case J.PDigits{}: {==}
                                                                case J.PInvalid{}: {==}
                                                        case True{}:
                                                          match p:
                                                            case J.PStart{}: {==}
                                                            case J.PMinus{}: {==}
                                                            case J.PZero{}: {==}
                                                            case J.PInteger{}: {==}
                                                            case J.PDot{}: {==}
                                                            case J.PFraction{}: {==}
                                                            case J.PExponent{}: {==}
                                                            case J.PSign{}: {==}
                                                            case J.PDigits{}: {==}
                                                            case J.PInvalid{}: {==}
                                                    case True{}:
                                                      match p:
                                                        case J.PStart{}: {==}
                                                        case J.PMinus{}: {==}
                                                        case J.PZero{}: {==}
                                                        case J.PInteger{}: {==}
                                                        case J.PDot{}: {==}
                                                        case J.PFraction{}: {==}
                                                        case J.PExponent{}: {==}
                                                        case J.PSign{}: {==}
                                                        case J.PDigits{}: {==}
                                                        case J.PInvalid{}: {==}
                                                case True{}:
                                                  match p:
                                                    case J.PStart{}: {==}
                                                    case J.PMinus{}: {==}
                                                    case J.PZero{}: {==}
                                                    case J.PInteger{}: {==}
                                                    case J.PDot{}: {==}
                                                    case J.PFraction{}: {==}
                                                    case J.PExponent{}: {==}
                                                    case J.PSign{}: {==}
                                                    case J.PDigits{}: {==}
                                                    case J.PInvalid{}: {==}
                                            case True{}:
                                              match p:
                                                case J.PStart{}: {==}
                                                case J.PMinus{}: {==}
                                                case J.PZero{}: {==}
                                                case J.PInteger{}: {==}
                                                case J.PDot{}: {==}
                                                case J.PFraction{}: {==}
                                                case J.PExponent{}: {==}
                                                case J.PSign{}: {==}
                                                case J.PDigits{}: {==}
                                                case J.PInvalid{}: {==}
                                        case True{}:
                                          match p:
                                            case J.PStart{}: {==}
                                            case J.PMinus{}: {==}
                                            case J.PZero{}: {==}
                                            case J.PInteger{}: {==}
                                            case J.PDot{}: {==}
                                            case J.PFraction{}: {==}
                                            case J.PExponent{}: {==}
                                            case J.PSign{}: {==}
                                            case J.PDigits{}: {==}
                                            case J.PInvalid{}: {==}
                                    case True{}:
                                      match p:
                                        case J.PStart{}: {==}
                                        case J.PMinus{}: {==}
                                        case J.PZero{}: {==}
                                        case J.PInteger{}: {==}
                                        case J.PDot{}: {==}
                                        case J.PFraction{}: {==}
                                        case J.PExponent{}: {==}
                                        case J.PSign{}: {==}
                                        case J.PDigits{}: {==}
                                        case J.PInvalid{}: {==}
                                case True{}:
                                  match p:
                                    case J.PStart{}: {==}
                                    case J.PMinus{}: {==}
                                    case J.PZero{}: {==}
                                    case J.PInteger{}: {==}
                                    case J.PDot{}: {==}
                                    case J.PFraction{}: {==}
                                    case J.PExponent{}: {==}
                                    case J.PSign{}: {==}
                                    case J.PDigits{}: {==}
                                    case J.PInvalid{}: {==}
                            case True{}:
                              match p:
                                case J.PStart{}: {==}
                                case J.PMinus{}: {==}
                                case J.PZero{}: {==}
                                case J.PInteger{}: {==}
                                case J.PDot{}: {==}
                                case J.PFraction{}: {==}
                                case J.PExponent{}: {==}
                                case J.PSign{}: {==}
                                case J.PDigits{}: {==}
                                case J.PInvalid{}: {==}
                    case True{}:
                      match p:
                        case J.PStart{}: {==}
                        case J.PMinus{}: {==}
                        case J.PZero{}: {==}
                        case J.PInteger{}: {==}
                        case J.PDot{}: {==}
                        case J.PFraction{}: {==}
                        case J.PExponent{}: {==}
                        case J.PSign{}: {==}
                        case J.PDigits{}: {==}
                        case J.PInvalid{}: {==}
            case True{}:
              match p:
                case J.PStart{}: {==}
                case J.PMinus{}: {==}
                case J.PZero{}: {==}
                case J.PInteger{}: {==}
                case J.PDot{}: {==}
                case J.PFraction{}: {==}
                case J.PExponent{}: {==}
                case J.PSign{}: {==}
                case J.PDigits{}: {==}
                case J.PInvalid{}: {==}

def reject_digit(+c: U32, +p: J.Phase, e: {U32.is_gt(c, 127) == True{} : Bool}) -> {J.number_digit(p, c, False{}) == J.PInvalid{} : J.Phase}:
  match c:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      reject_bits(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31, p, e)

def invalid_residual(+c: U32, +s: String, +p: J.Phase, ed: {J.digit(c) == False{} : Bool}, eh: {U32.is_gt(c, 127) == True{} : Bool}) -> {residual(J.number_step(p, c), s) == False{} : Bool}:
  Equal.trans(Bool, residual(J.number_step(p, c), s), residual(J.number_digit(p, c, False{}), s), False{}, Equal.cong(Bool, Bool, b => residual(J.number_digit(p, c, b), s), J.digit(c), False{}, ed), Equal.cong(J.Phase, Bool, q => residual(q, s), J.number_digit(p, c, False{}), J.PInvalid{}, reject_digit(c, p, eh)))

def step_bits(+b31: Bool, +b30: Bool, +b29: Bool, +b28: Bool, +b27: Bool, +b26: Bool, +b25: Bool, +b24: Bool, +b23: Bool, +b22: Bool, +b21: Bool, +b20: Bool, +b19: Bool, +b18: Bool, +b17: Bool, +b16: Bool, +b15: Bool, +b14: Bool, +b13: Bool, +b12: Bool, +b11: Bool, +b10: Bool, +b9: Bool, +b8: Bool, +b7: Bool, +b6: Bool, +b5: Bool, +b4: Bool, +b3: Bool, +b2: Bool, +b1: Bool, +b0: Bool, +s: String, +p: J.Phase) -> {residual(p, SCon{Chr{code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)}, s}) == residual(J.number_step(p, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s) : Bool}:
  match b31:
    case True{}:
      match p:
        case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
        case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
        case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
        case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
        case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
        case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
        case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
        case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
        case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
        case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
    case False{}:
      match b30:
        case True{}:
          match p:
            case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
            case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
            case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
            case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
            case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
            case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
            case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
            case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
            case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
            case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
        case False{}:
          match b29:
            case True{}:
              match p:
                case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
            case False{}:
              match b28:
                case True{}:
                  match p:
                    case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                    case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                    case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                    case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                    case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                    case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                    case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                    case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                    case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                    case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                case False{}:
                  match b27:
                    case True{}:
                      match p:
                        case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                        case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                        case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                        case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                        case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                        case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                        case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                        case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                        case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                        case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                    case False{}:
                      match b26:
                        case True{}:
                          match p:
                            case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                            case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                            case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                            case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                            case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                            case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                            case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                            case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                            case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                            case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                        case False{}:
                          match b25:
                            case True{}:
                              match p:
                                case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                            case False{}:
                              match b24:
                                case True{}:
                                  match p:
                                    case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                    case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                    case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                    case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                    case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                    case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                    case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                    case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                    case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                    case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                case False{}:
                                  match b23:
                                    case True{}:
                                      match p:
                                        case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                        case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                        case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                        case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                        case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                        case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                        case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                        case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                        case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                        case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                    case False{}:
                                      match b22:
                                        case True{}:
                                          match p:
                                            case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                            case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                            case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                            case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                            case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                            case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                            case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                            case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                            case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                            case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                        case False{}:
                                          match b21:
                                            case True{}:
                                              match p:
                                                case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                            case False{}:
                                              match b20:
                                                case True{}:
                                                  match p:
                                                    case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                    case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                    case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                    case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                    case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                    case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                    case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                    case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                    case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                    case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                case False{}:
                                                  match b19:
                                                    case True{}:
                                                      match p:
                                                        case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                        case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                        case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                        case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                        case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                        case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                        case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                        case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                        case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                        case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                    case False{}:
                                                      match b18:
                                                        case True{}:
                                                          match p:
                                                            case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                            case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                            case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                            case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                            case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                            case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                            case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                            case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                            case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                            case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                        case False{}:
                                                          match b17:
                                                            case True{}:
                                                              match p:
                                                                case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                            case False{}:
                                                              match b16:
                                                                case True{}:
                                                                  match p:
                                                                    case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                    case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                    case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                    case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                    case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                    case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                    case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                    case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                    case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                    case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                case False{}:
                                                                  match b15:
                                                                    case True{}:
                                                                      match p:
                                                                        case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                        case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                        case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                        case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                        case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                        case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                        case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                        case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                        case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                        case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                    case False{}:
                                                                      match b14:
                                                                        case True{}:
                                                                          match p:
                                                                            case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                            case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                            case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                            case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                            case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                            case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                            case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                            case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                            case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                            case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                        case False{}:
                                                                          match b13:
                                                                            case True{}:
                                                                              match p:
                                                                                case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                                case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                                case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                                case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                                case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                                case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                                case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                                case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                                case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                                case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                            case False{}:
                                                                              match b12:
                                                                                case True{}:
                                                                                  match p:
                                                                                    case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                                    case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                                    case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                                    case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                                    case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                                    case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                                    case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                                    case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                                    case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                                    case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                                case False{}:
                                                                                  match b11:
                                                                                    case True{}:
                                                                                      match p:
                                                                                        case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                                        case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                                        case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                                        case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                                        case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                                        case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                                        case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                                        case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                                        case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                                        case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                                    case False{}:
                                                                                      match b10:
                                                                                        case True{}:
                                                                                          match p:
                                                                                            case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                                            case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                                            case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                                            case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                                            case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                                            case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                                            case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                                            case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                                            case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                                            case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                                        case False{}:
                                                                                          match b9:
                                                                                            case True{}:
                                                                                              match p:
                                                                                                case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                                                case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                                                case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                                                case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                                                case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                                                case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                                                case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                                                case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                                                case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                                                case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                                            case False{}:
                                                                                              match b8:
                                                                                                case True{}:
                                                                                                  match p:
                                                                                                    case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                                                    case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                                                    case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                                                    case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                                                    case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                                                    case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                                                    case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                                                    case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                                                    case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                                                    case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                                                case False{}:
                                                                                                  match b7:
                                                                                                    case True{}:
                                                                                                      match p:
                                                                                                        case J.PStart{}: Equal.sym(Bool, residual(J.number_step(J.PStart{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PStart{}, {==}, {==}))
                                                                                                        case J.PMinus{}: Equal.sym(Bool, residual(J.number_step(J.PMinus{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PMinus{}, {==}, {==}))
                                                                                                        case J.PZero{}: Equal.sym(Bool, residual(J.number_step(J.PZero{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PZero{}, {==}, {==}))
                                                                                                        case J.PInteger{}: Equal.sym(Bool, residual(J.number_step(J.PInteger{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInteger{}, {==}, {==}))
                                                                                                        case J.PDot{}: Equal.sym(Bool, residual(J.number_step(J.PDot{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDot{}, {==}, {==}))
                                                                                                        case J.PFraction{}: Equal.sym(Bool, residual(J.number_step(J.PFraction{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PFraction{}, {==}, {==}))
                                                                                                        case J.PExponent{}: Equal.sym(Bool, residual(J.number_step(J.PExponent{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PExponent{}, {==}, {==}))
                                                                                                        case J.PSign{}: Equal.sym(Bool, residual(J.number_step(J.PSign{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PSign{}, {==}, {==}))
                                                                                                        case J.PDigits{}: Equal.sym(Bool, residual(J.number_step(J.PDigits{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PDigits{}, {==}, {==}))
                                                                                                        case J.PInvalid{}: Equal.sym(Bool, residual(J.number_step(J.PInvalid{}, code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31)), s), False{}, invalid_residual(code(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31), s, J.PInvalid{}, {==}, {==}))
                                                                                                    case False{}:
                                                                                                      match b6:
                                                                                                        case True{}:
                                                                                                          match b5:
                                                                                                            case True{}:
                                                                                                              match b4:
                                                                                                                case True{}:
                                                                                                                  match b3:
                                                                                                                    case True{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                    case False{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                case False{}:
                                                                                                                  match b3:
                                                                                                                    case True{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                    case False{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                            case False{}:
                                                                                                              match b4:
                                                                                                                case True{}:
                                                                                                                  match b3:
                                                                                                                    case True{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                    case False{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                case False{}:
                                                                                                                  match b3:
                                                                                                                    case True{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                    case False{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                        case False{}:
                                                                                                          match b5:
                                                                                                            case True{}:
                                                                                                              match b4:
                                                                                                                case True{}:
                                                                                                                  match b3:
                                                                                                                    case True{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                    case False{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                case False{}:
                                                                                                                  match b3:
                                                                                                                    case True{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                    case False{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                            case False{}:
                                                                                                              match b4:
                                                                                                                case True{}:
                                                                                                                  match b3:
                                                                                                                    case True{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                    case False{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                case False{}:
                                                                                                                  match b3:
                                                                                                                    case True{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                    case False{}:
                                                                                                                      match b2:
                                                                                                                        case True{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                        case False{}:
                                                                                                                          match b1:
                                                                                                                            case True{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                            case False{}:
                                                                                                                              match b0:
                                                                                                                                case True{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}
                                                                                                                                case False{}:
                                                                                                                                  match p:
                                                                                                                                    case J.PStart{}: {==}
                                                                                                                                    case J.PMinus{}: {==}
                                                                                                                                    case J.PZero{}: {==}
                                                                                                                                    case J.PInteger{}: {==}
                                                                                                                                    case J.PDot{}: {==}
                                                                                                                                    case J.PFraction{}: {==}
                                                                                                                                    case J.PExponent{}: {==}
                                                                                                                                    case J.PSign{}: {==}
                                                                                                                                    case J.PDigits{}: {==}
                                                                                                                                    case J.PInvalid{}: {==}

def residual_step(+c: U32, +s: String, +p: J.Phase) -> {residual(p, SCon{Chr{c}, s}) == residual(J.number_step(p, c), s) : Bool}:
  match c:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      step_bits(b31, b30, b29, b28, b27, b26, b25, b24, b23, b22, b21, b20, b19, b18, b17, b16, b15, b14, b13, b12, b11, b10, b9, b8, b7, b6, b5, b4, b3, b2, b1, b0, s, p)

def residual_end(+p: J.Phase) -> {J.number_end(p) == residual(p, "") : Bool}:
  match p:
    case J.PStart{}: {==}
    case J.PMinus{}: {==}
    case J.PZero{}: {==}
    case J.PInteger{}: {==}
    case J.PDot{}: {==}
    case J.PFraction{}: {==}
    case J.PExponent{}: {==}
    case J.PSign{}: {==}
    case J.PDigits{}: {==}
    case J.PInvalid{}: {==}

def number_go_equiv(+s: String, +p: J.Phase) -> {J.number_valid_go(s, p) == residual(p, s) : Bool}:
  match s:
    case SNil{}: residual_end(p)
    case SCon{Chr{+c}, +t}:
      Equal.trans(Bool, J.number_valid_go(t, J.number_step(p, c)), residual(J.number_step(p, c), t), residual(p, SCon{Chr{c}, t}), number_go_equiv(t, J.number_step(p, c)), Equal.sym(Bool, residual(p, SCon{Chr{c}, t}), residual(J.number_step(p, c), t), residual_step(c, t, p)))

def number_equiv(+s: String) -> {J.number_valid(s) == Spec.number(s) : Bool}:
  number_go_equiv(s, J.PStart{})
