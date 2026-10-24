// Reads Bend `type` and `def` headers and renders TypeScript declarations
// for Bend 2.0.38's ES module ABI (docs/shared.md). The compiled `.mjs` is the
// authority on which defs exist and how many arguments each takes; source
// headers only supply names and types, so callers check every rendered
// signature against the compiled arity.

/** A type expression as written in a Bend signature or constructor field. */
export type TypeExpr =
  | { kind: "name"; name: string; args: TypeExpr[]; call: boolean }
  | { kind: "arrow"; from: TypeExpr; to: TypeExpr; erased: boolean }
  | { kind: "pair"; left: TypeExpr; right: TypeExpr }
  | { kind: "sum"; left: TypeExpr; right: TypeExpr }
  | { kind: "quantity" }
  | { kind: "number" }
  | { kind: "equality" }
  | { kind: "lambda" }
  | { kind: "term" };

export type ParamMode = "plain" | "erased" | "dup" | "template";
export type Param = { name: string; mode: ParamMode; type: TypeExpr | undefined };

export type DefDecl = {
  name: string;
  params: Param[];
  /** Absent for a def that fills a law (`def f(x, y):`). */
  result: TypeExpr | undefined;
  /** The body when it is a single expression, for type-level aliases. */
  body: string | undefined;
  header: string;
};

export type TypeParamRole = "quantity" | "type" | "index";
export type TypeParam = { name: string; role: TypeParamRole };
export type Field = { name: string; type: TypeExpr };
export type Ctor = { name: string; fields: Field[] };
export type TypeDecl = { name: string; params: TypeParam[]; ctors: Ctor[] };

export type Module = {
  file: string;
  /** Import alias to the imported file's absolute path. */
  imports: Map<string, string>;
  types: Map<string, TypeDecl>;
  defs: Map<string, DefDecl>;
};

export class BendSyntaxError extends Error {}

// ---- tokens ----

/** A token and the source offset just past it. */
type Token = { text: string; end: number };

const SYMBOLS = ["<&>", "->", "=>", "==", "&", "|", "@", ":", ",", "(", ")", "<", ">", "{", "}"];
const SYMBOLS_ONE = new Set(["-", "+", "~", "=", "[", "]", ";", "*", "/", "%", "!", "^", "."]);

function tokenize(source: string): Token[] {
  const tokens: Token[] = [];
  let at = 0;
  while (at < source.length) {
    const c = source[at] ?? "";
    if (/\s/.test(c)) {
      at++;
      continue;
    }
    if (c === "#") break;
    if (c === '"' || c === "'") {
      let end = at + 1;
      while (end < source.length && source[end] !== c) end += source[end] === "\\" ? 2 : 1;
      tokens.push({ text: source.slice(at, end + 1), end: end + 1 });
      at = end + 1;
      continue;
    }
    const word = /^(?:[A-Za-z_][A-Za-z0-9_?']*(?:\.[A-Za-z_][A-Za-z0-9_?']*)*|\d+n?)/.exec(
      source.slice(at),
    );
    if (word) {
      at += word[0].length;
      tokens.push({ text: word[0], end: at });
      continue;
    }
    const symbol = SYMBOLS.find((s) => source.startsWith(s, at));
    if (symbol !== undefined) {
      at += symbol.length;
      tokens.push({ text: symbol, end: at });
      continue;
    }
    if (SYMBOLS_ONE.has(c)) {
      at++;
      tokens.push({ text: c, end: at });
      continue;
    }
    throw new BendSyntaxError(`unexpected character ${JSON.stringify(c)}`);
  }
  return tokens;
}

class Cursor {
  private at = 0;
  constructor(private readonly tokens: Token[]) {}
  peek(offset = 0): string | undefined {
    return this.tokens[this.at + offset]?.text;
  }
  next(): string {
    return this.token().text;
  }
  token(): Token {
    const token = this.tokens[this.at];
    if (token === undefined) throw new BendSyntaxError("unexpected end of header");
    this.at++;
    return token;
  }
  eat(text: string): boolean {
    if (this.peek() !== text) return false;
    this.at++;
    return true;
  }
  expect(text: string): void {
    const found = this.next();
    if (found !== text) throw new BendSyntaxError(`expected ${text}, found ${found}`);
  }
  mark(): number {
    return this.at;
  }
  reset(at: number): void {
    this.at = at;
  }
  done(): boolean {
    return this.at >= this.tokens.length;
  }
}

const IDENT = /^[A-Za-z_][A-Za-z0-9_?'.]*$/;
const isIdent = (text: string | undefined): text is string =>
  text !== undefined && IDENT.test(text);

// ---- type expressions ----

function parseType(c: Cursor): TypeExpr {
  // Dependent forms bind a name: `@x: A -> B`, `@-x: A -> B`, `&x: A -> B`.
  if (c.peek() === "@") {
    c.next();
    const erased = c.eat("-");
    c.next();
    c.expect(":");
    const from = parseSum(c);
    c.expect("->");
    return { kind: "arrow", from, to: parseType(c), erased };
  }
  if (c.peek() === "&" && isIdent(c.peek(1)) && c.peek(2) === ":") {
    c.next();
    c.next();
    c.next();
    const left = parseSum(c);
    c.expect("->");
    return { kind: "pair", left, right: parseType(c) };
  }
  const from = parseSum(c);
  if (c.eat("->")) return { kind: "arrow", from, to: parseType(c), erased: false };
  return from;
}

function parseSum(c: Cursor): TypeExpr {
  const left = parsePair(c);
  if (c.eat("|")) return { kind: "sum", left, right: parseSum(c) };
  return left;
}

function parsePair(c: Cursor): TypeExpr {
  const left = parseAtom(c);
  if (c.peek() === "&" && !/^\d/.test(c.peek(1) ?? "")) {
    c.next();
    return { kind: "pair", left, right: parsePair(c) };
  }
  return left;
}

function parseArg(c: Cursor, close: string): TypeExpr {
  const start = c.mark();
  try {
    let arg = parseType(c);
    // Quantity arithmetic such as `a <&> b` is still a quantity.
    while (c.eat("<&>")) {
      parseType(c);
      arg = { kind: "quantity" };
    }
    if (c.peek() === "," || c.peek() === close) return arg;
  } catch (error) {
    if (!(error instanceof BendSyntaxError)) throw error;
  }
  // A type-level call may take values, such as `Word(1n+n)` or `F(h <> t)`.
  c.reset(start);
  let depth = 0;
  let braces = 0;
  while (depth > 0 || braces > 0 || (c.peek() !== "," && c.peek() !== close)) {
    const token = c.next();
    if (token === "{") braces++;
    else if (token === "}") braces--;
    else if (braces > 0) continue;
    else if (token === "(" || token === "<" || token === "[") depth++;
    else if (token === ")" || token === ">" || token === "]") depth--;
  }
  return { kind: "term" };
}

function parseArgs(c: Cursor, close: string): TypeExpr[] {
  const args: TypeExpr[] = [];
  if (c.eat(close)) return args;
  for (;;) {
    args.push(parseArg(c, close));
    if (c.eat(close)) return args;
    c.expect(",");
  }
}

function skipBalanced(c: Cursor, open: string, close: string): void {
  let depth = 0;
  do {
    const token = c.next();
    if (token === open) depth++;
    else if (token === close) depth--;
  } while (depth > 0);
}

function parseAtom(c: Cursor): TypeExpr {
  const token = c.peek();
  if (token === undefined) throw new BendSyntaxError("expected a type");
  if (token === "&") {
    c.next();
    c.next();
    return { kind: "quantity" };
  }
  // `+List<U32>` is `List<&2, U32>`: the marker only picks the omitted quantities.
  if (token === "+") {
    c.next();
    return parseAtom(c);
  }
  if (token === "(") {
    c.next();
    const inner = parseType(c);
    c.expect(")");
    return inner;
  }
  if (token === "{") {
    skipBalanced(c, "{", "}");
    return { kind: "equality" };
  }
  if (/^\d+n?$/.test(token)) {
    c.next();
    return { kind: "number" };
  }
  if (!isIdent(token)) throw new BendSyntaxError(`expected a type, found ${token}`);
  c.next();
  if (c.eat("=>")) {
    parseType(c);
    return { kind: "lambda" };
  }
  if (c.eat("<")) return { kind: "name", name: token, args: parseArgs(c, ">"), call: false };
  if (c.eat("(")) return { kind: "name", name: token, args: parseArgs(c, ")"), call: true };
  return { kind: "name", name: token, args: [], call: false };
}

/** Parses one complete type expression, such as a constructor field type. */
export function parseTypeText(text: string): TypeExpr {
  const c = new Cursor(tokenize(text));
  const type = parseType(c);
  if (!c.done()) throw new BendSyntaxError(`unexpected ${c.peek()} after type`);
  return type;
}

// ---- declarations ----

/** Splits at commas outside brackets and string literals. */
function splitTop(text: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let start = 0;
  let quote: string | undefined;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quote !== undefined) {
      if (c === "\\") i++;
      else if (c === quote) quote = undefined;
      continue;
    }
    if (c === '"' || c === "'") quote = c;
    else if (text.startsWith("<&>", i) || text.startsWith("->", i) || text.startsWith("=>", i))
      i += text[i] === "<" ? 2 : 1;
    else if (c === "(" || c === "{" || c === "[" || c === "<") depth++;
    else if (c === ")" || c === "}" || c === "]" || c === ">") depth--;
    else if (c === "," && depth === 0) {
      parts.push(text.slice(start, i));
      start = i + 1;
    }
  }
  const last = text.slice(start);
  if (last.trim() !== "") parts.push(last);
  return parts.map((part) => part.trim());
}

function parseTypeParams(text: string): TypeParam[] {
  return splitTop(text).map((part) => {
    const match = /^([-+]?)([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*(.+))?$/.exec(part);
    if (!match) throw new BendSyntaxError(`invalid type parameter ${part}`);
    const name = match[2] ?? "";
    const kind = match[3];
    if (kind === undefined) return { name, role: "quantity" };
    return { name, role: /^(?:Data|Type|Kind\b)/.test(kind) ? "type" : "index" };
  });
}

function parseCtor(line: string): Ctor {
  const match = /^([A-Za-z_][A-Za-z0-9_.]*)\s*\{(.*)\}\s*$/.exec(line);
  if (!match) throw new BendSyntaxError(`invalid constructor ${line}`);
  const fields = splitTop(match[2] ?? "").map((part): Field => {
    const colon = part.indexOf(":");
    if (colon < 0) throw new BendSyntaxError(`constructor field without a type: ${part}`);
    return { name: part.slice(0, colon).trim(), type: parseTypeText(part.slice(colon + 1)) };
  });
  return { name: match[1] ?? "", fields };
}

function parseParam(tokens: Token[]): Param {
  const c = new Cursor(tokens);
  const marker = c.peek();
  const mode: ParamMode =
    marker === "-" ? "erased" : marker === "+" ? "dup" : marker === "~" ? "template" : "plain";
  if (mode !== "plain") c.next();
  const name = c.next();
  if (!c.eat(":")) return { name, mode, type: undefined };
  const type = parseType(c);
  if (!c.done()) throw new BendSyntaxError(`unexpected ${c.peek()} in parameter ${name}`);
  return { name, mode, type };
}

/** Parses `def name(params) -> Result:`; `bodyStart` is the offset after the colon. */
function parseDefHeader(text: string): Omit<DefDecl, "header" | "body"> & { bodyStart: number } {
  const c = new Cursor(tokenize(text));
  c.expect("def");
  const name = c.next();
  c.expect("(");
  const params: Param[] = [];
  let current: Token[] = [];
  // Angle brackets nest only outside `{...}`, where `<` may compare values.
  let depth = 0;
  let braces = 0;
  for (;;) {
    const token = c.next();
    if (depth === 0 && braces === 0 && (token === "," || token === ")")) {
      if (current.length > 0) params.push(parseParam(current));
      current = [];
      if (token === ")") break;
      continue;
    }
    if (token === "{") braces++;
    else if (token === "}") braces--;
    else if (token === "(" || (token === "<" && braces === 0)) depth++;
    else if (token === ")" || (token === ">" && braces === 0)) depth--;
    current.push({ text: token, end: 0 });
  }
  const result = c.eat("->") ? parseType(c) : undefined;
  const colon = c.token();
  if (colon.text !== ":") throw new BendSyntaxError(`expected :, found ${colon.text}`);
  return { name, params, result, bodyStart: colon.end };
}

const IMPORT = /^import\s+(?:"([^"\n]+)"|(\.{1,2}\/\S+))(?:\s+as\s+([A-Za-z_][A-Za-z0-9_]*))?/;

/** Reads the declarations of one Bend file. `resolve` maps an import path to a file. */
export function parseModule(
  file: string,
  source: string,
  resolve: (imported: string) => string,
): Module {
  const lines = source.split("\n");
  const module: Module = { file, imports: new Map(), types: new Map(), defs: new Map() };
  const indented = (line: string | undefined): boolean =>
    line !== undefined && (/^\s+\S/.test(line) || line.trim() === "");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i] ?? "";
    const where = `${file}:${i + 1}`;
    try {
      const imported = IMPORT.exec(line);
      if (imported) {
        const path = imported[1] ?? imported[2];
        if (path !== undefined && imported[3] !== undefined)
          module.imports.set(imported[3], resolve(path));
        continue;
      }
      const type = /^type\s+([A-Za-z_][A-Za-z0-9_.]*)\s*(?:<(.*)>)?\s+is\s+.*:\s*$/.exec(line);
      if (type) {
        const ctors: Ctor[] = [];
        while (indented(lines[i + 1])) {
          i++;
          let body = stripComment(lines[i] ?? "").trim();
          if (body === "") continue;
          while (braces(body) > 0 && i + 1 < lines.length)
            body += ` ${stripComment(lines[++i] ?? "").trim()}`;
          ctors.push(parseCtor(body));
        }
        const name = type[1] ?? "";
        module.types.set(name, {
          name,
          params: type[2] === undefined ? [] : parseTypeParams(type[2]),
          ctors,
        });
        continue;
      }
      const def = /^(?:@unsafe\s+)?(def\s.*)$/.exec(
        line.trim() === "@unsafe" ? (lines[++i] ?? "") : line,
      );
      if (def) {
        // A header may continue while its parentheses are open.
        let header = def[1] ?? "";
        while ((unbalanced(header) || /->\s*$/.test(header)) && i + 1 < lines.length)
          header += ` ${lines[++i]?.trim()}`;
        const { bodyStart, ...parsed } = parseDefHeader(header);
        const inline = header.slice(bodyStart).replace(/#.*$/, "").trim();
        let body: string | undefined = inline === "" ? undefined : inline;
        const bodyLines: string[] = [];
        while (indented(lines[i + 1])) {
          i++;
          const text = (lines[i] ?? "").trim();
          if (text !== "" && !text.startsWith("#")) bodyLines.push(text);
        }
        if (body === undefined && bodyLines.length === 1) body = bodyLines[0];
        if (inline !== "" && bodyLines.length > 0) body = undefined;
        module.defs.set(parsed.name, { ...parsed, body, header: header.slice(0, bodyStart) });
      }
    } catch (error) {
      if (error instanceof BendSyntaxError) throw new BendSyntaxError(`${where}: ${error.message}`);
      throw error;
    }
  }
  return module;
}

function braces(text: string): number {
  let depth = 0;
  for (const c of text) {
    if (c === "{") depth++;
    if (c === "}") depth--;
  }
  return depth;
}

/** Drops a trailing `#` comment outside string literals. */
function stripComment(line: string): string {
  let quote: string | undefined;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quote !== undefined) {
      if (c === "\\") i++;
      else if (c === quote) quote = undefined;
    } else if (c === '"' || c === "'") quote = c;
    else if (c === "#") return line.slice(0, i);
  }
  return line;
}

function unbalanced(text: string): boolean {
  let depth = 0;
  for (const c of text) {
    if (c === "(") depth++;
    if (c === ")") depth--;
  }
  return depth > 0;
}

// ---- rendering ----

/** TypeScript declarations shared by every generated module. */
export const PRELUDE = `export type Unit = { $: "Unit" };
export type Cmp = { $: "LT" } | { $: "EQ" } | { $: "GT" };
export type List<A> = { $: "Nil" } | { $: "Con"; head: A; tail: List<A> };
export type Maybe<A> = { $: "None" } | { $: "Some"; value: A };
export type Result<E, A> = { $: "Fail"; error: E } | { $: "Done"; value: A };
export type Either<A, B> = { $: "Inl"; value: A } | { $: "Inr"; value: B };
/** Base's Sigma; a Bend pair \`A & B\` or \`Pair(A, B)\` is a Tuple. */
export type Sigma<A, B> = { $: "Tuple"; fst: A; snd: B };
export type Poll<A, R> = { $: "Ready"; value: A } | { $: "Wait"; rest: R };
/** A fixed-width bit word, least significant bit first. */
export type Word = { $: "WNil" } | { $: "WCon"; head: boolean; tail: Word };
export type BendMap<V> =
  | { $: "MTip" }
  | { $: "MLeaf"; key: string; val: V }
  | { $: "MNode"; pos: number; lo: BendMap<V>; hi: BendMap<V> };
`;

export const PRELUDE_NAMES = new Set([
  "Unit",
  "Cmp",
  "List",
  "Maybe",
  "Result",
  "Either",
  "Sigma",
  "Poll",
  "Word",
  "BendMap",
]);

/** A Base type: its leading quantity parameters, then its type parameters. */
type BaseRule = { quantities: number; types: number; render: (args: string[]) => string };

const BASE: ReadonlyMap<string, BaseRule> = new Map<string, BaseRule>([
  ["Nat", { quantities: 0, types: 0, render: () => "number" }],
  ["U32", { quantities: 0, types: 0, render: () => "number" }],
  ["F32", { quantities: 0, types: 0, render: () => "number" }],
  ["Bool", { quantities: 0, types: 0, render: () => "boolean" }],
  ["String", { quantities: 0, types: 0, render: () => "string" }],
  ["Char", { quantities: 0, types: 0, render: () => "string" }],
  ["Unit", { quantities: 0, types: 0, render: () => "Unit" }],
  ["Cmp", { quantities: 0, types: 0, render: () => "Cmp" }],
  ["Empty", { quantities: 0, types: 0, render: () => "never" }],
  ["List", { quantities: 1, types: 1, render: ([a]) => `List<${a}>` }],
  ["Maybe", { quantities: 1, types: 1, render: ([a]) => `Maybe<${a}>` }],
  ["Result", { quantities: 2, types: 2, render: ([e, a]) => `Result<${e}, ${a}>` }],
  ["Either", { quantities: 2, types: 2, render: ([a, b]) => `Either<${a}, ${b}>` }],
  ["Sigma", { quantities: 2, types: 2, render: ([a, b]) => `Sigma<${a}, ${b}>` }],
  ["Poll", { quantities: 2, types: 2, render: ([a, r]) => `Poll<${a}, ${r}>` }],
  ["Map", { quantities: 1, types: 1, render: ([v]) => `BendMap<${v}>` }],
  // Not `Array<...>`, which a module namespace could shadow; an arrow needs parentheses.
  [
    "Array",
    { quantities: 0, types: 1, render: ([t = ""]) => (t.includes("=>") ? `(${t})[]` : `${t}[]`) },
  ],
  ["Word.Nil", { quantities: 0, types: 0, render: () => "Word" }],
  ["Word.Con", { quantities: 0, types: 0, render: () => "Word" }],
]);

/** Base's type-level defs, called with parentheses. */
const BASE_CALLS: ReadonlyMap<string, (args: string[]) => string> = new Map([
  ["Word", () => "Word"],
  ["Pair", ([a, b]: string[]) => `Sigma<${a}, ${b}>`],
  ["Or", ([a, b]: string[]) => `Either<${a}, ${b}>`],
  ["Exists", ([a]: string[]) => `Sigma<${a}, unknown>`],
  ["Set", () => "BendMap<Unit>"],
]);

const RESERVED = new Set(
  (
    "break case catch class const continue debugger default delete do else enum export extends " +
    "false finally for function if import in instanceof new null return super switch this throw " +
    "true try typeof var void while with yield let static implements interface package private " +
    "protected public await"
  ).split(" "),
);

export function isExportName(name: string): boolean {
  return /^[A-Za-z_$][A-Za-z0-9_$]*$/.test(name) && !RESERVED.has(name);
}

/** Words TypeScript reads as an operator where a type is expected, as in `keyof.T`. */
const TYPE_OPERATORS = new Set(["infer", "keyof", "readonly", "unique"]);

/** A TypeScript identifier for a Bend name: a type, parameter or namespace. */
export function identifier(name: string): string {
  const clean = name.replace(/[^A-Za-z0-9_$]/g, "_");
  const safe = /^[0-9]/.test(clean) ? `_${clean}` : clean;
  return RESERVED.has(safe) || TYPE_OPERATORS.has(safe) ? `${safe}_` : safe;
}

/** How a rendered type refers to another module's declarations. */
export type Naming = {
  /** TypeScript prefix for a module's types: "" for the entry, "ns." otherwise. */
  prefix: (file: string) => string;
  module: (file: string) => Module | undefined;
};

export type Rendered = { text: string; io: boolean; kind: boolean };

type Scope = {
  module: Module;
  params: ReadonlySet<string>;
  naming: Naming;
  /** Aliases being expanded, as `file#def`, so a cyclic alias stops. */
  expanding: ReadonlySet<string>;
  /** Alias parameters bound to an IO argument, as in `Identity(IO(Unit))`. */
  ioParams?: ReadonlySet<string>;
};

/**
 * The type arguments of a use of a type whose parameters have the given roles,
 * or undefined when the count fits neither form. Bend lets a use omit every
 * quantity: `List<U32>` is `List<&1, U32>`.
 */
function typeArgs(args: TypeExpr[], roles: TypeParamRole[]): TypeExpr[] | undefined {
  const spelled =
    args.length === roles.length
      ? roles
      : args.length === roles.filter((role) => role !== "quantity").length
        ? roles.filter((role) => role !== "quantity")
        : undefined;
  return spelled === undefined ? undefined : args.filter((_, i) => spelled[i] === "type");
}

/** True when a def computes a type: its result is Data, Type or a Kind. */
export function isTypeLevel(def: DefDecl): boolean {
  const result = def.result;
  return result?.kind === "name" && ["Data", "Type", "Kind"].includes(result.name);
}

/** A type-level def TypeScript can express: erased type params and a type body. */
function aliasBody(def: DefDecl): TypeExpr | undefined {
  if (!isTypeLevel(def) || def.body === undefined) return undefined;
  if (def.params.some((p) => p.mode !== "erased" || !isKindExpr(p.type))) return undefined;
  try {
    return parseTypeText(def.body);
  } catch {
    return undefined;
  }
}

function isKindExpr(type: TypeExpr | undefined): boolean {
  return type?.kind === "name" && ["Data", "Type", "Kind"].includes(type.name);
}

function lookup(
  scope: Scope,
  name: string,
): { module: Module; local: string } | { module: undefined; local: string } {
  const dot = name.indexOf(".");
  if (dot > 0) {
    const target = scope.module.imports.get(name.slice(0, dot));
    if (target !== undefined) {
      const module = scope.naming.module(target);
      return module === undefined
        ? { module: undefined, local: name }
        : { module, local: name.slice(dot + 1) };
    }
  }
  return { module: scope.module, local: name };
}

function render(type: TypeExpr, scope: Scope): Rendered {
  const plain = (text: string): Rendered => ({ text, io: false, kind: false });
  switch (type.kind) {
    case "quantity":
    case "number":
    case "equality":
    case "lambda":
    case "term":
      return plain("unknown");
    case "arrow": {
      const from = render(type.from, scope).text;
      return plain(`(arg: ${from}) => ${render(type.to, scope).text}`);
    }
    case "pair":
      return plain(`Sigma<${render(type.left, scope).text}, ${render(type.right, scope).text}>`);
    case "sum":
      return plain(`Either<${render(type.left, scope).text}, ${render(type.right, scope).text}>`);
    case "name":
      return renderName(type, scope);
    default: {
      const exhaustive: never = type;
      return exhaustive;
    }
  }
}

function renderName(type: Extract<TypeExpr, { kind: "name" }>, scope: Scope): Rendered {
  const plain = (text: string): Rendered => ({ text, io: false, kind: false });
  const args = (): string[] => type.args.map((arg) => render(arg, scope).text);
  if (type.args.length === 0 && scope.params.has(type.name))
    return {
      text: identifier(type.name),
      io: scope.ioParams?.has(type.name) ?? false,
      kind: false,
    };
  if (["Data", "Type", "Kind"].includes(type.name))
    return { text: "unknown", io: false, kind: true };
  if (type.name === "IO" && type.call) return { text: "unknown", io: true, kind: false };
  const found = lookup(scope, type.name);
  if (found.module !== undefined) {
    const module = found.module;
    const prefix = scope.naming.prefix(module.file);
    const decl = module.types.get(found.local);
    if (decl !== undefined && !type.call) {
      const kept = typeArgs(
        type.args,
        decl.params.map((p) => p.role),
      );
      if (kept === undefined) return plain("unknown");
      const rendered = kept.map((arg) => render(arg, scope).text);
      const name = `${prefix}${identifier(decl.name)}`;
      return plain(rendered.length === 0 ? name : `${name}<${rendered.join(", ")}>`);
    }
    const def = module.defs.get(found.local);
    if (def !== undefined && type.call) {
      // An alias may stand for IO, as in `def Action() -> Type: IO(Unit)`.
      const io = aliasIo(def, module, scope, type.args);
      const body = aliasBody(def);
      if (body === undefined) return { text: "unknown", io, kind: false };
      const rendered = args();
      const name = `${prefix}${identifier(def.name)}`;
      const text = rendered.length === 0 ? name : `${name}<${rendered.join(", ")}>`;
      return { text, io, kind: false };
    }
    // A name declared in the module shadows Base; anything else is Base.
    if (decl !== undefined || def !== undefined) return plain("unknown");
  }
  if (type.call) {
    const call = BASE_CALLS.get(type.name);
    return plain(call === undefined ? "unknown" : call(args()));
  }
  const rule = BASE.get(type.name);
  if (rule === undefined) return plain("unknown");
  const roles: TypeParamRole[] = [
    ...Array<TypeParamRole>(rule.quantities).fill("quantity"),
    ...Array<TypeParamRole>(rule.types).fill("type"),
  ];
  const kept = typeArgs(type.args, roles);
  if (kept === undefined) return plain("unknown");
  return plain(rule.render(kept.map((arg) => render(arg, scope).text)));
}

/** True when a type-level def's body is IO, directly or through other aliases. */
function aliasIo(def: DefDecl, module: Module, scope: Scope, args: readonly TypeExpr[]): boolean {
  const key = `${module.file}#${def.name}`;
  if (!isTypeLevel(def) || def.body === undefined || scope.expanding.has(key)) return false;
  let body: TypeExpr;
  try {
    body = parseTypeText(def.body);
  } catch {
    return false;
  }
  const params = new Set(def.params.map((p) => p.name));
  const expanding = new Set([...scope.expanding, key]);
  // Arguments are rendered in the caller's scope and bound to parameters by position.
  const ioParams = new Set(
    def.params.flatMap((p, i) => {
      const arg = args[i];
      return arg !== undefined && render(arg, scope).io ? [p.name] : [];
    }),
  );
  return render(body, { module, params, naming: scope.naming, expanding, ioParams }).io;
}

/** A rendered declaration for a module's own types and type-level aliases. */
export function renderTypes(module: Module, naming: Naming): string[] {
  const lines: string[] = [];
  for (const decl of module.types.values()) {
    const params = decl.params.filter((p) => p.role === "type").map((p) => p.name);
    const scope: Scope = { module, params: new Set(params), naming, expanding: new Set() };
    const ctors = decl.ctors.map((ctor) => {
      const fields = ctor.fields.map(
        (f) => `; ${JSON.stringify(f.name)}: ${render(f.type, scope).text}`,
      );
      return `{ $: ${JSON.stringify(ctor.name)}${fields.join("")} }`;
    });
    const generics = params.length === 0 ? "" : `<${params.map(identifier).join(", ")}>`;
    lines.push(
      `export type ${identifier(decl.name)}${generics} = ${ctors.length === 0 ? "never" : ctors.join(" | ")};`,
    );
  }
  for (const def of module.defs.values()) {
    const body = aliasBody(def);
    if (body === undefined || module.types.has(def.name)) continue;
    const params = def.params.map((p) => p.name);
    const scope: Scope = { module, params: new Set(params), naming, expanding: new Set() };
    const generics = params.length === 0 ? "" : `<${params.map(identifier).join(", ")}>`;
    lines.push(`export type ${identifier(def.name)}${generics} = ${render(body, scope).text};`);
  }
  return lines;
}

/** What a def looks like from JavaScript, given the compiled arity. */
export type Signature =
  | { kind: "function"; text: string; generics: string; params: string; result: string }
  | { kind: "io" }
  | { kind: "type-level" }
  | { kind: "proof" }
  | { kind: "mismatch"; expected: number; found: number };

export function renderSignature(
  def: DefDecl,
  module: Module,
  naming: Naming,
  arity: number,
): Signature {
  if (def.result === undefined) return { kind: "proof" };
  if (isTypeLevel(def)) return { kind: "type-level" };
  const generics = def.params
    .filter((p) => p.mode === "erased" && isKindExpr(p.type))
    .map((p) => p.name);
  const scope: Scope = { module, params: new Set(generics), naming, expanding: new Set() };
  // An untyped parameter of a typed def is a quantity, as in `Map.new(a, ...)`.
  const runtime = def.params.filter(
    (p) => (p.mode === "plain" || p.mode === "dup") && p.type !== undefined,
  );
  const params: { name: string; type: string }[] = runtime.map((p) => ({
    name: identifier(p.name),
    type: p.type === undefined ? "unknown" : render(p.type, scope).text,
  }));
  // Bend uncurries a def whose result is a function: `f(x) -> A -> B` takes two.
  let result = def.result;
  while (params.length < arity && result.kind === "arrow" && !result.erased) {
    params.push({ name: `arg${params.length}`, type: render(result.from, scope).text });
    result = result.to;
  }
  if (params.length !== arity) return { kind: "mismatch", expected: arity, found: params.length };
  const rendered = render(result, scope);
  if (rendered.io) return { kind: "io" };
  const used = new Set<string>();
  const list = params
    .map((p) => {
      let name = p.name;
      while (used.has(name)) name = `${name}_`;
      used.add(name);
      return `${name}: ${p.type}`;
    })
    .join(", ");
  const typeParams = generics.length === 0 ? "" : `<${generics.map(identifier).join(", ")}>`;
  return {
    kind: "function",
    text: `${typeParams}(${list}) => ${rendered.text}`,
    generics: typeParams,
    params: list,
    result: rendered.text,
  };
}
