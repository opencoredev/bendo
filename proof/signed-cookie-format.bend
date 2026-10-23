# BND-32: the signer's wire value equals the independent RFC 4648 / RFC 3986
# specification in signed-cookie-spec.bend, for every key and value.
import Base
import ../src/data/base64.bend as B
import ../src/data/utf8.bend as U
import ../src/data/urlencoded.bend as F
import ../src/data/signed-cookie.bend as S
import ./signed-cookie-spec.bend as Spec
import ./cookie-serialization-spec.bend as CSpec
import ./crypto-base64.bend as Base64Proof
import ./percent.bend as Percent
import ./utf8.bend as UP

def con(+x: Char, +y: Char, +s: String, +t: String, e: {x == y : Char}, f: {s == t : String}) -> {SCon{x, s} == SCon{y, t} : String}:
  %e : {SCon{x, s} == SCon{_, t} : String}
  %f : {SCon{x, s} == SCon{x, _} : String}
  {==}

def app(+a: String, +b: String, +c: String, +d: String, e: {a == b : String}, f: {c == d : String}) -> {a ++ c == b ++ d : String}:
  %e : {a ++ c == _ ++ d : String}
  %f : {a ++ c == a ++ _ : String}
  {==}

# Each LSB-first six-bit word names the RFC 4648 symbol of its MSB-first value.
def symbol_spec(+b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool) -> {B.symbol(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, False{}) == Spec.sextet(b5, b4, b3, b2, b1, b0) : Char}:
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
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
            case True{}:
              match b3:
                case False{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
        case True{}:
          match b2:
            case False{}:
              match b3:
                case False{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
            case True{}:
              match b3:
                case False{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
    case True{}:
      match b1:
        case False{}:
          match b2:
            case False{}:
              match b3:
                case False{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
            case True{}:
              match b3:
                case False{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
        case True{}:
          match b2:
            case False{}:
              match b3:
                case False{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
            case True{}:
              match b3:
                case False{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                case True{}:
                  match b4:
                    case False{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}
                    case True{}:
                      match b5:
                        case False{}:
                          {==}
                        case True{}:
                          {==}

def one_eq(+a: Word(32n)) -> {B.encode_spec([U32{a}], False{}, True{}) == Spec.base64([U32{a}]) : String}:
  match a:
    case WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WCon{+a6, WCon{+a7, +ah}}}}}}}}:
      con(B.symbol(WCon{a2, WCon{a3, WCon{a4, WCon{a5, WCon{a6, WCon{a7, WNil{}}}}}}}, False{}), Spec.sextet(a7, a6, a5, a4, a3, a2), SCon{B.symbol(WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{a0, WCon{a1, WNil{}}}}}}}, False{}), "=="}, SCon{Spec.sextet(a1, a0, False{}, False{}, False{}, False{}), "=="}, symbol_spec(a2, a3, a4, a5, a6, a7), con(B.symbol(WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{a0, WCon{a1, WNil{}}}}}}}, False{}), Spec.sextet(a1, a0, False{}, False{}, False{}, False{}), "==", "==", symbol_spec(False{}, False{}, False{}, False{}, a0, a1), {==}))

def two_eq(+a: Word(32n), +b: Word(32n)) -> {B.encode_spec([U32{a}, U32{b}], False{}, True{}) == Spec.base64([U32{a}, U32{b}]) : String}:
  match a b:
    case WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WCon{+a6, WCon{+a7, +ah}}}}}}}} WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WCon{+b6, WCon{+b7, +bh}}}}}}}}:
      con(B.symbol(WCon{a2, WCon{a3, WCon{a4, WCon{a5, WCon{a6, WCon{a7, WNil{}}}}}}}, False{}), Spec.sextet(a7, a6, a5, a4, a3, a2), SCon{B.symbol(WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{a0, WCon{a1, WNil{}}}}}}}, False{}), SCon{B.symbol(WCon{False{}, WCon{False{}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}}}, False{}), "="}}, SCon{Spec.sextet(a1, a0, b7, b6, b5, b4), SCon{Spec.sextet(b3, b2, b1, b0, False{}, False{}), "="}}, symbol_spec(a2, a3, a4, a5, a6, a7), con(B.symbol(WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{a0, WCon{a1, WNil{}}}}}}}, False{}), Spec.sextet(a1, a0, b7, b6, b5, b4), SCon{B.symbol(WCon{False{}, WCon{False{}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}}}, False{}), "="}, SCon{Spec.sextet(b3, b2, b1, b0, False{}, False{}), "="}, symbol_spec(b4, b5, b6, b7, a0, a1), con(B.symbol(WCon{False{}, WCon{False{}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}}}, False{}), Spec.sextet(b3, b2, b1, b0, False{}, False{}), "=", "=", symbol_spec(False{}, False{}, b0, b1, b2, b3), {==})))

def three_eq(+a: Word(32n), +b: Word(32n), +c: Word(32n), +r1: String, +r2: String, e: {r1 == r2 : String}) -> {B.three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), False{}) ++ r1 == Spec.sextets(List.append(&2, Bool, Spec.octet_bits(U32{a}), List.append(&2, Bool, Spec.octet_bits(U32{b}), Spec.octet_bits(U32{c})))) ++ r2 : String}:
  match a b c:
    case WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WCon{+a6, WCon{+a7, +ah}}}}}}}} WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WCon{+b6, WCon{+b7, +bh}}}}}}}} WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WCon{+c6, WCon{+c7, +ch}}}}}}}}:
      con(B.symbol(WCon{a2, WCon{a3, WCon{a4, WCon{a5, WCon{a6, WCon{a7, WNil{}}}}}}}, False{}), Spec.sextet(a7, a6, a5, a4, a3, a2), SCon{B.symbol(WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{a0, WCon{a1, WNil{}}}}}}}, False{}), SCon{B.symbol(WCon{c6, WCon{c7, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}}}, False{}), SCon{B.symbol(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, False{}), r1}}}, SCon{Spec.sextet(a1, a0, b7, b6, b5, b4), SCon{Spec.sextet(b3, b2, b1, b0, c7, c6), SCon{Spec.sextet(c5, c4, c3, c2, c1, c0), r2}}}, symbol_spec(a2, a3, a4, a5, a6, a7), con(B.symbol(WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{a0, WCon{a1, WNil{}}}}}}}, False{}), Spec.sextet(a1, a0, b7, b6, b5, b4), SCon{B.symbol(WCon{c6, WCon{c7, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}}}, False{}), SCon{B.symbol(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, False{}), r1}}, SCon{Spec.sextet(b3, b2, b1, b0, c7, c6), SCon{Spec.sextet(c5, c4, c3, c2, c1, c0), r2}}, symbol_spec(b4, b5, b6, b7, a0, a1), con(B.symbol(WCon{c6, WCon{c7, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}}}, False{}), Spec.sextet(b3, b2, b1, b0, c7, c6), SCon{B.symbol(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, False{}), r1}, SCon{Spec.sextet(c5, c4, c3, c2, c1, c0), r2}, symbol_spec(c6, c7, b0, b1, b2, b3), con(B.symbol(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, False{}), Spec.sextet(c5, c4, c3, c2, c1, c0), r1, r2, symbol_spec(c0, c1, c2, c3, c4, c5), e))))

# The implementation's percent step agrees with the RFC 3986 octet rule.
def octet_eq(+w0: Bool, +w1: Bool, +w2: Bool, +w3: Bool, +w4: Bool, +w5: Bool, +w6: Bool, +w7: Bool) -> {F.encode_byte(Percent.byte(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WNil{}}}}}}}}}), False{}, F.safe(Percent.byte(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WNil{}}}}}}}}}), False{})) == Spec.percent_octet(Percent.byte(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WNil{}}}}}}}}}), Spec.unreserved(Percent.byte(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WNil{}}}}}}}}}))) : String}:
  match w0:
    case False{}:
      match w1:
        case False{}:
          match w2:
            case False{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
            case True{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
        case True{}:
          match w2:
            case False{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
            case True{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
    case True{}:
      match w1:
        case False{}:
          match w2:
            case False{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
            case True{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
        case True{}:
          match w2:
            case False{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
            case True{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}

# Every percent-encoded octet is made of RFC 6265 cookie-octets.
def octet_cookie(+w0: Bool, +w1: Bool, +w2: Bool, +w3: Bool, +w4: Bool, +w5: Bool, +w6: Bool, +w7: Bool) -> {CSpec.value_valid(Spec.percent_octet(Percent.byte(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WNil{}}}}}}}}}), Spec.unreserved(Percent.byte(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WNil{}}}}}}}}})))) == True{} : Bool}:
  match w0:
    case False{}:
      match w1:
        case False{}:
          match w2:
            case False{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
            case True{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
        case True{}:
          match w2:
            case False{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
            case True{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
    case True{}:
      match w1:
        case False{}:
          match w2:
            case False{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
            case True{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
        case True{}:
          match w2:
            case False{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
            case True{}:
              match w3:
                case False{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                case True{}:
                  match w4:
                    case False{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                    case True{}:
                      match w5:
                        case False{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                        case True{}:
                          match w6:
                            case False{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}
                            case True{}:
                              match w7:
                                case False{}:
                                  {==}
                                case True{}:
                                  {==}


def octet_word(+w: Word(8n)) -> {F.encode_byte(Percent.byte(w), False{}, F.safe(Percent.byte(w), False{})) == Spec.percent_octet(Percent.byte(w), Spec.unreserved(Percent.byte(w))) : String}:
  match w:
    case WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WNil{}}}}}}}}}:
      octet_eq(w0, w1, w2, w3, w4, w5, w6, w7)

def octet_cookie_word(+w: Word(8n)) -> {CSpec.value_valid(Spec.percent_octet(Percent.byte(w), Spec.unreserved(Percent.byte(w)))) == True{} : Bool}:
  match w:
    case WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WNil{}}}}}}}}}:
      octet_cookie(w0, w1, w2, w3, w4, w5, w6, w7)

def base64_eq(+xs: List<&2, U32>) -> {B.encode_spec(xs, False{}, True{}) == Spec.base64(xs) : String}:
  match xs:
    case Nil{}: {==}
    case U32{+a} <> Nil{}: one_eq(a)
    case U32{+a} <> U32{+b} <> Nil{}: two_eq(a, b)
    case U32{+a} <> U32{+b} <> U32{+c} <> +t:
      three_eq(a, b, c, B.encode_spec(t, False{}, True{}), Spec.base64(t), base64_eq(t))

# The public standard padded encoder is the RFC 4648 bit specification.
def encode_eq(+xs: List<&2, U32>) -> {B.encode(xs, False{}, True{}) == Spec.base64(xs) : String}:
  Equal.trans(String, B.encode(xs, False{}, True{}), B.encode_spec(xs, False{}, True{}), Spec.base64(xs), Base64Proof.encode_acc(xs, False{}, True{}, ""), base64_eq(xs))

def octet_spec(+c: U32, ok: {Percent.octet(c) == True{} : Bool}) -> {F.encode_byte(c, False{}, F.safe(c, False{})) == Spec.percent_octet(c, Spec.unreserved(c)) : String}:
  %Equal.sym(U32, c, Percent.byte(Percent.low(c)), Percent.octet_sound(c, ok)) : {F.encode_byte(_, False{}, F.safe(_, False{})) == Spec.percent_octet(_, Spec.unreserved(_)) : String}
  octet_word(Percent.low(c))

def percent_eq(+xs: List<&2, U32>, +ok: {Percent.octets(xs) == True{} : Bool}) -> {F.encode_bytes_spec(xs, False{}) == Spec.percent(xs) : String}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      app(F.encode_byte(c, False{}, F.safe(c, False{})), Spec.percent_octet(c, Spec.unreserved(c)), F.encode_bytes_spec(t, False{}), Spec.percent(t), octet_spec(c, Percent.and_left(Percent.octet(c), Percent.octets(t), ok)), percent_eq(t, Percent.and_right(Percent.octet(c), Percent.octets(t), ok)))

def utf8_octets(+s: String) -> {Percent.octets(U.encode(s)) == True{} : Bool}:
  Equal.trans(Bool, Percent.octets(U.encode(s)), Percent.octets(U.encode_spec(s)), True{}, Equal.cong(List<&2, U32>, Bool, bs => Percent.octets(bs), U.encode(s), U.encode_spec(s), UP.encode_equiv(s)), Percent.encode_octets(s))

# Url.encode is the RFC 3986 component encoder over UTF-8 octets.
def url_eq(+s: String) -> {F.encode(s) == Spec.percent(U.encode(s)) : String}:
  Equal.trans(String, F.encode_bytes(U.encode(s), False{}), F.encode_bytes_spec(U.encode(s), False{}), Spec.percent(U.encode(s)), Percent.encode_equiv(U.encode(s), False{}), percent_eq(U.encode(s), utf8_octets(s)))

def sign_eq(+key: String, +value: String) -> {S.sign(key, value) == Spec.signed_wire(key, value) : String}:
  %Equal.sym(String, B.encode(S.digest(key, value), False{}, True{}), Spec.base64(S.digest(key, value)), encode_eq(S.digest(key, value))) : {F.encode(value ++ "." ++ _) == Spec.signed_wire(key, value) : String}
  url_eq(value ++ "." ++ Spec.base64(S.digest(key, value)))

def octet_valid(+c: U32, ok: {Percent.octet(c) == True{} : Bool}) -> {CSpec.value_valid(Spec.percent_octet(c, Spec.unreserved(c))) == True{} : Bool}:
  %Equal.sym(U32, c, Percent.byte(Percent.low(c)), Percent.octet_sound(c, ok)) : {CSpec.value_valid(Spec.percent_octet(_, Spec.unreserved(_))) == True{} : Bool}
  octet_cookie_word(Percent.low(c))

def value_append(+a: String, +b: String, +oka: {CSpec.value_valid(a) == True{} : Bool}, +okb: {CSpec.value_valid(b) == True{} : Bool}) -> {CSpec.value_valid(a ++ b) == True{} : Bool}:
  match a:
    case SNil{}: okb
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, CSpec.octet(c), True{}, Percent.and_left(CSpec.octet(c), CSpec.value_valid(t), oka)) : {_ && CSpec.value_valid(t ++ b) == True{} : Bool}
      value_append(t, b, Percent.and_right(CSpec.octet(c), CSpec.value_valid(t), oka), okb)

def percent_valid(+xs: List<&2, U32>, +ok: {Percent.octets(xs) == True{} : Bool}) -> {CSpec.value_valid(Spec.percent(xs)) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      value_append(Spec.percent_octet(c, Spec.unreserved(c)), Spec.percent(t), octet_valid(c, Percent.and_left(Percent.octet(c), Percent.octets(t), ok)), percent_valid(t, Percent.and_right(Percent.octet(c), Percent.octets(t), ok)))

# The signed wire value is a raw cookie value under BND-31's octet rule.
def wire_valid(+key: String, +value: String) -> {CSpec.value_valid(Spec.signed_wire(key, value)) == True{} : Bool}:
  percent_valid(U.encode(value ++ "." ++ Spec.base64(S.digest(key, value))), utf8_octets(value ++ "." ++ Spec.base64(S.digest(key, value))))
