import {
  Outlet,
  createRootRoute,
  createRoute,
  createRouter,
  useMatchRoute,
} from "@tanstack/react-router";
import { useState } from "react";
import { API_BASE, isShow, type Show } from "./api.ts";
import { CheckContext } from "./check.ts";
import { EditPanel } from "./EditPanel.tsx";
import { TodoList } from "./TodoList.tsx";

type Search = { show: Show };

export const rootRoute = createRootRoute({
  validateSearch: (search: Record<string, unknown>): Search => ({
    show: isShow(search.show) ? search.show : "all",
  }),
  component: Shell,
});

const indexRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/",
  component: Placeholder,
});

export const todoRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/todos/$id",
  component: EditPanel,
});

const routeTree = rootRoute.addChildren([indexRoute, todoRoute]);

export const router = createRouter({ routeTree, defaultPreload: "intent" });

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}

function Shell() {
  const [browserCheck, setBrowserCheck] = useState(true);
  const matchRoute = useMatchRoute();
  const editing = matchRoute({ to: "/todos/$id" }) !== false;
  return (
    <CheckContext value={browserCheck}>
      <div className="app" data-editing={editing ? "true" : undefined}>
        <header className="masthead">
          <div className="brand">
            <h1>Todos</h1>
            <p className="meta">
              <span>Bend API</span> <code>{API_BASE.replace(/^https?:\/\//, "")}</code>
              <span aria-hidden="true"> · </span>
              <span>rules</span> <code>shared/todo.bend</code>
            </p>
          </div>
          <label className="switch">
            <input
              type="checkbox"
              role="switch"
              checked={browserCheck}
              onChange={(event) => setBrowserCheck(event.currentTarget.checked)}
            />
            <span className="switch-track" aria-hidden="true">
              <span className="switch-thumb" />
            </span>
            <span className="switch-text">
              <span className="switch-label">Check in the browser</span>
              <span className="switch-note">Turn off to see the server reject it</span>
            </span>
          </label>
        </header>
        <main className="list-pane">
          <TodoList />
        </main>
        <aside className="detail-pane" aria-label="Todo details">
          <Outlet />
        </aside>
      </div>
    </CheckContext>
  );
}

function Placeholder() {
  return (
    <div className="placeholder">
      <p className="placeholder-title">Pick a todo to edit it</p>
      <p className="placeholder-note">
        Titles are checked twice: here by <code>todo.bend</code> compiled to JavaScript, and by the
        same file compiled into the native server.
      </p>
    </div>
  );
}
