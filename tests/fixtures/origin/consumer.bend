# Origin, media-type and trim parsing exported for tests/origin.test.ts.
import Base
import ../../../src/http/origin.bend as O
import ../../../src/http/media.bend as M
import ../../../src/http/bytes.bend as B

# "" stands for a rejected value; every accepted origin is longer.
def shown(m: Maybe<&2, String>) -> String:
  match m:
    case None{}: ""
    case Some{s}: s

def canonical(s: String) -> String: shown(O.canonical(s))
def of_url(s: String) -> String: shown(O.of_url(s))
def of_host(scheme: String, host: String) -> String: shown(O.of_host(scheme, host))
def essence(s: String) -> String: M.essence(s)
def trim_text(s: String) -> String: B.trim_text(s)

def yes(b: Bool) -> String:
  match b:
    case True{}: "yes"
    case False{}: ""

def well_formed(s: String) -> String: yes(M.well_formed(s))

def main() -> String:
  canonical("https://[::1]:443")
