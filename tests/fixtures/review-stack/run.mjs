// Exercise the compiled .mjs in Node's default stack as well as Bun's.
const [modulePath, mode, input] = process.argv.slice(2);
if (!modulePath || !mode || input === undefined) throw new Error("Missing probe arguments");
const { default: api } = await import(modulePath);
let result;
if (mode.startsWith("override-")) {
  result = api.middleware_probe(mode, input)((value) => value);
} else {
  result = api.probe(mode, input);
}
if (typeof result !== "string") throw new Error("Expected a text result");
process.stdout.write(`${result}\n`);
