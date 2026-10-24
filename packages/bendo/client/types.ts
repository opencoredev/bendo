// Types for the Eden-style client tree. They read the generated `Routes` union
// (docs/route-types.md) and mirror the runtime in ./path.ts: change both together.

/** The shape of one generated `Routes` member. */
export type RouteRecord = {
  method: string;
  path: string;
  all: boolean;
  captures: readonly string[];
  input: Slots;
  output: Slots;
};
type Slots = {
  params: unknown;
  query: unknown;
  headers: unknown;
  body: unknown;
  response: unknown;
};

/** Methods the tree exposes. Fetch refuses CONNECT and TRACE; extension methods have no key. */
export type Method = "GET" | "HEAD" | "POST" | "PUT" | "DELETE" | "OPTIONS" | "PATCH";
export type MethodKey = Lowercase<Method>;

/** One query or header value as Bendo's text coercion reads it. */
export type TextValue = string | number | bigint | boolean;
export type TextField = TextValue | readonly TextValue[] | undefined;
export type TextRecord = { readonly [key: string]: TextField };
/** Fetch joins repeated header values into one field, so a header array holds one item. */
export type HeaderField = TextValue | readonly [TextValue] | undefined;
export type HeaderRecord = { readonly [key: string]: HeaderField };

export type BendoFieldError = {
  path: readonly (string | number)[];
  code: string;
  message: string;
};

/** A non-2xx body: Bendo's error JSON (BND-25, with BND-36's list), or the raw text. */
export type HttpErrorBody =
  | { kind: "bendo"; error: string; status: number; errors: readonly BendoFieldError[] }
  | { kind: "text"; text: string };

export type ResponseIssue = { path: readonly (string | number)[]; message: string };

/** Every call resolves to one of these; none rejects. */
export type ClientResult<T> =
  | { ok: true; status: number; data: T; response: Response }
  | { ok: false; kind: "http"; status: number; error: HttpErrorBody; response: Response }
  | { ok: false; kind: "request"; cause: unknown }
  | { ok: false; kind: "network"; cause: unknown }
  | {
      ok: false;
      kind: "invalid-response";
      status: number;
      issues: readonly ResponseIssue[];
      response: Response;
    };

// Path segments become steps: static text stays, every capture becomes `:name`.
// Optional captures form a trailing chain, so each one may end the path.
type Split<P extends string> = P extends `${infer H}/${infer T}` ? [H, ...Split<T>] : [P];
type RawSegments<P extends string> = P extends "/"
  ? []
  : P extends "*"
    ? ["*"]
    : P extends `/${infer Rest}`
      ? Split<Rest>
      : never;
type CaptureName<S extends string> = S extends `${infer Name}{${string}` ? Name : S;
type Steps<S extends string[]> = S extends [infer H extends string, ...infer T extends string[]]
  ? H extends `:${infer C}?`
    ? [] | [`:${CaptureName<C>}`, ...Steps<T>]
    : H extends `:${infer C}`
      ? [`:${CaptureName<C>}`, ...Steps<T>]
      : H extends "*"
        ? T extends []
          ? [":*"]
          : Steps<T>
        : H extends `*${infer Name}`
          ? [`:${Name}`]
          : H extends `${infer Prefix}*`
            ? [Prefix]
            : [H, ...Steps<T>]
  : [];

type Entries<R> = R extends RouteRecord
  ? Steps<RawSegments<R["path"]>> extends infer S
    ? S extends string[]
      ? { route: R; rest: S }
      : never
    : never
  : never;

type Head<E> = E extends { rest: [infer H extends string, ...string[]] } ? H : never;
type Keys<R> = R extends RouteRecord
  ? R["all"] extends true
    ? MethodKey
    : R["method"] extends Method
      ? Lowercase<R["method"]>
      : never
  : never;
type Routed<E, M> = E extends { route: infer R extends RouteRecord }
  ? M extends Keys<R>
    ? R
    : never
  : never;

type Slot<K extends string, T, Fallback> = unknown extends T
  ? { [P in K]?: Fallback }
  : {} extends T
    ? { [P in K]?: T }
    : { [P in K]: T };
type Text<T> = unknown extends T ? T : T & TextRecord;
// A schema array such as [string, ...string[]] narrows to one item for headers.
type OneValue<T> = T extends readonly [infer H, ...unknown[]]
  ? readonly [H]
  : T extends readonly (infer I)[]
    ? readonly [I]
    : T;
type HeaderText<T> = unknown extends T ? T : { [K in keyof T]: OneValue<T[K]> } & HeaderRecord;
export type RequestInput<R extends RouteRecord> = Slot<
  "query",
  Text<R["input"]["query"]>,
  TextRecord
> &
  Slot<"headers", HeaderText<R["input"]["headers"]>, HeaderRecord> &
  Slot<"body", R["input"]["body"], unknown> & { signal?: AbortSignal };
type Args<I> = {} extends I ? [input?: I] : [input: I];
/** A HEAD response has no body, so its data is `undefined`. */
export type Endpoint<R extends RouteRecord, M extends MethodKey> = (
  ...args: Args<RequestInput<R>>
) => Promise<ClientResult<M extends "head" ? undefined : R["output"]["response"]>>;

type Endpoints<E> = {
  [M in E extends { route: infer R } ? Keys<R> : never]: Endpoint<Routed<E, M>, M>;
};
// Key remapping groups entries by head in one pass: entries that share a head
// become one union, so a wide node costs O(routes) rather than O(routes²).
type Advance<E> = E extends { route: infer R; rest: [string, ...infer T] }
  ? { route: R; rest: T }
  : never;
type Children<E> = { [X in E as Head<X>]: Advance<X> };
type Statics<C> = { [S in Exclude<keyof C, `:${string}`>]: Node<C[S]> };

// A capture value comes from the route's params schema, else any text value.
type ParamValue<E, N extends string> = E extends { route: infer R extends RouteRecord }
  ? R["input"]["params"] extends { readonly [K in N]?: infer V }
    ? Exclude<V, undefined>
    : string | number
  : never;
// The value picks the routes it can reach: a GET that needs "read" and a PUT
// that needs "write" share the node, but `({ id: "write" })` keeps only the PUT
// and its descendants. tsc re-walks a node's entries for every new type
// argument of a generic signature, so only a node whose routes disagree on the
// value's type gets one; when they agree, every value keeps the whole node and
// the call stays plain, so its cost is paid once per node.
type Shared<E, N extends string> = Intersect<E extends unknown ? [ParamValue<E, N>] : never>;
type Accepting<E, N extends string, V> = E extends unknown
  ? [V] extends [ParamValue<E, N>]
    ? E
    : never
  : never;
type CaptureCall<E, N extends string, Accepted> =
  [Accepted] extends Shared<E, N>
    ? (params: { [P in N]: Accepted }) => Node<E>
    : <V extends Accepted>(params: { [P in N]: V }) => Node<Accepting<E, N, V>>;
type Capture<C, K extends keyof C> = K extends `:${infer N}`
  ? CaptureCall<C[K], N, ParamValue<C[K], N>>
  : never;
type Intersect<U> = (U extends unknown ? (value: U) => void : never) extends (
  value: infer I,
) => void
  ? I
  : never;

type Tree<E, C> = Endpoints<Extract<E, { rest: [] }>> &
  Statics<C> &
  Intersect<Capture<C, Extract<keyof C, `:${string}`>>>;
type Node<E> = Tree<E, Children<E>>;

/** The client for a generated `Routes` union. */
export type Client<Routes extends RouteRecord> = Node<Entries<Routes>>;
