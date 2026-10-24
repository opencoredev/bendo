import { useLayoutEffect, useRef, useState } from "react";
import type { Line } from "./protocol.ts";

const clock = new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" });
const day = new Intl.DateTimeFormat(undefined, { weekday: "long", month: "long", day: "numeric" });
const GROUP_MS = 5 * 60 * 1000;

/** A stable hue per name, so a person keeps their color across rooms and reloads. */
export function hue(name: string): number {
  let h = 0;
  for (const c of name) h = (h * 31 + (c.codePointAt(0) ?? 0)) % 360;
  return h;
}

export function Mark({ name, size = "md" }: { name: string; size?: "sm" | "md" }) {
  const initial = [...name][0]?.toUpperCase() ?? "?";
  return (
    <span className={`mark mark-${size}`} style={{ "--hue": hue(name) }} aria-hidden="true">
      {initial}
    </span>
  );
}

function dayKey(at: number): string {
  const d = new Date(at);
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

function dayLabel(at: number): string {
  if (dayKey(at) === dayKey(Date.now())) return "Today";
  if (dayKey(at) === dayKey(Date.now() - 86_400_000)) return "Yesterday";
  return day.format(at);
}

/** True when `line` continues the previous message's group: same author, within five minutes. */
function continues(prev: Line | undefined, line: Line): boolean {
  return (
    prev !== undefined &&
    prev.kind === "said" &&
    line.kind === "said" &&
    prev.id === line.id &&
    line.at - prev.at < GROUP_MS &&
    dayKey(prev.at) === dayKey(line.at)
  );
}

function Row({ line, prev, you }: { line: Line; prev: Line | undefined; you: number | null }) {
  const time = (
    <time className="gutter" dateTime={new Date(line.at).toISOString()}>
      {clock.format(line.at)}
    </time>
  );
  switch (line.kind) {
    case "joined":
    case "left":
      return (
        <li className="notice">
          {time}
          <p>
            <span aria-hidden="true">{line.kind === "joined" ? "→" : "←"}</span> <b>{line.name}</b>{" "}
            {line.kind === "joined" ? "joined" : "left"}
            <span className="inline-time" aria-hidden="true">
              {clock.format(line.at)}
            </span>
          </p>
        </li>
      );
    case "said": {
      const mine = line.id === you;
      if (continues(prev, line))
        return (
          <li className="said more">
            {time}
            <p className="body">{line.text}</p>
          </li>
        );
      return (
        <li className={mine ? "said first mine" : "said first"}>
          <Mark name={line.name} />
          <div>
            <p className="byline">
              <span className="author" style={{ "--hue": hue(line.name) }}>
                {line.name}
              </span>
              {mine && <span className="you">you</span>}
              <time dateTime={new Date(line.at).toISOString()}>{clock.format(line.at)}</time>
            </p>
            <p className="body">{line.text}</p>
          </div>
        </li>
      );
    }
    default: {
      const _exhaustive: never = line;
      return _exhaustive;
    }
  }
}

/** Distance from the bottom, in pixels, that still counts as reading the latest line. */
const STICK_PX = 80;

export function Transcript({
  lines,
  you,
  room,
  ready,
  truncated,
}: {
  lines: Line[];
  you: number | null;
  room: string;
  ready: boolean;
  truncated: boolean;
}) {
  const scroller = useRef<HTMLDivElement>(null);
  const stuck = useRef(true);
  const [unseen, setUnseen] = useState(0);
  const seen = useRef(lines.length);

  // Follow new lines while the reader is at the bottom; otherwise count them.
  useLayoutEffect(() => {
    const el = scroller.current;
    if (el === null) return;
    const added = lines.slice(seen.current).filter((l) => l.kind === "said").length;
    seen.current = lines.length;
    if (stuck.current || lines.at(-1)?.id === you) {
      el.scrollTop = el.scrollHeight;
      setUnseen(0);
    } else if (added > 0) setUnseen((n) => n + added);
  }, [lines, you]);

  useLayoutEffect(() => {
    stuck.current = true;
    seen.current = 0;
    setUnseen(0);
  }, [room]);

  function onScroll() {
    const el = scroller.current;
    if (el === null) return;
    stuck.current = el.scrollHeight - el.scrollTop - el.clientHeight < STICK_PX;
    if (stuck.current) setUnseen(0);
  }

  function jump() {
    const el = scroller.current;
    if (el === null) return;
    el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
  }

  const said = lines.some((l) => l.kind === "said");
  const items: React.ReactNode[] = [];
  lines.forEach((line, i) => {
    const prev = lines[i - 1];
    if (prev === undefined || dayKey(prev.at) !== dayKey(line.at))
      items.push(
        <li className="day" key={`day-${line.seq}`}>
          <span>{dayLabel(line.at)}</span>
        </li>,
      );
    items.push(<Row key={line.seq} line={line} prev={prev} you={you} />);
  });

  return (
    <div className="transcript-wrap">
      <div className="transcript" ref={scroller} onScroll={onScroll}>
        {ready && !said && (
          <div className="empty">
            <p className="empty-title">Nothing said in #{room} yet</p>
            <p>Messages show up here for everyone in the room as soon as they're sent.</p>
          </div>
        )}
        {truncated && <p className="earlier">Earlier messages not shown</p>}
        <ol aria-label={`Messages in #${room}`} aria-live="polite" aria-relevant="additions">
          {items}
        </ol>
      </div>
      {unseen > 0 && (
        <button type="button" className="jump" onClick={jump}>
          {unseen === 1 ? "1 new message" : `${unseen} new messages`}{" "}
          <span aria-hidden="true">↓</span>
        </button>
      )}
    </div>
  );
}
