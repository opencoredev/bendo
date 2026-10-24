import type { Verdict } from "./check.ts";

/** The line under a form that says which side caught the input, and why. */
export function VerdictLine({ verdict, id }: { verdict: Verdict; id: string }) {
  switch (verdict.kind) {
    case "none":
      return null;
    case "browser":
      return (
        <div className="verdict" data-side="browser" id={id} role="alert">
          <p className="verdict-source">
            Caught in the browser <code>shared/todo.bend</code>
          </p>
          <ul className="verdict-list">
            {verdict.issues.map((issue) => (
              <li key={`${issue.field}:${issue.message}`}>{issue.message}</li>
            ))}
          </ul>
        </div>
      );
    case "server": {
      const { rejection } = verdict;
      return (
        <div className="verdict" data-side="server" id={id} role="alert">
          <p className="verdict-source">
            Rejected by the server <code>{rejection.headline}</code>
          </p>
          {rejection.details.length === 0 ? null : (
            <ul className="verdict-list">
              {rejection.details.map((detail) => (
                <li key={`${detail.field}:${detail.message}`}>
                  <code>{detail.field}</code> {detail.message}
                </li>
              ))}
            </ul>
          )}
        </div>
      );
    }
    default: {
      const _exhaustive: never = verdict;
      return _exhaustive;
    }
  }
}
