import { useMutation, useQuery } from "@tanstack/react-query";
import { Link, useNavigate, useParams } from "@tanstack/react-router";
import { invalidate, mutationOptions, queryOptions } from "bendo/query";
import { useId, useState, type FormEvent } from "react";
import { describeFailure, isGone, queryClient, todos } from "./api.ts";
import { NO_VERDICT, useBrowserCheck, type Verdict } from "./check.ts";
import { BackIcon } from "./icons.tsx";
import { TITLE_LIMIT, checkUpdate, type TodoChange } from "./rules.ts";
import type { Todo } from "./TodoList.tsx";
import { VerdictLine } from "./Verdict.tsx";

export function EditPanel() {
  const { id } = useParams({ from: "/todos/$id" });
  // The route takes any text; the API only has positive integer IDs.
  const numeric = /^[1-9]\d{0,8}$/.test(id) ? Number(id) : undefined;
  return (
    <div className="panel">
      <div className="panel-bar">
        <Link to="/" search={(prev) => ({ show: prev.show ?? "all" })} className="back">
          <BackIcon />
          <span>All todos</span>
        </Link>
        <code className="panel-id">GET /api/todos/{id}</code>
      </div>
      {numeric === undefined ? <Missing /> : <Loaded id={numeric} />}
    </div>
  );
}

function Missing() {
  return (
    <div className="placeholder">
      <p className="placeholder-title">This todo is gone</p>
      <p className="placeholder-note">It was deleted, or the address is wrong.</p>
    </div>
  );
}

function Loaded({ id }: { id: number }) {
  const todo = useQuery(queryOptions(todos({ id }).get));
  if (todo.isPending) return <div className="panel-skeleton" aria-busy="true" />;
  if (todo.isError) {
    if (todo.error.kind === "http" && todo.error.status === 404) return <Missing />;
    return (
      <div className="notice" role="alert">
        <p className="notice-title">Could not load this todo</p>
        <p>{todo.error.message}</p>
      </div>
    );
  }
  return <EditForm key={todo.data.id} todo={todo.data} />;
}

function EditForm({ todo }: { todo: Todo }) {
  const browserCheck = useBrowserCheck();
  const navigate = useNavigate();
  // A field shows the server's value until the user edits it to something
  // else, so a change made elsewhere (the list's checkbox) reaches an open
  // editor, and saving sends only the fields the user changed. A draft equal to
  // the server's value is no draft.
  const [titleDraft, setTitleDraft] = useState<string | undefined>(undefined);
  const [doneDraft, setDoneDraft] = useState<boolean | undefined>(undefined);
  const title = titleDraft ?? todo.title;
  const done = doneDraft ?? todo.done;
  const [verdict, setVerdict] = useState<Verdict>(NO_VERDICT);
  const [saved, setSaved] = useState(false);
  const item = todos({ id: todo.id });
  const save = useMutation(mutationOptions(item.patch, { invalidates: [todos] }));
  const leave = () => void navigate({ to: "/", search: (prev) => ({ show: prev.show ?? "all" }) });
  const remove = useMutation(
    mutationOptions(item.delete, {
      invalidates: [todos],
      onSuccess: leave,
      // Deleted elsewhere already: the outcome the user asked for.
      onError: (error) => {
        if (!isGone(error)) return;
        void invalidate(queryClient, todos);
        leave();
      },
    }),
  );
  const verdictId = useId();
  const changed = title !== todo.title || done !== todo.done;

  function onSubmit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    const body: TodoChange = {
      ...(title !== todo.title ? { title } : {}),
      ...(done !== todo.done ? { done } : {}),
    };
    if (!changed) {
      setTitleDraft(undefined);
      setDoneDraft(undefined);
      setSaved(true);
      return;
    }
    if (browserCheck) {
      const issues = checkUpdate(body);
      if (issues.length > 0) {
        setVerdict({ kind: "browser", issues });
        document.getElementById("edit-title")?.focus();
        return;
      }
    }
    setVerdict(NO_VERDICT);
    save.mutate(
      { body },
      {
        // The fields are read-only while the save is in flight, and the
        // mutation's own onSuccess has already refetched the todo, so the
        // drafts are exactly what was saved.
        onSuccess: () => {
          setTitleDraft(undefined);
          setDoneDraft(undefined);
          setSaved(true);
        },
        onError: (error) => setVerdict({ kind: "server", rejection: describeFailure(error) }),
      },
    );
  }

  function onTitle(next: string): void {
    setTitleDraft(next === todo.title ? undefined : next);
    setSaved(false);
    if (verdict.kind === "browser") {
      const issues = checkUpdate({ title: next });
      setVerdict(issues.length === 0 ? NO_VERDICT : { kind: "browser", issues });
    } else if (verdict.kind === "server") setVerdict(NO_VERDICT);
  }

  const length = [...title].length;
  const invalid = verdict.kind !== "none";
  return (
    <form className="edit" noValidate onSubmit={onSubmit}>
      <div className="field" data-invalid={invalid ? "true" : undefined}>
        <div className="field-head">
          <label htmlFor="edit-title">Title</label>
          <span className="counter" data-over={length > TITLE_LIMIT ? "true" : undefined}>
            {length}/{TITLE_LIMIT}
          </span>
        </div>
        <textarea
          id="edit-title"
          name="title"
          rows={3}
          value={title}
          readOnly={save.isPending}
          aria-invalid={invalid ? true : undefined}
          aria-describedby={invalid ? verdictId : undefined}
          onChange={(event) => onTitle(event.currentTarget.value)}
        />
        <VerdictLine verdict={verdict} id={verdictId} />
      </div>
      <label className="done-toggle">
        <input
          type="checkbox"
          name="done"
          checked={done}
          disabled={save.isPending}
          onChange={(event) => {
            const checked = event.currentTarget.checked;
            setDoneDraft(checked === todo.done ? undefined : checked);
            setSaved(false);
          }}
        />
        <span className="done-box" aria-hidden="true" />
        <span>Done</span>
      </label>
      <div className="edit-actions">
        <button className="button button-primary" type="submit" disabled={save.isPending}>
          {save.isPending ? "Saving…" : "Save changes"}
        </button>
        <span className="saved" role="status">
          {saved && !changed ? "Saved" : ""}
        </span>
        <button
          className="button button-danger"
          type="button"
          disabled={remove.isPending}
          onClick={() => remove.mutate()}
        >
          {remove.isPending ? "Deleting…" : "Delete"}
        </button>
      </div>
      {remove.isError && !isGone(remove.error) ? (
        <VerdictLine
          verdict={{ kind: "server", rejection: describeFailure(remove.error) }}
          id={`${verdictId}-delete`}
        />
      ) : null}
    </form>
  );
}
