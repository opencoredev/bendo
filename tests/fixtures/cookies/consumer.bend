import Base
import ../../../src/data/cookie.bend as C

def parse(s: String) -> List<&2, C.Entry>: C.parse(s)
def serialize(name: String, value: String, options: C.Options) -> Result<&2, &2, C.Error, String>: C.serialize(name, value, options)
def name_valid(s: String) -> Bool: C.name_valid(s)
def value_valid(s: String) -> Bool: C.value_valid(s)
def expires_valid(s: String) -> Bool: C.expires_valid(s)
def first(pairs: List<&2, C.Entry>, name: String) -> Maybe<&2, String>: C.first(pairs, name)
def deletion(options: C.Options) -> C.Options: C.deletion(options)
def defaults() -> C.Options: C.defaults()
