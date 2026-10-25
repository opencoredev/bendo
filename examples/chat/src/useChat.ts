import { useCallback, useEffect, useReducer, useRef } from "react";
import { parseEvent, type Line, type Person, type RoomId, type ServerEvent } from "./protocol.ts";

export type Status =
  | { kind: "connecting" }
  | { kind: "live" }
  | { kind: "reconnecting"; retryAt: number };

/**
 * `next` is the first seq the welcome snapshot left out, or null before this
 * socket's welcome. Lines below it are already counted in `people`. Until the
 * welcome, live lines wait in `early` and `lines` still shows what the last
 * socket saw, so a reconnect doesn't blank the room. `truncated` is true when
 * the welcome left out older lines to fit in one frame.
 */
export type ChatState = {
  status: Status;
  you: number | null;
  next: number | null;
  lines: Line[];
  truncated: boolean;
  early: Line[];
  people: Person[];
  counts: ReadonlyMap<string, number>;
  notice: { id: number; text: string } | null;
};

type Action =
  | { kind: "connecting"; fresh: boolean }
  | { kind: "event"; room: RoomId; event: ServerEvent }
  | { kind: "closed"; retryAt: number }
  | { kind: "dismiss"; id: number }
  | { kind: "refused"; text: string };

const initial: ChatState = {
  status: { kind: "connecting" },
  you: null,
  next: null,
  lines: [],
  truncated: false,
  early: [],
  people: [],
  counts: new Map(),
  notice: null,
};

/** Merges lines by seq, keeping the first copy, in seq order. */
function merge(a: readonly Line[], b: readonly Line[]): Line[] {
  const bySeq = new Map<number, Line>();
  for (const line of [...a, ...b]) if (!bySeq.has(line.seq)) bySeq.set(line.seq, line);
  return [...bySeq.values()].sort((x, y) => x.seq - y.seq);
}

/** Applies arrivals and departures the snapshot in `people` did not include. */
function roster(people: readonly Person[], lines: readonly Line[], next: number): Person[] {
  let out = [...people];
  for (const line of lines) {
    if (line.seq < next) continue;
    switch (line.kind) {
      case "joined":
        if (!out.some((p) => p.id === line.id)) out = [...out, { id: line.id, name: line.name }];
        break;
      case "left":
        out = out.filter((p) => p.id !== line.id);
        break;
      case "said":
        break;
      default: {
        const _exhaustive: never = line;
        return _exhaustive;
      }
    }
  }
  return out;
}

let notices = 0;
function notice(text: string): ChatState["notice"] {
  notices += 1;
  return { id: notices, text };
}

function apply(state: ChatState, room: RoomId, event: ServerEvent): ChatState {
  switch (event.kind) {
    case "welcome": {
      // Lines that beat the welcome to this socket are merged, not lost.
      // The server's seq restarts with it, so the previous socket's lines go.
      const lines = merge(event.history, state.early);
      return {
        ...state,
        status: { kind: "live" },
        you: event.you,
        next: event.next,
        lines,
        truncated: event.truncated,
        early: [],
        people: roster(event.people, lines, event.next),
        counts: new Map(event.rooms.map((r) => [r.id, r.online])),
      };
    }
    case "line": {
      if (event.line.room !== room) return state;
      if (state.next === null) return { ...state, early: merge(state.early, [event.line]) };
      return {
        ...state,
        lines: merge(state.lines, [event.line]),
        people: roster(state.people, [event.line], state.next),
      };
    }
    case "presence":
      return { ...state, counts: new Map(event.rooms.map((r) => [r.id, r.online])) };
    case "error":
      return { ...state, notice: notice(event.reason) };
    default: {
      const _exhaustive: never = event;
      return _exhaustive;
    }
  }
}

function reduce(state: ChatState, action: Action): ChatState {
  switch (action.kind) {
    case "connecting":
      // A new room starts empty. A reconnect keeps the old lines on screen
      // until the welcome replaces them. Room counts stay either way.
      return action.fresh
        ? { ...initial, counts: state.counts }
        : { ...state, status: { kind: "connecting" }, next: null, early: [] };
    case "event":
      return apply(state, action.room, action.event);
    case "closed":
      return { ...state, status: { kind: "reconnecting", retryAt: action.retryAt } };
    case "dismiss":
      return state.notice?.id === action.id ? { ...state, notice: null } : state;
    case "refused":
      return { ...state, notice: notice(action.text) };
    default: {
      const _exhaustive: never = action;
      return _exhaustive;
    }
  }
}

function socketUrl(room: RoomId, name: string): string {
  const scheme = location.protocol === "https:" ? "wss" : "ws";
  return `${scheme}://${location.host}/ws/${room}?name=${encodeURIComponent(name)}`;
}

const NOTICE_MS = 5000;

/**
 * How long an open socket may go without its welcome. The server sends the
 * welcome first, and a refusal always closes the socket, but a stalled server
 * would otherwise leave it open and silent; closing it lands in the usual
 * retry.
 */
const WELCOME_MS = 10_000;

/**
 * One WebSocket to `room`, reopened with backoff (0.5 s doubling to 8 s)
 * whenever it drops. Switching rooms or names closes it and opens another.
 */
export function useChat({ room, name }: { room: RoomId; name: string }) {
  const [state, dispatch] = useReducer(reduce, initial);
  const socket = useRef<WebSocket | null>(null);
  const retryNow = useRef<() => void>(() => {});

  useEffect(() => {
    let disposed = false;
    let attempt = 0;
    let opened = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let welcomeTimer: ReturnType<typeof setTimeout> | undefined;

    function connect() {
      dispatch({ kind: "connecting", fresh: !opened });
      opened = true;
      const ws = new WebSocket(socketUrl(room, name));
      socket.current = ws;
      welcomeTimer = setTimeout(() => ws.close(4000, "no welcome"), WELCOME_MS);
      ws.onmessage = (message) => {
        if (typeof message.data !== "string") return;
        const event = parseEvent(message.data);
        if (event === null) return;
        if (event.kind === "welcome") {
          attempt = 0;
          clearTimeout(welcomeTimer);
        }
        dispatch({ kind: "event", room, event });
      };
      ws.onclose = () => {
        clearTimeout(welcomeTimer);
        if (disposed) return;
        socket.current = null;
        const delay = Math.min(8000, 500 * 2 ** attempt);
        attempt += 1;
        dispatch({ kind: "closed", retryAt: Date.now() + delay });
        timer = setTimeout(connect, delay);
      };
    }

    // Skips the rest of the backoff, but only while waiting to retry.
    function retry() {
      if (disposed || socket.current !== null) return;
      clearTimeout(timer);
      connect();
    }
    retryNow.current = retry;
    const onVisible = () => {
      if (document.visibilityState === "visible") retry();
    };
    window.addEventListener("online", retry);
    document.addEventListener("visibilitychange", onVisible);

    // Deferred, so a mount that is torn down at once (React's StrictMode
    // runs effects twice in development) never opens a socket, and the room
    // doesn't see a join and a leave for nothing.
    timer = setTimeout(connect, 0);
    return () => {
      disposed = true;
      clearTimeout(timer);
      clearTimeout(welcomeTimer);
      window.removeEventListener("online", retry);
      document.removeEventListener("visibilitychange", onVisible);
      socket.current?.close(1000, "switching");
      socket.current = null;
    };
  }, [room, name]);

  const noticeId = state.notice?.id;
  useEffect(() => {
    if (noticeId === undefined) return;
    const timer = setTimeout(() => dispatch({ kind: "dismiss", id: noticeId }), NOTICE_MS);
    return () => clearTimeout(timer);
  }, [noticeId]);

  /** Sends one message. False when the socket is not open. */
  const send = useCallback((text: string): boolean => {
    const ws = socket.current;
    if (ws === null || ws.readyState !== WebSocket.OPEN) {
      dispatch({ kind: "refused", text: "Not connected. Your message was not sent." });
      return false;
    }
    ws.send(text);
    return true;
  }, []);

  const retry = useCallback(() => retryNow.current(), []);

  return { state, send, retry };
}
