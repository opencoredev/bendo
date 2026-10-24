import { useEffect, useState, useSyncExternalStore, type FormEvent } from "react";
import { Composer } from "./Composer.tsx";
import { isRoomId, length, MAX_NAME, ROOMS, type RoomId } from "./protocol.ts";
import { Mark, Transcript } from "./Transcript.tsx";
import { useChat, type Status } from "./useChat.ts";

const NAME_KEY = "bendo-chat:name";

function readName(): string | null {
  const saved = localStorage.getItem(NAME_KEY)?.trim();
  return saved === undefined || saved === "" ? null : saved;
}

function subscribeHash(onChange: () => void) {
  window.addEventListener("hashchange", onChange);
  return () => window.removeEventListener("hashchange", onChange);
}

/** The room in the URL hash (`#random`), or general. */
function useRoom(): RoomId {
  const hash = useSyncExternalStore(subscribeHash, () => location.hash.slice(1));
  return isRoomId(hash) ? hash : "general";
}

function nameProblem(name: string): string | null {
  const n = length(name.trim());
  if (n === 0) return "Pick a name so people know who's talking.";
  if (n > MAX_NAME) return `Keep it to ${MAX_NAME} characters.`;
  if (/\p{Cc}/u.test(name)) return "Use letters, numbers and punctuation only.";
  return null;
}

function NameGate({
  initial,
  room,
  onDone,
}: {
  initial: string;
  room: RoomId;
  onDone: (name: string) => void;
}) {
  const [name, setName] = useState(initial);
  const [touched, setTouched] = useState(false);
  const problem = nameProblem(name);

  function submit(event: FormEvent) {
    event.preventDefault();
    setTouched(true);
    if (problem === null) onDone(name.trim());
  }

  return (
    <main className="gate">
      <form className="gate-card" onSubmit={submit} noValidate>
        <p className="brand">
          <span className="brand-mark" aria-hidden="true" />
          Bendo chat
        </p>
        <h1>What should we call you?</h1>
        <p className="gate-lede">
          Your name shows next to everything you say. It stays in this browser, and you can change
          it later.
        </p>
        <label htmlFor="name">Display name</label>
        <input
          id="name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          autoComplete="nickname"
          autoFocus
          aria-invalid={touched && problem !== null}
          aria-describedby="name-problem"
        />
        <p id="name-problem" className="gate-problem" role="alert">
          {touched ? problem : null}
        </p>
        <button type="submit" className="primary">
          Join #{room}
        </button>
      </form>
    </main>
  );
}

function StatusLine({ status, retry }: { status: Status; retry: () => void }) {
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    if (status.kind !== "reconnecting") return;
    const timer = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(timer);
  }, [status]);
  switch (status.kind) {
    case "connecting":
      return (
        <span className="status connecting" role="status">
          Connecting
        </span>
      );
    case "live":
      return (
        <span className="status live" role="status">
          Live
        </span>
      );
    case "reconnecting": {
      const seconds = Math.max(0, Math.ceil((status.retryAt - now) / 1000));
      return (
        <span className="status down" role="status">
          {seconds > 0 ? `Offline, retrying in ${seconds}s` : "Offline, retrying"}
          <button type="button" className="retry" onClick={retry}>
            Retry now
          </button>
        </span>
      );
    }
    default: {
      const _exhaustive: never = status;
      return _exhaustive;
    }
  }
}

function Occupancy({ online }: { online: number }) {
  return (
    <span className="occupancy" aria-label={`${online} online`}>
      {online}
    </span>
  );
}

function Chat({ name, room, onRename }: { name: string; room: RoomId; onRename: () => void }) {
  const { state, send, retry } = useChat({ room, name });
  const [peopleOpen, setPeopleOpen] = useState(false);
  const topic = ROOMS.find((r) => r.id === room)?.topic ?? "";
  const people = [...state.people].sort((a, b) =>
    a.id === state.you ? -1 : b.id === state.you ? 1 : a.name.localeCompare(b.name),
  );
  const live = state.status.kind === "live";

  useEffect(() => {
    document.title = `#${room} · Bendo chat`;
    setPeopleOpen(false);
  }, [room]);

  const roomLinks = ROOMS.map((r) => (
    <a
      key={r.id}
      href={`#${r.id}`}
      className="room-link"
      aria-current={r.id === room ? "page" : undefined}
    >
      <span className="room-name">
        <span className="hash" aria-hidden="true">
          #
        </span>
        {r.id}
      </span>
      <Occupancy online={state.counts.get(r.id) ?? 0} />
    </a>
  ));

  const roster = (
    <ul className="people" aria-label={`People in #${room}`}>
      {people.map((p) => (
        <li key={p.id}>
          <Mark name={p.name} size="sm" />
          <span className="person-name">{p.name}</span>
          {p.id === state.you && <span className="you">you</span>}
        </li>
      ))}
    </ul>
  );

  return (
    <div className="app">
      <aside className="rail">
        <p className="brand">
          <span className="brand-mark" aria-hidden="true" />
          Bendo chat
        </p>
        <nav aria-label="Rooms">
          <h2 className="rail-heading">Rooms</h2>
          {roomLinks}
        </nav>
        <section className="here" aria-label="Here now">
          <h2 className="rail-heading">
            Here now <span className="count">{live ? people.length : "–"}</span>
          </h2>
          {live && roster}
        </section>
        <footer className="me">
          <Mark name={name} size="sm" />
          <span className="person-name">{name}</span>
          <button type="button" className="quiet" onClick={onRename}>
            Change name
          </button>
        </footer>
      </aside>

      <main className="room">
        <header className="room-head">
          <div className="room-title">
            <h1>
              <span className="hash" aria-hidden="true">
                #
              </span>
              {room}
            </h1>
            <p className="topic">{topic}</p>
          </div>
          <StatusLine status={state.status} retry={retry} />
          <button
            type="button"
            className="people-toggle"
            aria-expanded={peopleOpen}
            aria-controls="people-sheet"
            onClick={() => setPeopleOpen((open) => !open)}
          >
            <span className="sr-only">People here: </span>
            {live ? people.length : "–"}
            <span aria-hidden="true"> here</span>
          </button>
        </header>
        <nav className="room-strip" aria-label="Rooms">
          {roomLinks}
        </nav>
        {peopleOpen && (
          <section id="people-sheet" className="people-sheet" aria-label="Here now">
            {roster}
            <button type="button" className="quiet" onClick={onRename}>
              Change name ({name})
            </button>
          </section>
        )}
        <Transcript
          lines={state.lines}
          you={state.you}
          room={room}
          ready={live}
          truncated={state.truncated}
        />
        <div className="notice-slot" role="status">
          {state.notice !== null && <p className="toast">{state.notice.text}</p>}
        </div>
        <Composer key={room} room={room} live={live} send={send} />
      </main>
    </div>
  );
}

export function App() {
  const [name, setName] = useState(readName);
  const [renaming, setRenaming] = useState(false);
  const room = useRoom();

  if (name === null || renaming)
    return (
      <NameGate
        initial={name ?? ""}
        room={room}
        onDone={(next) => {
          localStorage.setItem(NAME_KEY, next);
          setName(next);
          setRenaming(false);
        }}
      />
    );
  return <Chat name={name} room={room} onRename={() => setRenaming(true)} />;
}
