# BND-86: proofs of the source-string mounting laws.
import Base
import ../src/router/pattern.bend as P
import ../src/router/methods.bend as M
import ../src/router/proofs.bend as Core
import ../src/router/compile-spec-proofs.bend as CSP
import ../src/app/compose.bend as C
import ../src/app/table.bend as T
import ./compose-spec.bend as ComposeSpec
import ./compose-laws.bend as CL
import ./compose.bend as ComposeProof
import ./scoped-assembly-spec.bend as AssemblySpec
import ./router-compile-spec.bend as CS
import ./mount-spec.bend as S
import ./mount-laws.bend as L
import ./mount-options.bend as MO
import ./mount-join.bend as MJ
import ./mount-decompose.bend as MD
import ../src/router/equality-proofs.bend as Eq
import ../src/router/match-spec-proofs.bend as MSP
import ./router-match-spec.bend as MS
import ./fold-spec.bend as F

def L.match_options_spec(pattern, path, opts):
  MO.options_spec(pattern, path, opts)

# ---- The public source ----

def entry(+member: String) -> List<&2, T.Entry<L.Mark>>:
  [T.Route{M.all(L.Mark, member, L.Mark{})}]

def source_eq(+prefix: String, +member: String) -> {L.public_source(prefix, member) == AssemblySpec.path(prefix, ComposeSpec.canonical(member)) : String}:
  %Equal.sym(List<&2, T.Entry<L.Mark>>, C.mount(L.Mark, prefix, entry(member)), ComposeSpec.mount(L.Mark, prefix, entry(member)), CL.compose_mount(L.Mark, prefix, entry(member))) : {L.source_of(_) == AssemblySpec.path(prefix, ComposeSpec.canonical(member)) : String}
  {==}

def compile_view(+prefix: String, +member: String, placed: {S.placed(prefix, member) == True{} : Bool}) ->
    {CS.compile(L.public_source(prefix, member)) == S.assembled(prefix, member) : Maybe<&2, P.Pattern>}:
  %Equal.sym(String, L.public_source(prefix, member), AssemblySpec.path(prefix, ComposeSpec.canonical(member)), source_eq(prefix, member)) : {CS.compile(_) == S.assembled(prefix, member) : Maybe<&2, P.Pattern>}
  MJ.assembled_view(prefix, member, placed)

def L.mount_compile_spec(prefix, member, placed):
  Equal.trans(Maybe<&2, P.Pattern>, CS.accepted(P.compile(L.public_source(prefix, member))), CS.compile(L.public_source(prefix, member)), S.assembled(prefix, member), CSP.compile_spec(L.public_source(prefix, member)), compile_view(prefix, member, placed))

# ---- Admissibility facts ----

def placed_from(pp: Maybe<&2, List<&2, P.Segment>>, m: Maybe<&2, String>, adm: {S.fixed_and(pp, S.compiles(S.joined(pp, S.member_pieces(m)))) == True{} : Bool}) ->
    {S.compiles_text(m) == True{} : Bool}:
  match pp m:
    case None{} y:
      Core.absurd({S.compiles_text(y) == True{} : Bool}, Core.false_true(adm))
    case Some{+a} None{}:
      Core.absurd({S.compiles_text(None{}) == True{} : Bool}, Core.false_true(Core.and_right(S.fixed_prefix(a), False{}, adm)))
    case Some{a} Some{t}:
      {==}

def placed_at(at: S.Place, +member: String, adm: {S.admissible_at(at, member) == True{} : Bool}) -> {S.placed_at(at, member) == True{} : Bool}:
  match at:
    case S.AtRoot{}:
      {==}
    case S.Under{+raws}:
      placed_from(S.prefix_pieces(raws), S.member_text(member), adm)
    case S.Unplaced{}:
      Core.absurd({S.placed_at(S.Unplaced{}, member) == True{} : Bool}, Core.false_true(adm))

def compiles_from(pp: Maybe<&2, List<&2, P.Segment>>, +mp: Maybe<&2, List<&2, P.Segment>>, adm: {S.fixed_and(pp, S.compiles(S.joined(pp, mp))) == True{} : Bool}) ->
    {S.compiles(S.joined(pp, mp)) == True{} : Bool}:
  match pp:
    case None{}:
      Core.absurd({S.compiles(S.joined(None{}, mp)) == True{} : Bool}, Core.false_true(adm))
    case Some{+a}:
      Core.and_right(S.fixed_prefix(a), S.compiles(S.joined(Some{a}, mp)), adm)

def compiles_at(at: S.Place, +member: String, adm: {S.admissible_at(at, member) == True{} : Bool}) -> {S.compiles(S.assembled_at(at, member)) == True{} : Bool}:
  match at:
    case S.AtRoot{}:
      adm
    case S.Under{+raws}:
      compiles_from(S.prefix_pieces(raws), S.member_pieces(S.member_text(member)), adm)
    case S.Unplaced{}:
      Core.absurd({S.compiles(S.assembled_at(S.Unplaced{}, member)) == True{} : Bool}, Core.false_true(adm))

# ---- End to end ----

def main_at(r: Result<&2, &2, P.PatternError, P.Pattern>, +prefix: String, +member: String, +path: String, +opts: M.Options,
    e: {CS.accepted(r) == S.assembled(prefix, member) : Maybe<&2, P.Pattern>},
    +admissible: {S.admissible(prefix, member) == True{} : Bool}) ->
    {L.compiled_match(r, path, opts) == S.mounted(prefix, member, path, opts) : Maybe<&2, P.Params>}:
  match r:
    case Fail{x}:
      +clash = Equal.trans(Bool, False{}, S.compiles(S.assembled(prefix, member)), True{}, Equal.cong(Maybe<&2, P.Pattern>, Bool, m => S.compiles(m), None{}, S.assembled(prefix, member), e), compiles_at(S.place(prefix), member, admissible))
      Core.absurd({L.compiled_match(Fail{x}, path, opts) == S.mounted(prefix, member, path, opts) : Maybe<&2, P.Params>}, Core.false_true(clash))
    case Done{+p}:
      Equal.trans(Maybe<&2, P.Params>, M.match_path(p, path, opts), S.match_options(p, path, opts), S.mounted(prefix, member, path, opts), MO.options_spec(p, path, opts), MD.decompose_at(S.place(prefix), member, p, path, opts, Equal.sym(Maybe<&2, P.Pattern>, Some{p}, S.assembled(prefix, member), e), admissible))

def L.mount_match_spec(prefix, member, path, opts, admissible):
  +adm = admissible
  main_at(P.compile(L.public_source(prefix, member)), prefix, member, path, opts, L.mount_compile_spec(prefix, member, placed_at(S.place(prefix), member, adm)), adm)

# ---- Literal prefixes ----

def statics(raws: List<&2, String>) -> List<&2, P.Segment>:
  match raws:
    case Nil{}:
      Nil{}
    case raw <> t:
      P.Static{raw} <> statics(t)

def piece_plain(+raw: String, pt: {S.plain_text(raw) == True{} : Bool}) -> {CS.piece(raw, False{}) == Some{P.Static{raw}} : Maybe<&2, P.Segment>}:
  match raw:
    case SNil{}:
      Core.absurd({CS.piece(SNil{}, False{}) == Some{P.Static{SNil{}}} : Maybe<&2, P.Segment>}, Core.false_true(pt))
    case SCon{+h, +t}:
      +e = pt
      +abc = Core.and_left(Bool.not(Char.is_eq(h, ':')) && Bool.not(Char.is_eq(h, '*')) && Bool.not(String.ends_with(SCon{h, t}, "*")), CS.static_text(SCon{h, t}), e)
      +d = Core.and_right(Bool.not(Char.is_eq(h, ':')) && Bool.not(Char.is_eq(h, '*')) && Bool.not(String.ends_with(SCon{h, t}, "*")), CS.static_text(SCon{h, t}), e)
      +ab = Core.and_left(Bool.not(Char.is_eq(h, ':')) && Bool.not(Char.is_eq(h, '*')), Bool.not(String.ends_with(SCon{h, t}, "*")), abc)
      +c = Core.not_true(String.ends_with(SCon{h, t}, "*"), Core.and_right(Bool.not(Char.is_eq(h, ':')) && Bool.not(Char.is_eq(h, '*')), Bool.not(String.ends_with(SCon{h, t}, "*")), abc))
      +a = Core.not_true(Char.is_eq(h, ':'), Core.and_left(Bool.not(Char.is_eq(h, ':')), Bool.not(Char.is_eq(h, '*')), ab))
      +b = Core.not_true(Char.is_eq(h, '*'), Core.and_right(Bool.not(Char.is_eq(h, ':')), Bool.not(Char.is_eq(h, '*')), ab))
      %Equal.sym(Bool, Char.is_eq(h, ':'), False{}, a) : {CS.lead(_, Char.is_eq(h, '*'), h, t, False{}) == Some{P.Static{SCon{h, t}}} : Maybe<&2, P.Segment>}
      %Equal.sym(Bool, Char.is_eq(h, '*'), False{}, b) : {CS.lead(False{}, _, h, t, False{}) == Some{P.Static{SCon{h, t}}} : Maybe<&2, P.Segment>}
      %Equal.sym(Bool, String.ends_with(SCon{h, t}, "*"), False{}, c) : {CS.plain(_, SCon{h, t}) == Some{P.Static{SCon{h, t}}} : Maybe<&2, P.Segment>}
      %Equal.sym(Bool, CS.static_text(SCon{h, t}), True{}, d) : {CS.text(_, SCon{h, t}) == Some{P.Static{SCon{h, t}}} : Maybe<&2, P.Segment>}
      {==}

# Plain prefix text compiles to static segments holding that text.
def pieces_plain(+raws: List<&2, String>, plain: {S.all_plain(raws) == True{} : Bool}) -> {S.prefix_pieces(raws) == Some{statics(raws)} : Maybe<&2, List<&2, P.Segment>>}:
  match raws:
    case Nil{}:
      {==}
    case +raw <> +t:
      +e = plain
      %Equal.sym(Maybe<&2, P.Segment>, CS.piece(raw, False{}), Some{P.Static{raw}}, piece_plain(raw, Core.and_left(S.plain_text(raw), S.all_plain(t), e))) : {CS.both(_, S.prefix_pieces(t)) == Some{statics(raw <> t)} : Maybe<&2, List<&2, P.Segment>>}
      %Equal.sym(Maybe<&2, List<&2, P.Segment>>, S.prefix_pieces(t), Some{statics(t)}, pieces_plain(t, Core.and_right(S.plain_text(raw), S.all_plain(t), e))) : {CS.both(Some{P.Static{raw}}, _) == Some{statics(raw <> t)} : Maybe<&2, List<&2, P.Segment>>}
      {==}

def same_refl(+sens: Bool, +raw: String) -> {S.text_same(sens, raw, raw) == True{} : Bool}:
  match sens:
    case True{}:
      Eq.string_eq_refl(raw)
    case False{}:
      Eq.string_eq_refl(F.fold(raw))

# A literal prefix consumes its own segments and leaves the rest.
def walk_literal(+raws: List<&2, String>, +ys: List<&2, String>, +sens: Bool, +mb: List<&2, P.Segment>) ->
    {S.walk(statics(raws), List.append(&2, String, raws, ys), sens, mb) == S.segments_with(sens, mb, ys) : Maybe<&2, P.Params>}:
  match raws:
    case Nil{}:
      {==}
    case +raw <> +t:
      %Equal.sym(Bool, S.text_same(sens, raw, raw), True{}, same_refl(sens, raw)) : {MS.same_text(_, S.walk(statics(t), List.append(&2, String, t, ys), sens, mb)) == S.segments_with(sens, mb, ys) : Maybe<&2, P.Params>}
      walk_literal(t, ys, sens, mb)

def split_join_all(+raws: List<&2, String>, facts: MJ.UnderFacts(S.Under{raws})) -> {String.split(String.join(raws, "/"), '/') == raws : List<&2, String>}:
  match raws:
    case Nil{}:
      Core.absurd({String.split(String.join(Nil{}, "/"), '/') == Nil{} : List<&2, String>}, Core.false_true(facts))
    case +h <> +t:
      Core.split_join_base(t, h, Core.and_left(Core.clean_segments(h <> t), Bool.not(List.is_empty(&2, String, h <> t)), facts))

def lead_split(+raws: List<&2, String>, +r: String, facts: MJ.UnderFacts(S.Under{raws})) ->
    {String.split(String.join(raws, "/") ++ SCon{'/', r}, '/') == List.append(&2, String, raws, String.split(r, '/')) : List<&2, String>}:
  Equal.trans(List<&2, String>, String.split(String.join(raws, "/") ++ SCon{'/', r}, '/'), List.append(&2, String, String.split(String.join(raws, "/"), '/'), String.split(r, '/')), List.append(&2, String, raws, String.split(r, '/')), MJ.split_append(String.join(raws, "/"), r), Equal.cong(List<&2, String>, List<&2, String>, xs => List.append(&2, String, xs, String.split(r, '/')), String.split(String.join(raws, "/"), '/'), raws, split_join_all(raws, facts)))

def root_ordinary(+r: String, +b: List<&2, P.Segment>, ord: {String.eq(SCon{'/', r}, "/") && S.chain_at(Some{P.Pattern{b}}) == False{} : Bool}) ->
    {S.root_hit(String.split(r, '/'), b) == None{} : Maybe<&2, P.Params>}:
  match r:
    case SNil{}:
      match b:
        case P.Capture{+n, +c, True{}} <> +rest:
          %Equal.sym(Bool, MS.only_optional(rest), False{}, ord) : {MS.prefix_hit(_) == None{} : Maybe<&2, P.Params>}
          {==}
        case Nil{}:
          {==}
        case P.Capture{n, c, False{}} <> rest:
          {==}
        case P.Static{x} <> rest:
          {==}
        case P.Wildcard{n} <> rest:
          {==}
        case P.InteriorWildcard{} <> rest:
          {==}
        case P.PrefixWildcard{x} <> rest:
          {==}
        case P.Span{n} <> rest:
          {==}
    case SCon{+x, +y}:
      MO.root_fin(x, String.split(y, '/'), Char.is_eq(x, '/'), b, e => MO.split_ne(y, e))

def suffix_ok(+raws: List<&2, String>, +b: List<&2, P.Segment>, ok: Bool, +r: String, +sens: Bool,
    alone: {S.compiles(CS.accept(ok, b)) == True{} : Bool}, ord: {String.eq(SCon{'/', r}, "/") && S.chain_at(CS.accept(ok, b)) == False{} : Bool},
    facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk_pieces(Some{statics(raws)}, Some{b}, ("/" ++ String.join(raws, "/")) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.accept(ok, b), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}:
  match ok:
    case False{}:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{b}, ("/" ++ String.join(raws, "/")) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.accept(False{}, b), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}, Core.false_true(alone))
    case True{}:
      %Equal.sym(List<&2, String>, String.split(String.join(raws, "/") ++ SCon{'/', r}, '/'), List.append(&2, String, raws, String.split(r, '/')), lead_split(raws, r, facts)) : {S.walk(statics(raws), _, sens, b) == S.member_alone(Some{P.Pattern{b}}, "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(r, '/'), b), None{}, root_ordinary(r, b, ord)) : {S.walk(statics(raws), List.append(&2, String, raws, String.split(r, '/')), sens, b) == MS.or_else(S.segments_with(sens, b, String.split(r, '/')), u => _) : Maybe<&2, P.Params>}
      Equal.trans(Maybe<&2, P.Params>, S.walk(statics(raws), List.append(&2, String, raws, String.split(r, '/')), sens, b), S.segments_with(sens, b, String.split(r, '/')), MS.or_else(S.segments_with(sens, b, String.split(r, '/')), u => None{}), walk_literal(raws, String.split(r, '/'), sens, b), Equal.sym(Maybe<&2, P.Params>, MS.or_else(S.segments_with(sens, b, String.split(r, '/')), u => None{}), S.segments_with(sens, b, String.split(r, '/')), MSP.or_else_none(S.segments_with(sens, b, String.split(r, '/')))))

def suffix_pieces(+raws: List<&2, String>, mp: Maybe<&2, List<&2, P.Segment>>, +r: String, +sens: Bool,
    alone: {S.compiles(CS.checked(mp)) == True{} : Bool}, ord: {String.eq(SCon{'/', r}, "/") && S.chain_at(CS.checked(mp)) == False{} : Bool},
    facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk_pieces(Some{statics(raws)}, mp, ("/" ++ String.join(raws, "/")) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.checked(mp), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}:
  match mp:
    case None{}:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, None{}, ("/" ++ String.join(raws, "/")) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.checked(None{}), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}, Core.false_true(alone))
    case Some{+b}:
      suffix_ok(raws, b, CS.rules(b, Nil{}) && CS.spans(b), r, sens, alone, ord, facts)

def compile_member(+member: String, led: {S.compiles_text(S.member_text(member)) == True{} : Bool}) ->
    {CS.compile(member) == CS.checked(S.member_pieces(S.member_text(member))) : Maybe<&2, P.Pattern>}:
  MJ.compile_member(member, led)

def suffix_at(at: S.Place, +member: String, +r: String, +sens: Bool,
    adm: {S.admissible_at(at, member) == True{} : Bool}, lit: {S.literal_at(at) == True{} : Bool},
    alone: {S.compiles(CS.compile(member)) == True{} : Bool}, ord: {S.root_exception(member, "/" ++ r) == False{} : Bool},
    facts: MJ.UnderFacts(at)) ->
    {S.mounted_at(at, member, S.lead_at(at) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.compile(member), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}:
  match at:
    case S.AtRoot{}:
      Core.absurd({S.mounted_at(S.AtRoot{}, member, S.lead_at(S.AtRoot{}) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.compile(member), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}, Core.false_true(lit))
    case S.Unplaced{}:
      Core.absurd({S.mounted_at(S.Unplaced{}, member, S.lead_at(S.Unplaced{}) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.compile(member), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}, Core.false_true(lit))
    case S.Under{+raws}:
      +cm = compile_member(member, placed_from(S.prefix_pieces(raws), S.member_text(member), adm))
      +mp = S.member_pieces(S.member_text(member))
      +alone2 = Equal.trans(Bool, S.compiles(CS.checked(mp)), S.compiles(CS.compile(member)), True{}, Equal.cong(Maybe<&2, P.Pattern>, Bool, m => S.compiles(m), CS.checked(mp), CS.compile(member), Equal.sym(Maybe<&2, P.Pattern>, CS.compile(member), CS.checked(mp), cm)), alone)
      +ord2 = Equal.trans(Bool, String.eq(SCon{'/', r}, "/") && S.chain_at(CS.checked(mp)), String.eq(SCon{'/', r}, "/") && S.chain_at(CS.compile(member)), False{}, Equal.cong(Maybe<&2, P.Pattern>, Bool, m => String.eq(SCon{'/', r}, "/") && S.chain_at(m), CS.checked(mp), CS.compile(member), Equal.sym(Maybe<&2, P.Pattern>, CS.compile(member), CS.checked(mp), cm)), ord)
      %Equal.sym(Maybe<&2, List<&2, P.Segment>>, S.prefix_pieces(raws), Some{statics(raws)}, pieces_plain(raws, lit)) : {S.walk_pieces(_, mp, ("/" ++ String.join(raws, "/")) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.compile(member), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Pattern>, CS.compile(member), CS.checked(mp), cm) : {S.walk_pieces(Some{statics(raws)}, mp, ("/" ++ String.join(raws, "/")) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(_, "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}
      suffix_pieces(raws, mp, r, sens, alone2, ord2, facts)

# The member alone, registered without a mount.
def member_at(r: Result<&2, &2, P.PatternError, P.Pattern>, +member: String, +path: String, +opts: M.Options,
    e: {CS.accepted(r) == CS.compile(member) : Maybe<&2, P.Pattern>}, alone: {S.compiles(CS.compile(member)) == True{} : Bool}) ->
    {L.compiled_match(r, path, opts) == S.member_alone(CS.compile(member), path, opts) : Maybe<&2, P.Params>}:
  match r:
    case Fail{x}:
      +clash = Equal.trans(Bool, False{}, S.compiles(CS.compile(member)), True{}, Equal.cong(Maybe<&2, P.Pattern>, Bool, m => S.compiles(m), None{}, CS.compile(member), e), alone)
      Core.absurd({L.compiled_match(Fail{x}, path, opts) == S.member_alone(CS.compile(member), path, opts) : Maybe<&2, P.Params>}, Core.false_true(clash))
    case Done{+q}:
      %e : {M.match_path(q, path, opts) == S.member_alone(_, path, opts) : Maybe<&2, P.Params>}
      MO.options_spec(q, path, opts)

def member_view(+member: String, +path: String, +opts: M.Options, alone: {S.compiles(CS.compile(member)) == True{} : Bool}) ->
    {L.member_match(member, path, opts) == S.member_alone(CS.compile(member), path, opts) : Maybe<&2, P.Params>}:
  member_at(P.compile(member), member, path, opts, CSP.compile_spec(member), alone)

def L.mount_literal_suffix(prefix, member, r, sensitive, admissible, literal, alone, ordinary):
  +adm = admissible
  +al = alone
  Equal.trans(Maybe<&2, P.Params>, L.public_match(prefix, member, S.lead(prefix) ++ ("/" ++ r), M.Options{True{}, sensitive}), S.mounted(prefix, member, S.lead(prefix) ++ ("/" ++ r), M.Options{True{}, sensitive}), L.member_match(member, "/" ++ r, M.Options{True{}, sensitive}), L.mount_match_spec(prefix, member, S.lead(prefix) ++ ("/" ++ r), M.Options{True{}, sensitive}, adm), Equal.trans(Maybe<&2, P.Params>, S.mounted(prefix, member, S.lead(prefix) ++ ("/" ++ r), M.Options{True{}, sensitive}), S.member_alone(CS.compile(member), "/" ++ r, M.Options{True{}, sensitive}), L.member_match(member, "/" ++ r, M.Options{True{}, sensitive}), suffix_at(S.place(prefix), member, r, sensitive, adm, literal, al, ordinary, MJ.under_facts(prefix)), Equal.sym(Maybe<&2, P.Params>, L.member_match(member, "/" ++ r, M.Options{True{}, sensitive}), S.member_alone(CS.compile(member), "/" ++ r, M.Options{True{}, sensitive}), member_view(member, "/" ++ r, M.Options{True{}, sensitive}, al))))


# ---- The root convention ----

def app_nil(+xs: List<&2, String>) -> {List.append(&2, String, xs, Nil{}) == xs : List<&2, String>}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.cong(List<&2, String>, List<&2, String>, r => h <> r, List.append(&2, String, t, Nil{}), t, app_nil(t))

def opt_nil(+rest: List<&2, P.Segment>, oo: {MS.only_optional(rest) == True{} : Bool}) -> {MS.matches(rest, Nil{}, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}:
  match rest:
    case Nil{}:
      {==}
    case P.Capture{+n, +c, True{}} <> +t:
      opt_nil(t, oo)
    case P.Capture{n, c, False{}} <> t:
      Core.absurd({MS.matches(P.Capture{n, c, False{}} <> t, Nil{}, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(oo))
    case P.Static{x} <> t:
      Core.absurd({MS.matches(P.Static{x} <> t, Nil{}, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(oo))
    case P.Wildcard{n} <> t:
      Core.absurd({MS.matches(P.Wildcard{n} <> t, Nil{}, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(oo))
    case P.InteriorWildcard{} <> t:
      Core.absurd({MS.matches(P.InteriorWildcard{} <> t, Nil{}, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(oo))
    case P.PrefixWildcard{x} <> t:
      Core.absurd({MS.matches(P.PrefixWildcard{x} <> t, Nil{}, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(oo))
    case P.Span{n} <> t:
      Core.absurd({MS.matches(P.Span{n} <> t, Nil{}, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(oo))

def chain_compiles(m: Maybe<&2, P.Pattern>, chain: {S.chain_at(m) == True{} : Bool}) -> {S.compiles(m) == True{} : Bool}:
  match m:
    case None{}:
      Core.absurd({S.compiles(None{}) == True{} : Bool}, Core.false_true(chain))
    case Some{p}:
      {==}

def D() -> M.Options:
  M.Options{True{}, True{}}

# What the mount answers at the bare prefix path and at the prefix plus `/`.
def root_b(+raws: List<&2, String>, +b: List<&2, P.Segment>, chain: {S.chain_at(Some{P.Pattern{b}}) == True{} : Bool}, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk_pieces(Some{statics(raws)}, Some{b}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(Some{P.Pattern{b}}, "/", D()) : Maybe<&2, P.Params>}:
  match b:
    case P.Capture{+n, +c, True{}} <> +rest:
      +oo = chain
      %Equal.sym(List<&2, String>, String.split(String.join(raws, "/"), '/'), List.append(&2, String, raws, Nil{}), Equal.trans(List<&2, String>, String.split(String.join(raws, "/"), '/'), raws, List.append(&2, String, raws, Nil{}), split_join_all(raws, facts), Equal.sym(List<&2, String>, List.append(&2, String, raws, Nil{}), raws, app_nil(raws)))) : {S.walk(statics(raws), _, True{}, P.Capture{n, c, True{}} <> rest) == S.member_alone(Some{P.Pattern{P.Capture{n, c, True{}} <> rest}}, "/", D()) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, S.walk(statics(raws), List.append(&2, String, raws, Nil{}), True{}, P.Capture{n, c, True{}} <> rest), S.segments_with(True{}, P.Capture{n, c, True{}} <> rest, Nil{}), walk_literal(raws, Nil{}, True{}, P.Capture{n, c, True{}} <> rest)) : {_ == S.member_alone(Some{P.Pattern{P.Capture{n, c, True{}} <> rest}}, "/", D()) : Maybe<&2, P.Params>}
      %Equal.sym(Bool, MS.only_optional(rest), True{}, oo) : {MS.matches(rest, Nil{}, Nil{}) == MS.prefix_hit(_) : Maybe<&2, P.Params>}
      opt_nil(rest, oo)
    case Nil{}:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{Nil{}}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(Some{P.Pattern{Nil{}}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Capture{n, c, False{}} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.Capture{n, c, False{}} <> rest}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(Some{P.Pattern{P.Capture{n, c, False{}} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Static{x} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.Static{x} <> rest}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(Some{P.Pattern{P.Static{x} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Wildcard{n} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.Wildcard{n} <> rest}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(Some{P.Pattern{P.Wildcard{n} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.InteriorWildcard{} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.InteriorWildcard{} <> rest}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(Some{P.Pattern{P.InteriorWildcard{} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.PrefixWildcard{x} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.PrefixWildcard{x} <> rest}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(Some{P.Pattern{P.PrefixWildcard{x} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Span{n} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.Span{n} <> rest}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(Some{P.Pattern{P.Span{n} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))

def root_b2(+raws: List<&2, String>, +b: List<&2, P.Segment>, chain: {S.chain_at(Some{P.Pattern{b}}) == True{} : Bool}, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk_pieces(Some{statics(raws)}, Some{b}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}:
  match b:
    case P.Capture{+n, +c, True{}} <> +rest:
      %Equal.sym(List<&2, String>, String.split(String.join(raws, "/") ++ SCon{'/', SNil{}}, '/'), List.append(&2, String, raws, [""]), lead_split(raws, SNil{}, facts)) : {S.walk(statics(raws), _, True{}, P.Capture{n, c, True{}} <> rest) == None{} : Maybe<&2, P.Params>}
      walk_literal(raws, [""], True{}, P.Capture{n, c, True{}} <> rest)
    case Nil{}:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{Nil{}}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Capture{n, c, False{}} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.Capture{n, c, False{}} <> rest}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Static{x} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.Static{x} <> rest}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Wildcard{n} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.Wildcard{n} <> rest}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.InteriorWildcard{} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.InteriorWildcard{} <> rest}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.PrefixWildcard{x} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.PrefixWildcard{x} <> rest}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Span{n} <> rest:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{P.Span{n} <> rest}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))

def root_ok(+raws: List<&2, String>, +b: List<&2, P.Segment>, ok: Bool, chain: {S.chain_at(CS.accept(ok, b)) == True{} : Bool}, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk_pieces(Some{statics(raws)}, Some{b}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(CS.accept(ok, b), "/", D()) : Maybe<&2, P.Params>}:
  match ok:
    case False{}:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{b}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(CS.accept(False{}, b), "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case True{}:
      root_b(raws, b, chain, facts)

def root_ok2(+raws: List<&2, String>, +b: List<&2, P.Segment>, ok: Bool, chain: {S.chain_at(CS.accept(ok, b)) == True{} : Bool}, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk_pieces(Some{statics(raws)}, Some{b}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}:
  match ok:
    case False{}:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{b}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case True{}:
      root_b2(raws, b, chain, facts)

def root_pieces(+raws: List<&2, String>, mp: Maybe<&2, List<&2, P.Segment>>, chain: {S.chain_at(CS.checked(mp)) == True{} : Bool}, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk_pieces(Some{statics(raws)}, mp, "/" ++ String.join(raws, "/"), D()) == S.member_alone(CS.checked(mp), "/", D()) : Maybe<&2, P.Params>}:
  match mp:
    case None{}:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, None{}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(CS.checked(None{}), "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case Some{+b}:
      root_ok(raws, b, CS.rules(b, Nil{}) && CS.spans(b), chain, facts)

def root_pieces2(+raws: List<&2, String>, mp: Maybe<&2, List<&2, P.Segment>>, chain: {S.chain_at(CS.checked(mp)) == True{} : Bool}, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk_pieces(Some{statics(raws)}, mp, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}:
  match mp:
    case None{}:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, None{}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case Some{+b}:
      root_ok2(raws, b, CS.rules(b, Nil{}) && CS.spans(b), chain, facts)

def root1_at(at: S.Place, +member: String, adm: {S.admissible_at(at, member) == True{} : Bool}, lit: {S.literal_at(at) == True{} : Bool},
    chain: {S.chain_at(CS.compile(member)) == True{} : Bool}, facts: MJ.UnderFacts(at)) ->
    {S.mounted_at(at, member, S.lead_at(at), D()) == S.member_alone(CS.compile(member), "/", D()) : Maybe<&2, P.Params>}:
  match at:
    case S.AtRoot{}:
      Core.absurd({S.mounted_at(S.AtRoot{}, member, S.lead_at(S.AtRoot{}), D()) == S.member_alone(CS.compile(member), "/", D()) : Maybe<&2, P.Params>}, Core.false_true(lit))
    case S.Unplaced{}:
      Core.absurd({S.mounted_at(S.Unplaced{}, member, S.lead_at(S.Unplaced{}), D()) == S.member_alone(CS.compile(member), "/", D()) : Maybe<&2, P.Params>}, Core.false_true(lit))
    case S.Under{+raws}:
      +cm = compile_member(member, placed_from(S.prefix_pieces(raws), S.member_text(member), adm))
      +mp = S.member_pieces(S.member_text(member))
      +chain2 = Equal.trans(Bool, S.chain_at(CS.checked(mp)), S.chain_at(CS.compile(member)), True{}, Equal.cong(Maybe<&2, P.Pattern>, Bool, m => S.chain_at(m), CS.checked(mp), CS.compile(member), Equal.sym(Maybe<&2, P.Pattern>, CS.compile(member), CS.checked(mp), cm)), chain)
      %Equal.sym(Maybe<&2, List<&2, P.Segment>>, S.prefix_pieces(raws), Some{statics(raws)}, pieces_plain(raws, lit)) : {S.walk_pieces(_, mp, "/" ++ String.join(raws, "/"), D()) == S.member_alone(CS.compile(member), "/", D()) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Pattern>, CS.compile(member), CS.checked(mp), cm) : {S.walk_pieces(Some{statics(raws)}, mp, "/" ++ String.join(raws, "/"), D()) == S.member_alone(_, "/", D()) : Maybe<&2, P.Params>}
      root_pieces(raws, mp, chain2, facts)

def root2_at(at: S.Place, +member: String, adm: {S.admissible_at(at, member) == True{} : Bool}, lit: {S.literal_at(at) == True{} : Bool},
    chain: {S.chain_at(CS.compile(member)) == True{} : Bool}, facts: MJ.UnderFacts(at)) ->
    {S.mounted_at(at, member, S.lead_at(at) ++ "/", D()) == None{} : Maybe<&2, P.Params>}:
  match at:
    case S.AtRoot{}:
      Core.absurd({S.mounted_at(S.AtRoot{}, member, S.lead_at(S.AtRoot{}) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(lit))
    case S.Unplaced{}:
      Core.absurd({S.mounted_at(S.Unplaced{}, member, S.lead_at(S.Unplaced{}) ++ "/", D()) == None{} : Maybe<&2, P.Params>}, Core.false_true(lit))
    case S.Under{+raws}:
      +cm = compile_member(member, placed_from(S.prefix_pieces(raws), S.member_text(member), adm))
      +mp = S.member_pieces(S.member_text(member))
      +chain2 = Equal.trans(Bool, S.chain_at(CS.checked(mp)), S.chain_at(CS.compile(member)), True{}, Equal.cong(Maybe<&2, P.Pattern>, Bool, m => S.chain_at(m), CS.checked(mp), CS.compile(member), Equal.sym(Maybe<&2, P.Pattern>, CS.compile(member), CS.checked(mp), cm)), chain)
      %Equal.sym(Maybe<&2, List<&2, P.Segment>>, S.prefix_pieces(raws), Some{statics(raws)}, pieces_plain(raws, lit)) : {S.walk_pieces(_, mp, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}
      root_pieces2(raws, mp, chain2, facts)

def L.mount_literal_root(prefix, member, admissible, literal, chain):
  +adm = admissible
  +lit = literal
  +ch = chain
  (Equal.trans(Maybe<&2, P.Params>, L.public_match(prefix, member, S.lead(prefix), D()), S.mounted(prefix, member, S.lead(prefix), D()), L.member_match(member, "/", D()), L.mount_match_spec(prefix, member, S.lead(prefix), D(), adm), Equal.trans(Maybe<&2, P.Params>, S.mounted(prefix, member, S.lead(prefix), D()), S.member_alone(CS.compile(member), "/", D()), L.member_match(member, "/", D()), root1_at(S.place(prefix), member, adm, lit, ch, MJ.under_facts(prefix)), Equal.sym(Maybe<&2, P.Params>, L.member_match(member, "/", D()), S.member_alone(CS.compile(member), "/", D()), member_view(member, "/", D(), chain_compiles(CS.compile(member), ch))))), Equal.trans(Maybe<&2, P.Params>, L.public_match(prefix, member, S.lead(prefix) ++ "/", D()), S.mounted(prefix, member, S.lead(prefix) ++ "/", D()), None{}, L.mount_match_spec(prefix, member, S.lead(prefix) ++ "/", D(), adm), root2_at(S.place(prefix), member, adm, lit, ch, MJ.under_facts(prefix))))

# ---- The converse: nowhere else ----

def none_params(m: Maybe<&2, P.Params>) -> Type:
  match m:
    case None{}:
      Unit
    case Some{x}:
      Empty

def none_some_p(+ps: P.Params, e: {None{} == Some{ps} : Maybe<&2, P.Params>}) -> Empty:
  %e : none_params(_)
  Unit{}

def str_app_nil(+s: String) -> {s ++ "" == s : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      Equal.cong(String, String, z => SCon{h, z}, t ++ "", t, str_app_nil(t))

def str_assoc(+a: String, +b: String, +c: String) -> {(a ++ b) ++ c == a ++ (b ++ c) : String}:
  match a:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      Equal.cong(String, String, z => SCon{h, z}, (t ++ b) ++ c, t ++ (b ++ c), str_assoc(t, b, c))

def go_cons(+ss: List<&2, String>, +h: Char, +s1: String) -> {String.join.go(ss, SCon{h, s1}, "/") == SCon{h, String.join.go(ss, s1, "/")} : String}:
  match ss:
    case Nil{}:
      {==}
    case s2 <> st:
      {==}

def slash_char(+x: U32, e: {Char.is_eq(Chr{x}, '/') == True{} : Bool}) -> {Chr{x} == '/' : Char}:
  Equal.cong(U32, Char, y => Chr{y}, x, 47, Eq.u32_cmp_sound(x, 47, e))

def js_step(+x: U32, +u: String, +r: List<&2, String>, c: Bool, e: {Char.is_eq(Chr{x}, '/') == c : Bool}, ih: {String.join(r, "/") == u : String}, ne: {r == Nil{} : List<&2, String>} -> Empty) ->
    {String.join(String.split.fin(Chr{x}, r, c), "/") == SCon{Chr{x}, u} : String}:
  match r:
    case Nil{}:
      Core.absurd({String.join(String.split.fin(Chr{x}, Nil{}, c), "/") == SCon{Chr{x}, u} : String}, ne({==}))
    case +s1 <> +ss:
      match c:
        case True{}:
          %Equal.sym(String, String.join.go(ss, s1, "/"), u, ih) : {SCon{'/', _} == SCon{Chr{x}, u} : String}
          %Equal.sym(Char, Chr{x}, '/', slash_char(x, e)) : {SCon{'/', u} == SCon{_, u} : String}
          {==}
        case False{}:
          %Equal.sym(String, String.join.go(ss, SCon{Chr{x}, s1}, "/"), SCon{Chr{x}, String.join.go(ss, s1, "/")}, go_cons(ss, Chr{x}, s1)) : {_ == SCon{Chr{x}, u} : String}
          Equal.cong(String, String, z => SCon{Chr{x}, z}, String.join.go(ss, s1, "/"), u, ih)

# Joining the segments of a split recovers the text.
def join_split(+t: String) -> {String.join(String.split(t, '/'), "/") == t : String}:
  match t:
    case SNil{}:
      {==}
    case SCon{Chr{+x}, +u}:
      js_step(x, u, String.split(u, '/'), Char.is_eq(Chr{x}, '/'), {==}, join_split(u), e => MO.split_ne(u, e))

def join_app(+t: List<&2, String>, +h: String, +y: String, +yt: List<&2, String>) ->
    {String.join.go(List.append(&2, String, t, y <> yt), h, "/") == String.join.go(t, h, "/") ++ ("/" ++ String.join.go(yt, y, "/")) : String}:
  match t:
    case Nil{}:
      {==}
    case +t1 <> +tt:
      %Equal.sym(String, String.join.go(List.append(&2, String, tt, y <> yt), t1, "/"), String.join.go(tt, t1, "/") ++ ("/" ++ String.join.go(yt, y, "/")), join_app(tt, t1, y, yt)) : {h ++ ("/" ++ _) == String.join.go(t1 <> tt, h, "/") ++ ("/" ++ String.join.go(yt, y, "/")) : String}
      Equal.sym(String, (h ++ ("/" ++ String.join.go(tt, t1, "/"))) ++ ("/" ++ String.join.go(yt, y, "/")), h ++ (("/" ++ String.join.go(tt, t1, "/")) ++ ("/" ++ String.join.go(yt, y, "/"))), str_assoc(h, "/" ++ String.join.go(tt, t1, "/"), "/" ++ String.join.go(yt, y, "/")))

def Rest(+raws: List<&2, String>, +ys: List<&2, String>) -> Type:
  &rest: String -> ({String.join(List.append(&2, String, raws, ys), "/") == String.join(raws, "/") ++ rest : String} & {S.boundary(rest) == True{} : Bool})

def conv_rest(+raws: List<&2, String>, +ys: List<&2, String>, facts: MJ.UnderFacts(S.Under{raws})) -> Rest(raws, ys):
  match raws ys:
    case +rs Nil{}:
      ("", (Equal.trans(String, String.join(List.append(&2, String, rs, Nil{}), "/"), String.join(rs, "/"), String.join(rs, "/") ++ "", Equal.cong(List<&2, String>, String, z => String.join(z, "/"), List.append(&2, String, rs, Nil{}), rs, app_nil(rs)), Equal.sym(String, String.join(rs, "/") ++ "", String.join(rs, "/"), str_app_nil(String.join(rs, "/")))), {==}))
    case Nil{} +y <> +yt:
      Core.absurd(Rest(Nil{}, y <> yt), Core.false_true(facts))
    case +h <> +t +y <> +yt:
      ("/" ++ String.join(y <> yt, "/"), (join_app(t, h, y, yt), {==}))

def Inv(+raws: List<&2, String>, +xs: List<&2, String>) -> Type:
  &ys: List<&2, String> -> {xs == List.append(&2, String, raws, ys) : List<&2, String>}

def inv_rest(+raw: String, +x: String, +w: Maybe<&2, P.Params>, +ps: P.Params, q: Bool, eq: {String.eq(raw, x) == q : Bool}, e: {MS.same_text(String.eq(raw, x), w) == Some{ps} : Maybe<&2, P.Params>}) -> {w == Some{ps} : Maybe<&2, P.Params>}:
  match q:
    case True{}:
      Equal.trans(Maybe<&2, P.Params>, w, MS.same_text(String.eq(raw, x), w), Some{ps}, Equal.cong(Bool, Maybe<&2, P.Params>, z => MS.same_text(z, w), True{}, String.eq(raw, x), Equal.sym(Bool, String.eq(raw, x), True{}, eq)), e)
    case False{}:
      Core.absurd({w == Some{ps} : Maybe<&2, P.Params>}, none_some_p(ps, Equal.trans(Maybe<&2, P.Params>, None{}, MS.same_text(String.eq(raw, x), w), Some{ps}, Equal.cong(Bool, Maybe<&2, P.Params>, z => MS.same_text(z, w), False{}, String.eq(raw, x), Equal.sym(Bool, String.eq(raw, x), False{}, eq)), e)))

def inv_same(+raw: String, +x: String, +w: Maybe<&2, P.Params>, +ps: P.Params, q: Bool, eq: {String.eq(raw, x) == q : Bool}, e: {MS.same_text(String.eq(raw, x), w) == Some{ps} : Maybe<&2, P.Params>}) -> {raw == x : String}:
  match q:
    case True{}:
      Eq.string_eq_sound(raw, x, eq)
    case False{}:
      Core.absurd({raw == x : String}, none_some_p(ps, Equal.trans(Maybe<&2, P.Params>, None{}, MS.same_text(String.eq(raw, x), w), Some{ps}, Equal.cong(Bool, Maybe<&2, P.Params>, z => MS.same_text(z, w), False{}, String.eq(raw, x), Equal.sym(Bool, String.eq(raw, x), False{}, eq)), e)))

def inv_pack(+raw: String, +rt: List<&2, String>, +x: String, +xt: List<&2, String>, same: {raw == x : String}, ih: Inv(rt, xt)) -> Inv(raw <> rt, x <> xt):
  (+ys, h) = ih
  (ys, Equal.trans(List<&2, String>, x <> xt, raw <> xt, raw <> List.append(&2, String, rt, ys), Equal.cong(String, List<&2, String>, z => z <> xt, x, raw, Equal.sym(String, raw, x, same)), Equal.cong(List<&2, String>, List<&2, String>, z => raw <> z, xt, List.append(&2, String, rt, ys), h)))

# A literal walk that answers consumed exactly the prefix's segments first.
def walk_inv(+raws: List<&2, String>, +xs: List<&2, String>, +b: List<&2, P.Segment>, +ps: P.Params, +e: {S.walk(statics(raws), xs, True{}, b) == Some{ps} : Maybe<&2, P.Params>}) -> Inv(raws, xs):
  match raws xs:
    case Nil{} ys:
      (ys, {==})
    case +raw <> +rt Nil{}:
      Core.absurd(Inv(raw <> rt, Nil{}), none_some_p(ps, e))
    case +raw <> +rt +x <> +xt:
      inv_pack(raw, rt, x, xt, inv_same(raw, x, S.walk(statics(rt), xt, True{}, b), ps, String.eq(raw, x), {==}, e), walk_inv(rt, xt, b, ps, inv_rest(raw, x, S.walk(statics(rt), xt, True{}, b), ps, String.eq(raw, x), {==}, e)))

def Conv(+path: String, +lead: String) -> Type:
  &rest: String -> ({path == lead ++ rest : String} & {S.boundary(rest) == True{} : Bool})

def conv_fin2(+raws: List<&2, String>, +t: String, +path: String, +ys: List<&2, String>, eqpath: {path == SCon{'/', t} : String}, h1: {String.split(t, '/') == List.append(&2, String, raws, ys) : List<&2, String>}, cr: Rest(raws, ys)) ->
    Conv(path, "/" ++ String.join(raws, "/")):
  (+rest, pr) = cr
  (h2, h3) = pr
  (rest, (Equal.trans(String, path, SCon{'/', t}, SCon{'/', String.join(raws, "/") ++ rest}, eqpath, Equal.cong(String, String, z => SCon{'/', z}, t, String.join(raws, "/") ++ rest, Equal.trans(String, t, String.join(String.split(t, '/'), "/"), String.join(raws, "/") ++ rest, Equal.sym(String, String.join(String.split(t, '/'), "/"), t, join_split(t)), Equal.trans(String, String.join(String.split(t, '/'), "/"), String.join(List.append(&2, String, raws, ys), "/"), String.join(raws, "/") ++ rest, Equal.cong(List<&2, String>, String, z => String.join(z, "/"), String.split(t, '/'), List.append(&2, String, raws, ys), h1), h2)))), h3))

def conv_fin(+raws: List<&2, String>, +t: String, +path: String, eqpath: {path == SCon{'/', t} : String}, inv: Inv(raws, String.split(t, '/')), facts: MJ.UnderFacts(S.Under{raws})) ->
    Conv(path, "/" ++ String.join(raws, "/")):
  (+ys, h1) = inv
  conv_fin2(raws, t, path, ys, eqpath, h1, conv_rest(raws, ys, facts))

def conv_tail(+raws: List<&2, String>, +b: List<&2, P.Segment>, m: Maybe<&2, String>, +path: String, e: {S.slash_tail(path) == m : Maybe<&2, String>}, +ps: P.Params,
    facts: MJ.UnderFacts(S.Under{raws}), ms: {S.walk_at(m, statics(raws), b, D()) == Some{ps} : Maybe<&2, P.Params>}) ->
    Conv(path, "/" ++ String.join(raws, "/")):
  match m:
    case None{}:
      Core.absurd(Conv(path, "/" ++ String.join(raws, "/")), none_some_p(ps, ms))
    case Some{+t}:
      conv_fin(raws, t, path, MJ.tail_inv(path, t, e), walk_inv(raws, String.split(t, '/'), b, ps, ms), facts)

def conv_pieces(+raws: List<&2, String>, mp: Maybe<&2, List<&2, P.Segment>>, +path: String, +ps: P.Params, facts: MJ.UnderFacts(S.Under{raws}),
    ms: {S.walk_pieces(Some{statics(raws)}, mp, path, D()) == Some{ps} : Maybe<&2, P.Params>}) -> Conv(path, "/" ++ String.join(raws, "/")):
  match mp:
    case None{}:
      Core.absurd(Conv(path, "/" ++ String.join(raws, "/")), none_some_p(ps, ms))
    case Some{+b}:
      conv_tail(raws, b, S.slash_tail(path), path, {==}, ps, facts, ms)

def conv_at(at: S.Place, +member: String, +path: String, +ps: P.Params, lit: {S.literal_at(at) == True{} : Bool}, facts: MJ.UnderFacts(at),
    ms: {S.mounted_at(at, member, path, D()) == Some{ps} : Maybe<&2, P.Params>}) -> Conv(path, S.lead_at(at)):
  match at:
    case S.AtRoot{}:
      Core.absurd(Conv(path, S.lead_at(S.AtRoot{})), Core.false_true(lit))
    case S.Unplaced{}:
      Core.absurd(Conv(path, S.lead_at(S.Unplaced{})), Core.false_true(lit))
    case S.Under{+raws}:
      +mp = S.member_pieces(S.member_text(member))
      conv_pieces(raws, mp, path, ps, facts, Equal.trans(Maybe<&2, P.Params>, S.walk_pieces(Some{statics(raws)}, mp, path, D()), S.walk_pieces(S.prefix_pieces(raws), mp, path, D()), Some{ps}, Equal.cong(Maybe<&2, List<&2, P.Segment>>, Maybe<&2, P.Params>, z => S.walk_pieces(z, mp, path, D()), Some{statics(raws)}, S.prefix_pieces(raws), Equal.sym(Maybe<&2, List<&2, P.Segment>>, S.prefix_pieces(raws), Some{statics(raws)}, pieces_plain(raws, lit))), ms))

def L.mount_literal_converse(prefix, member, path, ps, admissible, literal, hit):
  +adm = admissible
  conv_at(S.place(prefix), member, path, ps, literal, MJ.under_facts(prefix), Equal.trans(Maybe<&2, P.Params>, S.mounted(prefix, member, path, D()), L.public_match(prefix, member, path, D()), Some{ps}, Equal.sym(Maybe<&2, P.Params>, L.public_match(prefix, member, path, D()), S.mounted(prefix, member, path, D()), L.mount_match_spec(prefix, member, path, D(), adm)), hit))


# ---- Examples ----

def L.mount_admissible_examples():
  {==}

def L.mount_spec_examples():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def L.mount_counterexamples():
  ({==}, ({==}, ({==}, ({==}, {==}))))
