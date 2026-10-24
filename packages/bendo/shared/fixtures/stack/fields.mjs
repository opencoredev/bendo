// Decodes through an object schema with many declared fields, in Node at its
// default stack. Prints the result tags for a 64 KiB body that sets every
// optional field, and for an empty body against required fields.
const [url, count] = process.argv.slice(2);
const bendo = (await import(url)).default;
const find = (suffix) => {
  const key = Object.keys(bendo).find((k) => k.endsWith(suffix));
  if (key === undefined) throw new Error(`missing ${suffix}`);
  return bendo[key];
};
const decode = find("src/data/schema:decode");
const parse = find("src/data/json:parse_string");
const list = (xs) => xs.reduceRight((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
const n = Number(count);
const number = { $: "NumberSchema", min: { $: "None" }, max: { $: "None" } };
const schema = (presence) => ({
  $: "ObjectSchema",
  fields: list(
    Array.from({ length: n }, (_, i) => ({
      $: "Field",
      key: `f${i}`,
      schema: number,
      presence: { $: presence },
    })),
  ),
  unknown: { $: "Strict" },
});
const digits = "9".repeat(Math.ceil((64 * 1024) / n));
const body = parse(`{${Array.from({ length: n }, (_, i) => `"f${i}":${digits}`).join(",")}}`);
const empty = parse("{}");
if (body.$ !== "Done" || empty.$ !== "Done") throw new Error("parse failed");
console.log(decode(schema("Optional"), body.value).$, decode(schema("Required"), empty.value).$);
