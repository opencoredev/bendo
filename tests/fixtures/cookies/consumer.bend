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

# Exercise serialization through the same public entry points on both targets.
def serialization_case(mode: String, payload: String) -> Result<&2, &2, C.Error, String>:
  match mode:
    case "name": C.serialize(payload, "v", C.defaults())
    case "value": C.serialize("a", payload, C.defaults())
    case "path": C.serialize("a", "v", C.Options{Some{payload}, None{}, Some{C.Seconds{60n}}, Some{"Wed, 21 Oct 2015 07:28:00 GMT"}, True{}, True{}, Some{C.Strict{}}, True{}})
    case "domain": C.serialize("a", "v", C.Options{None{}, Some{payload}, None{}, None{}, False{}, False{}, None{}, False{}})
    case "expires": C.serialize("a", "v", C.Options{None{}, None{}, None{}, Some{payload}, False{}, False{}, None{}, False{}})
    case _: Fail{C.InvalidName{}}

def context_wire(result: Result<&2, &2, C.Error, Context.Ctx<Unit>>) -> Result<&2, &2, C.Error, String>:
  match result:
    case Fail{error}: Fail{error}
    case Done{Context.Ctx{r, p, b, q, code, headers, vars, observation}}:
      match headers:
        case R.Header{name, bytes} <> Nil{}: Done{Context.cookie_ascii_go(bytes, "")}
        case _: Fail{C.InvalidValue{}}

def context_case_go(mode: String, payload: String, c: Context.Ctx<Unit>) -> Result<&2, &2, C.Error, String>:
  match mode:
    case "set-name": context_wire(Context.set_cookie(Unit, c, payload, "v", C.defaults()))
    case "set-value": context_wire(Context.set_cookie(Unit, c, "a", payload, C.defaults()))
    case "set-path": context_wire(Context.set_cookie(Unit, c, "a", "v", C.Options{Some{payload}, None{}, None{}, None{}, False{}, False{}, None{}, False{}}))
    case "delete-path": context_wire(Context.delete_cookie(Unit, c, "a", C.Options{Some{payload}, None{}, None{}, None{}, False{}, False{}, None{}, False{}}))
    case "delete-name": context_wire(Context.delete_cookie(Unit, c, payload, C.defaults()))
    case "set-domain": context_wire(Context.set_cookie(Unit, c, "a", "v", C.Options{None{}, Some{payload}, None{}, None{}, False{}, False{}, None{}, False{}}))
    case "delete-domain": context_wire(Context.delete_cookie(Unit, c, "a", C.Options{None{}, Some{payload}, None{}, None{}, False{}, False{}, None{}, False{}}))
    case _: Fail{C.InvalidName{}}

def context_case(mode: String, payload: String) -> Result<&2, &2, C.Error, String>:
  context_case_go(mode, payload, Context.create(R.Req{R.Get{}, "/", None{}, R.Http11{}, []}, [], [], []))
