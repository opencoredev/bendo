import { QueryClient } from "@tanstack/react-query";
import { createClient } from "bendo/client";
import { isBendoQueryError, type BendoMutationError } from "bendo/query";
import type { Routes } from "../.bendo/routes.ts";
import { schemas } from "../.bendo/routes.schemas.ts";

/** The API's origin: VITE_BENDO_API, or port 8787 on the host that served the page. */
function apiBase(): string {
  const configured: unknown = import.meta.env.VITE_BENDO_API;
  if (typeof configured === "string" && configured !== "") return configured;
  return `${location.protocol}//${location.hostname}:8787`;
}

export const API_BASE = apiBase();

// Responses are checked against the route schemas from `bendo gen`.
export const api = createClient<Routes>(API_BASE, { schemas });

export const todos = api.api.todos;

export type Show = "all" | "active" | "done";
export const SHOWS: readonly Show[] = ["all", "active", "done"];

export function isShow(value: unknown): value is Show {
  return SHOWS.some((show) => show === value);
}

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5_000,
      // A 4xx will fail the same way again.
      retry: (count, error) =>
        count < 2 &&
        isBendoQueryError(error) &&
        (error.kind === "network" || (error.kind === "http" && error.status >= 500)),
    },
  },
});

/** What the server said about a failed write, in words for the page. */
export type ServerRejection = {
  status: number | undefined;
  headline: string;
  details: { field: string; message: string }[];
};

export function describeFailure(error: BendoMutationError): ServerRejection {
  switch (error.kind) {
    case "http": {
      const body = error.error;
      const details =
        body.kind === "bendo"
          ? body.errors.map((e) => ({ field: e.path.join("."), message: e.message }))
          : [];
      const reason = body.kind === "bendo" ? body.error : error.response.statusText;
      return { status: error.status, headline: `${error.status} ${reason}`, details };
    }
    case "network":
      return {
        status: undefined,
        headline: `Could not reach the API at ${API_BASE}.`,
        details: [],
      };
    case "invalid-response":
      return {
        status: error.status,
        headline: "The API answered with a body its route schema does not allow.",
        details: error.issues.map((i) => ({ field: i.path.join("."), message: i.message })),
      };
    case "request":
      return { status: undefined, headline: "The request could not be built.", details: [] };
    default: {
      const _exhaustive: never = error;
      return _exhaustive;
    }
  }
}
