// Pure request-side helpers. `shapes` mirrors the `Steps` type in ./types.ts.

export type Step =
  | { kind: "static"; name: string }
  | { kind: "capture"; name: string; value: unknown }
  | { kind: "invalid"; reason: string };

/**
 * The step sequences a route pattern accepts from the client tree. Static
 * text stays as written and each capture becomes `:name`. An optional capture
 * may end the path, an interior `*` takes no segment, a final `*` is the
 * capture `:*`, and a prefix wildcard `assets*` is the static `assets`.
 */
export function shapes(pattern: string): string[][] {
  const raw = pattern === "/" ? [] : pattern === "*" ? ["*"] : pattern.slice(1).split("/");
  const results: string[][] = [];
  const steps: string[] = [];
  for (const [index, segment] of raw.entries()) {
    const last = index === raw.length - 1;
    if (segment.startsWith(":")) {
      const optional = segment.endsWith("?");
      const body = optional ? segment.slice(1, -1) : segment.slice(1);
      const brace = body.indexOf("{");
      if (optional) results.push([...steps]);
      steps.push(`:${brace === -1 ? body : body.slice(0, brace)}`);
    } else if (segment === "*") {
      if (last) steps.push(":*");
    } else if (segment.startsWith("*")) steps.push(`:${segment.slice(1)}`);
    else if (segment.endsWith("*")) steps.push(segment.slice(0, -1));
    else steps.push(segment);
  }
  results.push(steps);
  return results;
}

/** The chain's shape in the same terms as `shapes`. An invalid step matches no row. */
export function chainShape(steps: readonly Step[]): string[] {
  return steps.map((step) => {
    switch (step.kind) {
      case "static":
        return step.name;
      case "capture":
        return `:${step.name}`;
      case "invalid":
        return "\u0000";
      default: {
        const exhaustive: never = step;
        return exhaustive;
      }
    }
  });
}

/** A capture call takes one object with exactly one key: the capture's name. */
export function captureStep(params: unknown): Step {
  if (typeof params !== "object" || params === null)
    return { kind: "invalid", reason: "a capture call takes an object such as { id }" };
  const entries = Object.entries(params);
  const [entry] = entries;
  if (entry === undefined || entries.length !== 1)
    return { kind: "invalid", reason: "a capture call takes exactly one key, the capture name" };
  return { kind: "capture", name: entry[0], value: entry[1] };
}

export type Built<T> = { ok: true; value: T } | { ok: false; reason: string };

export function text(value: unknown): string | undefined {
  switch (typeof value) {
    case "string":
      return value;
    case "number":
    case "bigint":
      return String(value);
    case "boolean":
      return value ? "true" : "false";
    default:
      return undefined;
  }
}

/**
 * Percent-encodes each capture with encodeURIComponent, so `/` travels as
 * `%2F`; Bendo decodes it back for one-segment captures, spans and wildcards
 * alike. `.` and `..` cannot be sent: the URL parser would remove them.
 */
export function pathOf(steps: readonly Step[]): Built<string> {
  const parts: string[] = [];
  for (const step of steps) {
    switch (step.kind) {
      case "static":
        parts.push(step.name);
        break;
      case "capture": {
        const value = text(step.value);
        if (value === undefined)
          return {
            ok: false,
            reason: `capture ${step.name} must be a string, number, bigint or boolean`,
          };
        if (value === "." || value === "..")
          return {
            ok: false,
            reason: `capture ${step.name} cannot be "${value}"; URLs remove dot segments`,
          };
        parts.push(encodeURIComponent(value));
        break;
      }
      case "invalid":
        return { ok: false, reason: step.reason };
      default: {
        const exhaustive: never = step;
        return exhaustive;
      }
    }
  }
  return { ok: true, value: `/${parts.join("/")}` };
}

/**
 * Bendo's text coercion: an array is one key repeated per item, numbers use
 * their JavaScript string form and booleans are `true` or `false`.
 * `undefined` omits the key, so an empty array sends nothing.
 */
export function textEntries(record: unknown, slot: string): Built<[string, string][]> {
  if (record === undefined) return { ok: true, value: [] };
  if (typeof record !== "object" || record === null || Array.isArray(record))
    return { ok: false, reason: `${slot} must be an object` };
  const entries: [string, string][] = [];
  for (const [key, value] of Object.entries(record)) {
    if (value === undefined) continue;
    for (const item of Array.isArray(value) ? value : [value]) {
      const serialized = text(item);
      if (serialized === undefined)
        return {
          ok: false,
          reason: `${slot}.${key} must be text, a number, a boolean, or an array of them`,
        };
      entries.push([key, serialized]);
    }
  }
  return { ok: true, value: entries };
}
