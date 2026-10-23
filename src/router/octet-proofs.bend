# Finite octet proofs for the existing URI codec, without arithmetic axioms.
import Base
import ./encoding.bend as E

def no_slash(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{+h, t}:
      Bool.not(Char.is_eq(h, '/')) && no_slash(t)

# Read eight bits into an initially zero accumulator, covering every octet.
def word_value(n: Nat, +prefix: U32, w: Word(n)) -> U32:
  match n w:
    case 0n WNil{}:
      prefix
    case 1n+k WCon{False{}, t}:
      word_value(k, U32.shl(prefix), t)
    case 1n+k WCon{True{}, t}:
      word_value(k, U32.inc(U32.shl(prefix)), t)

def octet(w: Word(8n)) -> U32:
  word_value(8n, 0, w)

def byte_claim(+n: U32) -> Type:
  (@tail: String -> {E.unescape(E.byte(n) ++ tail) == Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape(tail), bs => Some{n <> bs}) : Maybe<&2, List<&2, U32>>}) & {no_slash(E.byte(n)) == True{} : Bool}

# A binary tree of evidence contains a leaf for every remaining bit assignment.
def ByteTree(n: Nat, +prefix: U32) -> Type:
  match n:
    case 0n:
      byte_claim(prefix)
    case 1n+k:
      ByteTree(k, U32.shl(prefix)) & ByteTree(k, U32.inc(U32.shl(prefix)))

def byte_case(n: Nat, +prefix: U32, w: Word(n), evidence: ByteTree(n, prefix)) -> byte_claim(word_value(n, prefix, w)):
  match n w:
    case 0n WNil{}:
      evidence
    case 1n+k WCon{False{}, t}:
      (lo, hi) = evidence
      byte_case(k, U32.shl(prefix), t, lo)
    case 1n+k WCon{True{}, t}:
      (lo, hi) = evidence
      byte_case(k, U32.inc(U32.shl(prefix)), t, hi)

# Each leaf reduces one of the 256 octets; byte_case selects its proof.
def byte_cases() -> ByteTree(8n, 0):
  (
    (
      (
        (
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          ),
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          )
        ),
        (
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          ),
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          )
        )
      ),
      (
        (
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          ),
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          )
        ),
        (
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          ),
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          )
        )
      )
    ),
    (
      (
        (
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          ),
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          )
        ),
        (
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          ),
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          )
        )
      ),
      (
        (
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          ),
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          )
        ),
        (
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          ),
          (
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==})))),
            ((((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))), (((+tail => {==}, {==}), (+tail => {==}, {==})), ((+tail => {==}, {==}), (+tail => {==}, {==}))))
          )
        )
      )
    )
  )

def decoded_byte(+w: Word(8n), +tail: String, evidence: byte_claim(octet(w))) ->
    {E.unescape(E.byte(octet(w)) ++ tail) == Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape(tail), bs => Some{octet(w) <> bs}) : Maybe<&2, List<&2, U32>>}:
  (decoded, clean) = evidence
  decoded(tail)

def clean_byte(+w: Word(8n), evidence: byte_claim(octet(w))) -> {no_slash(E.byte(octet(w))) == True{} : Bool}:
  (decoded, clean) = evidence
  clean

# Percent-decoding an encoded octet prepends that octet to the decoded suffix.
law unescape_byte:
  for +w: Word(8n)
  for +tail: String
  {E.unescape(E.byte(octet(w)) ++ tail) == Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape(tail), bs => Some{octet(w) <> bs}) : Maybe<&2, List<&2, U32>>}

def unescape_byte(w, tail):
  decoded_byte(w, tail, byte_case(8n, 0, w, byte_cases()))

# No encoded octet introduces a path separator.
law byte_no_slash:
  for +w: Word(8n)
  {no_slash(E.byte(octet(w))) == True{} : Bool}

def byte_no_slash(w):
  clean_byte(w, byte_case(8n, 0, w, byte_cases()))

def escape_octets(xs: List<&2, Word(8n)>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      E.byte(octet(h)) ++ escape_octets(t)

def octet_values(xs: List<&2, Word(8n)>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      octet(h) <> octet_values(t)

# Strict percent decoding inverts percent encoding for every finite octet list.
law unescape_octets:
  for +xs: List<&2, Word(8n)>
  {E.unescape(escape_octets(xs)) == Some{octet_values(xs)} : Maybe<&2, List<&2, U32>>}

def unescape_octets(xs):
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      %Equal.sym(Maybe<&2, List<&2, U32>>, E.unescape(E.byte(octet(h)) ++ escape_octets(t)), Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape(escape_octets(t)), bs => Some{octet(h) <> bs}), unescape_byte(h, escape_octets(t))) : {_ == Some{octet(h) <> octet_values(t)} : Maybe<&2, List<&2, U32>>}
      %Equal.sym(Maybe<&2, List<&2, U32>>, E.unescape(escape_octets(t)), Some{octet_values(t)}, unescape_octets(t)) : {Maybe.bind(&2, List<&2, U32>, List<&2, U32>, _, bs => Some{octet(h) <> bs}) == Some{octet(h) <> octet_values(t)} : Maybe<&2, List<&2, U32>>}
      {==}
