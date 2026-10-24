/** The supported Bendo JSON Schema vocabulary, parsed once at the codegen boundary. */
export type Schema = { shape: Shape; defaulted: boolean };
type Property = { name: string; schema: Schema; required: boolean };
type Shape =
  | { kind: "unknown" | "never" | "string" | "number" | "boolean" | "null" }
  | { kind: "literal"; text: string }
  | { kind: "array"; items: Schema }
  | { kind: "object"; properties: Property[]; open: boolean }
  | { kind: "union" | "intersection"; members: Schema[] }
  | { kind: "nullable"; inner: Schema };

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function fail(location: string, keyword: string, detail: string): never {
  throw new Error(`Route types: ${location}: keyword ${JSON.stringify(keyword)} ${detail}`);
}

function literal(value: unknown, location: string, keyword: string): string {
  if (value === null) return "null";
  if (typeof value === "string" || typeof value === "boolean") return JSON.stringify(value);
  // JSON.parse can overflow a valid decimal token such as 1e400. TypeScript
  // has no infinity literal type, so retain the JavaScript numeric envelope.
  if (typeof value === "number") return Number.isFinite(value) ? String(value) : "number";
  if (Array.isArray(value)) {
    const items: unknown[] = value;
    return `[${items.map((item) => literal(item, location, keyword)).join(", ")}]`;
  }
  if (isObject(value))
    return `{ ${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}: ${literal(value[key], location, keyword)}`)
      .join("; ")} }`;
  return fail(location, keyword, "must hold a JSON value");
}

const annotations = new Set([
  "$schema",
  "$comment",
  "default",
  "minLength",
  "maxLength",
  "pattern",
  "format",
  "minimum",
  "maximum",
  "minItems",
  "maxItems",
]);
const structure = new Set([
  "type",
  "const",
  "enum",
  "anyOf",
  "allOf",
  "not",
  "properties",
  "required",
  "additionalProperties",
  "items",
]);

export function parseRouteSchema(value: unknown, location: string, depth = 0): Schema {
  if (depth > 256) return fail(location, "schema", "exceeds the 256-level codegen limit");
  const node = (shape: Shape): Schema => ({
    shape,
    defaulted: isObject(value) && Object.hasOwn(value, "default"),
  });
  if (typeof value === "boolean") return node({ kind: value ? "unknown" : "never" });
  if (!isObject(value)) return fail(location, "schema", "must be an object or boolean");
  const child = (input: unknown, key: string): Schema =>
    parseRouteSchema(input, `${location}.${key}`, depth + 1);
  for (const [key, entry] of Object.entries(value)) {
    if (!annotations.has(key) && !structure.has(key)) fail(location, key, "is not supported");
    switch (key) {
      case "$schema":
        if (entry !== "https://json-schema.org/draft/2020-12/schema")
          fail(location, key, "must name draft 2020-12");
        break;
      case "$comment":
      case "pattern":
      case "format":
        if (typeof entry !== "string") fail(location, key, "must be a string");
        break;
      case "minLength":
      case "maxLength":
      case "minItems":
      case "maxItems":
        if (
          typeof entry !== "number" ||
          entry < 0 ||
          (entry !== Infinity && !Number.isInteger(entry))
        )
          fail(location, key, "must be a nonnegative integer");
        break;
      case "minimum":
      case "maximum":
        if (typeof entry !== "number") fail(location, key, "must be a number");
        break;
      case "default":
        literal(entry, location, key);
        break;
    }
  }
  const parts: Schema[] = [];
  if (Object.hasOwn(value, "const"))
    parts.push(node({ kind: "literal", text: literal(value.const, location, "const") }));
  if (Object.hasOwn(value, "enum")) {
    if (!Array.isArray(value.enum) || value.enum.length === 0)
      fail(location, "enum", "must be a nonempty array");
    const values: unknown[] = value.enum;
    parts.push(
      node({
        kind: "union",
        members: values.map((entry) =>
          node({ kind: "literal", text: literal(entry, location, "enum") }),
        ),
      }),
    );
  }
  if (Object.hasOwn(value, "type")) {
    switch (value.type) {
      case "string":
      case "boolean":
      case "null":
        parts.push(node({ kind: value.type }));
        break;
      case "number":
      case "integer":
        parts.push(node({ kind: "number" }));
        break;
      case "array":
        if (!Object.hasOwn(value, "items")) fail(location, "items", "is required for an array");
        parts.push(node({ kind: "array", items: child(value.items, "items") }));
        break;
      case "object": {
        if (!isObject(value.properties)) fail(location, "properties", "must be an object");
        if (!Array.isArray(value.required)) fail(location, "required", "must be an array");
        const required = new Set<string>();
        for (const key of value.required) {
          if (typeof key !== "string" || !Object.hasOwn(value.properties, key))
            fail(location, "required", "must name declared properties");
          required.add(key);
        }
        if (typeof value.additionalProperties !== "boolean")
          fail(location, "additionalProperties", "must be a boolean");
        const fields = value.properties;
        const properties = Object.keys(fields)
          .sort()
          .map((name) => ({
            name,
            required: required.has(name),
            schema: child(fields[name], `properties[${JSON.stringify(name)}]`),
          }));
        parts.push(node({ kind: "object", properties, open: value.additionalProperties }));
        break;
      }
      default:
        fail(location, "type", `has unsupported value ${JSON.stringify(value.type)}`);
    }
  }
  for (const key of ["properties", "required", "additionalProperties"]) {
    if (Object.hasOwn(value, key) && value.type !== "object")
      fail(location, key, "requires type object");
  }
  if (Object.hasOwn(value, "items") && value.type !== "array")
    fail(location, "items", "requires type array");
  for (const key of ["anyOf", "allOf"]) {
    if (!Object.hasOwn(value, key)) continue;
    const entries = value[key];
    if (!Array.isArray(entries) || entries.length === 0)
      fail(location, key, "must be a nonempty array");
    const members = entries.map((entry: unknown, index) => child(entry, `${key}[${index}]`));
    const [first, second] = members;
    // BND-37 distinguishes Nullable from Union with the union's first-match comment.
    if (
      key === "anyOf" &&
      members.length === 2 &&
      first?.shape.kind === "null" &&
      second !== undefined &&
      value.$comment !== "Bendo decodes with the first matching member"
    )
      parts.push(node({ kind: "nullable", inner: second }));
    else parts.push(node({ kind: key === "anyOf" ? "union" : "intersection", members }));
  }
  if (Object.hasOwn(value, "not")) {
    child(value.not, "not"); // Check nested keywords even in constraints erased from TS.
    if (!isObject(value.not)) fail(location, "not", "must be the Bendo empty or pattern guard");
    if (Object.keys(value.not).length === 0) parts.push(node({ kind: "never" }));
    else if (Object.keys(value.not).length !== 1 || typeof value.not.pattern !== "string")
      fail(location, "not", "only supports the Bendo pattern guard or {} rejection");
  }
  if (parts.length === 0) return node({ kind: "unknown" });
  if (parts.length === 1 && parts[0] !== undefined) return node(parts[0].shape);
  return node({ kind: "intersection", members: parts });
}

export type Mode = "json" | "text" | "decoded" | "response";

export function schemaType(schema: Schema, mode: Mode): string {
  const shape = schema.shape;
  switch (shape.kind) {
    case "unknown":
    case "never":
    case "string":
    case "null":
      return shape.kind;
    case "number":
      return mode === "text" ? "(number | string)" : "number";
    case "boolean":
      return mode === "text" ? '(boolean | "true" | "false")' : "boolean";
    case "literal":
      return shape.text;
    case "nullable":
      return `(null | ${schemaType(shape.inner, mode)})`;
    case "array":
      return `Array<${schemaType(shape.items, mode)}>`;
    case "union":
      return `(${shape.members.map((member) => schemaType(member, mode === "text" ? "json" : mode)).join(" | ")})`;
    case "intersection":
      return `(${shape.members.map((member) => schemaType(member, mode)).join(" & ")})`;
    case "object": {
      const open = shape.open && mode !== "decoded";
      const fields = shape.properties.map(
        ({ name, required, schema: property }) =>
          `${JSON.stringify(name)}${required || (mode === "decoded" && property.defaulted) ? "" : "?"}: ${schemaType(property, mode)};`,
      );
      if (open) fields.push("[key: string]: unknown;");
      if (fields.length === 0) return "Record<string, never>";
      return `{ ${fields.join(" ")} }`;
    }
    default: {
      const exhaustive: never = shape;
      return exhaustive;
    }
  }
}
