// Typed access to the BND-51 frame codec and message assembler, compiled to
// an ES module. Values from Bend are parsed here; tests use the domain types.
import { pathToFileURL } from "node:url";
import { compile } from "./harness.ts";

export type Opcode = "OpContinue" | "OpText" | "OpBinary" | "OpClose" | "OpPing" | "OpPong";
export type Key = readonly [number, number, number, number];
export type Frame = { fin: boolean; opcode: Opcode; payload: Uint8Array | number[] };
export type Role = "Server" | "Client";

/** Payload progress returned by `start`/`resume`; only `resume` reads it. */
export class Body {
  constructor(readonly value: unknown) {}
}
/** Assembler state returned by `step`; only `step` reads it. */
export class State {
  constructor(readonly value: unknown) {}
}

export type Decoded =
  | { kind: "need"; need: number }
  | { kind: "partial"; body: Body; left: number }
  | { kind: "got"; frame: DecodedFrame; key: Key | null; rest: number[] }
  | { kind: "reject"; code: number };
export type DecodedFrame = { fin: boolean; opcode: Opcode; payload: number[] };

export type Message =
  | { kind: "text"; text: string }
  | { kind: "binary"; data: number[] }
  | { kind: "ping"; data: number[] }
  | { kind: "pong"; data: number[] }
  | { kind: "close"; code: number | null; reason: string };
export type Outcome =
  | { kind: "absorbed" }
  | { kind: "deliver"; message: Message }
  | { kind: "failed"; code: number };
export type Advance = { state: State; ended: boolean; outcome: Outcome };

type BendList = { $: "Nil" } | { $: "Con"; head: number; tail: BendList };

export function list(bytes: ArrayLike<number>): BendList {
  let tail: BendList = { $: "Nil" };
  for (let i = bytes.length - 1; i >= 0; i--) {
    const head = bytes[i];
    if (head === undefined) throw new Error("missing byte");
    tail = { $: "Con", head, tail };
  }
  return tail;
}

function field(value: unknown, name: string): unknown {
  if (typeof value !== "object" || value === null || !(name in value))
    throw new Error(`missing field ${name}`);
  return Reflect.get(value, name);
}

function tag(value: unknown): string {
  const t = field(value, "$");
  if (typeof t !== "string") throw new Error("missing constructor tag");
  return t;
}

function num(value: unknown): number {
  if (typeof value !== "number") throw new Error(`expected number, got ${typeof value}`);
  return value;
}

function bool(value: unknown): boolean {
  if (typeof value !== "boolean") throw new Error(`expected boolean, got ${typeof value}`);
  return value;
}

function str(value: unknown): string {
  if (typeof value !== "string") throw new Error(`expected string, got ${typeof value}`);
  return value;
}

export function bytesOf(value: unknown): number[] {
  const out: number[] = [];
  let node = value;
  while (tag(node) === "Con") {
    out.push(num(field(node, "head")));
    node = field(node, "tail");
  }
  if (tag(node) !== "Nil") throw new Error("malformed list");
  return out;
}

const OPCODES: readonly Opcode[] = [
  "OpContinue",
  "OpText",
  "OpBinary",
  "OpClose",
  "OpPing",
  "OpPong",
];
function opcode(value: unknown): Opcode {
  const t = tag(value);
  const found = OPCODES.find((o) => o === t);
  if (found === undefined) throw new Error(`unknown opcode ${t}`);
  return found;
}

function key(value: unknown): Key | null {
  switch (tag(value)) {
    case "None":
      return null;
    case "Some": {
      const k = field(value, "value");
      return [num(field(k, "a")), num(field(k, "b")), num(field(k, "c")), num(field(k, "d"))];
    }
    default:
      throw new Error("malformed key");
  }
}

function bendKey(k: Key | null): unknown {
  return k === null
    ? { $: "None" }
    : { $: "Some", value: { $: "MaskKey", a: k[0], b: k[1], c: k[2], d: k[3] } };
}

function bendFrame(f: Frame): unknown {
  return { $: "Frame", fin: f.fin, opcode: { $: f.opcode }, payload: list(f.payload) };
}

function decoded(value: unknown): Decoded {
  const t = tag(value);
  switch (t) {
    case "NeedMore":
      return { kind: "need", need: num(field(value, "need")) };
    case "Partial": {
      const body = field(value, "body");
      return { kind: "partial", body: new Body(body), left: num(field(body, "left")) };
    }
    case "Got": {
      const f = field(value, "frame");
      return {
        kind: "got",
        frame: {
          fin: bool(field(f, "fin")),
          opcode: opcode(field(f, "opcode")),
          payload: bytesOf(field(f, "payload")),
        },
        key: key(field(value, "key")),
        rest: bytesOf(field(value, "rest")),
      };
    }
    case "Reject":
      return { kind: "reject", code: num(field(value, "code")) };
    default:
      throw new Error(`unknown Decoded ${t}`);
  }
}

function message(value: unknown): Message {
  const t = tag(value);
  switch (t) {
    case "TextMessage":
      return { kind: "text", text: str(field(value, "text")) };
    case "BinaryMessage":
      return { kind: "binary", data: bytesOf(field(value, "data")) };
    case "PingMessage":
      return { kind: "ping", data: bytesOf(field(value, "data")) };
    case "PongMessage":
      return { kind: "pong", data: bytesOf(field(value, "data")) };
    case "CloseMessage": {
      const code = field(value, "code");
      return {
        kind: "close",
        code: tag(code) === "Some" ? num(field(code, "value")) : null,
        reason: str(field(value, "reason")),
      };
    }
    default:
      throw new Error(`unknown Message ${t}`);
  }
}

function outcome(value: unknown): Outcome {
  const t = tag(value);
  switch (t) {
    case "Absorbed":
      return { kind: "absorbed" };
    case "Deliver":
      return { kind: "deliver", message: message(field(value, "message")) };
    case "Failed":
      return { kind: "failed", code: num(field(value, "code")) };
    default:
      throw new Error(`unknown Outcome ${t}`);
  }
}

export type Codec = {
  encode: (max: number, frame: Frame, key: Key | null) => number[] | null;
  encodeRaw: (frame: Frame, key: Key | null) => number[];
  decode: (role: Role, max: number, bytes: ArrayLike<number>) => Decoded;
  start: (role: Role, max: number, bytes: ArrayLike<number>) => Decoded;
  resume: (body: Body, bytes: ArrayLike<number>) => Decoded;
  mask: (key: Key, bytes: ArrayLike<number>) => number[];
  idle: State;
  step: (max: number, state: State, frame: Frame) => Advance;
  closePayload: (code: number, reason: string) => number[];
  codeOk: (code: number) => boolean;
};

/** Compiles the fixture (cached) and loads it. */
export async function loadCodec(): Promise<Codec> {
  const path = compile("tests/fixtures/ws/consumer.bend", "mjs");
  const loaded: unknown = await import(pathToFileURL(path).href);
  const exports = field(loaded, "default");
  const fn = (name: string): ((...args: unknown[]) => unknown) => {
    const f = field(exports, name);
    if (typeof f !== "function") throw new Error(`not callable: ${name}`);
    return (...args) => Reflect.apply(f, undefined, args);
  };
  const encode = fn("encode");
  const encodeRaw = fn("encode_raw");
  const decode = fn("decode");
  const start = fn("start");
  const resume = fn("resume");
  const mask = fn("mask");
  const step = fn("step");
  const closePayload = fn("close_payload");
  const codeOk = fn("code_ok");
  const config = (role: Role, max: number) => ({ $: "Config", role: { $: role }, max });
  const state = (value: unknown): State => new State(value);
  return {
    encode: (max, frame, k) => {
      const r = encode(max, bendFrame(frame), bendKey(k));
      return tag(r) === "Some" ? bytesOf(field(r, "value")) : null;
    },
    encodeRaw: (frame, k) => bytesOf(encodeRaw(bendFrame(frame), bendKey(k))),
    decode: (role, max, bytes) => decoded(decode(config(role, max), list(bytes))),
    start: (role, max, bytes) => decoded(start(config(role, max), list(bytes))),
    resume: (body, bytes) => decoded(resume(body.value, list(bytes))),
    mask: (k, bytes) =>
      bytesOf(mask({ $: "MaskKey", a: k[0], b: k[1], c: k[2], d: k[3] }, list(bytes))),
    idle: state({ $: "Idle" }),
    step: (max, s, frame) => {
      const r = step(max, s.value, bendFrame(frame));
      const next = field(r, "state");
      return {
        state: state(next),
        ended: tag(next) === "Ended",
        outcome: outcome(field(r, "event")),
      };
    },
    closePayload: (code, reason) => bytesOf(closePayload(code, reason)),
    codeOk: (code) => bool(codeOk(code)),
  };
}
