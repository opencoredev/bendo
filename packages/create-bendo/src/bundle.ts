// prepack: copy the Bend library and its toolchain pins into bend/, so a packed
// create-bendo can write apps without a Bendo checkout. Run from the checkout.
import { cpSync, existsSync, mkdirSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { PINS } from "./create.ts";

const packageDir = resolve(import.meta.dir, "..");
const root = resolve(packageDir, "../..");
if (!existsSync(join(root, "src/main.bend")))
  throw new Error(`prepack must run inside a Bendo checkout (no ${join(root, "src/main.bend")})`);
const out = join(packageDir, "bend");
rmSync(out, { recursive: true, force: true });
mkdirSync(out);
cpSync(join(root, "src"), join(out, "src"), { recursive: true });
for (const pin of PINS) cpSync(join(root, pin), join(out, pin));
