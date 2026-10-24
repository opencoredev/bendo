import { createRootRoute, createRoute, createRouter, Link, Outlet } from "@tanstack/react-router";
import { About } from "./about.tsx";
import { Home } from "./home.tsx";
import { Wire } from "./wire.tsx";

function Layout() {
  return (
    <div className="shell">
      <header className="bar">
        <span className="mark">
          <span className="mark-dot" aria-hidden="true" />
          bendo app
        </span>
        <nav className="nav">
          <Link to="/" activeOptions={{ exact: true }}>
            Notes
          </Link>
          <Link to="/about">About</Link>
        </nav>
      </header>
      <div className="split">
        <main className="page">
          <Outlet />
        </main>
        <Wire />
      </div>
    </div>
  );
}

function NotFound() {
  return (
    <section>
      <h1>Nothing here</h1>
      <p className="lede">
        This page has no route. Add one in <code>src/router.tsx</code>.
      </p>
      <Link to="/">Back to notes</Link>
    </section>
  );
}

const rootRoute = createRootRoute({ component: Layout, notFoundComponent: NotFound });
const homeRoute = createRoute({ getParentRoute: () => rootRoute, path: "/", component: Home });
const aboutRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/about",
  component: About,
});

export const router = createRouter({ routeTree: rootRoute.addChildren([homeRoute, aboutRoute]) });

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
