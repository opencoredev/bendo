// Generated from manifest JSON Schemas. Wire input and normalized response differ.
export interface TodoInput {
  title: string;
  done?: boolean;
  due?: string;
}
export interface Todo {
  title: string;
  done: boolean;
  due?: string;
}
export type Validation = { kind: "ok"; value: Todo } | { kind: "error"; error: string };
export function validateTodo(input: unknown, mode?: "body" | "query" | "response"): Validation;
