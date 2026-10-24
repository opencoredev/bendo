// The frames main.bend sends, parsed once where they arrive. Everything past
// parseEvent works with these types and never sees raw JSON.

export const ROOMS = [
  { id: "general", topic: "Anything goes" },
  { id: "random", topic: "Off topic, links, pictures in words" },
  { id: "bend", topic: "The language, the runtime and the proofs" },
] as const;

export type RoomId = (typeof ROOMS)[number]["id"];

/** The server's limits, mirrored from chat.bend so the composer can warn early. */
export const MAX_NAME = 24;
export const MAX_TEXT = 2000;

export type Person = { id: number; name: string };
export type RoomCount = { id: string; online: number };

type LineBase = { seq: number; room: string; id: number; name: string; at: number };
export type Line =
  | (LineBase & { kind: "said"; text: string })
  | (LineBase & { kind: "joined" })
  | (LineBase & { kind: "left" });

export type ServerEvent =
  | {
      kind: "welcome";
      room: string;
      you: number;
      next: number;
      /** Older lines were left out so the welcome fits one frame. */
      truncated: boolean;
      people: Person[];
      history: Line[];
      rooms: RoomCount[];
    }
  | { kind: "line"; line: Line }
  | { kind: "presence"; rooms: RoomCount[] }
  | { kind: "error"; reason: string };

export function isRoomId(value: string): value is RoomId {
  return ROOMS.some((room) => room.id === value);
}

/** Counts code points, as the server does. */
export function length(text: string): number {
  let n = 0;
  for (const _ of text) n++;
  return n;
}

type Fields = { get: (key: string) => unknown };

function fields(value: unknown): Fields | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return null;
  return { get: (key) => Reflect.get(value, key) };
}

function text(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function flag(value: unknown): boolean | null {
  return typeof value === "boolean" ? value : null;
}

function count(value: unknown): number | null {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function list<T>(value: unknown, item: (v: unknown) => T | null): T[] | null {
  if (!Array.isArray(value)) return null;
  const out: T[] = [];
  for (const v of value) {
    const parsed = item(v);
    if (parsed === null) return null;
    out.push(parsed);
  }
  return out;
}

function person(value: unknown): Person | null {
  const f = fields(value);
  if (f === null) return null;
  const id = count(f.get("id"));
  const name = text(f.get("name"));
  return id === null || name === null ? null : { id, name };
}

function roomCount(value: unknown): RoomCount | null {
  const f = fields(value);
  if (f === null) return null;
  const id = text(f.get("id"));
  const online = count(f.get("online"));
  return id === null || online === null ? null : { id, online };
}

function line(value: unknown): Line | null {
  const f = fields(value);
  if (f === null) return null;
  const seq = count(f.get("seq"));
  const room = text(f.get("room"));
  const id = count(f.get("id"));
  const name = text(f.get("name"));
  const at = count(f.get("at"));
  if (seq === null || room === null || id === null || name === null || at === null) return null;
  const base = { seq, room, id, name, at };
  switch (f.get("type")) {
    case "said": {
      const said = text(f.get("text"));
      return said === null ? null : { ...base, kind: "said", text: said };
    }
    case "joined":
      return { ...base, kind: "joined" };
    case "left":
      return { ...base, kind: "left" };
    default:
      return null;
  }
}

/** One text frame from the server, or null if it isn't one we know. */
export function parseEvent(data: string): ServerEvent | null {
  let raw: unknown;
  try {
    raw = JSON.parse(data);
  } catch {
    return null;
  }
  const f = fields(raw);
  if (f === null) return null;
  switch (f.get("type")) {
    case "welcome": {
      const room = text(f.get("room"));
      const you = count(f.get("you"));
      const next = count(f.get("next"));
      const truncated = flag(f.get("truncated"));
      const people = list(f.get("people"), person);
      const history = list(f.get("history"), line);
      const rooms = list(f.get("rooms"), roomCount);
      if (
        room === null ||
        you === null ||
        next === null ||
        truncated === null ||
        people === null ||
        history === null ||
        rooms === null
      )
        return null;
      return { kind: "welcome", room, you, next, truncated, people, history, rooms };
    }
    case "presence": {
      const rooms = list(f.get("rooms"), roomCount);
      return rooms === null ? null : { kind: "presence", rooms };
    }
    case "error": {
      const reason = text(f.get("reason"));
      return reason === null ? null : { kind: "error", reason };
    }
    default: {
      const parsed = line(raw);
      return parsed === null ? null : { kind: "line", line: parsed };
    }
  }
}
