import { createContext, useContext } from "react";
import type { ServerRejection } from "./api.ts";
import type { Issue } from "./rules.ts";

/** Whether forms run shared/todo.bend before sending. Off shows the server's own rejection. */
export const CheckContext = createContext(true);

export function useBrowserCheck(): boolean {
  return useContext(CheckContext);
}

/** Who stopped the last attempt, if anyone. */
export type Verdict =
  | { kind: "none" }
  | { kind: "browser"; issues: Issue[] }
  | { kind: "server"; rejection: ServerRejection };

export const NO_VERDICT: Verdict = { kind: "none" };
