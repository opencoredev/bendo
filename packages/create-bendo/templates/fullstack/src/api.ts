import { createClient, type Fetch } from "bendo/client";
import type { Routes } from "../.bendo/routes.ts";
import { schemas } from "../.bendo/routes.schemas.ts";

// One line per request the typed client sends, shown in the wire panel.
export type Exchange = {
  id: number;
  method: string;
  path: string;
  outcome: { kind: "response"; status: number } | { kind: "cancelled" } | { kind: "failed" };
  ms: number;
};

const limit = 8;
let exchanges: readonly Exchange[] = [];
let nextId = 1;
const listeners = new Set<() => void>();

function record(exchange: Omit<Exchange, "id">): void {
  exchanges = [{ id: nextId++, ...exchange }, ...exchanges].slice(0, limit);
  for (const listener of listeners) listener();
}

export const wire = {
  subscribe(listener: () => void): () => void {
    listeners.add(listener);
    return () => listeners.delete(listener);
  },
  snapshot: (): readonly Exchange[] => exchanges,
};

const recorded: Fetch = async (input, init) => {
  const url = new URL(input);
  const method = init.method ?? "GET";
  const path = `${url.pathname}${url.search}`;
  const started = performance.now();
  const elapsed = () => Math.round(performance.now() - started);
  try {
    const response = await fetch(input, init);
    record({ method, path, outcome: { kind: "response", status: response.status }, ms: elapsed() });
    return response;
  } catch (cause) {
    // TanStack Query aborts a request when its result is no longer wanted.
    const outcome: Exchange["outcome"] = init.signal?.aborted
      ? { kind: "cancelled" }
      : { kind: "failed" };
    record({ method, path, outcome, ms: elapsed() });
    throw cause;
  }
};

// Vite proxies /api to the Bendo server in development; in production the
// same server sends this page, so the page's own origin is the API's origin.
const client = createClient<Routes>(window.location.origin, { schemas, fetch: recorded });

export const api = client.api;
