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
export type RequestInput<R extends RouteRecord> = Slot<
  "query",
  Text<R["input"]["query"]>,
  TextRecord
> &
  Slot<"headers", Text<R["input"]["headers"]>, TextRecord> &
  Slot<"body", R["input"]["body"], unknown> & { signal?: AbortSignal };
type Args<I> = {} extends I ? [input?: I] : [input: I];
export type Endpoint<R extends RouteRecord> = (
  ...args: Args<RequestInput<R>>
) => Promise<ClientResult<R["output"]["response"]>>;

type Endpoints<E> = {
  [M in E extends { route: infer R } ? Keys<R> : never]: Endpoint<Routed<E, M>>;
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
type Capture<C, K extends keyof C> = K extends `:${infer N}`
  ? (params: { [P in N]: ParamValue<C[K], N> }) => Node<C[K]>
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
