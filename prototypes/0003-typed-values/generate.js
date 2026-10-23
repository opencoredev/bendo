// A bounded generator for this spike's three field forms, not bendo gen.
import { mkdirSync, readFileSync, writeFileSync, copyFileSync } from "node:fs";
import { resolve, join } from "node:path";
import { pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";
import { compile } from "../../tests/harness.ts";

const source = import.meta.dirname;
const out = resolve(process.argv[2] ?? join(source, "generated"));
mkdirSync(out, { recursive: true });
function run(args) {
  const result = spawnSync(args[0], args.slice(1), { encoding: "utf8", timeout: 30000 });
  if (result.status !== 0) throw new Error(`${args.join(" ")}\n${result.stdout}\n${result.stderr}`);
}
copyFileSync(compile(join(source, "schema.bend"), "mjs"), join(out, "schema.mjs"));
const { default: schemaModule } = await import(pathToFileURL(join(out, "schema.mjs")).href);
const schema = schemaModule.todo_schema();
const fields = [];
for (let list = schema.fields; list.$ === "Con"; list = list.tail) fields.push(list.head);
const forms = {
  "StringField/RequiredField": {
    bend: "String",
    reader: "read_string",
    json: { type: "string" },
  },
  "StringField/OptionalField": {
    bend: "Maybe<&2, String>",
    reader: "read_optional_string",
    json: { type: "string" },
  },
  "BooleanField/DefaultFalse": {
    bend: "Bool",
    reader: "read_flag",
    json: { type: "boolean", default: false },
  },
};
for (const field of fields) {
  if (!/^[a-z][a-z_]*$/.test(field.name)) throw new Error("unsupported field name");
  field.form = forms[`${field.scalar.$}/${field.presence.$}`];
  if (!field.form) throw new Error("unsupported field form");
}
const quoted = (s) => JSON.stringify(s);
const properties = Object.fromEntries(fields.map((f) => [f.name, f.form.json]));
const jsonSchema = {
  $schema: "https://json-schema.org/draft/2020-12/schema",
  type: "object",
  properties,
  required: fields.filter((f) => f.presence.$ === "RequiredField").map((f) => f.name),
  additionalProperties: false,
};
const responseSchema = {
  ...jsonSchema,
  required: fields.filter((f) => f.presence.$ !== "OptionalField").map((f) => f.name),
};
const routes = [];
for (let list = schemaModule.routes(); list.$ === "Con"; list = list.tail) {
  const route = list.head;
  routes.push({
    method: route.method,
    path: route.path,
    handler: route.tag.$,
    bodyDecoder: "Todo:body",
    responseDecoder: "Todo:response",
    body: jsonSchema,
    response: responseSchema,
  });
}
const manifest = {
  version: 1,
  schemas: { Todo: jsonSchema, TodoResponse: responseSchema },
  routes,
  validators: {
    Todo: {
      module: "./todo.mjs",
      export: "decode",
      inputAbi: "JsonValue",
      extraFields: "reject",
      body: { defaults: true, coerce: false },
      query: { defaults: true, booleanStrings: ["true", "1", "false", "0"] },
      response: { defaults: false, coerce: false },
    },
  },
};
writeFileSync(join(out, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
const bend = `# Generated from schema.bend by generate.js. Do not edit.
import Base
import ./value.bend as V

type Todo is Data:
  Todo{${fields.map((f) => `${f.name}: ${f.form.bend}`).join(", ")}}

def known(+name: String) -> Bool:
  ${fields.map((f) => `String.eq(name, ${quoted(f.name)})`).join(" || ")}

def known_fields(fields: List<&2, V.JsonField>) -> Bool:
  match fields:
    case Nil{}:
      True{}
    case V.JsonField{name, value} <> rest:
      known(name) && known_fields(rest)

def decode_object(+fields: List<&2, V.JsonField>, +mode: V.DecodeMode) -> Result<&2, &2, String, Todo>:
  do Result<&2, &2, String, Todo>:
    _ : Unit <- V.require_known(known_fields(fields))
${fields.map((f) => `    ${f.name} : ${f.form.bend} <- V.${f.form.reader}(V.lookup(fields, ${quoted(f.name)})${f.form.reader === "read_flag" ? ", mode" : ""})`).join("\n")}
    return Todo{${fields.map((f) => f.name).join(", ")}}

def decode(value: V.JsonValue, mode: V.DecodeMode) -> Result<&2, &2, String, Todo>:
  match value:
    case V.JsonObject{fields}:
      decode_object(fields, mode)
    case _:
      Fail{"expected object"}
`;
writeFileSync(join(out, "todo.bend"), bend);
for (const file of ["value.bend", "app.bend", "schema.bend"]) {
  copyFileSync(join(source, file), join(out, file));
}
function tsFields(objectSchema) {
  return Object.entries(objectSchema.properties)
    .map(
      ([name, property]) =>
        `  ${name}${objectSchema.required.includes(name) ? "" : "?"}: ${property.type};`,
    )
    .join("\n");
}
const declaration = `// Generated from manifest JSON Schemas. Wire input and normalized response differ.
export interface TodoInput {
${tsFields(manifest.schemas.Todo)}
}
export interface Todo {
${tsFields(manifest.schemas.TodoResponse)}
}
export type Validation = { kind: "ok"; value: Todo } | { kind: "error"; error: string };
export function validateTodo(input: unknown, mode?: "body" | "query" | "response"): Validation;
`;
writeFileSync(join(out, "validator.d.ts"), declaration);
// The bridge contains no field validation: the compiled Bend decoder owns it.
const bridge = readFileSync(join(source, "bridge.js"), "utf8").replace(
  "/* PROJECT_FIELDS */",
  fields
    .map((f) => {
      if (f.presence.$ === "OptionalField")
        return `if (_todo.${f.name}.$ === "Some") value.${f.name} = _todo.${f.name}.value;`;
      return `value.${f.name} = _todo.${f.name};`;
    })
    .join("\n  "),
);
writeFileSync(join(out, "validator.js"), bridge);
copyFileSync(join(source, "page.html"), join(out, "page.html"));
copyFileSync(compile(join(out, "todo.bend"), "mjs"), join(out, "todo.mjs"));
run([
  join(source, "../../node_modules/.bin/oxfmt"),
  "--threads=4",
  ...["manifest.json", "validator.d.ts", "validator.js"].map((file) => join(out, file)),
]);
console.log(`Generated typed decoder, manifest, declarations and shared validator in ${out}`);
