import Base
import ../../../src/http/conditional.bend as Conditional
import ../../../src/mw/cache.bend as Cache

def match_text(field: String, tag: String) -> Bool:
  Conditional.matches(Some{field}, tag)

def cache_values() -> String:
  Cache.value(Cache.NoStore{}) ++ "|" ++ Cache.value(Cache.NoCache{}) ++ "|" ++ Cache.value(Cache.Private{7}) ++ "|" ++ Cache.value(Cache.Public{8, False{}})
