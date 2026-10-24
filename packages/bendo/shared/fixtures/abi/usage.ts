// Typed usage of the generated abi.mjs. abi.test.ts runs `tsc --noEmit` over
// this file, so every @ts-expect-error below must be a real type error, and
// then imports it so each `same` call also compares the runtime value.
import bendo, {
  add_u32,
  adder,
  apply,
  bag_full,
  bag_short,
  boxed,
  brightness,
  color,
  counts,
  dup_list,
  filled,
  first_fn,
  greet,
  half,
  initial,
  letter,
  lookup,
  measure,
  names,
  negate,
  next_nat,
  nothing,
  order,
  pair,
  parse_flag,
  pile_full,
  pile_short,
  reserved,
  shape,
  shapes,
  short_list,
  short_maybe,
  short_result,
  side,
  singleton,
  total,
  unbox,
  type Color,
  type List,
  type Result,
  type class_ as ClassNs,
  type default_ as DefaultNs,
  type shapes as Shapes,
} from "./dist/abi.mjs";

export type Check = { name: string; actual: unknown; expected: unknown };
export const checks: Check[] = [];

/** The expected value must have the declared type of `actual`. */
function same<T>(name: string, actual: T, expected: NoInfer<T>): void {
  checks.push({ name, actual, expected });
}

function list<A>(...items: A[]): List<A> {
  return items.reduceRight<List<A>>((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
}

function describe(c: Color): string {
  switch (c.$) {
    case "Red":
      return "red";
    case "Rgb":
      return `rgb(${c.r}, ${c.g}, ${c.b})`;
    default: {
      const exhaustive: never = c;
      return exhaustive;
    }
  }
}

function flag(r: Result<string, boolean>): string {
  return r.$ === "Done" ? String(r.value) : r.error;
}

same("Nat is a number", next_nat(41), 42);
same("U32 is a number", add_u32(4294967295, 1), 0);
same("F32 is a number", half(3), 1.5);
same("Bool is a boolean", negate(true), false);
same("String is a string", greet("é😀"), "hello é😀");
same("Char is a string", letter(), "b");
same("Maybe of Char", initial("😀x"), { $: "Some", value: "😀" });
same("empty Maybe", initial(""), { $: "None" });
same("List of U32", counts(), list(1, 2, 3));
same("List argument", total(list(1, 2, 3), 10), 16);
same("Result Done", parse_flag("yes"), { $: "Done", value: true });
same("Result Fail", parse_flag("maybe"), { $: "Fail", error: "expected yes or no" });
same("Result narrowing", flag(parse_flag("no")), "false");
same("user type, no fields", color(true), { $: "Red" });
same("user type with fields", color(false), { $: "Rgb", r: 1, g: 2, b: 3 });
same("user type argument", brightness({ $: "Rgb", r: 10, g: 20, b: 30 }), 60);
same("exhaustive switch", describe(color(false)), "rgb(1, 2, 3)");
same("generic constructor", boxed("x"), { $: "Box", value: "x" });
same("generic argument", unbox(boxed(7)), 7);
same("recursive generic type", singleton(true), {
  $: "Node",
  left: { $: "Leaf" },
  value: true,
  right: { $: "Leaf" },
});
same("pair is a Tuple", pair(3, "c"), { $: "Tuple", fst: 3, snd: "c" });
same("Either Inl", side(true), { $: "Inl", value: 1 });
same("Either Inr", side(false), { $: "Inr", value: "right" });
same("Cmp", order(1, 2), { $: "LT" });
same("Unit", nothing(), { $: "Unit" });
same("type-level alias", names(), list("ada", "grace"));
same("imported type", shape(true), { $: "Line", length: 7 });
same("imported alias", shapes(), list<Shapes.Shape>({ $: "Dot" }, { $: "Line", length: 2 }));
same("imported type argument", measure({ $: "Line", length: 9 }), 9);
same("uncurried function result", adder(2, 3), 5);
same(
  "function argument",
  apply((n) => n * 2, 21),
  42,
);
same("Array is a JavaScript array", filled(2, 9), [9, 9, 9, 9]);
same("Map", lookup("a").snd, 1);
same("shorthand List", short_list(), list(4, 5));
same("shorthand reusable List", dup_list(), list(6));
same("shorthand Maybe", short_maybe("a"), { $: "Some", value: "a" });
same("shorthand Result", short_result(false), { $: "Fail", error: "no" });
same("shorthand user type", bag_short(3), { $: "Bag", items: list(3) });
same("explicit user type", bag_full(4), { $: "Bag", items: list(4, 4) });
same("shorthand imported type", pile_short(1), { $: "Pile", top: { $: "Some", value: 1 } });
same("explicit imported type", pile_full(2), { $: "Pile", top: { $: "Some", value: 2 } });
same("array of functions", first_fn([(x) => x + 1, (x) => x * 2], 41), 42);
const kept: [DefaultNs.Thing, ClassNs.Thing] = [
  { $: "Default", n: 2 },
  { $: "Class", n: 2 },
];
same("reserved-word namespaces", reserved(2), {
  $: "Tuple",
  fst: kept[0],
  snd: {
    $: "Tuple",
    fst: kept[1],
    snd: { $: "Tuple", fst: { $: "Delete", n: 2 }, snd: { $: "Keyof", n: 2 } },
  },
});
same("default export", bendo.greet("x"), "hello x");
same("imported def on the default export", bendo["../lib/shapes:length"]({ $: "Dot" }), 0);

export function rejected(): void {
  // @ts-expect-error Nat crosses as a number, not a bigint.
  next_nat(1n);
  // @ts-expect-error Color has no Blue constructor.
  if (color(true).$ === "Blue") return;
  // @ts-expect-error Rgb needs every field.
  brightness({ $: "Rgb", r: 1, g: 2 });
  // @ts-expect-error U32 fields are numbers.
  brightness({ $: "Rgb", r: "1", g: 2, b: 3 });
  // @ts-expect-error Fail has no value; narrow on $ first.
  void parse_flag("yes").value;
  // @ts-expect-error Maybe<Char> is not a string.
  const char: string = initial("a");
  void char;
  // @ts-expect-error The generic result keeps its argument type.
  const text: string = unbox(boxed(1));
  void text;
  // @ts-expect-error Imported constructors are checked too.
  measure({ $: "Circle" });
  // @ts-expect-error The declaration takes every argument at once.
  adder(1);
  // @ts-expect-error Tuple's fst here is a U32.
  const first: string = pair(1, "a").fst;
  void first;
  // @ts-expect-error Lists are Con/Nil objects, not arrays.
  total([1, 2, 3], 0);
  // @ts-expect-error The default export is typed per key.
  bendo["../lib/shapes:length"]({ $: "Line" });
  // @ts-expect-error A function argument gets a Nat.
  apply((s: string) => s.length, 1);
  // @ts-expect-error A shorthand user type keeps its element type.
  const words: List<string> = bag_short(1).items;
  void words;
  // @ts-expect-error So does a shorthand imported type.
  const pile: Shapes.Pile<string> = pile_short(1);
  void pile;
  // @ts-expect-error The argument is an array of functions, not a function.
  first_fn((x: number) => [x], 1);
  // @ts-expect-error Each element is a function.
  first_fn([1], 1);
  // @ts-expect-error A namespace keeps its module's constructors.
  const thing: DefaultNs.Thing = { $: "Class", n: 1 };
  void thing;
}
