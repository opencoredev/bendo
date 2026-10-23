import TodoDecoder from "./todo.mjs";

// JSON.parse owns JSON syntax for this spike. This adapter preserves value types.
export function toBend(input) {
  if (input === null) return { $: "JsonNull" };
  if (typeof input === "string") return { $: "JsonString", value: input };
  if (typeof input === "boolean") return { $: "JsonBool", value: input };
  if (typeof input === "number") return { $: "JsonNumber", value: String(input) };
  if (Array.isArray(input)) return { $: "JsonArray" };
  if (typeof input === "object") {
    let fields = { $: "Nil" };
    for (const [name, value] of Object.entries(input).reverse()) {
      fields = { $: "Con", head: { $: "JsonField", name, value: toBend(value) }, tail: fields };
    }
    return { $: "JsonObject", fields };
  }
  throw new TypeError("expected JSON value");
}

export function validateTodo(input, mode = "response") {
  const modes = { body: "BodyMode", query: "QueryMode", response: "ResponseMode" };
  if (!Object.hasOwn(modes, mode)) throw new TypeError("unknown decode mode");
  const result = TodoDecoder.decode(toBend(input), { $: modes[mode] });
  if (result.$ === "Fail") return { kind: "error", error: result.error };
  const _todo = result.value;
  const value = {};
  value.title = _todo.title;
  value.done = _todo.done;
  if (_todo.due.$ === "Some") value.due = _todo.due.value;
  return { kind: "ok", value };
}
