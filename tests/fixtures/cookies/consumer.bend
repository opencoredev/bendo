import Base
import ../../../src/data/cookie.bend as C
import ../../../src/app/context.bend as Context
import ../../../src/http/request.bend as R

def parse(s: String) -> List<&2, C.Entry>: C.parse(s)
def serialize(name: String, value: String, options: C.Options) -> Result<&2, &2, C.Error, String>: C.serialize(name, value, options)
def name_valid(s: String) -> Bool: C.name_valid(s)
def value_valid(s: String) -> Bool: C.value_valid(s)
def expires_valid(s: String) -> Bool: C.expires_valid(s)
def first(pairs: List<&2, C.Entry>, name: String) -> Maybe<&2, String>: C.first(pairs, name)
def deletion(options: C.Options) -> C.Options: C.deletion(options)
def defaults() -> C.Options: C.defaults()

# Build request bytes without introducing a test-only JavaScript stack limit.
def bytes_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}: List.reverse(&2, U32, acc)
    case SCon{Chr{c}, t}: bytes_go(t, c <> acc)

def cookies_headers(headers: List<&2, R.Header>) -> List<&2, C.Entry>:
  Context.cookies(Unit, Context.create(R.Req{R.Get{}, "/", None{}, R.Http11{}, headers}, [], [], []))

def cookies_header(s: String) -> List<&2, C.Entry>:
  cookies_headers([R.Header{"cookie", bytes_go(s, [])}])
