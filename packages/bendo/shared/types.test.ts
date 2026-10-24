// The Bend header reader behind `bendo build --shared` (src/bend-types.ts).
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import {
  parseModule,
  renderSignature,
  renderTypes,
  type Module,
  type Naming,
} from "../src/bend-types.ts";

const root = resolve(import.meta.dir, "../../..");

/** Parses `/m.bend`; `./x.bend` imports resolve to the given `/x` modules. */
function setup(source: string, others: Module[] = []): { m: Module; naming: Naming } {
  const m = parseModule("/m.bend", source, (path) => `/${basename(path, ".bend")}`);
  const files = new Map([m, ...others].map((x): [string, Module] => [x.file, x]));
  return {
    m,
    naming: {
      prefix: (file) => (file === m.file ? "" : `${file.slice(1)}.`),
      module: (file) => files.get(file),
    },
  };
}

function signature(source: string, name: string, arity: number): string {
  const { m, naming } = setup(source);
  const def = m.defs.get(name);
  if (def === undefined) throw new Error(`no def ${name}`);
  const rendered = renderSignature(def, m, naming, arity);
  return rendered.kind === "function" ? rendered.text : rendered.kind;
}

test.each([
  ["def f(n: Nat, a: U32, x: F32) -> Bool:", 3, "(n: number, a: number, x: number) => boolean"],
  ["def f(s: String) -> Maybe<&2, Char>:", 1, "(s: string) => Maybe<string>"],
  [
    "def f(xs: List<&2, U32>) -> Result<&2, &2, String, Nat>:",
    1,
    "(xs: List<number>) => Result<string, number>",
  ],
  ["def f(-A: Data, +x: A, d: A) -> List<&2, A>:", 2, "<A>(x: A, d: A) => List<A>"],
  ["def f(n: Nat) -> Nat -> Nat:", 2, "(n: number, arg1: number) => number"],
  ["def f(n: Nat) -> Nat -> Nat:", 1, "(n: number) => (arg: number) => number"],
  [
    "def f(g: Nat -> Bool) -> U32 & String:",
    1,
    "(g: (arg: number) => boolean) => Sigma<number, string>",
  ],
  ["def f(-n: Nat, w: Word(n)) -> Pair(U32, Bool):", 1, "(w: Word) => Sigma<number, boolean>"],
  ["def f(e: Either<&2, &2, U32, Unit>) -> Cmp:", 1, "(e: Either<number, Unit>) => Cmp"],
  [
    "def f(a: Array<U32>, m: Map<&2, Nat>) -> Set():",
    2,
    "(a: number[], m: BendMap<number>) => BendMap<Unit>",
  ],
  ["def f(xs: List<U32>) -> Maybe<Char>:", 1, "(xs: List<number>) => Maybe<string>"],
  ["def f(xs: +List<U32>) -> Map<Nat>:", 1, "(xs: List<number>) => BendMap<number>"],
  [
    "def f(e: Either<U32, Unit>) -> Result<String, Nat>:",
    1,
    "(e: Either<number, Unit>) => Result<string, number>",
  ],
  ["def f(p: Result<&2, String, Nat>) -> Nat:", 1, "(p: unknown) => number"],
  [
    "def f(fs: Array<(U32 -> U32)>) -> Array<List<U32>>:",
    1,
    "(fs: ((arg: number) => number)[]) => List<number>[]",
  ],
  ["def f(ok: {x == True{} : Bool}) -> Nat:", 1, "(ok: unknown) => number"],
  ["def f(s: String) -> IO(Unit):", 1, "io"],
  ["def f() -> Data:", 0, "type-level"],
  ["def f(a, b):", 2, "proof"],
  ["def f(a, -V: Kind(a), x: V) -> Maybe<a, V>:", 1, "<V>(x: V) => Maybe<V>"],
  ["def f(x: Nat) -> Nat:", 2, "mismatch"],
])("%s with arity %d renders %s", (header, arity, expected) => {
  expect(signature(`${header}\n  x\n`, "f", arity)).toBe(expected);
});

test("user types render as unions of `$`-tagged objects with type parameters", () => {
  const { m, naming } = setup(
    [
      "type Tree<-A: Data> is Data:",
      "  Leaf{}",
      "  # a comment between constructors",
      "  Node{left: Tree<A>, value: A, right: Tree<A>}",
      "type Counted<a, -A: Kind(a), -n: Nat> is Kind(a):",
      "  Counted{items: List<a, A>,",
      "    size: Nat}",
      "def Forest(-A: Data) -> Data:",
      "  List<&2, Tree<A>>",
      "def Value(s: Nat) -> Data:",
      "  match s:",
      "    case _: Nat",
    ].join("\n"),
  );
  expect(renderTypes(m, naming)).toEqual([
    'export type Tree<A> = { $: "Leaf" } | { $: "Node"; "left": Tree<A>; "value": A; "right": Tree<A> };',
    'export type Counted<A> = { $: "Counted"; "items": List<A>; "size": number };',
    "export type Forest<A> = List<Tree<A>>;",
  ]);
});

test("a use of a type may omit its quantities", () => {
  const lib = parseModule(
    "/lib",
    "type Pile<a, -A: Kind(a), -n: Nat> is Kind(a):\n  Pile{top: Maybe<a, A>}\n",
    (path) => path,
  );
  const { m, naming } = setup(
    [
      "import ./lib.bend as L",
      "type Bag<a, -A: Kind(a)> is Kind(a):",
      "  Bag{items: List<a, A>, more: Bag<A>}",
      "type Two<a, b, -A: Kind(a), -B: Kind(b)> is Kind(a <&> b):",
      "  Two{a: A, b: B}",
    ].join("\n"),
    [lib],
  );
  expect(renderTypes(m, naming)).toEqual([
    'export type Bag<A> = { $: "Bag"; "items": List<A>; "more": Bag<A> };',
    'export type Two<A, B> = { $: "Two"; "a": A; "b": B };',
  ]);
  const render = (type: string): string => {
    const def = parseModule("/m.bend", `def f(x: ${type}) -> Nat:\n  0n\n`, (p) => p).defs.get("f");
    if (def === undefined) throw new Error("no def");
    const rendered = renderSignature(def, m, naming, 1);
    return rendered.kind === "function" ? rendered.params : rendered.kind;
  };
  expect(render("Bag<U32>")).toBe("x: Bag<number>");
  expect(render("Bag<&2, U32>")).toBe("x: Bag<number>");
  expect(render("Two<U32, String>")).toBe("x: Two<number, string>");
  expect(render("Two<&2, &1, U32, String>")).toBe("x: Two<number, string>");
  expect(render("Two<&2, U32, String>")).toBe("x: unknown");
  expect(render("L.Pile<U32, 3n>")).toBe("x: lib.Pile<number>");
  expect(render("L.Pile<&2, U32, 3n>")).toBe("x: lib.Pile<number>");
});

test("a def returning an IO alias is IO, however the alias is reached", () => {
  const lib = parseModule(
    "/lib",
    "def Effect() -> Type: IO(Unit)\ndef Pure() -> Type: Nat\n",
    (path) => path,
  );
  const { m, naming } = setup(
    [
      "import ./lib.bend as L",
      "def Action() -> Type: IO(Unit)",
      "def Later() -> Type: Action()",
      "def Remote() -> Type: L.Effect()",
      "def Loop() -> Type: Loop()",
      "def Ping() -> Type: Pong()",
      "def Pong() -> Type: Ping()",
      "def a() -> Action(): x",
      "def b() -> Later(): x",
      "def c() -> L.Effect(): x",
      "def d() -> Remote(): x",
      "def e() -> L.Pure(): x",
      "def f() -> Loop(): x",
      "def g() -> Ping(): x",
    ].join("\n"),
    [lib],
  );
  const kinds = ["a", "b", "c", "d", "e", "f", "g"].map((name) => {
    const def = m.defs.get(name);
    if (def === undefined) throw new Error(`no def ${name}`);
    const rendered = renderSignature(def, m, naming, 0);
    return rendered.kind === "function" ? rendered.text : rendered.kind;
  });
  expect(kinds).toEqual(["io", "io", "io", "io", "() => lib.Pure", "() => Loop", "() => Ping"]);
});

test("imported names resolve through their alias and namespace", () => {
  const lib = parseModule(
    "/lib",
    "type Shape is Data:\n  Dot{}\ndef Shapes() -> Data: List<&2, Shape>\n",
    (path) => path,
  );
  const { m, naming } = setup("import ./lib.bend as L\ndef f(s: L.Shape) -> L.Shapes():\n  s\n", [
    lib,
  ]);
  const def = m.defs.get("f");
  if (def === undefined) throw new Error("no def");
  const rendered = renderSignature(def, m, naming, 1);
  expect(rendered.kind === "function" && rendered.text).toBe("(s: lib.Shape) => lib.Shapes");
  expect(renderTypes(lib, naming)).toEqual([
    'export type Shape = { $: "Dot" };',
    "export type Shapes = List<lib.Shape>;",
  ]);
});

test("every Bend file in the repository parses", () => {
  // Walk the tree rather than ask git: test sandboxes may have no .git.
  const files = [...new Bun.Glob("**/*.bend").scanSync({ cwd: root })].filter(
    (file) => !file.split("/").some((part) => part === "node_modules" || part === "dist"),
  );
  expect(files.length).toBeGreaterThan(400);
  for (const file of files) {
    const path = join(root, file);
    expect(() =>
      parseModule(path, readFileSync(path, "utf8"), (p) => resolve(dirname(path), p)),
    ).not.toThrow();
  }
});
