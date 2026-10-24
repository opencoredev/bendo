# Network-free entrypoint; only the app dispatcher may perform IO.
import Base
import ../net/conn_info.bend as Conn
import ../mw/logger.bend as Logger
import ../mw/response_policy.bend as Policy
import ../stream.bend as Stream
import ../http/stream_types.bend as StreamTypes
import ./transport.bend as Transport
import ./table.bend as Table
import ./context.bend as Context
import ./middleware.bend as Middleware
import ./hooks.bend as Hooks
import ./route-slot.bend as RouteSlot
import ./observability.bend as Obs
import ../data/urlencoded.bend as Query
import ../router/methods.bend as Methods
import ../router/router.bend as Router
import ../router/spec.bend as Spec
import ../router/pattern.bend as Pattern
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/write_response.bend as Write
import ../http/bytes.bend as Bytes
import ../http/date_response.bend as DateResponse
import ./validate.bend as Validate
import ./finalize.bend as Final
import ../data/schema-prepared.bend as SP
import ./config.bend as Config
import ./errors.bend as Errors
import ../data/schema.bend as Schema
import ../data/json.bend as Json
import ../http/stream_marker.bend as StreamMarker

def Ctx() -> Data: Context.Ctx<Unit>

# Normalize the returned response just as the wire writer would, retaining the
# HEAD representation length in headers while returning an empty body.
def normalized(+method: Request.Method, +res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, Write.response_headers(method, res), Write.payload(method, res), rep}

def finish_valid(method: Request.Method, res: Response.Res, valid: Bool) -> Response.Res:
  match valid:
    case True{}: normalized(method, res)
    case False{}: normalized(method, Response.body(500, [], []))

def finish(method: Request.Method, +res: Response.Res) -> Response.Res:
  finish_valid(method, res, Response.valid(res))

# BND-36: a response that breaks the route's response schema. Development
# answers a 500 with the BND-25 public body; Production logs the failing paths
# to stderr and sends the response unchanged. The log names the registered
# route pattern, never the request path, so captured values such as tokens
# stay out of it.
def violation_line(-Vars: Data, +c: Context.Ctx<Vars>, +route: String, text: Result<&2, &2, Json.Error, String>) -> String:
  match text:
    case Done{s}: "bendo: response schema violation: " ++ Request.method_text(Context.method(Vars, c)) ++ " " ++ route ++ " " ++ s
    case Fail{e}: "bendo: response schema violation: " ++ Request.method_text(Context.method(Vars, c)) ++ " " ++ route

def replacement(-Vars: Data, +c: Context.Ctx<Vars>, action: Validate.Action) -> Response.Res:
  match action:
    case Validate.Replace{}: Context.error(Vars, c, Errors.HttpError{500, "response schema violation", False{}})
    case Validate.Send{}: Response.body(500, [], [])
    case Validate.Report{errors}: Response.body(500, [], [])

def reported(-Vars: Data, +c: Context.Ctx<Vars>, action: Validate.Action, route: String) -> IO(Unit):
  match action:
    case Validate.Report{errors}: IO.print_err(violation_line(Vars, c, route, Json.stringify(Schema.errors_json(errors))))
    case Validate.Send{}: IO.pure(Unit, Unit{})
    case Validate.Replace{}: IO.pure(Unit, Unit{})

# The response is checked after the retained policies have produced its final
# fields, and the checked response is the one sent (Final.answered); a 500
# replacement gets the same policies. Delivery comes from the request's actual
# registration, through the same eligibility test transport selection applies
# (Marker.eligible), so a forged or stale marker header cannot exempt a
# buffered response, and policies cannot set or remove the marker
# (law finalized_policies_keep_delivery).
def check_response(~validator: Validate.Job -> Validate.Answer, -Vars: Data, +c: Context.Ctx<Vars>, schema: Maybe<&2, SP.Checked>, +policies: List<&2, Policy.Policy>, res: Response.Res, mode: Config.Mode, route: String, claim: StreamMarker.Claim) -> IO(Response.Res):
  +checked = Policy.finalized(policies, res)
  +action = Final.action(~validator, mode, claim, schema, checked)
  do IO<Response.Res>:
    reported(Vars, c, action, route)
    return Final.answered(policies, checked, action, replacement(Vars, c, action))

# The registered pattern of the route with this reversed ordinal.
def route_source(-Tag: Data, xs: List<&2, Methods.Registration(Tag)>, k: Nat) -> String:
  match xs:
    case Nil{}: "(unknown route)"
    case Spec.Registration{source, binding} <> t:
      match k:
        case 0n: source
        case 1n+j: route_source(Tag, t, j)

def route_label(-Tag: Data, xs: List<&2, Methods.Registration(Tag)>, count: Nat, route: Maybe<&2, Nat>) -> String:
  match route:
    case None{}: "(no route)"
    case Some{n}: route_source(Tag, xs, Nat.sub(Nat.sub(count, 1n), n))

def terminal(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), missing: List<&2, Tag>, resolution: Methods.Resolution<Tag>, +ctx: Context.Ctx<Vars>, env: Env, slot: Chan(Context.Ctx<Vars>)) -> IO(Response.Res):
  match resolution:
    case Methods.NotFound{}:
      Hooks.chain(~Vars, ~Tag, ~Env, ~middleware, missing, env, slot, ctx, c => IO.pure(Response.Res, Context.not_found(Vars, c)))
    case Methods.MethodNotAllowed{allow}:
      IO.pure(Response.Res, Context.body(Vars, Context.header(Vars, Context.status(Vars, ctx, 405), "allow", Methods.allow_text(allow)), [], None{}))
    case Methods.Found{Spec.Match{index, tag, params}, head_from_get}: dispatch(tag, ctx, env)

def params(-Tag: Data, resolution: Methods.Resolution<Tag>) -> Pattern.Params:
  match resolution:
    case Methods.Found{Spec.Match{index, tag, ps}, head_from_get}: ps
    case _: []

# Attach route captures without losing variables or pending response headers.
def with_params(-Vars: Data, ctx: Context.Ctx<Vars>, ps: Pattern.Params) -> Context.Ctx<Vars>:
  Context.Ctx{req, old, body, pairs, code, hs, vars, observation} = ctx
  Context.Ctx{req, ps, body, pairs, code, hs, vars, observation}

# BND-36: request validation runs after parse and transform hooks and before
# before_handle, as one step of the same chain. A rejection answers at once;
# the handler never runs. The chain remembers the validated context. A route
# with any schema, a response schema alone included, takes this step, so the
# plain entrypoints reject it before dispatch. BND-96: a route whose schemas
# check nothing in the request takes ClearValues instead, which forwards the
# context the step would have admitted, without running the validator.
type Step<-Tag: Data> is Data:
  Run{tag: Tag}
  Check{schemas: Validate.Schemas}
  ClearValues{}

def runs(-Tag: Data, ids: List<&2, Tag>) -> List<&2, Step<Tag>>:
  match ids:
    case Nil{}: []
    case id <> tail: Run{id} <> runs(Tag, tail)

def entered(-Vars: Data, e: Context.Entry<Vars>, next: Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  match e:
    case Context.EnterHandler{c}: next(c)
    case Context.RejectRequest{res}: IO.pure(Response.Res, res)

def judged(-Vars: Data, +ctx: Context.Ctx<Vars>, answer: Validate.Answer, next: Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  entered(Vars, Context.answered(Vars, ctx, answer), next)

def stepped(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), step: Step<Tag>, +ctx: Context.Ctx<Vars>, env: Env, next: Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  match step:
    case Run{tag}: middleware(tag, ctx, env, next)
    case Check{schemas}: judged(Vars, ctx, validator(Validate.RequestJob{schemas, Context.validation_input(Vars, ctx)}), next)
    case ClearValues{}: next(Context.without_values(Vars, ctx))

# BND-96: the schemas a request can meet. `validates` says whether the table
# declares any schema (computed once per served table, at startup), and a
# table that declares none has none on any route (law
# undeclared_table_checks_nothing), so it is not looked up.
def route_checks(-Tag: Data, layers: List<&2, Table.Middleware<Tag>>, route: Maybe<&2, Nat>, validates: Bool) -> Validate.Schemas:
  match validates:
    case False{}: Validate.none()
    case True{}: Table.route_schemas(Tag, layers, route)

# A route whose schemas check nothing in the request runs the same hooks
# without the validation step. With a decoder only a response schema, it still
# clears the decoded values early hooks may have stored, as the admitting step
# did (law request_free_route_enters_cleared_run). A route with no schema at
# all never had the step and forwards its context untouched.
def unchecked_onion(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), clears: Bool, early: List<&2, Tag>, before: List<&2, Tag>, env: Env, slot: Chan(Context.Ctx<Vars>)) -> Middleware.Value(Context.Ctx<Vars>, IO(Response.Res)):
  match clears:
    case False{}: Hooks.chain(~Vars, ~Tag, ~Env, ~middleware, List.append(&2, Tag, early, before), env, slot)
    case True{}: Hooks.chain(~Vars, ~Step<Tag>, ~Env, ~(step => c => e => next => stepped(~validator, ~Vars, ~Tag, ~Env, ~middleware, step, c, e, next)), List.concat(&2, Step<Tag>, [runs(Tag, early), [ClearValues{}], runs(Tag, before)]), env, slot)

def onion_for(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), early: List<&2, Tag>, before: List<&2, Tag>, schemas: Validate.Schemas, env: Env, slot: Chan(Context.Ctx<Vars>), declared: Bool) -> Middleware.Value(Context.Ctx<Vars>, IO(Response.Res)):
  match declared:
    case False{}: unchecked_onion(~validator, ~Vars, ~Tag, ~Env, ~middleware, Validate.declares(schemas), early, before, env, slot)
    case True{}: Hooks.chain(~Vars, ~Step<Tag>, ~Env, ~(step => c => e => next => stepped(~validator, ~Vars, ~Tag, ~Env, ~middleware, step, c, e, next)), List.concat(&2, Step<Tag>, [runs(Tag, early), [Check{schemas}], runs(Tag, before)]), env, slot)

def resolved_with(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), +resolution: Methods.Resolution<Tag>, +layers: List<&2, Table.Middleware<Tag>>, ctx: Context.Ctx<Vars>, +env: Env, +slot: Chan(Context.Ctx<Vars>), +route_slot: Chan(Maybe<&2, Nat>), count: Nat, validates: Bool) -> IO(Response.Res):
  +route = RouteSlot.identity(Tag, count, resolution)
  +routed = with_params(Vars, ctx, params(Tag, resolution))
  +schemas = route_checks(Tag, layers, route, validates)
  early = List.concat(&2, Tag, [Table.selected(Tag, layers, Context.path(Vars, routed)), Table.scoped_stage_ids(Tag, layers, route, Table.Parse{}), Table.scoped_stage_ids(Tag, layers, route, Table.Transform{})])
  onion = onion_for(~validator, ~Vars, ~Tag, ~Env, ~middleware, early, Table.scoped_stage_ids(Tag, layers, route, Table.BeforeHandle{}), schemas, env, slot, Validate.checks_request(Validate.enabled(validator(Validate.Probe{})), schemas))
  do IO<Response.Res>:
    RouteSlot.remember(route_slot, route)
    Hooks.remember(Vars, slot, routed)
    onion(routed, changed => terminal(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, Table.stage_ids(Tag, layers, Table.NotFound{}), resolution, changed, env, slot))

# Route the context on_request produced, through the configured router. Every
# kind returns Methods.resolve's result (law methods_router_resolve).
def route_with(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), kind: Router.RouterKind, table: Table.Table<Tag>, +ctx: Context.Ctx<Vars>, env: Env, slot: Chan(Context.Ctx<Vars>), route_slot: Chan(Maybe<&2, Nat>), validates: Bool) -> IO(Response.Res):
  Table.Table{entries, compiled, layers, count} = table
  resolved_with(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, Methods.resolve_with(Tag, kind, compiled, Context.path(Vars, ctx), Context.method(Vars, ctx), Methods.defaults()), layers, ctx, env, slot, route_slot, count, validates)

def recover(~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), ids: List<&2, Tag>, ctx: Context.Ctx<Vars>, env: Env, res: Response.Res, failed: Bool) -> IO(Response.Res):
  match failed:
    case False{}: IO.pure(Response.Res, res)
    case True{}: Hooks.post(~Vars, ~Tag, ~Env, ~middleware, ids, ctx, env, res)

def validated(res: Response.Res, valid: Bool) -> Response.Res:
  match valid:
    case True{}: res
    case False{}: Response.body(500, [], [])

def error_response(res: Response.Res) -> Bool:
  Response.Res{code, hs, body, rep} = res
  U32.is_ge(code, 400)

# Transport owns the deferred action. This internal entrypoint never runs it.
def transport_selected(~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), ids: List<&2, Tag>, +ctx: Context.Ctx<Vars>, env: Env, selected: Response.Res & StreamTypes.Transport) -> IO(Response.Res & (StreamTypes.Transport & IO(Unit))):
  (+res, stream) = selected
  do IO<Response.Res & (StreamTypes.Transport & IO(Unit))>:
    Logger.flush(Obs.access(Context.observation(Vars, ctx)), res)
    return (res, (stream, Hooks.observe(~Vars, ~Tag, ~Env, ~middleware, ids, Context.with_observation(Vars, ctx, Obs.without_access(Context.observation(Vars, ctx))), env, res)))

# BND-36: the response schema checks the response every hook produced or
# replaced, for the route the request resolved to, after the retained policies.
# BND-96: a route without a response schema sends the response the policies
# produced: that is what the check answers for no schema, with either
# validator (laws response_without_schema_is_sent_run and _skip), so neither
# the check nor the route's label is built.
def answered_response(~validator: Validate.Job -> Validate.Answer, -Vars: Data, -Tag: Data, +c: Context.Ctx<Vars>, schema: Maybe<&2, SP.Checked>, +policies: List<&2, Policy.Policy>, res: Response.Res, mode: Config.Mode, entries: List<&2, Methods.Registration(Tag)>, count: Nat, route: Maybe<&2, Nat>, claim: StreamMarker.Claim) -> IO(Response.Res):
  match schema:
    case None{}: IO.pure(Response.Res, Policy.finalized(policies, res))
    case Some{s}: check_response(~validator, Vars, c, Some{s}, policies, res, mode, route_label(Tag, entries, count, route), claim)

def answered_transport(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), +req: Request.Req, entries: List<&2, Methods.Registration(Tag)>, layers: List<&2, Table.Middleware<Tag>>, +count: Nat, env: Env, network: Bool, mode: Config.Mode, +route: Maybe<&2, Nat>, plan: Table.Lifecycle<Tag>, +latest: Context.Ctx<Vars>, recovered: Response.Res, claimed: StreamMarker.Claim & Maybe<&1, StreamTypes.Registration>) -> IO(Response.Res & (StreamTypes.Transport & IO(Unit))):
  Request.Req{+method, path, query, version, headers} = req
  (claim, registration) = claimed
  do IO<Response.Res & (StreamTypes.Transport & IO(Unit))>:
    # A clock failure's 500 still gets the retained policies.
    dated : Response.Res <- DateResponse.ensure(recovered)
    +policies : List<&2, Policy.Policy> <- Obs.take_policies(Context.observation(Vars, latest))
    answered : Response.Res <- answered_response(~validator, Vars, Tag, latest, Validate.response_schema(Table.route_schemas(Tag, layers, route)), policies, dated, mode, entries, count, route, claim)
    # Later finalizers only stamp Server-Timing and X-Request-ID.
    decorated : Response.Res <- Obs.finalized_timing(Context.observation(Vars, latest), answered)
    +final : Response.Res = finish(method, decorated)
    selected : Response.Res & StreamTypes.Transport <- Transport.select(req, final, registration)
    supported : Response.Res & StreamTypes.Transport <- Transport.network(selected, network)
    transport_selected(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_observers(Tag, plan), latest, env, supported)

# A table that declares route schemas: request validation runs as a step of
# the pre-handler chain, and finalization checks responses (BND-36).
def parsed_checked(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), +kind: Router.RouterKind, +table: Table.Table<Tag>, +env: Env, +req: Request.Req, body: List<&2, U32>, network: Bool, +mode: Config.Mode, peer: Maybe<&2, Conn.ConnInfo>, parsed_query: Result<&2, &2, Query.Error, List<&2, Query.Entry>>) -> IO(Response.Res & (StreamTypes.Transport & IO(Unit))):
  Table.Table{+entries, +compiled, +layers, +count} = table
  Request.Req{+method, path, query, version, headers} = req
  match parsed_query:
    case Fail{error}: IO.pure(Response.Res & (StreamTypes.Transport & IO(Unit)), (finish(method, Response.text(400, "Bad Request")), (StreamTypes.Buffered{}, IO.pure(Unit, Unit{}))))
    case Done{pairs}:
      +initial = RouteSlot.identity(Tag, count, Methods.resolve_with(Tag, kind, compiled, path, method, Methods.defaults()))
      request_ids = Table.scoped_stage_ids(Tag, layers, initial, Table.Request{})
      do IO<Response.Res & (StreamTypes.Transport & IO(Unit))>:
        +access : Chan(List<&2, Obs.Access>) <- Chan.new(List<&2, Obs.Access>, 1)
        access_seeded : Result<&1, &1, List<&2, Obs.Access>, Unit> <- Chan.send(List<&2, Obs.Access>, access, [])
        Hooks.sent(List<&2, Obs.Access>, access_seeded)
        +policies : Chan(List<&2, Policy.Policy>) <- Chan.new(List<&2, Policy.Policy>, 1)
        policy_seeded : Result<&1, &1, List<&2, Policy.Policy>, Unit> <- Chan.send(List<&2, Policy.Policy>, policies, [])
        Hooks.sent(List<&2, Policy.Policy>, policy_seeded)
        +stream_slot : Chan(StreamTypes.Registration) <- Chan.new(StreamTypes.Registration, 1)
        +ctx : Context.Ctx<Vars> = Context.with_observation(Vars, Context.variables(Vars, Context.create(req, [], body, pairs)), Obs.with_access(Obs.with_peer(Obs.with_policies(Obs.with_stream(Obs.empty(), stream_slot), policies), peer), access))
        +route_slot : Chan(Maybe<&2, Nat>) <- Chan.new(Maybe<&2, Nat>, 1)
        route_seeded : Result<&1, &1, Maybe<&2, Nat>, Unit> <- Chan.send(Maybe<&2, Nat>, route_slot, initial)
        Hooks.sent(Maybe<&2, Nat>, route_seeded)
        +slot : Chan(Context.Ctx<Vars>) <- Chan.new(Context.Ctx<Vars>, 1)
        seeded : Result<&1, &1, Context.Ctx<Vars>, Unit> <- Chan.send(Context.Ctx<Vars>, slot, ctx)
        Hooks.sent(Context.Ctx<Vars>, seeded)
        res : Response.Res <- Hooks.chain(~Vars, ~Tag, ~Env, ~middleware, request_ids, env, slot, ctx, changed => route_with(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, kind, table, changed, env, slot, route_slot, True{}))
        +route : Maybe<&2, Nat> <- RouteSlot.recall(route_slot)
        +latest : Context.Ctx<Vars> <- Hooks.recall(Vars, slot)
        +plan : Table.Lifecycle<Tag> = Table.scoped_lifecycle(Tag, layers, Context.path(Vars, latest), route)
        after : Response.Res <- Hooks.post(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_after(Tag, plan), latest, env, res)
        +mapped : Response.Res <- Hooks.post(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_map(Tag, plan), latest, env, after)
        +checked : Response.Res = validated(mapped, Response.valid(mapped))
        +recovered : Response.Res <- recover(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_errors(Tag, plan), latest, env, checked, error_response(checked))
        # Every hook has run, so the registration is final; close its slot now.
        registration : Maybe<&1, StreamTypes.Registration> <- Stream.take(stream_slot)
        answered_transport(~validator, ~Vars, ~Tag, ~Env, ~middleware, req, entries, layers, count, env, network, mode, route, plan, latest, validated(recovered, Response.valid(recovered)), Transport.claimed(registration))

# BND-96: a table that declares no route schema runs the lifecycle without
# validation: no route's schemas are looked up (law
# undeclared_table_checks_nothing), no request is checked, and finalization
# sends what the retained policies produce, as BND-36's check does for a route
# without a response schema. This repeats parsed_checked's setup on purpose;
# tests/pipelines.test.ts checks the two answer and trace alike.
# Measured on Boat, either splitting finalization into its own IO-returning
# def or giving the lifecycle functions a second caller in the same binary
# (which stops the compiler inlining them) cost hello 5,000 to 8,000
# instructions and 15,000 to 25,000 cycles per request.
def parsed_plain(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), +kind: Router.RouterKind, +table: Table.Table<Tag>, +env: Env, +req: Request.Req, body: List<&2, U32>, network: Bool, peer: Maybe<&2, Conn.ConnInfo>, parsed_query: Result<&2, &2, Query.Error, List<&2, Query.Entry>>) -> IO(Response.Res & (StreamTypes.Transport & IO(Unit))):
  Table.Table{entries, +compiled, +layers, +count} = table
  Request.Req{+method, path, query, version, headers} = req
  match parsed_query:
    case Fail{error}: IO.pure(Response.Res & (StreamTypes.Transport & IO(Unit)), (finish(method, Response.text(400, "Bad Request")), (StreamTypes.Buffered{}, IO.pure(Unit, Unit{}))))
    case Done{pairs}:
      +initial = RouteSlot.identity(Tag, count, Methods.resolve_with(Tag, kind, compiled, path, method, Methods.defaults()))
      request_ids = Table.scoped_stage_ids(Tag, layers, initial, Table.Request{})
      do IO<Response.Res & (StreamTypes.Transport & IO(Unit))>:
        +access : Chan(List<&2, Obs.Access>) <- Chan.new(List<&2, Obs.Access>, 1)
        access_seeded : Result<&1, &1, List<&2, Obs.Access>, Unit> <- Chan.send(List<&2, Obs.Access>, access, [])
        Hooks.sent(List<&2, Obs.Access>, access_seeded)
        +policies : Chan(List<&2, Policy.Policy>) <- Chan.new(List<&2, Policy.Policy>, 1)
        policy_seeded : Result<&1, &1, List<&2, Policy.Policy>, Unit> <- Chan.send(List<&2, Policy.Policy>, policies, [])
        Hooks.sent(List<&2, Policy.Policy>, policy_seeded)
        +stream_slot : Chan(StreamTypes.Registration) <- Chan.new(StreamTypes.Registration, 1)
        +ctx : Context.Ctx<Vars> = Context.with_observation(Vars, Context.variables(Vars, Context.create(req, [], body, pairs)), Obs.with_access(Obs.with_peer(Obs.with_policies(Obs.with_stream(Obs.empty(), stream_slot), policies), peer), access))
        +route_slot : Chan(Maybe<&2, Nat>) <- Chan.new(Maybe<&2, Nat>, 1)
        route_seeded : Result<&1, &1, Maybe<&2, Nat>, Unit> <- Chan.send(Maybe<&2, Nat>, route_slot, initial)
        Hooks.sent(Maybe<&2, Nat>, route_seeded)
        +slot : Chan(Context.Ctx<Vars>) <- Chan.new(Context.Ctx<Vars>, 1)
        seeded : Result<&1, &1, Context.Ctx<Vars>, Unit> <- Chan.send(Context.Ctx<Vars>, slot, ctx)
        Hooks.sent(Context.Ctx<Vars>, seeded)
        res : Response.Res <- Hooks.chain(~Vars, ~Tag, ~Env, ~middleware, request_ids, env, slot, ctx, changed => route_with(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, kind, table, changed, env, slot, route_slot, False{}))
        route : Maybe<&2, Nat> <- RouteSlot.recall(route_slot)
        +latest : Context.Ctx<Vars> <- Hooks.recall(Vars, slot)
        +plan : Table.Lifecycle<Tag> = Table.scoped_lifecycle(Tag, layers, Context.path(Vars, latest), route)
        after : Response.Res <- Hooks.post(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_after(Tag, plan), latest, env, res)
        +mapped : Response.Res <- Hooks.post(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_map(Tag, plan), latest, env, after)
        +checked : Response.Res = validated(mapped, Response.valid(mapped))
        +recovered : Response.Res <- recover(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_errors(Tag, plan), latest, env, checked, error_response(checked))
        # A clock failure's 500 still gets the retained policies.
        dated : Response.Res <- DateResponse.ensure(validated(recovered, Response.valid(recovered)))
        retained : List<&2, Policy.Policy> <- Obs.take_policies(Context.observation(Vars, latest))
        # Later finalizers only stamp Server-Timing and X-Request-ID.
        decorated : Response.Res <- Obs.finalized_timing(Context.observation(Vars, latest), Policy.finalized(retained, dated))
        +final : Response.Res = finish(method, decorated)
        # Every hook has run, so the registration is final; close its slot now.
        registration : Maybe<&1, StreamTypes.Registration> <- Stream.take(stream_slot)
        selected : Response.Res & StreamTypes.Transport <- Transport.select(req, final, registration)
        supported : Response.Res & StreamTypes.Transport <- Transport.network(selected, network)
        transport_selected(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_observers(Tag, plan), latest, env, supported)

# `validates`: whether the table declares any route schema; serving computes
# it once, at startup (BND-96).
def parsed_transport(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), validates: Bool, kind: Router.RouterKind, table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>, network: Bool, mode: Config.Mode, peer: Maybe<&2, Conn.ConnInfo>, parsed_query: Result<&2, &2, Query.Error, List<&2, Query.Entry>>) -> IO(Response.Res & (StreamTypes.Transport & IO(Unit))):
  match validates:
    case False{}: parsed_plain(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, kind, table, env, req, body, network, peer, parsed_query)
    case True{}: parsed_checked(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, kind, table, env, req, body, network, mode, peer, parsed_query)

def buffered_pending(result: Response.Res & (StreamTypes.Transport & IO(Unit))) -> IO(Response.Res & IO(Unit)):
  (res, (stream, after)) = result
  match stream:
    case StreamTypes.Buffered{}: IO.pure(Response.Res & IO(Unit), (res, after))
    case StreamTypes.Streamed{plan}:
      do IO<Response.Res & IO(Unit)>:
        Stream.cancel(plan)
        return (finish(Request.Get{}, Response.body(500, [], [])), after)
    case StreamTypes.Upgraded{session}:
      do IO<Response.Res & IO(Unit)>:
        Stream.abort(session)
        return (finish(Request.Get{}, Response.body(500, [], [])), after)

def transport_routed(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), kind: Router.RouterKind, mode: Config.Mode, table: Table.Table<Tag>, env: Env, +req: Request.Req, body: List<&2, U32>, peer: Maybe<&2, Conn.ConnInfo>, validates: Bool) -> IO(Response.Res & (StreamTypes.Transport & IO(Unit))):
  Request.Req{method, path, query, version, headers} = req
  parsed_transport(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, validates, kind, table, env, req, body, True{}, mode, peer, Context.query_pairs(query))

# BND-96: serving a table without route schemas, which the plain entrypoints
# guarantee at startup. Only parsed_plain is reachable from here, so a binary
# served this way does not link the validating pipeline, and the compiler
# keeps each lifecycle function inlined at its one call site.
def transport_plain(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), kind: Router.RouterKind, table: Table.Table<Tag>, env: Env, +req: Request.Req, body: List<&2, U32>, peer: Maybe<&2, Conn.ConnInfo>) -> IO(Response.Res & (StreamTypes.Transport & IO(Unit))):
  Request.Req{method, path, query, version, headers} = req
  parsed_plain(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, kind, table, env, req, body, True{}, peer, Context.query_pairs(query))

def pending_routed(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), kind: Router.RouterKind, +table: Table.Table<Tag>, env: Env, +req: Request.Req, body: List<&2, U32>) -> IO(Response.Res & IO(Unit)):
  Request.Req{method, path, query, version, headers} = req
  do IO<Response.Res & IO(Unit)>:
    result : Response.Res & (StreamTypes.Transport & IO(Unit)) <- parsed_transport(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, Table.declares_schemas(Tag, Table.layers(Tag, table)), kind, table, env, req, body, False{}, Config.Development{}, None{}, Context.query_pairs(query))
    buffered_pending(result)

def pending_with(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res & IO(Unit)):
  pending_routed(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, Router.default_kind(), table, env, req, body)

def returned(result: Response.Res & IO(Unit)) -> IO(Response.Res):
  (res, after) = result
  do IO<Response.Res>:
    dated : Response.Res <- DateResponse.ensure(res)
    after
    return dated

# For network-free consumers, returning the normalized response is the boundary.
def handle_checked(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  do IO<Response.Res>:
    result : Response.Res & IO(Unit) <- pending_with(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, env, req, body)
    returned(result)

# Without the validator, a route with request schemas answers 500 (see
# Validate.skip); serving entrypoints refuse such a table at startup instead.
def handle_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  handle_checked(~Validate.skip, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, env, req, body)

# Existing apps keep their dispatcher signature. Registering middleware requires
# handle_with/serve_with so no identifier can be silently ignored.
def unconfigured(-Tag: Data, -Env: Data, tag: Tag, ctx: Ctx, env: Env, next: Ctx -> IO(Response.Res)) -> IO(Response.Res):
  IO.die(Response.Res, 1, "Bendo middleware requires handle_with or serve_with")

def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  handle_with(~Unit, ~Tag, ~Env, ~dispatch, ~(tag => ctx => env => next => unconfigured(Tag, Env, tag, ctx, env, next)), table, env, req, body)
