// Which steps built each client node. Package-internal: `bendo/query` reads it
// to derive query keys from `api.todos({ id }).get`; it is not exported from
// `bendo/client`.
import type { Step } from "./path.ts";

const chains = new WeakMap<object, readonly Step[]>();

export function remember(node: object, steps: readonly Step[]): void {
  chains.set(node, steps);
}

/** The steps of a node returned by `createClient`, or `undefined` for any other value. */
export function chainOf(value: unknown): readonly Step[] | undefined {
  return (typeof value === "object" || typeof value === "function") && value !== null
    ? chains.get(value)
    : undefined;
}
