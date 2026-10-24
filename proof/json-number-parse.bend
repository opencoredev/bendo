# JSON numbers: the parser walks the same phases the admissibility check
# walked, and stops on the character after the number without consuming it.
import Base
import ../src/data/json.bend as J
import ../src/data/utf8.bend as U
import ./utf8.bend as P
import ./json-support.bend as Sup
import ./json-credit.bend as C
import ./json-classes.bend as K

def invalid_go(+s: String) -> {J.number_valid_go(s, J.PInvalid{}) == False{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: invalid_go(t)

def is_inv(p: J.Phase) -> Bool:
  match p:
    case J.PStart{}: False{}
    case J.PMinus{}: False{}
    case J.PZero{}: False{}
    case J.PInteger{}: False{}
    case J.PDot{}: False{}
    case J.PFraction{}: False{}
    case J.PExponent{}: False{}
    case J.PSign{}: False{}
    case J.PDigits{}: False{}
    case J.PInvalid{}: True{}

def inv_sound(x: J.Phase, e: {is_inv(x) == True{} : Bool}) -> {x == J.PInvalid{} : J.Phase}:
  match x:
    case J.PStart{}: P.absurd({J.PStart{} == J.PInvalid{} : J.Phase}, P.false_true(e))
    case J.PMinus{}: P.absurd({J.PMinus{} == J.PInvalid{} : J.Phase}, P.false_true(e))
    case J.PZero{}: P.absurd({J.PZero{} == J.PInvalid{} : J.Phase}, P.false_true(e))
    case J.PInteger{}: P.absurd({J.PInteger{} == J.PInvalid{} : J.Phase}, P.false_true(e))
    case J.PDot{}: P.absurd({J.PDot{} == J.PInvalid{} : J.Phase}, P.false_true(e))
    case J.PFraction{}: P.absurd({J.PFraction{} == J.PInvalid{} : J.Phase}, P.false_true(e))
    case J.PExponent{}: P.absurd({J.PExponent{} == J.PInvalid{} : J.Phase}, P.false_true(e))
    case J.PSign{}: P.absurd({J.PSign{} == J.PInvalid{} : J.Phase}, P.false_true(e))
    case J.PDigits{}: P.absurd({J.PDigits{} == J.PInvalid{} : J.Phase}, P.false_true(e))
    case J.PInvalid{}: {==}

# A character that ends a number in every phase.
def stops(+c: U32) -> Bool:
  (is_inv(J.number_step(J.PStart{}, c)) && (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))))

def ends(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: stops(c)

def stop_at(+p: J.Phase, +c: U32, e: {stops(c) == True{} : Bool}) -> {J.number_step(p, c) == J.PInvalid{} : J.Phase}:
  match p:
    case J.PStart{}: inv_sound(J.number_step(J.PStart{}, c), P.and_left(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e))
    case J.PMinus{}: inv_sound(J.number_step(J.PMinus{}, c), P.and_left(is_inv(J.number_step(J.PMinus{}, c)), (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))))), P.and_right(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e)))
    case J.PZero{}: inv_sound(J.number_step(J.PZero{}, c), P.and_left(is_inv(J.number_step(J.PZero{}, c)), (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))), P.and_right(is_inv(J.number_step(J.PMinus{}, c)), (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))))), P.and_right(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e))))
    case J.PInteger{}: inv_sound(J.number_step(J.PInteger{}, c), P.and_left(is_inv(J.number_step(J.PInteger{}, c)), (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))), P.and_right(is_inv(J.number_step(J.PZero{}, c)), (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))), P.and_right(is_inv(J.number_step(J.PMinus{}, c)), (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))))), P.and_right(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e)))))
    case J.PDot{}: inv_sound(J.number_step(J.PDot{}, c), P.and_left(is_inv(J.number_step(J.PDot{}, c)), (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))), P.and_right(is_inv(J.number_step(J.PInteger{}, c)), (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))), P.and_right(is_inv(J.number_step(J.PZero{}, c)), (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))), P.and_right(is_inv(J.number_step(J.PMinus{}, c)), (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))))), P.and_right(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e))))))
    case J.PFraction{}: inv_sound(J.number_step(J.PFraction{}, c), P.and_left(is_inv(J.number_step(J.PFraction{}, c)), (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))), P.and_right(is_inv(J.number_step(J.PDot{}, c)), (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))), P.and_right(is_inv(J.number_step(J.PInteger{}, c)), (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))), P.and_right(is_inv(J.number_step(J.PZero{}, c)), (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))), P.and_right(is_inv(J.number_step(J.PMinus{}, c)), (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))))), P.and_right(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e)))))))
    case J.PExponent{}: inv_sound(J.number_step(J.PExponent{}, c), P.and_left(is_inv(J.number_step(J.PExponent{}, c)), (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))), P.and_right(is_inv(J.number_step(J.PFraction{}, c)), (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))), P.and_right(is_inv(J.number_step(J.PDot{}, c)), (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))), P.and_right(is_inv(J.number_step(J.PInteger{}, c)), (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))), P.and_right(is_inv(J.number_step(J.PZero{}, c)), (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))), P.and_right(is_inv(J.number_step(J.PMinus{}, c)), (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))))), P.and_right(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e))))))))
    case J.PSign{}: inv_sound(J.number_step(J.PSign{}, c), P.and_left(is_inv(J.number_step(J.PSign{}, c)), (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))), P.and_right(is_inv(J.number_step(J.PExponent{}, c)), (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))), P.and_right(is_inv(J.number_step(J.PFraction{}, c)), (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))), P.and_right(is_inv(J.number_step(J.PDot{}, c)), (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))), P.and_right(is_inv(J.number_step(J.PInteger{}, c)), (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))), P.and_right(is_inv(J.number_step(J.PZero{}, c)), (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))), P.and_right(is_inv(J.number_step(J.PMinus{}, c)), (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))))), P.and_right(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e)))))))))
    case J.PDigits{}: inv_sound(J.number_step(J.PDigits{}, c), P.and_left(is_inv(J.number_step(J.PDigits{}, c)), is_inv(J.number_step(J.PInvalid{}, c)), P.and_right(is_inv(J.number_step(J.PSign{}, c)), (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))), P.and_right(is_inv(J.number_step(J.PExponent{}, c)), (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))), P.and_right(is_inv(J.number_step(J.PFraction{}, c)), (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))), P.and_right(is_inv(J.number_step(J.PDot{}, c)), (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))), P.and_right(is_inv(J.number_step(J.PInteger{}, c)), (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))), P.and_right(is_inv(J.number_step(J.PZero{}, c)), (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))), P.and_right(is_inv(J.number_step(J.PMinus{}, c)), (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))))), P.and_right(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e))))))))))
    case J.PInvalid{}: inv_sound(J.number_step(J.PInvalid{}, c), P.and_right(is_inv(J.number_step(J.PDigits{}, c)), is_inv(J.number_step(J.PInvalid{}, c)), P.and_right(is_inv(J.number_step(J.PSign{}, c)), (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))), P.and_right(is_inv(J.number_step(J.PExponent{}, c)), (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))), P.and_right(is_inv(J.number_step(J.PFraction{}, c)), (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))), P.and_right(is_inv(J.number_step(J.PDot{}, c)), (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))), P.and_right(is_inv(J.number_step(J.PInteger{}, c)), (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))), P.and_right(is_inv(J.number_step(J.PZero{}, c)), (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))), P.and_right(is_inv(J.number_step(J.PMinus{}, c)), (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c))))))))), P.and_right(is_inv(J.number_step(J.PStart{}, c)), (is_inv(J.number_step(J.PMinus{}, c)) && (is_inv(J.number_step(J.PZero{}, c)) && (is_inv(J.number_step(J.PInteger{}, c)) && (is_inv(J.number_step(J.PDot{}, c)) && (is_inv(J.number_step(J.PFraction{}, c)) && (is_inv(J.number_step(J.PExponent{}, c)) && (is_inv(J.number_step(J.PSign{}, c)) && (is_inv(J.number_step(J.PDigits{}, c)) && is_inv(J.number_step(J.PInvalid{}, c)))))))))), e))))))))))

def next_ok(n: J.Phase, +p: J.Phase, +rev: String, +c: U32, +input: String, +fs: List<&2, J.Frame>, +d: Nat, +rest: String, valid: {J.number_valid_go(rest, n) == True{} : Bool}) -> {J.number_next(n, p, rev, c, input, fs, d) == J.Machine{J.MNumber{n, SCon{Chr{c}, rev}}, input, fs, d} : J.Machine}:
  match n:
    case J.PInvalid{}: P.absurd({J.number_next(J.PInvalid{}, p, rev, c, input, fs, d) == J.Machine{J.MNumber{J.PInvalid{}, SCon{Chr{c}, rev}}, input, fs, d} : J.Machine}, P.false_true(Equal.trans(Bool, False{}, J.number_valid_go(rest, J.PInvalid{}), True{}, Equal.sym(Bool, J.number_valid_go(rest, J.PInvalid{}), False{}, invalid_go(rest)), valid)))
    case J.PStart{}: {==}
    case J.PMinus{}: {==}
    case J.PZero{}: {==}
    case J.PInteger{}: {==}
    case J.PDot{}: {==}
    case J.PFraction{}: {==}
    case J.PExponent{}: {==}
    case J.PSign{}: {==}
    case J.PDigits{}: {==}

def num_end(+p: J.Phase, +rev: String, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +endp: {J.number_end(p) == True{} : Bool}, stop: {ends(suffix) == True{} : Bool}, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JNumber{String.reverse(rev)}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(suffix, 1n+a), J.Machine{J.MNumber{p, rev}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match suffix:
    case SNil{}:
      %Equal.sym(Bool, J.number_end(p), True{}, endp) : {J.parse_go(a, J.Machine{J.number_finish(rev, _), "", stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
      h
    case SCon{Chr{c}, t}:
      %Equal.sym(Nat, J.fuel_go(t, 1n+(4n+a)), 1n+J.fuel_go(t, 4n+a), C.fuel_succ(t, 4n+a)) : {J.parse_go(_, J.Machine{J.MNumber{p, rev}, SCon{Chr{c}, t}, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
      %Equal.sym(J.Phase, J.number_step(p, c), J.PInvalid{}, stop_at(p, c, stop)) : {J.parse_go(J.fuel_go(t, 4n+a), J.number_next(_, p, rev, c, t, stack, depth)) == Done{v} : Result<&2, &2, J.Error, J.Json>}
      %Equal.sym(Bool, J.number_end(p), True{}, endp) : {J.parse_go(J.fuel_go(t, 4n+a), J.Machine{J.number_finish(rev, _), SCon{Chr{c}, t}, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
      h

def num_next(+p: J.Phase, +rev: String, +c: U32, +t: String, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +valid: {J.number_valid_go(t, J.number_step(p, c)) == True{} : Bool}, h: {J.parse_go(J.fuel_go(t ++ suffix, 1n+a), J.Machine{J.MNumber{J.number_step(p, c), SCon{Chr{c}, rev}}, t ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(t ++ suffix, 1n+a), J.number_next(J.number_step(p, c), p, rev, c, t ++ suffix, stack, depth)) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(J.Machine, J.number_next(J.number_step(p, c), p, rev, c, t ++ suffix, stack, depth), J.Machine{J.MNumber{J.number_step(p, c), SCon{Chr{c}, rev}}, t ++ suffix, stack, depth}, next_ok(J.number_step(p, c), p, rev, c, t ++ suffix, stack, depth, t, valid)) : {J.parse_go(J.fuel_go(t ++ suffix, 1n+a), _) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

def num_go(+s: String, +p: J.Phase, +rev: String, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +valid: {J.number_valid_go(s, p) == True{} : Bool}, +stop: {ends(suffix) == True{} : Bool}, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JNumber{String.reverse(String.reverse.go(s, rev))}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(s ++ suffix, 1n+a), J.Machine{J.MNumber{p, rev}, s ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match s:
    case SNil{}: num_end(p, rev, suffix, stack, depth, a, v, valid, stop, h)
    case SCon{Chr{c}, t}:
      C.consume(Chr{c}, t ++ suffix, 1n+a, J.Machine{J.MNumber{p, rev}, SCon{Chr{c}, t ++ suffix}, stack, depth}, v, num_next(p, rev, c, t, suffix, stack, depth, a, v, valid, num_go(t, J.number_step(p, c), SCon{Chr{c}, rev}, suffix, stack, depth, a, v, valid, stop, h)), {==})

def not_first_d(+c: U32, +t: String, +k: U32, valid: {J.number_valid_go(t, J.number_step(J.PStart{}, c)) == True{} : Bool}, bad: {J.number_step(J.PStart{}, k) == J.PInvalid{} : J.Phase}, b: Bool, e: {U32.is_eq(c, k) == b : Bool}) -> {b == False{} : Bool}:
  match b:
    case False{}: {==}
    case True{}:
      eq = C.u32_eq_sound(c, k, e)
      cong1 = Equal.cong(U32, Bool, x => J.number_valid_go(t, J.number_step(J.PStart{}, x)), c, k, eq)
      e1 = Equal.trans(Bool, J.number_valid_go(t, J.number_step(J.PStart{}, k)), J.number_valid_go(t, J.number_step(J.PStart{}, c)), True{}, Equal.sym(Bool, J.number_valid_go(t, J.number_step(J.PStart{}, c)), J.number_valid_go(t, J.number_step(J.PStart{}, k)), cong1), valid)
      cong2 = Equal.cong(J.Phase, Bool, x => J.number_valid_go(t, x), J.number_step(J.PStart{}, k), J.PInvalid{}, bad)
      e2 = Equal.trans(Bool, False{}, J.number_valid_go(t, J.PInvalid{}), J.number_valid_go(t, J.number_step(J.PStart{}, k)), Equal.sym(Bool, J.number_valid_go(t, J.PInvalid{}), False{}, invalid_go(t)), Equal.sym(Bool, J.number_valid_go(t, J.number_step(J.PStart{}, k)), J.number_valid_go(t, J.PInvalid{}), cong2))
      P.absurd({True{} == False{} : Bool}, P.false_true(Equal.trans(Bool, False{}, J.number_valid_go(t, J.number_step(J.PStart{}, k)), True{}, e2, e1)))

# A number's first character is none of the parser's other value starts,
# not whitespace, and not a closing bracket.
def not_first(+c: U32, +t: String, +k: U32, valid: {J.number_valid_go(t, J.number_step(J.PStart{}, c)) == True{} : Bool}, bad: {J.number_step(J.PStart{}, k) == J.PInvalid{} : J.Phase}) -> {U32.is_eq(c, k) == False{} : Bool}:
  not_first_d(c, t, k, valid, bad, U32.is_eq(c, k), {==})

def blank_false(+c: U32, +t: String, +valid: {J.number_valid_go(t, J.number_step(J.PStart{}, c)) == True{} : Bool}) -> {J.whitespace(c) == False{} : Bool}:
  K.not_space(c, not_first(c, t, 32, valid, {==}), not_first(c, t, 9, valid, {==}), not_first(c, t, 10, valid, {==}), not_first(c, t, 13, valid, {==}))

def value_step(+c: U32, +r: String, +fs: List<&2, J.Frame>, +d: Nat, +t: String, +valid: {J.number_valid_go(t, J.number_step(J.PStart{}, c)) == True{} : Bool}) -> {J.step(J.Machine{J.MValue{}, SCon{Chr{c}, r}, fs, d}) == J.Machine{J.MNumber{J.number_step(J.PStart{}, c), SCon{Chr{c}, ""}}, r, fs, d} : J.Machine}:
  %Equal.sym(Bool, J.whitespace(c), False{}, blank_false(c, t, valid)) : {J.skip(J.MValue{}, SCon{Chr{c}, r}, r, fs, d, True{} && _) == J.Machine{J.MNumber{J.number_step(J.PStart{}, c), SCon{Chr{c}, ""}}, r, fs, d} : J.Machine}
  Equal.trans(J.Machine, J.token(J.MValue{}, SCon{Chr{c}, r}, fs, d), J.number_next(J.number_step(J.PStart{}, c), J.PStart{}, "", c, r, fs, d), J.Machine{J.MNumber{J.number_step(J.PStart{}, c), SCon{Chr{c}, ""}}, r, fs, d}, K.value_number(c, r, fs, d, not_first(c, t, 110, valid, {==}), not_first(c, t, 116, valid, {==}), not_first(c, t, 102, valid, {==}), not_first(c, t, 34, valid, {==}), not_first(c, t, 91, valid, {==}), not_first(c, t, 123, valid, {==})), next_ok(J.number_step(J.PStart{}, c), J.PStart{}, "", c, r, fs, d, t, valid))

def first_step(+c: U32, +r: String, +fs: List<&2, J.Frame>, +d: Nat, +t: String, +valid: {J.number_valid_go(t, J.number_step(J.PStart{}, c)) == True{} : Bool}) -> {J.step(J.Machine{J.MArrayFirst{}, SCon{Chr{c}, r}, fs, d}) == J.Machine{J.MValue{}, SCon{Chr{c}, r}, J.ArrayFrame{[]} <> fs, d} : J.Machine}:
  %Equal.sym(Bool, J.whitespace(c), False{}, blank_false(c, t, valid)) : {J.skip(J.MArrayFirst{}, SCon{Chr{c}, r}, r, fs, d, True{} && _) == J.Machine{J.MValue{}, SCon{Chr{c}, r}, J.ArrayFrame{[]} <> fs, d} : J.Machine}
  K.first_value(c, r, fs, d, not_first(c, t, 93, valid, {==}))

def number_done(+n: String, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JNumber{n}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JNumber{String.reverse(String.reverse.go(n, ""))}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(String, String.reverse(String.reverse.go(n, "")), n, Sup.reverse_go_inverse(n, "")) : {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JNumber{_}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

def value_h(+c: U32, +t: String, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +valid: {J.number_valid_go(t, J.number_step(J.PStart{}, c)) == True{} : Bool}, h: {J.parse_go(J.fuel_go(t ++ suffix, 3n+a), J.Machine{J.MNumber{J.number_step(J.PStart{}, c), SCon{Chr{c}, ""}}, t ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(t ++ suffix, 3n+a), J.step(J.Machine{J.MValue{}, SCon{Chr{c}, t ++ suffix}, stack, depth})) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(J.Machine, J.step(J.Machine{J.MValue{}, SCon{Chr{c}, t ++ suffix}, stack, depth}), J.Machine{J.MNumber{J.number_step(J.PStart{}, c), SCon{Chr{c}, ""}}, t ++ suffix, stack, depth}, value_step(c, t ++ suffix, stack, depth, t, valid)) : {J.parse_go(J.fuel_go(t ++ suffix, 3n+a), _) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

def number_cps(+n: String, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +valid: {J.number_valid(n) == True{} : Bool}, +stop: {ends(suffix) == True{} : Bool}, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JNumber{n}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(n ++ suffix, a), J.Machine{J.MValue{}, n ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match n:
    case SNil{}: P.absurd({J.parse_go(J.fuel_go(SNil{} ++ suffix, a), J.Machine{J.MValue{}, SNil{} ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(valid))
    case SCon{Chr{c}, t}:
      C.consume_full(Chr{c}, t ++ suffix, a, J.Machine{J.MValue{}, SCon{Chr{c}, t ++ suffix}, stack, depth}, v, value_h(c, t, suffix, stack, depth, a, v, valid, num_go(t, J.number_step(J.PStart{}, c), SCon{Chr{c}, ""}, suffix, stack, depth, 2n+a, v, valid, stop, C.raise_add(2n, suffix, a, J.Machine{J.MEmit{J.JNumber{String.reverse(String.reverse.go(SCon{Chr{c}, t}, ""))}}, suffix, stack, depth}, v, number_done(SCon{Chr{c}, t}, suffix, stack, depth, a, v, h)))), {==})

# Every character a number phase accepts is a Unicode scalar.
def not_inv(n: J.Phase, +t: String, valid: {J.number_valid_go(t, n) == True{} : Bool}) -> {is_inv(n) == False{} : Bool}:
  match n:
    case J.PStart{}: {==}
    case J.PMinus{}: {==}
    case J.PZero{}: {==}
    case J.PInteger{}: {==}
    case J.PDot{}: {==}
    case J.PFraction{}: {==}
    case J.PExponent{}: {==}
    case J.PSign{}: {==}
    case J.PDigits{}: {==}
    case J.PInvalid{}: P.absurd({is_inv(J.PInvalid{}) == False{} : Bool}, P.false_true(Equal.trans(Bool, False{}, J.number_valid_go(t, J.PInvalid{}), True{}, Equal.sym(Bool, J.number_valid_go(t, J.PInvalid{}), False{}, invalid_go(t)), valid)))

def scalar_at(+c: U32, +k: U32, eq: {c == k : U32}, good: {U.scalar(k) == True{} : Bool}) -> {U.scalar(c) == True{} : Bool}:
  Equal.trans(Bool, U.scalar(c), U.scalar(k), True{}, Equal.cong(U32, Bool, x => U.scalar(x), c, k, eq), good)

def sign_none(+p: J.Phase, +c: U32, ok: {is_inv(J.number_step(p, c)) == False{} : Bool}, nd: {J.digit(c) == False{} : Bool}, minus: {U32.is_eq(c, 45) == False{} : Bool}, dot: {U32.is_eq(c, 46) == False{} : Bool}, small_e: {U32.is_eq(c, 101) == False{} : Bool}, big_e: {U32.is_eq(c, 69) == False{} : Bool}, plus: {U32.is_eq(c, 43) == False{} : Bool}, zero: {U32.is_eq(c, 48) == False{} : Bool}) -> {U.scalar(c) == True{} : Bool}:
  x1 = Equal.cong(Bool, Bool, x => is_inv(J.number_digit(p, c, x)), J.digit(c), False{}, nd)
  x2 = Equal.cong(J.Phase, Bool, x => is_inv(x), J.number_digit(p, c, False{}), J.PInvalid{}, K.nondigit(p, c, minus, dot, small_e, big_e, plus, zero))
  y = Equal.trans(Bool, is_inv(J.number_step(p, c)), is_inv(J.number_digit(p, c, False{})), True{}, x1, x2)
  P.absurd({U.scalar(c) == True{} : Bool}, P.false_true(Equal.trans(Bool, False{}, is_inv(J.number_step(p, c)), True{}, Equal.sym(Bool, is_inv(J.number_step(p, c)), False{}, ok), y)))

def sign_zero(+p: J.Phase, +c: U32, ok: {is_inv(J.number_step(p, c)) == False{} : Bool}, nd: {J.digit(c) == False{} : Bool}, minus: {U32.is_eq(c, 45) == False{} : Bool}, dot: {U32.is_eq(c, 46) == False{} : Bool}, small_e: {U32.is_eq(c, 101) == False{} : Bool}, big_e: {U32.is_eq(c, 69) == False{} : Bool}, plus: {U32.is_eq(c, 43) == False{} : Bool}, b: Bool, e: {U32.is_eq(c, 48) == b : Bool}) -> {U.scalar(c) == True{} : Bool}:
  match b:
    case True{}: scalar_at(c, 48, C.u32_eq_sound(c, 48, e), {==})
    case False{}: sign_none(p, c, ok, nd, minus, dot, small_e, big_e, plus, e)

def sign_plus(+p: J.Phase, +c: U32, ok: {is_inv(J.number_step(p, c)) == False{} : Bool}, nd: {J.digit(c) == False{} : Bool}, minus: {U32.is_eq(c, 45) == False{} : Bool}, dot: {U32.is_eq(c, 46) == False{} : Bool}, small_e: {U32.is_eq(c, 101) == False{} : Bool}, big_e: {U32.is_eq(c, 69) == False{} : Bool}, b: Bool, e: {U32.is_eq(c, 43) == b : Bool}) -> {U.scalar(c) == True{} : Bool}:
  match b:
    case True{}: scalar_at(c, 43, C.u32_eq_sound(c, 43, e), {==})
    case False{}: sign_zero(p, c, ok, nd, minus, dot, small_e, big_e, e, U32.is_eq(c, 48), {==})

def sign_big_e(+p: J.Phase, +c: U32, ok: {is_inv(J.number_step(p, c)) == False{} : Bool}, nd: {J.digit(c) == False{} : Bool}, minus: {U32.is_eq(c, 45) == False{} : Bool}, dot: {U32.is_eq(c, 46) == False{} : Bool}, small_e: {U32.is_eq(c, 101) == False{} : Bool}, b: Bool, e: {U32.is_eq(c, 69) == b : Bool}) -> {U.scalar(c) == True{} : Bool}:
  match b:
    case True{}: scalar_at(c, 69, C.u32_eq_sound(c, 69, e), {==})
    case False{}: sign_plus(p, c, ok, nd, minus, dot, small_e, e, U32.is_eq(c, 43), {==})

def sign_small_e(+p: J.Phase, +c: U32, ok: {is_inv(J.number_step(p, c)) == False{} : Bool}, nd: {J.digit(c) == False{} : Bool}, minus: {U32.is_eq(c, 45) == False{} : Bool}, dot: {U32.is_eq(c, 46) == False{} : Bool}, b: Bool, e: {U32.is_eq(c, 101) == b : Bool}) -> {U.scalar(c) == True{} : Bool}:
  match b:
    case True{}: scalar_at(c, 101, C.u32_eq_sound(c, 101, e), {==})
    case False{}: sign_big_e(p, c, ok, nd, minus, dot, e, U32.is_eq(c, 69), {==})

def sign_dot(+p: J.Phase, +c: U32, ok: {is_inv(J.number_step(p, c)) == False{} : Bool}, nd: {J.digit(c) == False{} : Bool}, minus: {U32.is_eq(c, 45) == False{} : Bool}, b: Bool, e: {U32.is_eq(c, 46) == b : Bool}) -> {U.scalar(c) == True{} : Bool}:
  match b:
    case True{}: scalar_at(c, 46, C.u32_eq_sound(c, 46, e), {==})
    case False{}: sign_small_e(p, c, ok, nd, minus, e, U32.is_eq(c, 101), {==})

def sign_minus(+p: J.Phase, +c: U32, ok: {is_inv(J.number_step(p, c)) == False{} : Bool}, nd: {J.digit(c) == False{} : Bool}, b: Bool, e: {U32.is_eq(c, 45) == b : Bool}) -> {U.scalar(c) == True{} : Bool}:
  match b:
    case True{}: scalar_at(c, 45, C.u32_eq_sound(c, 45, e), {==})
    case False{}: sign_dot(p, c, ok, nd, e, U32.is_eq(c, 46), {==})

def digit_or_sign(+p: J.Phase, +c: U32, ok: {is_inv(J.number_step(p, c)) == False{} : Bool}, d: Bool, e: {J.digit(c) == d : Bool}) -> {U.scalar(c) == True{} : Bool}:
  match d:
    case True{}: K.digit_scalar(c, e)
    case False{}: sign_minus(p, c, ok, e, U32.is_eq(c, 45), {==})

def num_text_valid(+s: String, +p: J.Phase, +valid: {J.number_valid_go(s, p) == True{} : Bool}) -> {U.valid(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      %Equal.sym(Bool, U.scalar(c), True{}, digit_or_sign(p, c, not_inv(J.number_step(p, c), t, valid), J.digit(c), {==})) : {_ && U.valid(t) == True{} : Bool}
      num_text_valid(t, J.number_step(p, c), valid)

def number_text_valid(+n: String, +valid: {J.number_valid(n) == True{} : Bool}) -> {U.valid(n) == True{} : Bool}:
  num_text_valid(n, J.PStart{}, valid)
