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

def placed_from(pp: Maybe<&2, List<&2, P.Segment>>, m: Maybe<&2, String>, adm: {S.kept_and(pp, S.compiles(S.joined(pp, S.member_pieces(m)))) == True{} : Bool}) ->
    {S.compiles_text(m) == True{} : Bool}:
  match pp m:
    case None{} y:
      Core.absurd({S.compiles_text(y) == True{} : Bool}, Core.false_true(adm))
    case Some{+a} None{}:
      Core.absurd({S.compiles_text(None{}) == True{} : Bool}, Core.false_true(Core.and_right(S.ends_solid(a, False{}), False{}, adm)))
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

def compiles_from(pp: Maybe<&2, List<&2, P.Segment>>, +mp: Maybe<&2, List<&2, P.Segment>>, adm: {S.kept_and(pp, S.compiles(S.joined(pp, mp))) == True{} : Bool}) ->
    {S.compiles(S.joined(pp, mp)) == True{} : Bool}:
  match pp:
    case None{}:
      Core.absurd({S.compiles(S.joined(None{}, mp)) == True{} : Bool}, Core.false_true(adm))
    case Some{+a}:
      Core.and_right(S.ends_solid(a, False{}), S.compiles(S.joined(Some{a}, mp)), adm)

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
    {S.walk(statics(raws), List.append(&2, String, raws, ys), sens, mb, Nil{}) == S.segments_with(sens, mb, ys) : Maybe<&2, P.Params>}:
  match raws:
    case Nil{}:
      Equal.sym(Maybe<&2, P.Params>, S.segments_with(sens, mb, ys), S.segments_at(sens, mb, ys, Nil{}), MD.with_at(sens, mb, ys))
    case +raw <> +t:
      %Equal.sym(Bool, S.text_same(sens, raw, raw), True{}, same_refl(sens, raw)) : {MS.same_text(_, S.walk(statics(t), List.append(&2, String, t, ys), sens, mb, Nil{})) == S.segments_with(sens, mb, ys) : Maybe<&2, P.Params>}
      walk_literal(t, ys, sens, mb)

def static_root(+xs: List<&2, String>, +r: String, +rest: List<&2, P.Segment>) -> {S.root_hit(xs, P.Static{r} <> rest) == None{} : Maybe<&2, P.Params>}:
  match xs:
    case Nil{}:
      {==}
    case SCon{a, b} <> t:
      {==}
    case SNil{} <> y <> z:
      {==}
    case SNil{} <> Nil{}:
      {==}

# Under a literal prefix the assembled root rule never fires.
def rooted_cons(+sens: Bool, +r: String, +rt: List<&2, String>, +xs: List<&2, String>, +mb: List<&2, P.Segment>) ->
    {S.rooted(sens, statics(r <> rt), xs, mb) == S.walk(statics(r <> rt), xs, sens, mb, Nil{}) : Maybe<&2, P.Params>}:
  %Equal.sym(Maybe<&2, P.Params>, S.root_hit(xs, P.Static{r} <> List.append(&2, P.Segment, statics(rt), mb)), None{}, static_root(xs, r, List.append(&2, P.Segment, statics(rt), mb))) : {MS.or_else(S.walk(statics(r <> rt), xs, sens, mb, Nil{}), u => _) == S.walk(statics(r <> rt), xs, sens, mb, Nil{}) : Maybe<&2, P.Params>}
  MSP.or_else_none(S.walk(statics(r <> rt), xs, sens, mb, Nil{}))

def rooted_static(+sens: Bool, +raws: List<&2, String>, +xs: List<&2, String>, +mb: List<&2, P.Segment>, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.rooted(sens, statics(raws), xs, mb) == S.walk(statics(raws), xs, sens, mb, Nil{}) : Maybe<&2, P.Params>}:
  match raws:
    case Nil{}:
      Core.absurd({S.rooted(sens, statics(Nil{}), xs, mb) == S.walk(statics(Nil{}), xs, sens, mb, Nil{}) : Maybe<&2, P.Params>}, Core.false_true(facts))
    case +r <> +rt:
      rooted_cons(sens, r, rt, xs, mb)

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

def suffix_walk(+raws: List<&2, String>, +b: List<&2, P.Segment>, +r: String, +sens: Bool,
    ord: {String.eq(SCon{'/', r}, "/") && S.chain_at(Some{P.Pattern{b}}) == False{} : Bool}, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk(statics(raws), String.split(String.join(raws, "/") ++ SCon{'/', r}, '/'), sens, b, Nil{}) == S.member_alone(Some{P.Pattern{b}}, "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}:
  %Equal.sym(List<&2, String>, String.split(String.join(raws, "/") ++ SCon{'/', r}, '/'), List.append(&2, String, raws, String.split(r, '/')), lead_split(raws, r, facts)) : {S.walk(statics(raws), _, sens, b, Nil{}) == S.member_alone(Some{P.Pattern{b}}, "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}
  %Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(r, '/'), b), None{}, root_ordinary(r, b, ord)) : {S.walk(statics(raws), List.append(&2, String, raws, String.split(r, '/')), sens, b, Nil{}) == MS.or_else(S.segments_with(sens, b, String.split(r, '/')), u => _) : Maybe<&2, P.Params>}
  Equal.trans(Maybe<&2, P.Params>, S.walk(statics(raws), List.append(&2, String, raws, String.split(r, '/')), sens, b, Nil{}), S.segments_with(sens, b, String.split(r, '/')), MS.or_else(S.segments_with(sens, b, String.split(r, '/')), u => None{}), walk_literal(raws, String.split(r, '/'), sens, b), Equal.sym(Maybe<&2, P.Params>, MS.or_else(S.segments_with(sens, b, String.split(r, '/')), u => None{}), S.segments_with(sens, b, String.split(r, '/')), MSP.or_else_none(S.segments_with(sens, b, String.split(r, '/')))))

def suffix_ok(+raws: List<&2, String>, +b: List<&2, P.Segment>, ok: Bool, +r: String, +sens: Bool,
    alone: {S.compiles(CS.accept(ok, b)) == True{} : Bool}, ord: {String.eq(SCon{'/', r}, "/") && S.chain_at(CS.accept(ok, b)) == False{} : Bool},
    +facts: {Core.clean_segments(raws) && Bool.not(List.is_empty(&2, String, raws)) == True{} : Bool}) ->
    {S.walk_pieces(Some{statics(raws)}, Some{b}, ("/" ++ String.join(raws, "/")) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.accept(ok, b), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}:
  match ok:
    case False{}:
      Core.absurd({S.walk_pieces(Some{statics(raws)}, Some{b}, ("/" ++ String.join(raws, "/")) ++ ("/" ++ r), M.Options{True{}, sens}) == S.member_alone(CS.accept(False{}, b), "/" ++ r, M.Options{True{}, sens}) : Maybe<&2, P.Params>}, Core.false_true(alone))
    case True{}:
      Equal.trans(Maybe<&2, P.Params>, S.rooted(sens, statics(raws), String.split(String.join(raws, "/") ++ SCon{'/', r}, '/'), b), S.walk(statics(raws), String.split(String.join(raws, "/") ++ SCon{'/', r}, '/'), sens, b, Nil{}), S.member_alone(Some{P.Pattern{b}}, "/" ++ r, M.Options{True{}, sens}), rooted_static(sens, raws, String.split(String.join(raws, "/") ++ SCon{'/', r}, '/'), b, facts), suffix_walk(raws, b, r, sens, ord, facts))

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
def root_bw(+raws: List<&2, String>, +b: List<&2, P.Segment>, chain: {S.chain_at(Some{P.Pattern{b}}) == True{} : Bool}, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk(statics(raws), String.split(String.join(raws, "/"), '/'), True{}, b, Nil{}) == S.member_alone(Some{P.Pattern{b}}, "/", D()) : Maybe<&2, P.Params>}:
  match b:
    case P.Capture{+n, +c, True{}} <> +rest:
      +oo = chain
      %Equal.sym(List<&2, String>, String.split(String.join(raws, "/"), '/'), List.append(&2, String, raws, Nil{}), Equal.trans(List<&2, String>, String.split(String.join(raws, "/"), '/'), raws, List.append(&2, String, raws, Nil{}), split_join_all(raws, facts), Equal.sym(List<&2, String>, List.append(&2, String, raws, Nil{}), raws, app_nil(raws)))) : {S.walk(statics(raws), _, True{}, P.Capture{n, c, True{}} <> rest, Nil{}) == S.member_alone(Some{P.Pattern{P.Capture{n, c, True{}} <> rest}}, "/", D()) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, S.walk(statics(raws), List.append(&2, String, raws, Nil{}), True{}, P.Capture{n, c, True{}} <> rest, Nil{}), S.segments_with(True{}, P.Capture{n, c, True{}} <> rest, Nil{}), walk_literal(raws, Nil{}, True{}, P.Capture{n, c, True{}} <> rest)) : {_ == S.member_alone(Some{P.Pattern{P.Capture{n, c, True{}} <> rest}}, "/", D()) : Maybe<&2, P.Params>}
      %Equal.sym(Bool, MS.only_optional(rest), True{}, oo) : {MS.matches(rest, Nil{}, Nil{}) == MS.prefix_hit(_) : Maybe<&2, P.Params>}
      opt_nil(rest, oo)
    case Nil{}:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/"), '/'), True{}, Nil{}, Nil{}) == S.member_alone(Some{P.Pattern{Nil{}}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Capture{n, c, False{}} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/"), '/'), True{}, P.Capture{n, c, False{}} <> rest, Nil{}) == S.member_alone(Some{P.Pattern{P.Capture{n, c, False{}} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Static{x} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/"), '/'), True{}, P.Static{x} <> rest, Nil{}) == S.member_alone(Some{P.Pattern{P.Static{x} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Wildcard{n} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/"), '/'), True{}, P.Wildcard{n} <> rest, Nil{}) == S.member_alone(Some{P.Pattern{P.Wildcard{n} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.InteriorWildcard{} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/"), '/'), True{}, P.InteriorWildcard{} <> rest, Nil{}) == S.member_alone(Some{P.Pattern{P.InteriorWildcard{} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.PrefixWildcard{x} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/"), '/'), True{}, P.PrefixWildcard{x} <> rest, Nil{}) == S.member_alone(Some{P.Pattern{P.PrefixWildcard{x} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Span{n} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/"), '/'), True{}, P.Span{n} <> rest, Nil{}) == S.member_alone(Some{P.Pattern{P.Span{n} <> rest}}, "/", D()) : Maybe<&2, P.Params>}, Core.false_true(chain))

def root_bw2(+raws: List<&2, String>, +b: List<&2, P.Segment>, chain: {S.chain_at(Some{P.Pattern{b}}) == True{} : Bool}, facts: MJ.UnderFacts(S.Under{raws})) ->
    {S.walk(statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), True{}, b, Nil{}) == None{} : Maybe<&2, P.Params>}:
  match b:
    case P.Capture{+n, +c, True{}} <> +rest:
      %Equal.sym(List<&2, String>, String.split(String.join(raws, "/") ++ SCon{'/', SNil{}}, '/'), List.append(&2, String, raws, [""]), lead_split(raws, SNil{}, facts)) : {S.walk(statics(raws), _, True{}, P.Capture{n, c, True{}} <> rest, Nil{}) == None{} : Maybe<&2, P.Params>}
      walk_literal(raws, [""], True{}, P.Capture{n, c, True{}} <> rest)
    case Nil{}:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), True{}, Nil{}, Nil{}) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Capture{n, c, False{}} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), True{}, P.Capture{n, c, False{}} <> rest, Nil{}) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Static{x} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), True{}, P.Static{x} <> rest, Nil{}) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Wildcard{n} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), True{}, P.Wildcard{n} <> rest, Nil{}) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.InteriorWildcard{} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), True{}, P.InteriorWildcard{} <> rest, Nil{}) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.PrefixWildcard{x} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), True{}, P.PrefixWildcard{x} <> rest, Nil{}) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))
    case P.Span{n} <> rest:
      Core.absurd({S.walk(statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), True{}, P.Span{n} <> rest, Nil{}) == None{} : Maybe<&2, P.Params>}, Core.false_true(chain))

def root_b(+raws: List<&2, String>, +b: List<&2, P.Segment>, chain: {S.chain_at(Some{P.Pattern{b}}) == True{} : Bool}, +facts: {Core.clean_segments(raws) && Bool.not(List.is_empty(&2, String, raws)) == True{} : Bool}) ->
    {S.walk_pieces(Some{statics(raws)}, Some{b}, "/" ++ String.join(raws, "/"), D()) == S.member_alone(Some{P.Pattern{b}}, "/", D()) : Maybe<&2, P.Params>}:
  Equal.trans(Maybe<&2, P.Params>, S.rooted(True{}, statics(raws), String.split(String.join(raws, "/"), '/'), b), S.walk(statics(raws), String.split(String.join(raws, "/"), '/'), True{}, b, Nil{}), S.member_alone(Some{P.Pattern{b}}, "/", D()), rooted_static(True{}, raws, String.split(String.join(raws, "/"), '/'), b, facts), root_bw(raws, b, chain, facts))

def root_b2(+raws: List<&2, String>, +b: List<&2, P.Segment>, chain: {S.chain_at(Some{P.Pattern{b}}) == True{} : Bool}, +facts: {Core.clean_segments(raws) && Bool.not(List.is_empty(&2, String, raws)) == True{} : Bool}) ->
    {S.walk_pieces(Some{statics(raws)}, Some{b}, ("/" ++ String.join(raws, "/")) ++ "/", D()) == None{} : Maybe<&2, P.Params>}:
  Equal.trans(Maybe<&2, P.Params>, S.rooted(True{}, statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), b), S.walk(statics(raws), String.split(String.join(raws, "/") ++ "/", '/'), True{}, b, Nil{}), None{}, rooted_static(True{}, raws, String.split(String.join(raws, "/") ++ "/", '/'), b, facts), root_bw2(raws, b, chain, facts))

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

def Rest(+segs: List<&2, String>, +ys: List<&2, String>) -> Type:
  &rest: String -> ({String.join(List.append(&2, String, segs, ys), "/") == String.join(segs, "/") ++ rest : String} & {S.boundary(rest) == True{} : Bool})

def conv_rest(+h: String, +t: List<&2, String>, ys: List<&2, String>) -> Rest(h <> t, ys):
  match ys:
    case Nil{}:
      ("", (Equal.trans(String, String.join(List.append(&2, String, h <> t, Nil{}), "/"), String.join(h <> t, "/"), String.join(h <> t, "/") ++ "", Equal.cong(List<&2, String>, String, z => String.join(z, "/"), List.append(&2, String, h <> t, Nil{}), h <> t, app_nil(h <> t)), Equal.sym(String, String.join(h <> t, "/") ++ "", String.join(h <> t, "/"), str_app_nil(String.join(h <> t, "/")))), {==}))
    case +y <> +yt:
      ("/" ++ String.join(y <> yt, "/"), (join_app(t, h, y, yt), {==}))

# What a literal walk consumed: request segments matching the prefix's
# segments under the case option, then the rest.
type Took is Data:
  Took{segs: List<&2, String>, ys: List<&2, String>}

def took_segs(k: Took) -> List<&2, String>:
  match k:
    case Took{segs, ys}:
      segs

def took_ys(k: Took) -> List<&2, String>:
  match k:
    case Took{segs, ys}:
      ys

def Inv(+sens: Bool, +raws: List<&2, String>, +xs: List<&2, String>) -> Type:
  &k: Took -> ({xs == List.append(&2, String, took_segs(k), took_ys(k)) : List<&2, String>} & {S.same_segments(sens, raws, took_segs(k)) == True{} : Bool})

def inv_rest(+sens: Bool, +raw: String, +x: String, +w: Maybe<&2, P.Params>, +ps: P.Params, q: Bool, eq: {S.text_same(sens, raw, x) == q : Bool}, e: {MS.same_text(S.text_same(sens, raw, x), w) == Some{ps} : Maybe<&2, P.Params>}) -> {w == Some{ps} : Maybe<&2, P.Params>}:
  match q:
    case True{}:
      Equal.trans(Maybe<&2, P.Params>, w, MS.same_text(S.text_same(sens, raw, x), w), Some{ps}, Equal.cong(Bool, Maybe<&2, P.Params>, z => MS.same_text(z, w), True{}, S.text_same(sens, raw, x), Equal.sym(Bool, S.text_same(sens, raw, x), True{}, eq)), e)
    case False{}:
      Core.absurd({w == Some{ps} : Maybe<&2, P.Params>}, none_some_p(ps, Equal.trans(Maybe<&2, P.Params>, None{}, MS.same_text(S.text_same(sens, raw, x), w), Some{ps}, Equal.cong(Bool, Maybe<&2, P.Params>, z => MS.same_text(z, w), False{}, S.text_same(sens, raw, x), Equal.sym(Bool, S.text_same(sens, raw, x), False{}, eq)), e)))

def inv_same(+sens: Bool, +raw: String, +x: String, +w: Maybe<&2, P.Params>, +ps: P.Params, q: Bool, eq: {S.text_same(sens, raw, x) == q : Bool}, e: {MS.same_text(S.text_same(sens, raw, x), w) == Some{ps} : Maybe<&2, P.Params>}) -> {S.text_same(sens, raw, x) == True{} : Bool}:
  match q:
    case True{}:
      eq
    case False{}:
      Core.absurd({S.text_same(sens, raw, x) == True{} : Bool}, none_some_p(ps, Equal.trans(Maybe<&2, P.Params>, None{}, MS.same_text(S.text_same(sens, raw, x), w), Some{ps}, Equal.cong(Bool, Maybe<&2, P.Params>, z => MS.same_text(z, w), False{}, S.text_same(sens, raw, x), Equal.sym(Bool, S.text_same(sens, raw, x), False{}, eq)), e)))

def and_true(a: Bool, +b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  match a:
    case True{}:
      eb
    case False{}:
      Core.absurd({False{} && b == True{} : Bool}, Core.false_true(ea))

def inv_pack(+sens: Bool, +raw: String, +rt: List<&2, String>, +x: String, +xt: List<&2, String>, same: {S.text_same(sens, raw, x) == True{} : Bool}, ih: Inv(sens, rt, xt)) -> Inv(sens, raw <> rt, x <> xt):
  (+k, pr) = ih
  (h1, h2) = pr
  (Took{x <> took_segs(k), took_ys(k)}, (Equal.cong(List<&2, String>, List<&2, String>, z => x <> z, xt, List.append(&2, String, took_segs(k), took_ys(k)), h1), and_true(S.text_same(sens, raw, x), S.same_segments(sens, rt, took_segs(k)), same, h2)))

# A literal walk that answers consumed request segments matching the
# prefix's segments first.
def walk_inv(+sens: Bool, +raws: List<&2, String>, +xs: List<&2, String>, +b: List<&2, P.Segment>, +ps: P.Params, +e: {S.walk(statics(raws), xs, sens, b, Nil{}) == Some{ps} : Maybe<&2, P.Params>}) -> Inv(sens, raws, xs):
  match raws xs:
    case Nil{} ys:
      (Took{Nil{}, ys}, ({==}, {==}))
    case +raw <> +rt Nil{}:
      Core.absurd(Inv(sens, raw <> rt, Nil{}), none_some_p(ps, e))
    case +raw <> +rt +x <> +xt:
      inv_pack(sens, raw, rt, x, xt, inv_same(sens, raw, x, S.walk(statics(rt), xt, sens, b, Nil{}), ps, S.text_same(sens, raw, x), {==}, e), walk_inv(sens, rt, xt, b, ps, inv_rest(sens, raw, x, S.walk(statics(rt), xt, sens, b, Nil{}), ps, S.text_same(sens, raw, x), {==}, e)))

def eq_blank(+c: Char, +y: String) -> {String.eq(SCon{c, y}, "") == False{} : Bool}:
  match c:
    case Chr{x}:
      {==}

# A nonempty segment never equals the empty one, folded or not.
def blank_differs(sens: Bool, +c: Char, +y: String) -> {S.text_same(sens, SCon{c, y}, "") == False{} : Bool}:
  match sens:
    case True{}:
      eq_blank(c, y)
    case False{}:
      eq_blank(F.small(c, F.letters()), F.fold(y))

# Lenient mode keeps one empty segment for an otherwise empty path, which a
# plain first prefix segment never matches.
def lenient_walk(d: List<&2, String>, r: String, +sens: Bool, +rt: List<&2, String>, +b: List<&2, P.Segment>, +ps: P.Params, lit: {S.all_plain(r <> rt) == True{} : Bool},
    e: {S.walk(statics(r <> rt), S.root_text(d), sens, b, Nil{}) == Some{ps} : Maybe<&2, P.Params>}) -> {S.walk(statics(r <> rt), d, sens, b, Nil{}) == Some{ps} : Maybe<&2, P.Params>}:
  match d:
    case dh <> dt:
      e
    case Nil{}:
      match r:
        case SNil{}:
          Core.absurd({S.walk(statics(SNil{} <> rt), Nil{}, sens, b, Nil{}) == Some{ps} : Maybe<&2, P.Params>}, Core.false_true(lit))
        case SCon{+c, +y}:
          Core.absurd({S.walk(statics(SCon{c, y} <> rt), Nil{}, sens, b, Nil{}) == Some{ps} : Maybe<&2, P.Params>}, none_some_p(ps, Equal.trans(Maybe<&2, P.Params>, None{}, MS.same_text(S.text_same(sens, SCon{c, y}, ""), S.walk(statics(rt), Nil{}, sens, b, Nil{})), Some{ps}, Equal.cong(Bool, Maybe<&2, P.Params>, z => MS.same_text(z, S.walk(statics(rt), Nil{}, sens, b, Nil{})), False{}, S.text_same(sens, SCon{c, y}, ""), Equal.sym(Bool, S.text_same(sens, SCon{c, y}, ""), False{}, blank_differs(sens, c, y))), e)))

# ---- Lenient mode only drops trailing empty segments ----

def list_head(l: List<&2, String>, +d: String) -> String:
  match l:
    case Nil{}:
      d
    case h <> t:
      h

def list_tail(l: List<&2, String>) -> List<&2, String>:
  match l:
    case Nil{}:
      Nil{}
    case h <> t:
      t

def nil_type(l: List<&2, String>) -> Type:
  match l:
    case Nil{}:
      Unit
    case h <> t:
      Empty

def cons_nil(+w: String, +ws: List<&2, String>, e: {Nil{} == w <> ws : List<&2, String>}) -> Empty:
  %e : nil_type(_)
  Unit{}

def keep_z(+d: List<&2, String>, +z: String, +w: String, +ws: List<&2, String>, e: {S.keep_text(d, z) == w <> ws : List<&2, String>}) -> {z == w : String}:
  match d:
    case Nil{}:
      match z:
        case SNil{}:
          Core.absurd({SNil{} == w : String}, cons_nil(w, ws, e))
        case SCon{+x, +y}:
          Equal.cong(List<&2, String>, String, l => list_head(l, SCon{x, y}), [SCon{x, y}], w <> ws, e)
    case +r <> +t:
      Equal.cong(List<&2, String>, String, l => list_head(l, z), z <> r <> t, w <> ws, e)

def keep_d(+d: List<&2, String>, +z: String, +w: String, +ws: List<&2, String>, e: {S.keep_text(d, z) == w <> ws : List<&2, String>}) -> {d == ws : List<&2, String>}:
  match d:
    case Nil{}:
      match z:
        case SNil{}:
          Core.absurd({Nil{} == ws : List<&2, String>}, cons_nil(w, ws, e))
        case SCon{+x, +y}:
          Equal.cong(List<&2, String>, List<&2, String>, l => list_tail(l), [SCon{x, y}], w <> ws, e)
    case +r <> +t:
      Equal.cong(List<&2, String>, List<&2, String>, l => list_tail(l), z <> r <> t, w <> ws, e)

def Undrop(+zs: List<&2, String>, +s1: String, +st: List<&2, String>) -> Type:
  &ys2: List<&2, String> -> {zs == s1 <> List.append(&2, String, st, ys2) : List<&2, String>}

def undrop_pack(+z: String, +zt: List<&2, String>, +s1: String, +sh: String, +stt: List<&2, String>, hz: {z == s1 : String}, ih: Undrop(zt, sh, stt)) -> Undrop(z <> zt, s1, sh <> stt):
  (+ys2, h) = ih
  (ys2, Equal.trans(List<&2, String>, z <> zt, s1 <> zt, s1 <> sh <> List.append(&2, String, stt, ys2), Equal.cong(String, List<&2, String>, q => q <> zt, z, s1, hz), Equal.cong(List<&2, String>, List<&2, String>, l => s1 <> l, zt, sh <> List.append(&2, String, stt, ys2), h)))

# When the kept segments start with some segments, so do the raw ones.
def undrop(zs: List<&2, String>, +s1: String, st: List<&2, String>, +ys: List<&2, String>, +e: {S.drop_empty(zs) == s1 <> List.append(&2, String, st, ys) : List<&2, String>}) -> Undrop(zs, s1, st):
  match zs st:
    case Nil{} st2:
      Core.absurd(Undrop(Nil{}, s1, st2), cons_nil(s1, List.append(&2, String, st2, ys), e))
    case +z <> +zt Nil{}:
      (zt, Equal.cong(String, List<&2, String>, q => q <> zt, z, s1, keep_z(S.drop_empty(zt), z, s1, ys, e)))
    case +z <> +zt +sh <> +stt:
      undrop_pack(z, zt, s1, sh, stt, keep_z(S.drop_empty(zt), z, s1, sh <> List.append(&2, String, stt, ys), e), undrop(zt, sh, stt, ys, keep_d(S.drop_empty(zt), z, s1, sh <> List.append(&2, String, stt, ys), e)))

# ---- The converse under every option ----

def Conv(+path: String, at: S.Place, +sens: Bool) -> Type:
  &cut: S.Cut -> ({path == S.cut_path(cut) : String} & ({S.boundary(S.cut_rest(cut)) == True{} : Bool} & {S.prefix_same_at(at, sens, S.cut_segs(cut)) == True{} : Bool}))

def conv_fin2(+raws: List<&2, String>, +sens: Bool, +t: String, +path: String, +s1: String, +st: List<&2, String>, +ys2: List<&2, String>, eqpath: {path == SCon{'/', t} : String},
    hsplit: {String.split(t, '/') == s1 <> List.append(&2, String, st, ys2) : List<&2, String>}, same: {S.same_segments(sens, raws, s1 <> st) == True{} : Bool}, cr: Rest(s1 <> st, ys2)) ->
    Conv(path, S.Under{raws}, sens):
  (+rest, pr) = cr
  (h2, h3) = pr
  (S.Cut{s1 <> st, rest}, (Equal.trans(String, path, SCon{'/', t}, SCon{'/', String.join(s1 <> st, "/") ++ rest}, eqpath, Equal.cong(String, String, z => SCon{'/', z}, t, String.join(s1 <> st, "/") ++ rest, Equal.trans(String, t, String.join(String.split(t, '/'), "/"), String.join(s1 <> st, "/") ++ rest, Equal.sym(String, String.join(String.split(t, '/'), "/"), t, join_split(t)), Equal.trans(String, String.join(String.split(t, '/'), "/"), String.join(List.append(&2, String, s1 <> st, ys2), "/"), String.join(s1 <> st, "/") ++ rest, Equal.cong(List<&2, String>, String, z => String.join(z, "/"), String.split(t, '/'), List.append(&2, String, s1 <> st, ys2), hsplit), h2)))), (h3, same)))

def conv_fin(+raws: List<&2, String>, +sens: Bool, +t: String, +path: String, +s1: String, +st: List<&2, String>, +ys2: List<&2, String>, eqpath: {path == SCon{'/', t} : String},
    hsplit: {String.split(t, '/') == s1 <> List.append(&2, String, st, ys2) : List<&2, String>}, same: {S.same_segments(sens, raws, s1 <> st) == True{} : Bool}) ->
    Conv(path, S.Under{raws}, sens):
  conv_fin2(raws, sens, t, path, s1, st, ys2, eqpath, hsplit, same, conv_rest(s1, st, ys2))

def conv_took_s(+sens: Bool, +r: String, +rt: List<&2, String>, +t: String, +path: String, segs: List<&2, String>, +ys: List<&2, String>, eqpath: {path == SCon{'/', t} : String},
    h1: {String.split(t, '/') == List.append(&2, String, segs, ys) : List<&2, String>}, h2: {S.same_segments(sens, r <> rt, segs) == True{} : Bool}) -> Conv(path, S.Under{r <> rt}, sens):
  match segs:
    case Nil{}:
      Core.absurd(Conv(path, S.Under{r <> rt}, sens), Core.false_true(h2))
    case +s1 <> +st:
      conv_fin(r <> rt, sens, t, path, s1, st, ys, eqpath, h1, h2)

def conv_undrop(+sens: Bool, +r: String, +rt: List<&2, String>, +t: String, +path: String, +s1: String, +st: List<&2, String>, eqpath: {path == SCon{'/', t} : String},
    u: Undrop(String.split(t, '/'), s1, st), h2: {S.same_segments(sens, r <> rt, s1 <> st) == True{} : Bool}) -> Conv(path, S.Under{r <> rt}, sens):
  (+ys2, h) = u
  conv_fin(r <> rt, sens, t, path, s1, st, ys2, eqpath, h, h2)

def conv_took_l(+sens: Bool, +r: String, +rt: List<&2, String>, +t: String, +path: String, segs: List<&2, String>, +ys: List<&2, String>, eqpath: {path == SCon{'/', t} : String},
    h1: {S.drop_empty(String.split(t, '/')) == List.append(&2, String, segs, ys) : List<&2, String>}, h2: {S.same_segments(sens, r <> rt, segs) == True{} : Bool}) -> Conv(path, S.Under{r <> rt}, sens):
  match segs:
    case Nil{}:
      Core.absurd(Conv(path, S.Under{r <> rt}, sens), Core.false_true(h2))
    case +s1 <> +st:
      conv_undrop(sens, r, rt, t, path, s1, st, eqpath, undrop(String.split(t, '/'), s1, st, ys, h1), h2)

def conv_strict(+sens: Bool, +r: String, +rt: List<&2, String>, +t: String, +path: String, eqpath: {path == SCon{'/', t} : String}, inv: Inv(sens, r <> rt, String.split(t, '/'))) -> Conv(path, S.Under{r <> rt}, sens):
  (+k, pr) = inv
  (h1, h2) = pr
  conv_took_s(sens, r, rt, t, path, took_segs(k), took_ys(k), eqpath, h1, h2)

def conv_lenient(+sens: Bool, +r: String, +rt: List<&2, String>, +t: String, +path: String, eqpath: {path == SCon{'/', t} : String}, inv: Inv(sens, r <> rt, S.drop_empty(String.split(t, '/')))) -> Conv(path, S.Under{r <> rt}, sens):
  (+k, pr) = inv
  (h1, h2) = pr
  conv_took_l(sens, r, rt, t, path, took_segs(k), took_ys(k), eqpath, h1, h2)

def walk_opts(strict: Bool, +sens: Bool, +r: String, +rt: List<&2, String>, +t: String, +path: String, +b: List<&2, P.Segment>, +ps: P.Params, eqpath: {path == SCon{'/', t} : String},
    lit: {S.all_plain(r <> rt) == True{} : Bool}, e: {S.walk(statics(r <> rt), S.normal_path(strict, String.split(t, '/')), sens, S.member_segments(strict, b), Nil{}) == Some{ps} : Maybe<&2, P.Params>}) ->
    Conv(path, S.Under{r <> rt}, sens):
  match strict:
    case True{}:
      conv_strict(sens, r, rt, t, path, eqpath, walk_inv(sens, r <> rt, String.split(t, '/'), b, ps, e))
    case False{}:
      conv_lenient(sens, r, rt, t, path, eqpath, walk_inv(sens, r <> rt, S.drop_empty(String.split(t, '/')), S.drop_static(b), ps, lenient_walk(S.drop_empty(String.split(t, '/')), r, sens, rt, S.drop_static(b), ps, lit, e)))

def conv_tail(+r: String, +rt: List<&2, String>, +b: List<&2, P.Segment>, m: Maybe<&2, String>, +path: String, e: {S.slash_tail(path) == m : Maybe<&2, String>}, +ps: P.Params,
    +strict: Bool, +sens: Bool, lit: {S.all_plain(r <> rt) == True{} : Bool}, ms: {S.walk_at(m, statics(r <> rt), b, M.Options{strict, sens}) == Some{ps} : Maybe<&2, P.Params>}) ->
    Conv(path, S.Under{r <> rt}, sens):
  match m:
    case None{}:
      Core.absurd(Conv(path, S.Under{r <> rt}, sens), none_some_p(ps, ms))
    case Some{+t}:
      walk_opts(strict, sens, r, rt, t, path, b, ps, MJ.tail_inv(path, t, e), lit, Equal.trans(Maybe<&2, P.Params>, S.walk(statics(r <> rt), S.normal_path(strict, String.split(t, '/')), sens, S.member_segments(strict, b), Nil{}), S.rooted(sens, statics(r <> rt), S.normal_path(strict, String.split(t, '/')), S.member_segments(strict, b)), Some{ps}, Equal.sym(Maybe<&2, P.Params>, S.rooted(sens, statics(r <> rt), S.normal_path(strict, String.split(t, '/')), S.member_segments(strict, b)), S.walk(statics(r <> rt), S.normal_path(strict, String.split(t, '/')), sens, S.member_segments(strict, b), Nil{}), rooted_cons(sens, r, rt, S.normal_path(strict, String.split(t, '/')), S.member_segments(strict, b))), ms))

def conv_pieces(+r: String, +rt: List<&2, String>, mp: Maybe<&2, List<&2, P.Segment>>, +path: String, +ps: P.Params, +strict: Bool, +sens: Bool, lit: {S.all_plain(r <> rt) == True{} : Bool},
    ms: {S.walk_pieces(Some{statics(r <> rt)}, mp, path, M.Options{strict, sens}) == Some{ps} : Maybe<&2, P.Params>}) -> Conv(path, S.Under{r <> rt}, sens):
  match mp:
    case None{}:
      Core.absurd(Conv(path, S.Under{r <> rt}, sens), none_some_p(ps, ms))
    case Some{+b}:
      conv_tail(r, rt, b, S.slash_tail(path), path, {==}, ps, strict, sens, lit, ms)

def conv_under(+raws: List<&2, String>, +member: String, +path: String, +ps: P.Params, +strict: Bool, +sens: Bool, +lit: {S.all_plain(raws) == True{} : Bool}, facts: MJ.UnderFacts(S.Under{raws}),
    ms: {S.mounted_at(S.Under{raws}, member, path, M.Options{strict, sens}) == Some{ps} : Maybe<&2, P.Params>}) -> Conv(path, S.Under{raws}, sens):
  match raws:
    case Nil{}:
      Core.absurd(Conv(path, S.Under{Nil{}}, sens), Core.false_true(facts))
    case +r <> +rt:
      +mp = S.member_pieces(S.member_text(member))
      conv_pieces(r, rt, mp, path, ps, strict, sens, lit, Equal.trans(Maybe<&2, P.Params>, S.walk_pieces(Some{statics(r <> rt)}, mp, path, M.Options{strict, sens}), S.walk_pieces(S.prefix_pieces(r <> rt), mp, path, M.Options{strict, sens}), Some{ps}, Equal.cong(Maybe<&2, List<&2, P.Segment>>, Maybe<&2, P.Params>, z => S.walk_pieces(z, mp, path, M.Options{strict, sens}), Some{statics(r <> rt)}, S.prefix_pieces(r <> rt), Equal.sym(Maybe<&2, List<&2, P.Segment>>, S.prefix_pieces(r <> rt), Some{statics(r <> rt)}, pieces_plain(r <> rt, lit))), ms))

def conv_at(at: S.Place, +member: String, +path: String, +ps: P.Params, +strict: Bool, +sens: Bool, lit: {S.literal_at(at) == True{} : Bool}, facts: MJ.UnderFacts(at),
    ms: {S.mounted_at(at, member, path, M.Options{strict, sens}) == Some{ps} : Maybe<&2, P.Params>}) -> Conv(path, at, sens):
  match at:
    case S.AtRoot{}:
      Core.absurd(Conv(path, S.AtRoot{}, sens), Core.false_true(lit))
    case S.Unplaced{}:
      Core.absurd(Conv(path, S.Unplaced{}, sens), Core.false_true(lit))
    case S.Under{+raws}:
      conv_under(raws, member, path, ps, strict, sens, lit, facts, ms)

def L.mount_literal_converse_options(prefix, member, path, strict, sensitive, ps, admissible, literal, hit):
  +adm = admissible
  conv_at(S.place(prefix), member, path, ps, strict, sensitive, literal, MJ.under_facts(prefix), Equal.trans(Maybe<&2, P.Params>, S.mounted(prefix, member, path, M.Options{strict, sensitive}), L.public_match(prefix, member, path, M.Options{strict, sensitive}), Some{ps}, Equal.sym(Maybe<&2, P.Params>, L.public_match(prefix, member, path, M.Options{strict, sensitive}), S.mounted(prefix, member, path, M.Options{strict, sensitive}), L.mount_match_spec(prefix, member, path, M.Options{strict, sensitive}, adm)), hit))

# Case-sensitive matching compares exactly, so the request spells the prefix.
def same_eq(raws: List<&2, String>, segs: List<&2, String>, h: {S.same_segments(True{}, raws, segs) == True{} : Bool}) -> {segs == raws : List<&2, String>}:
  match raws segs:
    case Nil{} Nil{}:
      {==}
    case +r <> +rt +x <> +xt:
      +e = h
      Equal.trans(List<&2, String>, x <> xt, r <> xt, r <> rt, Equal.cong(String, List<&2, String>, q => q <> xt, x, r, Equal.sym(String, r, x, Eq.string_eq_sound(r, x, Core.and_left(String.eq(r, x), S.same_segments(True{}, rt, xt), e)))), Equal.cong(List<&2, String>, List<&2, String>, l => r <> l, xt, rt, same_eq(rt, xt, Core.and_right(String.eq(r, x), S.same_segments(True{}, rt, xt), e))))
    case Nil{} x <> xt:
      Core.absurd({x <> xt == Nil{} : List<&2, String>}, Core.false_true(h))
    case r <> rt Nil{}:
      Core.absurd({Nil{} == r <> rt : List<&2, String>}, Core.false_true(h))

def lead_same(at: S.Place, cut: S.Cut, h: {S.prefix_same_at(at, True{}, S.cut_segs(cut)) == True{} : Bool}) -> {S.cut_path(cut) == S.lead_at(at) ++ S.cut_rest(cut) : String}:
  match at:
    case S.AtRoot{}:
      Core.absurd({S.cut_path(cut) == S.lead_at(S.AtRoot{}) ++ S.cut_rest(cut) : String}, Core.false_true(h))
    case S.Unplaced{}:
      Core.absurd({S.cut_path(cut) == S.lead_at(S.Unplaced{}) ++ S.cut_rest(cut) : String}, Core.false_true(h))
    case S.Under{+raws}:
      match cut:
        case S.Cut{+segs, +rest}:
          Equal.cong(List<&2, String>, String, z => ("/" ++ String.join(z, "/")) ++ rest, segs, raws, same_eq(raws, segs, h))

def sens_pack(at: S.Place, +path: String, c: Conv(path, at, True{})) -> &rest: String -> ({path == S.lead_at(at) ++ rest : String} & {S.boundary(rest) == True{} : Bool}):
  (+cut, pr) = c
  (h1, pr2) = pr
  (h2, h3) = pr2
  (S.cut_rest(cut), (Equal.trans(String, path, S.cut_path(cut), S.lead_at(at) ++ S.cut_rest(cut), h1, lead_same(at, cut, h3)), h2))

def L.mount_literal_converse_sensitive(prefix, member, path, strict, ps, admissible, literal, hit):
  sens_pack(S.place(prefix), path, L.mount_literal_converse_options(prefix, member, path, strict, True{}, ps, admissible, literal, hit))

def L.mount_literal_converse(prefix, member, path, ps, admissible, literal, hit):
  L.mount_literal_converse_sensitive(prefix, member, path, True{}, ps, admissible, literal, hit)


# ---- Examples ----

def L.mount_admissible_examples():
  {==}

def L.mount_admissible_forms():
  ({==}, {==})

def L.mount_spec_examples():
  ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))

def L.mount_spec_form_examples():
  ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, {==})))))))))

def L.mount_counterexamples():
  ({==}, ({==}, ({==}, ({==}, {==}))))

def L.mount_lenient_suffix_counterexample():
  ({==}, ({==}, ({==}, {==})))
