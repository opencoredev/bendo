import Base
import ../../../src/http/response.bend as Response
import ../../../src/data/json.bend as J
import ../../../src/data/json_http.bend as H

def parse(s: List<&2, U32>) -> Result<&2, &2, J.Error, J.Json>: J.parse(s)
def parse_string(s: String) -> Result<&2, &2, J.Error, J.Json>: J.parse_string(s)
def write(v: J.Json, pretty: Bool, ascii: Bool) -> Result<&2, &2, J.Error, String>: J.write(v, pretty, ascii)
def lookup(xs: List<&2, J.Field>, key: String) -> Maybe<&2, J.Json>: J.lookup(xs, key)
def response(status: U32, v: J.Json) -> Result<&2, &2, J.Error, Response.Res>: H.json(status, v)
def request(body: List<&2, U32>) -> Result<&2, &2, J.Error, J.Json>: H.req_json(body)

def to_u32(v: J.Json) -> Maybe<&2, U32>: J.to_u32(v)
