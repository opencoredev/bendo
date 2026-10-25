import { cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

/**
 * The Bendo checkout this CLI runs from. `new` copies the checkout's Bend
 * library, so an installed `bendo` package (inside some app's node_modules)
 * refuses rather than copy whatever sits three directories up.
 */
function checkoutRoot(): string {
  const root = resolve(import.meta.dir, "../../..");
  const inCheckout =
    existsSync(resolve(root, ".bend-version")) &&
    existsSync(resolve(root, "src/main.bend")) &&
    existsSync(resolve(root, "packages/bendo/package.json"));
  if (!inCheckout)
    throw new Error(
      "bendo new copies the Bend library from a Bendo checkout. Outside one, create an app with: bun create bendo <dir>",
    );
  return root;
}

export function scaffold(directory: string): void {
  const root = checkoutRoot();
  // mkdir without recursive deliberately refuses existing destinations, even empty ones.
  mkdirSync(directory);
  cpSync(resolve(root, "src"), resolve(directory, "bendo"), { recursive: true });
  writeFileSync(
    resolve(directory, "main.bend"),
    `import Base
import ./bendo/main.bend as B

type Tag is Data:
  Hello{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, B.text(ctx, "Hello from Bendo!"))

def ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Hello{})]))
`,
  );
  writeFileSync(resolve(directory, ".gitignore"), ".cache/\ndist/\nnode_modules/\n");
  writeFileSync(resolve(directory, ".bend-version"), readFileSync(resolve(root, ".bend-version")));
  writeFileSync(
    resolve(directory, "package.json"),
    `${JSON.stringify({ private: true, type: "module", scripts: { dev: "bendo dev", build: "bendo build", start: "bendo start" } }, null, 2)}\n`,
  );
}
