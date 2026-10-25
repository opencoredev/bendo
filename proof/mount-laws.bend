# BND-86: source-string mounting answers at the prefixed paths and nowhere
# else. The specification is proof/mount-spec.bend.
import Base
import ../src/app/compose.bend as C
import ../src/app/table.bend as T
import ../src/router/methods.bend as M
import ../src/router/router.bend as Router
import ../src/router/pattern.bend as P
import ../src/router/spec.bend as R
import ../src/http/request.bend as H
import ./compose-spec.bend as ComposeSpec
import ./router-compile-spec.bend as CS
import ./mount-spec.bend as S

type Mark is Data:
  Mark{}

def source_of(entries: List<&2, T.Entry<Mark>>) -> String:
  match entries:
    case T.ScopedRoute{R.Registration{source, binding}, hooks} <> rest:
      source
    case _:
      ""

# What users write: a member route mounted under a prefix with `B.route`
# (Compose.mount). This is the source the table builder compiles.
def public_source(prefix: String, member: String) -> String:
  source_of(C.mount(Mark, prefix, [T.Route{M.all(Mark, member, Mark{})}]))

def compiled_match(r: Result<&2, &2, P.PatternError, P.Pattern>, path: String, opts: M.Options) -> Maybe<&2, P.Params>:
  match r:
    case Done{p}:
      M.match_path(p, path, opts)
    case Fail{e}:
      None{}

# Compile the public assembled source and match it with the method layer's
# slash and case options.
def public_match(prefix: String, member: String, path: String, opts: M.Options) -> Maybe<&2, P.Params>:
  compiled_match(P.compile(public_source(prefix, member)), path, opts)

# The member registered alone, without a mount.
def member_match(member: String, path: String, opts: M.Options) -> Maybe<&2, P.Params>:
  compiled_match(P.compile(member), path, opts)

# Matching under every slash and case option agrees with the independent
# option reading, for every pattern and raw path: lenient mode drops
# terminal empty segments of path and pattern (keeping one for root), and
# case-insensitive mode folds ASCII letters only in static text.
law match_options_spec:
  for +pattern: P.Pattern
  for +path: String
  for +opts: M.Options
  {M.match_path(pattern, path, opts) == S.match_options(pattern, path, opts) : Maybe<&2, P.Params>}

# The public assembled source compiles, to exactly the pattern the
# independent segment-level join gives, or fails exactly when that join
# fails. Placed: the prefix is empty or starts with `/`, and a member under
# a nonroot prefix starts with `/` or is `*`.
law mount_compile_spec:
  for +prefix: String
  for +member: String
  for placed: {S.placed(prefix, member) == True{} : Bool}
  {CS.accepted(P.compile(public_source(prefix, member))) == S.assembled(prefix, member) : Maybe<&2, P.Pattern>}

# End to end: for an admissible prefix and member, compiling the public
# assembled source and matching it under any options gives exactly the
# specified mounted match: the prefix walks the request's segments first,
# each segment by its own rule (static, capture, optional capture, interior
# wildcard, span), the member matches the rest, and prefix captures precede
# member captures; the assembled pattern alone keeps the root rule. No match
# exactly when the specification has none.
law mount_match_spec:
  for +prefix: String
  for +member: String
  for +path: String
  for +opts: M.Options
  for admissible: {S.admissible(prefix, member) == True{} : Bool}
  {public_match(prefix, member, path, opts) == S.mounted(prefix, member, path, opts) : Maybe<&2, P.Params>}

# Ordered method resolution for a mounted registration list, through every
# router kind: the table builds, and resolution equals first-match over the
# specified mounted answers, with HEAD falling back to the first GET, 405
# with the canonical Allow set of every answering registration, and 404.
law mount_resolve_spec:
  for -Tag: Data
  for +prefix: String
  for +routes: List<&2, M.Registration(Tag)>
  for +kind: Router.RouterKind
  for +path: String
  for +method: H.Method
  for +opts: M.Options
  for admissible: {S.all_admissible(Tag, prefix, routes) == True{} : Bool}
  for valid: {S.methods_valid(Tag, routes) == True{} : Bool}
  {ComposeSpec.routed(Tag, kind, T.build(Tag, C.mount(Tag, prefix, S.entries(Tag, routes))), path, method, opts) == Done{S.resolve(Tag, prefix, routes, path, method, opts)} : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}

# Suffix cancellation: under a literal prefix, with strict trailing slashes,
# a request for the prefix's path plus a suffix `/r` routes exactly as the
# member alone routes `/r`, except for the documented root convention (an
# optional-capture member at suffix `/`).
law mount_literal_suffix:
  for +prefix: String
  for +member: String
  for +r: String
  for +sensitive: Bool
  for admissible: {S.admissible(prefix, member) == True{} : Bool}
  for literal: {S.literal(prefix) == True{} : Bool}
  for alone: {S.compiles(CS.compile(member)) == True{} : Bool}
  for ordinary: {S.root_exception(member, "/" ++ r) == False{} : Bool}
  {public_match(prefix, member, S.lead(prefix) ++ "/" ++ r, M.Options{True{}, sensitive}) == member_match(member, "/" ++ r, M.Options{True{}, sensitive}) : Maybe<&2, P.Params>}

# The root convention: an optional-capture member answers the bare prefix
# path as it alone answers `/`, and the prefix path plus `/` not at all.
law mount_literal_root:
  for +prefix: String
  for +member: String
  for admissible: {S.admissible(prefix, member) == True{} : Bool}
  for literal: {S.literal(prefix) == True{} : Bool}
  for chain: {S.root_optional(member) == True{} : Bool}
  {public_match(prefix, member, S.lead(prefix), M.defaults()) == member_match(member, "/", M.defaults()) : Maybe<&2, P.Params>} & {public_match(prefix, member, S.lead(prefix) ++ "/", M.defaults()) == None{} : Maybe<&2, P.Params>}

# The converse, nowhere else: with default options, every request a literal
# mount answers is the prefix's path plus an empty suffix or one that
# starts with `/`.
law mount_literal_converse:
  for +prefix: String
  for +member: String
  for +path: String
  for +ps: P.Params
  for admissible: {S.admissible(prefix, member) == True{} : Bool}
  for literal: {S.literal(prefix) == True{} : Bool}
  for hit: {public_match(prefix, member, path, M.defaults()) == Some{ps} : Maybe<&2, P.Params>}
  exs rest: String
  {path == S.lead(prefix) ++ rest : String} & {S.boundary(rest) == True{} : Bool}

# The converse under every slash and case option: every request a literal
# mount answers starts with request segments that spell the prefix's
# segments under the case option (exactly, or after ASCII folding), followed
# by nothing or by a suffix that starts with `/`.
law mount_literal_converse_options:
  for +prefix: String
  for +member: String
  for +path: String
  for +strict: Bool
  for +sensitive: Bool
  for +ps: P.Params
  for admissible: {S.admissible(prefix, member) == True{} : Bool}
  for literal: {S.literal(prefix) == True{} : Bool}
  for hit: {public_match(prefix, member, path, M.Options{strict, sensitive}) == Some{ps} : Maybe<&2, P.Params>}
  exs cut: S.Cut
  {path == S.cut_path(cut) : String} & ({S.boundary(S.cut_rest(cut)) == True{} : Bool} & {S.prefix_same(prefix, sensitive, S.cut_segs(cut)) == True{} : Bool})

# With case-sensitive matching, strict or lenient, every request a literal
# mount answers is the prefix's path plus an empty suffix or one that starts
# with `/`.
law mount_literal_converse_sensitive:
  for +prefix: String
  for +member: String
  for +path: String
  for +strict: Bool
  for +ps: P.Params
  for admissible: {S.admissible(prefix, member) == True{} : Bool}
  for literal: {S.literal(prefix) == True{} : Bool}
  for hit: {public_match(prefix, member, path, M.Options{strict, True{}}) == Some{ps} : Maybe<&2, P.Params>}
  exs rest: String
  {path == S.lead(prefix) ++ rest : String} & {S.boundary(rest) == True{} : Bool}

# Typical mounts are admissible: `/api` + `/users/:id`, `/v1/:tenant` +
# `/files/*`, a root mount, an optional member, a constrained capture
# prefix, and a `*` member under a prefix with a trailing slash.
law mount_admissible_examples:
  {S.admissible("/api", "/users/:id") && S.admissible("/v1/:tenant", "/files/*") && S.admissible("/", "/:id?") && S.admissible("", "/users") && S.admissible("/api", "/:id?") && S.admissible("/t/:n{int}", "/") && S.admissible("/api/", "*") == True{} : Bool}

# Every prefix form the pattern syntax allows is admissible when the
# assembled pattern compiles: an anonymous wildcard that becomes interior, an
# optional prefix capture before an optional member (one trailing chain), a
# span with its static anchor in the member, and repeated slashes inside a
# prefix. An optional prefix before a required member, or before the
# member `/` (an empty static), does not compile.
law mount_admissible_forms:
  {S.admissible("/*", "/x") && S.admissible("/:tenant?", "/:id?") && S.admissible("/:scope{.+}", "/x") && S.admissible("/a//b", "/x") && S.admissible("/a/*/b", "/:id") == True{} : Bool} & {S.admissible("/:tenant?", "/x") || S.admissible("/:tenant?", "/") == False{} : Bool}

# What the specification answers for them.
law mount_spec_examples:
  {S.mounted("/api", "/users/:id", "/api/users/42", M.defaults()) == Some{[P.Param{"id", "42"}]} : Maybe<&2, P.Params>} & ({S.mounted("/api", "/users/:id", "/users/42", M.defaults()) == None{} : Maybe<&2, P.Params>} & ({S.mounted("/api", "/users/:id", "/apix/users/42", M.defaults()) == None{} : Maybe<&2, P.Params>} & ({S.mounted("/v1/:tenant", "/files/*", "/v1/acme/files/a/b", M.defaults()) == Some{[P.Param{"tenant", "acme"}, P.Param{"*", "a/b"}]} : Maybe<&2, P.Params>} & ({S.mounted("/", "/:id?", "/", M.defaults()) == Some{[]} : Maybe<&2, P.Params>} & {S.mounted("/API/", "/Users", "/api/users/", M.Options{False{}, False{}}) == Some{[]} : Maybe<&2, P.Params>}))))

# What the specification answers for the other prefix forms: the interior
# wildcard skips zero or more whole segments; the optional chain answers with both, one
# or neither capture, and the bare root through the assembled root rule;
# the span takes as many segments as still let `/x` match; an empty interior
# prefix segment must be present.
law mount_spec_form_examples:
  {S.mounted("/*", "/x", "/a/b/x", M.defaults()) == Some{[]} : Maybe<&2, P.Params>} & ({S.mounted("/*", "/x", "/x", M.defaults()) == Some{[]} : Maybe<&2, P.Params>} & ({S.mounted("/*", "/x", "/a/b", M.defaults()) == None{} : Maybe<&2, P.Params>} & ({S.mounted("/:tenant?", "/:id?", "/acme/7", M.defaults()) == Some{[P.Param{"tenant", "acme"}, P.Param{"id", "7"}]} : Maybe<&2, P.Params>} & ({S.mounted("/:tenant?", "/:id?", "/acme", M.defaults()) == Some{[P.Param{"tenant", "acme"}]} : Maybe<&2, P.Params>} & ({S.mounted("/:tenant?", "/:id?", "/", M.defaults()) == Some{[]} : Maybe<&2, P.Params>} & ({S.mounted("/:scope{.+}", "/x", "/a/x/b/x", M.defaults()) == Some{[P.Param{"scope", "a/x/b"}]} : Maybe<&2, P.Params>} & ({S.mounted("/:scope{.+}", "/x", "/x", M.defaults()) == None{} : Maybe<&2, P.Params>} & ({S.mounted("/a//b", "/x", "/a//b/x", M.defaults()) == Some{[]} : Maybe<&2, P.Params>} & {S.mounted("/a//b", "/x", "/a/b/x", M.defaults()) == None{} : Maybe<&2, P.Params>}))))))))

# The documented counterexamples stay outside. Mounted `/:id?` answers
# `/api` but rejects `/api/`, although alone it answers `/`; so suffix
# cancellation excludes it by its root-convention premise. A prefix ending
# in repeated slashes ends with an empty prefix segment, which no law admits.
law mount_counterexamples:
  {S.mounted("/api", "/:id?", "/api", M.defaults()) == Some{[]} : Maybe<&2, P.Params>} & ({S.mounted("/api", "/:id?", "/api/", M.defaults()) == None{} : Maybe<&2, P.Params>} & ({S.root_exception("/:id?", "/") == True{} : Bool} & ({S.admissible("/a//", "/x") == False{} : Bool} & {S.admissible("//", "/x") == False{} : Bool})))

# Why suffix cancellation needs strict trailing slashes. Under lenient
# matching, `//:id?` alone answers `/` with no captures, but mounted under
# `/api` it rejects `/api/`, although the mount is admissible, the prefix is
# literal and `/` is no root-convention exception for this member.
law mount_lenient_suffix_counterexample:
  {public_match("/api", "//:id?", "/api/", M.Options{False{}, True{}}) == None{} : Maybe<&2, P.Params>} & ({member_match("//:id?", "/", M.Options{False{}, True{}}) == Some{[]} : Maybe<&2, P.Params>} & ({S.admissible("/api", "//:id?") && S.literal("/api") == True{} : Bool} & {S.root_exception("//:id?", "/") == False{} : Bool}))
