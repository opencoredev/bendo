# Drive the pure rate-limit table through EvictOldest churn for mw-ip tests.
import Base
import ../../../src/mw/rate_limit_core.bend as Core

# Admit n distinct keys tag ++ i at a fixed time, so no sweep falls due after
# the first one and every new key past max_keys evicts.
def admit_many(+policy: Core.Policy, +max_keys: Nat, +tag: String, n: Nat, t: Core.Table) -> Core.Table:
  match n:
    case 0n: t
    case 1n+(+k): admit_many(policy, max_keys, tag, k, Core.admit(policy, Core.EvictOldest{}, max_keys, tag ++ Nat.show(k), 1000n, t))

# Admit n requests from the already tracked keys tag ++ (i mod size).
def admit_known(+policy: Core.Policy, +max_keys: Nat, +tag: String, +size: Nat, n: Nat, t: Core.Table) -> Core.Table:
  match n:
    case 0n: t
    case 1n+(+k): admit_known(policy, max_keys, tag, size, k, Core.admit(policy, Core.EvictOldest{}, max_keys, tag ++ Nat.show(Nat.mod(k, size)), 1000n, t))

def stats_text(s: Core.Stats) -> String:
  Core.Stats{tracked, saturated, saturating} = s
  Nat.show(tracked) ++ " " ++ Nat.show(saturated)

def number(s: String) -> Nat:
  Maybe.default(&2, Nat, Nat.read(s), 0n)

def filled(+policy: Core.Policy, +max_keys: Nat) -> Core.Table:
  admit_many(policy, max_keys, "f", max_keys, Core.empty(policy))

# Fill a table of max_keys keys, then admit rounds new keys, each evicting
# one. "tracked saturated".
def churn(keys: String, rounds: String) -> String:
  +policy = Core.fixed_window_policy(1000000n, 60000n)
  +max_keys = number(keys)
  stats_text(Core.stats(admit_many(policy, max_keys, "c", number(rounds), filled(policy, max_keys))))

# The same table, then rounds requests from keys it already tracks.
def known(keys: String, rounds: String) -> String:
  +policy = Core.fixed_window_policy(1000000n, 60000n)
  +max_keys = number(keys)
  stats_text(Core.stats(admit_known(policy, max_keys, "f", Nat.max(1n, max_keys), number(rounds), filled(policy, max_keys))))

def found_text(s: Core.Seek) -> String:
  match s:
    case Core.Found{k, f, b, n, m}: "found " ++ k
    case Core.Seeking{f, b, n, m}: "seeking"
    case Core.Exhausted{m}: "exhausted"

# Search a recency queue whose first pair is current with the given fuel.
def seek(fuel: String) -> String:
  +m = Map.set(&2, Core.Slot, Map.new(&2, Core.Slot), "k", Core.Slot{Core.Win{Core.Counter{0n, 0n}}, 7n})
  found_text(Core.seek_run(number(fuel), Core.Seeking{[Core.Recent{"k", 7n}], [], 1n, m}))
