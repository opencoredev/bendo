import { keepPreviousData, useMutation, useQuery } from "@tanstack/react-query";
import { mutationOptions, queryOptions, type BendoQueryError } from "bendo/query";
import { useState, type FormEvent } from "react";
import { fits, length, max_length } from "../shared/notes.bend";
import { api } from "./api.ts";

function problem(error: BendoQueryError): string {
  switch (error.kind) {
    case "http":
      return error.status === 422
        ? "The server rejected that note."
        : `The server answered ${error.status}.`;
    case "network":
      return "Can't reach the API. Is the Bendo server running?";
    default:
      return error.message;
  }
}

function Greeting() {
  const [name, setName] = useState("");
  const trimmed = name.trim();
  // An empty name leaves the query out, so the server's default applies.
  const hello = useQuery(
    queryOptions(api.hello.get, trimmed === "" ? {} : { query: { name: trimmed } }, {
      placeholderData: keepPreviousData,
    }),
  );
  return (
    <section className="block" aria-labelledby="greeting-title">
      <h2 id="greeting-title" className="block-title">
        GET /api/hello
      </h2>
      <label className="field">
        <span className="label">Name</span>
        <input
          value={name}
          maxLength={40}
          placeholder="world"
          autoComplete="off"
          onChange={(event) => setName(event.target.value)}
        />
      </label>
      <output className="reply" aria-live="polite">
        {hello.isError ? problem(hello.error) : (hello.data?.message ?? "…")}
      </output>
    </section>
  );
}

function Notes() {
  const [text, setText] = useState("");
  const notes = useQuery(queryOptions(api.notes.get));
  const add = useMutation(mutationOptions(api.notes.post, { invalidates: [api.notes] }));
  const max = max_length();
  const used = length(text);
  const ready = fits(text) && !add.isPending;

  function submit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    if (!ready) return;
    add.mutate({ body: { text } }, { onSuccess: () => setText("") });
  }

  return (
    <section className="block" aria-labelledby="notes-title">
      <h2 id="notes-title" className="block-title">
        POST /api/notes
      </h2>
      <form className="compose" onSubmit={submit}>
        <label className="field">
          <span className="label">New note</span>
          <textarea
            value={text}
            rows={3}
            placeholder="Write something short"
            onChange={(event) => setText(event.target.value)}
          />
        </label>
        <div className="compose-foot">
          <span className={used > max ? "count over" : "count"}>
            {used} / {max}
          </span>
          <button type="submit" disabled={!ready}>
            {add.isPending ? "Saving…" : "Add note"}
          </button>
        </div>
        {add.isError ? <p className="error">{problem(add.error)}</p> : null}
      </form>
      {notes.isPending ? (
        <p className="quiet">Loading notes…</p>
      ) : notes.isError ? (
        <p className="error">{problem(notes.error)}</p>
      ) : notes.data.notes.length === 0 ? (
        <p className="quiet">No notes yet. They live in server memory until it restarts.</p>
      ) : (
        <ol className="notes">
          {notes.data.notes.map((note) => (
            <li key={note.id} className="note">
              <span className="note-id">#{note.id}</span>
              <span className="note-text">{note.text}</span>
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

export function Home() {
  return (
    <>
      <h1>Your Bendo app</h1>
      <p className="lede">
        This page calls the API in <code>main.bend</code> through a typed client. Edit a route,
        save, and the server rebuilds.
      </p>
      <Greeting />
      <Notes />
    </>
  );
}
