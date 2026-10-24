import { useMutation, useQuery } from "@tanstack/react-query";
import { Link, useMatchRoute, useNavigate, useSearch } from "@tanstack/react-router";
import { mutationOptions, queryOptions, type ResponseOf } from "bendo/query";
import { useId, useState, type FormEvent } from "react";
import { API_BASE, SHOWS, describeFailure, todos, type Show } from "./api.ts";
import { NO_VERDICT, useBrowserCheck, type Verdict } from "./check.ts";
import { CheckIcon, TrashIcon } from "./icons.tsx";
import { TITLE_LIMIT, checkCreate } from "./rules.ts";
import { VerdictLine } from "./Verdict.tsx";

export type Todo = ResponseOf<typeof todos.get>["todos"][number];

const SHOW_LABELS: Record<Show, string> = { all: "All", active: "Active", done: "Done" };

export function TodoList() {
  const { show } = useSearch({ from: "__root__" });
  const list = useQuery(queryOptions(todos.get, { query: { show } }));
  const counts = list.data?.counts;
  return (
    <section className="list" aria-labelledby="list-title">
      <h2 id="list-title" className="visually-hidden">
        Your todos
      </h2>
      <Composer />
      <nav className="filters" aria-label="Filter todos">
        {SHOWS.map((value) => (
          <Link
            key={value}
            to="."
            search={{ show: value }}
            className="filter"
            aria-current={value === show ? "page" : undefined}
          >
            {SHOW_LABELS[value]}
            <span className="filter-count">{counts === undefined ? "–" : counts[value]}</span>
          </Link>
        ))}
      </nav>
      {list.isPending ? (
        <ul className="rows" aria-busy="true" aria-label="Loading todos">
          {[0, 1, 2].map((n) => (
            <li key={n} className="row row-skeleton" />
          ))}
        </ul>
      ) : list.isError ? (
        <div className="notice" role="alert">
          <p className="notice-title">The API is not answering</p>
          <p>
            Start it from <code>examples/todo</code> with <code>bun run api</code>, then reload. The
            page expects it at <code>{API_BASE}</code>.
          </p>
        </div>
      ) : list.data.todos.length === 0 ? (
        <Empty show={show} />
      ) : (
        <ul className="rows">
          {list.data.todos.map((todo) => (
            <TodoRow key={todo.id} todo={todo} />
          ))}
        </ul>
      )}
    </section>
  );
}

function Empty({ show }: { show: Show }) {
  const text: Record<Show, string> = {
    all: "No todos yet. Add one above.",
    active: "Nothing left to do.",
    done: "Nothing finished yet.",
  };
  return <p className="empty">{text[show]}</p>;
}

function Composer() {
  const browserCheck = useBrowserCheck();
  const [title, setTitle] = useState("");
  const [verdict, setVerdict] = useState<Verdict>(NO_VERDICT);
  const create = useMutation(mutationOptions(todos.post, { invalidates: [todos] }));
  const verdictId = useId();
  const counterId = useId();

  function onSubmit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    const body = { title };
    if (browserCheck) {
      const issues = checkCreate(body);
      if (issues.length > 0) {
        setVerdict({ kind: "browser", issues });
        document.getElementById("new-title")?.focus();
        return;
      }
    }
    setVerdict(NO_VERDICT);
    create.mutate(
      { body },
      {
        onSuccess: () => setTitle(""),
        onError: (error) => setVerdict({ kind: "server", rejection: describeFailure(error) }),
      },
    );
  }

  // Once an attempt failed in the browser, re-check on every keystroke so the
  // message clears as soon as the title is fixed.
  function onChange(next: string): void {
    setTitle(next);
    if (verdict.kind === "browser") {
      const issues = checkCreate({ title: next });
      setVerdict(issues.length === 0 ? NO_VERDICT : { kind: "browser", issues });
    } else if (verdict.kind === "server") setVerdict(NO_VERDICT);
  }

  const length = [...title].length;
  const invalid = verdict.kind !== "none";
  return (
    <form className="composer" noValidate onSubmit={onSubmit}>
      <label className="visually-hidden" htmlFor="new-title">
        New todo
      </label>
      <div className="composer-field" data-invalid={invalid ? "true" : undefined}>
        <input
          id="new-title"
          name="title"
          placeholder="What needs doing?"
          autoComplete="off"
          value={title}
          aria-invalid={invalid ? true : undefined}
          aria-describedby={`${counterId}${invalid ? ` ${verdictId}` : ""}`}
          onChange={(event) => onChange(event.currentTarget.value)}
        />
        <span
          id={counterId}
          className="counter"
          data-over={length > TITLE_LIMIT ? "true" : undefined}
          aria-label={`${length} of ${TITLE_LIMIT} characters`}
        >
          {length}/{TITLE_LIMIT}
        </span>
        <button className="button button-primary" type="submit" disabled={create.isPending}>
          {create.isPending ? "Adding…" : "Add"}
        </button>
      </div>
      <VerdictLine verdict={verdict} id={verdictId} />
    </form>
  );
}

function TodoRow({ todo }: { todo: Todo }) {
  const navigate = useNavigate();
  const matchRoute = useMatchRoute();
  const selected = matchRoute({ to: "/todos/$id", params: { id: String(todo.id) } }) !== false;
  const item = todos({ id: todo.id });
  const toggle = useMutation(mutationOptions(item.patch, { invalidates: [todos] }));
  const remove = useMutation(
    mutationOptions(item.delete, {
      invalidates: [todos],
      onSuccess: () => {
        if (selected) void navigate({ to: "/", search: (prev) => ({ show: prev.show ?? "all" }) });
      },
    }),
  );
  // Show the new state while the request and the refetch are in flight.
  const done = toggle.isPending ? (toggle.variables?.body?.done ?? todo.done) : todo.done;
  return (
    <li
      className="row"
      data-done={done ? "true" : undefined}
      data-selected={selected ? "true" : undefined}
      data-leaving={remove.isPending ? "true" : undefined}
    >
      <button
        type="button"
        className="tick"
        role="checkbox"
        aria-checked={done}
        aria-label={`${todo.title}: ${done ? "done" : "not done"}`}
        onClick={() => toggle.mutate({ body: { done: !done } })}
      >
        <CheckIcon />
      </button>
      <Link
        to="/todos/$id"
        params={{ id: String(todo.id) }}
        search={(prev) => ({ show: prev.show ?? "all" })}
        className="row-title"
      >
        {todo.title}
      </Link>
      <button
        type="button"
        className="icon-button row-delete"
        aria-label={`Delete “${todo.title}”`}
        disabled={remove.isPending}
        onClick={() => remove.mutate()}
      >
        <TrashIcon />
      </button>
    </li>
  );
}
