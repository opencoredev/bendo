// BND-65: the chat example. The compiled server is driven by real WebSocket
// clients: rooms are isolated topics, a message reaches everyone in its room
// (the sender included), arrivals and departures are announced, and every
// close path, an abrupt TCP drop included, takes the connection out of the
// room. The React app must build and typecheck.
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { connect } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseEvent, type Line, type ServerEvent } from "../examples/chat/src/protocol.ts";
import { build, start, type RunningServer } from "./harness.ts";

const APP = join(import.meta.dir, "../examples/chat");

// Compile outside any test's timeout, through the shared fixture cache.
const binary = build("examples/chat/main.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => server?.[Symbol.asyncDispose]());

/** How long to wait for one expected frame. Generous: CI runners are about twice as slow as Boat. */
const WAIT_MS = 10_000;

type Waiter = { match: (e: ServerEvent) => boolean; resolve: (e: ServerEvent) => void };

/** A Bun WebSocket that records every event and lets a test wait for the next one it cares about. */
class Client {
  readonly events: ServerEvent[] = [];
  private waiters: Waiter[] = [];
  private closed: Promise<void>;
  private constructor(readonly ws: WebSocket) {
    ws.onmessage = (message) => {
      const event = parseEvent(String(message.data));
      if (event === null) throw new Error(`unparsed frame: ${String(message.data)}`);
      this.events.push(event);
      this.waiters = this.waiters.filter((w) => {
        if (!w.match(event)) return true;
        w.resolve(event);
        return false;
      });
    };
    this.closed = new Promise((resolve) => ws.addEventListener("close", () => resolve()));
  }

  static async open(room: string, name: string): Promise<Client> {
    const ws = new WebSocket(
      `${server.url.replace("http", "ws")}/ws/${room}?name=${encodeURIComponent(name)}`,
    );
    const client = new Client(ws);
    await new Promise<void>((resolve, reject) => {
      ws.onopen = () => resolve();
      ws.onerror = () => reject(new Error(`could not open ${room} as ${name}`));
    });
    return client;
  }

  /** The first event, already seen or still to come, that matches. */
  next<E extends ServerEvent>(match: (e: ServerEvent) => e is E, what: string): Promise<E> {
    const seen = this.events.find(match);
    if (seen !== undefined) return Promise.resolve(seen);
    return new Promise<E>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`timed out waiting for ${what}`)), WAIT_MS);
      this.waiters.push({
        match,
        resolve: (e) => {
          clearTimeout(timer);
          if (match(e)) resolve(e);
        },
      });
    });
  }

  welcome() {
    return this.next(
      (e): e is Extract<ServerEvent, { kind: "welcome" }> => e.kind === "welcome",
      "welcome",
    );
  }

  /** The line event for which `match` holds. */
  line(match: (l: Line) => boolean, what: string) {
    return this.next(
      (e): e is Extract<ServerEvent, { kind: "line" }> => e.kind === "line" && match(e.line),
      what,
    ).then((e) => e.line);
  }

  said(text: string) {
    return this.line((l) => l.kind === "said" && l.text === text, `"${text}"`);
  }

  lines(): Line[] {
    return this.events.flatMap((e) => (e.kind === "line" ? [e.line] : []));
  }

  async close(): Promise<void> {
    this.ws.close(1000);
    await this.closed;
  }
}

async function counts(): Promise<Record<string, number>> {
  const response = await fetch(`${server.url}/api/rooms`, { signal: AbortSignal.timeout(5000) });
  expect(response.status).toBe(200);
  const body: unknown = await response.json();
  if (typeof body !== "object" || body === null) throw new Error("bad /api/rooms body");
  const rooms: unknown = Reflect.get(body, "rooms");
  if (!Array.isArray(rooms)) throw new Error("bad /api/rooms body");
  const out: Record<string, number> = {};
  for (const room of rooms)
    out[String(Reflect.get(room, "id"))] = Number(Reflect.get(room, "online"));
  return out;
}

/** Waits for a condition on events already recorded by the clients' handlers. */
async function until(check: () => boolean, what: string): Promise<void> {
  const deadline = Date.now() + WAIT_MS;
  while (!check()) {
    if (Date.now() >= deadline) throw new Error(`timed out waiting for ${what}`);
    await Bun.sleep(5);
  }
}

/** Polls /api/rooms until it reports `expected`. The lobby update after a close is asynchronous. */
async function countsBecome(expected: Record<string, number>): Promise<void> {
  const deadline = Date.now() + WAIT_MS;
  let last = await counts();
  while (JSON.stringify(last) !== JSON.stringify(expected)) {
    if (Date.now() >= deadline)
      throw new Error(`counts stayed ${JSON.stringify(last)}, wanted ${JSON.stringify(expected)}`);
    await Bun.sleep(20);
    last = await counts();
  }
}

const EMPTY = { general: 0, random: 0, bend: 0 };

describe("HTTP", () => {
  test("lists the rooms with nobody in them", async () => {
    expect(await counts()).toEqual(EMPTY);
  });

  test("refuses unknown rooms and bad names before the upgrade", async () => {
    const get = (path: string) =>
      fetch(`${server.url}${path}`, { signal: AbortSignal.timeout(5000) });
    const unknown = await get("/ws/presence?name=Ada");
    expect(unknown.status).toBe(404);
    for (const name of ["", "%20%20", "a".repeat(25), "tab%09name"]) {
      const response = await get(`/ws/general?name=${name}`);
      expect(response.status, name).toBe(400);
      expect(await response.text()).toBe("name must be 1 to 24 characters");
    }
    expect((await get("/ws/general")).status).toBe(400);
  });
});

describe("rooms", () => {
  test("a message reaches everyone in its room, the sender too, and no other room", async () => {
    const ada = await Client.open("general", "Ada");
    const welcome = await ada.welcome();
    expect(welcome.room).toBe("general");
    expect(welcome.people).toEqual([{ id: welcome.you, name: "Ada" }]);
    expect(welcome.history.at(-1)).toMatchObject({ kind: "joined", id: welcome.you, name: "Ada" });

    const grace = await Client.open("general", "  Grace  ");
    const graceWelcome = await grace.welcome();
    // Ada hears the arrival, with the name trimmed.
    await ada.line((l) => l.kind === "joined" && l.id === graceWelcome.you, "Grace joined");
    expect(graceWelcome.people.map((p) => p.name).sort()).toEqual(["Ada", "Grace"]);

    const cy = await Client.open("random", "Cy");
    await cy.welcome();

    ada.ws.send("  hello, general  ");
    const atAda = await ada.said("hello, general");
    const atGrace = await grace.said("hello, general");
    expect(atGrace).toEqual(atAda);
    expect(atAda).toMatchObject({ room: "general", id: welcome.you, name: "Ada" });

    cy.ws.send("hello, random");
    await cy.said("hello, random");
    grace.ws.send("hello again, general");
    await ada.said("hello again, general");
    await grace.said("hello again, general");
    // Cy's own line has round-tripped since both general lines were offered,
    // and neither general line was offered to Cy at all.
    expect(cy.lines().map((l) => l.room)).toEqual(["random"]);
    expect(ada.lines().some((l) => l.room !== "general")).toBe(false);
    expect(grace.lines().some((l) => l.room !== "general")).toBe(false);

    expect(await counts()).toEqual({ general: 2, random: 1, bend: 0 });
    await Promise.all([ada.close(), grace.close(), cy.close()]);
    await countsBecome(EMPTY);
  });

  test("every message reaches every member exactly once, in send order", async () => {
    const members = await Promise.all(["P1", "P2", "P3", "P4"].map((n) => Client.open("bend", n)));
    await Promise.all(members.map((m) => m.welcome()));
    const sender = members[0];
    if (sender === undefined) throw new Error("no sender");
    // One at a time, so no mailbox sees a burst it could drop.
    for (let i = 1; i <= 20; i++) {
      sender.ws.send(`m${i}`);
      await Promise.all(members.map((m) => m.said(`m${i}`)));
    }
    for (const member of members) {
      const said = member.lines().filter((l) => l.kind === "said");
      expect(said.map((l) => (l.kind === "said" ? l.text : ""))).toEqual(
        Array.from({ length: 20 }, (_, i) => `m${i + 1}`),
      );
      // seq increases with every line, so clients can merge and dedupe.
      const seqs = said.map((l) => l.seq);
      expect(seqs).toEqual([...seqs].sort((a, b) => a - b));
    }
    await Promise.all(members.map((m) => m.close()));
    await countsBecome(EMPTY);
  });

  test("bad messages get an error for the sender only", async () => {
    const ada = await Client.open("random", "Ada");
    const grace = await Client.open("random", "Grace");
    await Promise.all([ada.welcome(), grace.welcome()]);
    ada.ws.send("   \n  ");
    ada.ws.send("x".repeat(2001));
    ada.ws.send(new Uint8Array([1, 2, 3]));
    ada.ws.send("bell\u0007");
    const errors = () => ada.events.filter((e) => e.kind === "error");
    ada.ws.send("ok");
    await ada.said("ok");
    await grace.said("ok");
    // Each refusal was answered before "ok" was handled, on the same socket.
    expect(errors().map((e) => (e.kind === "error" ? e.reason : ""))).toEqual([
      "Messages are 1 to 2000 characters.",
      "Messages are 1 to 2000 characters.",
      "Send text frames.",
      "Messages are 1 to 2000 characters.",
    ]);
    expect(grace.events.some((e) => e.kind === "error")).toBe(false);
    expect(grace.lines().filter((l) => l.kind === "said")).toHaveLength(1);

    // 2000 characters is allowed, counted in code points, not bytes.
    const long = "é".repeat(2000);
    ada.ws.send(long);
    await grace.said(long);
    await Promise.all([ada.close(), grace.close()]);
    await countsBecome(EMPTY);
  });
});

describe("history and presence", () => {
  test("a newcomer sees the room's recent lines and who is here", async () => {
    const ada = await Client.open("general", "Ada");
    const adaWelcome = await ada.welcome();
    ada.ws.send("before you came");
    await ada.said("before you came");

    const grace = await Client.open("general", "Grace");
    const welcome = await grace.welcome();
    const said = welcome.history.filter((l) => l.kind === "said");
    expect(said.at(-1)).toMatchObject({ text: "before you came", name: "Ada" });
    expect(welcome.history.every((l) => l.room === "general")).toBe(true);
    expect(welcome.history.every((l) => l.seq < welcome.next)).toBe(true);
    expect(welcome.people.map((p) => p.id).sort()).toEqual([adaWelcome.you, welcome.you].sort());
    expect(welcome.rooms).toContainEqual({ id: "general", online: 2 });
    await Promise.all([ada.close(), grace.close()]);
    await countsBecome(EMPTY);
  });

  test("keeps the newest 100 lines per room", async () => {
    const ada = await Client.open("random", "Ada");
    await ada.welcome();
    for (let i = 1; i <= 105; i++) {
      ada.ws.send(`n${i}`);
      await ada.said(`n${i}`);
    }
    const late = await Client.open("random", "Late");
    const { history } = await late.welcome();
    expect(history).toHaveLength(100);
    expect(history.at(-1)).toMatchObject({ kind: "joined", name: "Late" });
    expect(history.at(-2)).toMatchObject({ kind: "said", text: "n105" });
    await Promise.all([ada.close(), late.close()]);
    await countsBecome(EMPTY);
  });

  test("a close is announced and updates every connection's room counts", async () => {
    const ada = await Client.open("general", "Ada");
    await ada.welcome();
    const grace = await Client.open("bend", "Grace");
    await grace.welcome();
    const hugo = await Client.open("bend", "Hugo");
    const hugoWelcome = await hugo.welcome();
    await grace.line((l) => l.kind === "joined" && l.id === hugoWelcome.you, "Hugo joined");
    await hugo.close();
    const left = await grace.line(
      (l) => l.kind === "left" && l.id === hugoWelcome.you,
      "Hugo left",
    );
    expect(left).toMatchObject({ room: "bend", name: "Hugo" });

    // Ada, in another room, sees bend's count rise to 2 and fall back to 1,
    // but not the arrival or the departure.
    const bend = (e: ServerEvent) =>
      e.kind === "presence" ? e.rooms.find((r) => r.id === "bend")?.online : undefined;
    await until(() => {
      const rise = ada.events.findIndex((e) => bend(e) === 2);
      return rise >= 0 && ada.events.slice(rise).some((e) => bend(e) === 1);
    }, "bend 2 then 1 at Ada");
    expect(ada.lines().some((l) => l.room === "bend")).toBe(false);

    const ivy = await Client.open("bend", "Ivy");
    const { people } = await ivy.welcome();
    expect(people.map((p) => p.name).sort()).toEqual(["Grace", "Ivy"]);
    await Promise.all([ada.close(), grace.close(), ivy.close()]);
    await countsBecome(EMPTY);
  });

  test("a dropped TCP connection leaves the room", async () => {
    const ada = await Client.open("general", "Ada");
    await ada.welcome();
    const { port } = new URL(server.url);
    const socket = connect(Number(port), "127.0.0.1");
    socket.write(
      "GET /ws/general?name=Dropped HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\n" +
        "Connection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" +
        "Sec-WebSocket-Version: 13\r\n\r\n",
    );
    const joined = await ada.line(
      (l) => l.kind === "joined" && l.name === "Dropped",
      "Dropped joined",
    );
    expect(await counts()).toEqual({ general: 2, random: 0, bend: 0 });
    // No close frame: the server sees EOF and closes with 1006.
    socket.destroy();
    await ada.line((l) => l.kind === "left" && l.id === joined.id, "Dropped left");
    await countsBecome({ general: 1, random: 0, bend: 0 });
    await ada.close();
    await countsBecome(EMPTY);
  });
});

describe("web app", () => {
  test("builds with Vite and typechecks", () => {
    const dist = mkdtempSync(join(tmpdir(), "bendo-chat-web-"));
    try {
      const vite = Bun.spawnSync(
        [
          process.execPath,
          "x",
          "vite",
          "build",
          "--outDir",
          dist,
          "--emptyOutDir",
          "--logLevel",
          "warn",
        ],
        { cwd: APP, stdout: "pipe", stderr: "pipe", timeout: 60_000 },
      );
      expect(vite.exitCode, vite.stderr.toString()).toBe(0);
      expect(readFileSync(join(dist, "index.html"), "utf8")).toContain('<div id="root">');
      const tsc = Bun.spawnSync([process.execPath, "x", "tsc", "-p", "tsconfig.json"], {
        cwd: APP,
        stdout: "pipe",
        stderr: "pipe",
        timeout: 60_000,
      });
      expect(tsc.exitCode, tsc.stdout.toString()).toBe(0);
    } finally {
      rmSync(dist, { recursive: true, force: true });
    }
  }, 120_000);
});
