# Chat example

Chat rooms on Bendo's [WebSocket publish and subscribe](../../docs/websocket-pubsub.md),
with a small React client on Vite. Each room is a topic on one `P.Hub`. A
message goes to everyone in its room, the sender included, and to no other
room. People see who joins and leaves, who is in the room now, and how many
people are in every room. A newcomer gets the room's last 100 lines, or as
many of the newest as fit in one 16 KiB frame.

## Run it

You need Bun and Bend (see the repository's `CLAUDE.md` for the pinned
versions). From the repository root:

```sh
bun install
cd examples/chat
bun run api    # the Bend server on http://127.0.0.1:8787
bun run web    # in a second terminal: the app on http://127.0.0.1:5173
```

Open http://127.0.0.1:5173 in two tabs, pick a name in each, and talk.
`bun run api` runs `bendo dev --native`, which compiles the server (about 40
seconds the first time) and rebuilds it when a `.bend` file changes. Restarting
the server clears the rooms; the tabs reconnect on their own.

Vite proxies `/ws` and `/api` to the server, so the app uses one origin. To run
the server elsewhere, set `PORT` for the server and `CHAT_API` for Vite:

```sh
PORT=9000 bun run api
CHAT_API=http://127.0.0.1:9000 bun run web
```

For a production build, run `bun run build` and serve `dist/` behind the same
two proxy routes. The server listens on 127.0.0.1 only, as every Bendo app does
by default.

## How it fits together

| File | What it does |
| --- | --- |
| `chat.bend` | Pure state: the rooms, the name and message rules, each room's history, who is where, and the JSON for every event |
| `main.bend` | The routes, the hub, the lobby store, and the WebSocket handlers |
| `src/protocol.ts` | Parses each server frame into a typed event |
| `src/useChat.ts` | One socket per room, reconnecting with backoff, folding events into state |
| `src/App.tsx`, `src/Transcript.tsx`, `src/Composer.tsx` | The interface |

A connection opens with `GET /ws/:room?name=<name>`. The server checks both
before the upgrade: an unknown room gets 404, and a name that is empty, longer
than 24 characters after trimming, or holds control characters gets 400. On
open the handler subscribes the connection to its room and to a `presence`
topic, records the arrival in the lobby store, sends the newcomer a welcome,
and publishes the arrival to the room and the new counts to everyone.

The connection subscribes before it reads the store. A line recorded after the
welcome's snapshot is therefore always delivered live, and a line can arrive
both ways. Every line carries a `seq` that counts up across the lobby, so the
client merges by `seq` and drops duplicates.

`P.handlers` takes a connection out of every topic on any close: a clean
close, an idle timeout, or a dropped TCP connection. The close handler then
records the departure and publishes it, so the people list stays right. The
server pings every 20 seconds, and browsers answer on their own, which keeps an
open tab inside the 60-second idle limit.

## Protocol

The client sends each message as one text frame: 1 to 2000 characters after
trimming, with no control characters other than tab and newline. Anything else
gets an `error` event back, and only the sender sees it.

The server sends JSON text frames. `type` says which:

| `type` | Fields | When |
| --- | --- | --- |
| `welcome` | `room`, `you` (this connection's ID), `next`, `truncated`, `people`, `history`, `rooms` | First, to the new connection |
| `said` | `seq`, `room`, `id`, `name`, `at`, `text` | Someone in the room sent a message |
| `joined`, `left` | `seq`, `room`, `id`, `name`, `at` | Someone entered or left the room |
| `presence` | `rooms` | Anyone entered or left any room |
| `error` | `reason` | The connection's last frame was refused |

`at` is the server's wall clock in milliseconds. `next` is the first `seq` the
welcome's `history` and `people` leave out: a `joined` or `left` line below it
is already reflected in `people`. `rooms` is `[{"id", "online"}]` for every
room. `GET /api/rooms` returns the same list as `{"rooms": [...]}`.

Every frame the server sends or accepts is at most 16 KiB. One message fits
with room to spare, but a hundred long ones do not, so the welcome's `history`
holds the room's newest lines that fit, with no gaps. `truncated` is `true`
when older lines were left out, and the app then shows "Earlier messages not
shown" above them. If even an empty history would not fit, which takes well
over a hundred people in one room, the server sends an `error` and closes the
connection with 1011. That close goes through the connection's 64-command
mailbox, so a burst of room traffic that fills it during the join can drop it.
The app closes a socket that has no welcome after 10 s and retries; BND-101
tracks a close that can't be dropped.

There are no accounts. Anyone who can reach the server can pick any name, and
two people can share one. The server accepts any `Origin`, which is safe only
because the chat has no cookies or other credentials to ride along.

## Tests

```sh
bun test --timeout 30000 tests/chat-example.test.ts
```

The tests compile the server and connect real Bun WebSocket clients. They
check that a message reaches everyone in its room once, in order, and no other
room; that bad names, rooms and messages are refused; that a newcomer gets the
history and the people list; that history stops at 100 lines per room; that
the welcome fits one frame, keeping the newest lines, however long the
messages; that
departures are announced, including a dropped TCP connection; and that the
React app builds and typechecks.
