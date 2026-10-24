import { useSyncExternalStore } from "react";
import { wire, type Exchange } from "./api.ts";

function Status({ outcome }: { outcome: Exchange["outcome"] }) {
  switch (outcome.kind) {
    case "response":
      return (
        <span className={outcome.status < 400 ? "status ok" : "status bad"}>{outcome.status}</span>
      );
    case "cancelled":
      return <span className="status">cancelled</span>;
    case "failed":
      return <span className="status bad">failed</span>;
  }
}

// Every request the typed client sends, newest first.
export function Wire() {
  const exchanges = useSyncExternalStore(wire.subscribe, wire.snapshot);
  return (
    <aside className="wire" aria-labelledby="wire-title">
      <h2 id="wire-title" className="wire-title">
        Wire
      </h2>
      <p className="wire-hint">Requests from bendo/client, newest first.</p>
      {exchanges.length === 0 ? (
        <p className="wire-empty">No requests yet.</p>
      ) : (
        <ol className="wire-list">
          {exchanges.map((exchange) => (
            <li key={exchange.id} className="wire-row">
              <span className="method">{exchange.method}</span>
              <span className="path">{exchange.path}</span>
              <Status outcome={exchange.outcome} />
              <span className="ms">{exchange.ms} ms</span>
            </li>
          ))}
        </ol>
      )}
    </aside>
  );
}
