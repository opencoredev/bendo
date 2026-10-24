import { useState, type FormEvent, type KeyboardEvent } from "react";
import { length, MAX_TEXT } from "./protocol.ts";

/** Show the counter once a message gets this close to the limit. */
const WARN_AT = MAX_TEXT - 200;

export function Composer({
  room,
  live,
  send,
}: {
  room: string;
  live: boolean;
  send: (text: string) => boolean;
}) {
  const [draft, setDraft] = useState("");
  const size = length(draft.trim());
  const over = size > MAX_TEXT;
  const ready = live && size > 0 && !over;

  function submit(event?: FormEvent) {
    event?.preventDefault();
    if (!ready) return;
    if (send(draft.trim())) setDraft("");
  }

  function onKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) {
      event.preventDefault();
      submit();
    }
  }

  return (
    <form className="composer" onSubmit={submit}>
      <label className="sr-only" htmlFor="draft">
        Message #{room}
      </label>
      <textarea
        id="draft"
        rows={1}
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onKeyDown={onKeyDown}
        placeholder={live ? `Message #${room}` : "Waiting for the connection…"}
        autoComplete="off"
        enterKeyHint="send"
        aria-invalid={over}
        aria-describedby="draft-hint"
      />
      <div className="composer-side">
        <span id="draft-hint" className={over ? "hint over" : "hint"}>
          {size >= WARN_AT ? (
            `${size} / ${MAX_TEXT}`
          ) : (
            <span className="keys">Shift + Enter for a new line</span>
          )}
        </span>
        <button type="submit" className="send" disabled={!ready}>
          Send
        </button>
      </div>
    </form>
  );
}
