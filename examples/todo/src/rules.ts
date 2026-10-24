// The browser half of the shared validator. vite-plugin-bendo compiles
// ../shared/todo.bend to JavaScript, the same file the API's routes take their
// schemas from, so these checks are the server's decoder running here.
import {
  check_create,
  check_update,
  title_limit,
  type Checked,
  type List,
} from "../shared/todo.bend";

export type Issue = { field: string; message: string };

export const TITLE_LIMIT: number = title_limit();

function toArray<A>(list: List<A>): A[] {
  const out: A[] = [];
  for (let at = list; at.$ === "Con"; at = at.tail) out.push(at.head);
  return out;
}

function issuesOf(checked: Checked): Issue[] {
  switch (checked.$) {
    case "Accepted":
      return [];
    case "Rejected":
      return toArray(checked.issues).map(({ field, message }) => ({ field, message }));
    default: {
      const _exhaustive: never = checked;
      return _exhaustive;
    }
  }
}

export type NewTodo = { title: string; done?: boolean };
export type TodoChange = { title?: string; done?: boolean };

/** Checks the exact JSON text the client will send to POST /api/todos. */
export function checkCreate(body: NewTodo): Issue[] {
  return issuesOf(check_create(JSON.stringify(body)));
}

/** Checks the exact JSON text the client will send to PATCH /api/todos/:id. */
export function checkUpdate(body: TodoChange): Issue[] {
  return issuesOf(check_update(JSON.stringify(body)));
}
