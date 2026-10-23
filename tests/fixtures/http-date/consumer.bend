import Base
import ../../../src/http/date.bend as Date

def format_imf(s: Nat) -> String: Date.format_imf(s)
def parse_imf(s: String) -> Maybe<&2, Nat>: Date.parse_imf(s)
