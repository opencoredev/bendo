// The signup form validates in the browser with the Bend schema the server
// uses: ../../dist/shared/signup.mjs is shared/signup.bend compiled by
// `bendo build --shared`, and its .d.mts types every value below.
import { useRef, useState, type FormEvent } from "react";
import {
  check,
  reply_text,
  type Checked,
  type Issue,
  type List,
} from "../../dist/shared/signup.mjs";

const FIELDS = ["name", "email", "username", "age", "plan"] as const;
type FieldName = (typeof FIELDS)[number];
type Plan = "free" | "pro";
type Values = { name: string; email: string; username: string; age: string; plan: Plan };

function toArray<A>(list: List<A>): A[] {
  const out: A[] = [];
  for (let at = list; at.$ === "Con"; at = at.tail) out.push(at.head);
  return out;
}

function issuesOf(checked: Checked): Issue[] {
  return checked.$ === "Rejected" ? toArray(checked.issues) : [];
}

/** The JSON text both sides check. An age that is not digits stays text, so the schema rejects it. */
function bodyOf(values: Values): string {
  const age = values.age.trim();
  return JSON.stringify({
    name: values.name,
    email: values.email,
    username: values.username,
    ...(age === "" ? {} : { age: /^\d+$/.test(age) ? Number(age) : age }),
    plan: values.plan,
  });
}

type ServerIssue = { field: string; message: string };
type ServerReply =
  | { kind: "accepted"; status: number; text: string; user: unknown }
  | { kind: "rejected"; status: number; text: string; issues: ServerIssue[] }
  | { kind: "unreachable"; message: string };

function parseIssues(value: unknown): ServerIssue[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((item: unknown) => {
    if (typeof item !== "object" || item === null) return [];
    const field: unknown = Reflect.get(item, "field");
    const message: unknown = Reflect.get(item, "message");
    return typeof field === "string" && typeof message === "string" ? [{ field, message }] : [];
  });
}

async function send(body: string): Promise<ServerReply> {
  try {
    const response = await fetch("/api/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body,
    });
    const text = await response.text();
    const parsed: unknown = JSON.parse(text);
    if (typeof parsed !== "object" || parsed === null)
      return { kind: "unreachable", message: "The server sent something other than JSON." };
    if (Reflect.get(parsed, "ok") === true)
      return { kind: "accepted", status: response.status, text, user: Reflect.get(parsed, "user") };
    return {
      kind: "rejected",
      status: response.status,
      text,
      issues: parseIssues(Reflect.get(parsed, "issues")),
    };
  } catch {
    return { kind: "unreachable", message: "Could not reach the Bend server on /api." };
  }
}

type Attempt = { body: string; browser: Checked; server: ServerReply };

const LABELS: Record<FieldName, string> = {
  name: "Full name",
  email: "Email",
  username: "Username",
  age: "Age",
  plan: "Plan",
};

export function App() {
  const [values, setValues] = useState<Values>({
    name: "",
    email: "",
    username: "",
    age: "",
    plan: "free",
  });
  const [submitted, setSubmitted] = useState(false);
  const [pending, setPending] = useState(false);
  const [attempt, setAttempt] = useState<Attempt | undefined>(undefined);
  const form = useRef<HTMLFormElement>(null);

  // After the first submit, the browser re-checks on every keystroke.
  const live = check(bodyOf(values));
  const issues = submitted ? issuesOf(live) : [];
  const errorFor = (field: FieldName): string | undefined =>
    issues.find((issue) => issue.field === field)?.message;
  const formIssue = issues.find((issue) => !FIELDS.some((field) => field === issue.field));

  const update = (field: keyof Values) => (value: string) =>
    setValues((current) => ({ ...current, [field]: value }));

  async function onSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    setSubmitted(true);
    const body = bodyOf(values);
    const browser = check(body);
    const first = issuesOf(browser)[0];
    if (first !== undefined)
      form.current?.querySelector<HTMLElement>(`[name="${first.field}"]`)?.focus();
    // The fixture sends every attempt, so the ledger can compare both checks.
    setPending(true);
    const server = await send(body);
    setPending(false);
    setAttempt({ body, browser, server });
  }

  const browserText = attempt === undefined ? "" : reply_text(attempt.browser);
  const match =
    attempt !== undefined && attempt.server.kind !== "unreachable"
      ? attempt.server.text === browserText
      : undefined;

  return (
    <main className="page">
      <section className="intro">
        <p className="eyebrow">Bendo · shared schema fixture</p>
        <h1>Create your account</h1>
        <p className="lede">
          This form checks your entries in the browser with <code>shared/signup.bend</code>,
          compiled to JavaScript. The Bend server decodes the same request with the same schema.
        </p>
      </section>

      <form ref={form} className="form" noValidate onSubmit={(e) => void onSubmit(e)}>
        <TextField
          name="name"
          label={LABELS.name}
          value={values.name}
          error={errorFor("name")}
          autoComplete="name"
          onChange={update("name")}
        />
        <TextField
          name="email"
          label={LABELS.email}
          type="email"
          value={values.email}
          error={errorFor("email")}
          autoComplete="email"
          onChange={update("email")}
        />
        <TextField
          name="username"
          label={LABELS.username}
          hint="3 to 20 lowercase letters, digits or underscores."
          value={values.username}
          error={errorFor("username")}
          autoComplete="username"
          onChange={update("username")}
        />
        <TextField
          name="age"
          label={LABELS.age}
          optional
          inputMode="numeric"
          value={values.age}
          error={errorFor("age")}
          autoComplete="off"
          onChange={update("age")}
        />
        <fieldset
          className="plans"
          aria-invalid={errorFor("plan") === undefined ? undefined : true}
          aria-describedby={errorFor("plan") === undefined ? undefined : "plan-error"}
        >
          <legend>{LABELS.plan}</legend>
          {(["free", "pro"] as const).map((plan) => (
            <label key={plan} className="plan">
              <input
                type="radio"
                name="plan"
                value={plan}
                checked={values.plan === plan}
                onChange={() => setValues((current) => ({ ...current, plan }))}
              />
              <span className="plan-name">{plan === "free" ? "Free" : "Pro"}</span>
              <span className="plan-note">
                {plan === "free" ? "One project" : "Unlimited projects"}
              </span>
            </label>
          ))}
          {errorFor("plan") === undefined ? null : (
            <p className="error" id="plan-error">
              {errorFor("plan")}
            </p>
          )}
        </fieldset>
        {formIssue === undefined ? null : (
          <p className="error form-error" role="alert">
            {formIssue.message}
          </p>
        )}
        <button className="submit" type="submit" disabled={pending}>
          {pending ? "Creating account…" : "Create account"}
        </button>
      </form>

      <Ledger attempt={attempt} match={match} />
    </main>
  );
}

type TextFieldProps = {
  name: FieldName;
  label: string;
  value: string;
  error: string | undefined;
  autoComplete: string;
  onChange: (value: string) => void;
  hint?: string;
  optional?: boolean;
  type?: "text" | "email";
  inputMode?: "numeric";
};

function TextField(props: TextFieldProps) {
  const errorId = `${props.name}-error`;
  const hintId = `${props.name}-hint`;
  // An error replaces the hint rather than repeating it.
  const hint = props.error === undefined ? props.hint : undefined;
  const described = [hint === undefined ? "" : hintId, props.error === undefined ? "" : errorId]
    .filter((id) => id !== "")
    .join(" ");
  return (
    <div className="field" data-invalid={props.error === undefined ? undefined : "true"}>
      <label htmlFor={props.name}>
        {props.label}
        {props.optional === true ? <span className="optional">Optional</span> : null}
      </label>
      <input
        id={props.name}
        name={props.name}
        type={props.type ?? "text"}
        inputMode={props.inputMode}
        autoComplete={props.autoComplete}
        spellCheck={false}
        value={props.value}
        aria-invalid={props.error === undefined ? undefined : true}
        aria-describedby={described === "" ? undefined : described}
        onChange={(event) => props.onChange(event.currentTarget.value)}
      />
      {hint === undefined ? null : (
        <p className="hint" id={hintId}>
          {hint}
        </p>
      )}
      {props.error === undefined ? null : (
        <p className="error" id={errorId}>
          {props.error}
        </p>
      )}
    </div>
  );
}

function Ledger({ attempt, match }: { attempt: Attempt | undefined; match: boolean | undefined }) {
  const browserIssues = attempt === undefined ? [] : issuesOf(attempt.browser);
  const server = attempt?.server;
  const serverIssues = server?.kind === "rejected" ? server.issues : [];
  const rows = [...new Set([...browserIssues, ...serverIssues].map((issue) => issue.field))];
  const browserStatus =
    attempt === undefined ? "–" : attempt.browser.$ === "Accepted" ? "valid" : "invalid";
  const serverStatus =
    server === undefined ? "–" : server.kind === "unreachable" ? "offline" : String(server.status);
  return (
    <aside
      className="ledger"
      aria-labelledby="ledger-title"
      data-browser-status={browserStatus}
      data-server-status={serverStatus}
      data-match={match === undefined ? "none" : String(match)}
    >
      <h2 id="ledger-title">One schema, two runtimes</h2>
      <p className="ledger-note">
        Each submit is checked by <code>signup.mjs</code> here and sent to the native Bend server.
      </p>
      <div
        role="status"
        className="verdict"
        data-match={match === undefined ? "none" : String(match)}
      >
        {attempt === undefined
          ? "Submit the form to compare both checks."
          : server?.kind === "unreachable"
            ? server.message
            : match === true
              ? "Same result on both sides, byte for byte."
              : "The server answered differently."}
      </div>
      <dl className="totals">
        <div>
          <dt>Browser</dt>
          <dd>{browserStatus}</dd>
        </div>
        <div>
          <dt>Server</dt>
          <dd>{serverStatus}</dd>
        </div>
      </dl>
      {rows.length === 0 ? null : (
        <table className="rows">
          <thead>
            <tr>
              <th scope="col">Field</th>
              <th scope="col">Browser</th>
              <th scope="col">Server</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((field) => {
              const here = browserIssues.find((issue) => issue.field === field)?.message ?? "ok";
              const there = serverIssues.find((issue) => issue.field === field)?.message ?? "ok";
              return (
                <tr key={field} data-same={String(here === there)}>
                  <th scope="row">{field === "" ? "(form)" : field}</th>
                  <td>{here}</td>
                  <td>{there}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
      {server?.kind === "accepted" ? (
        <figure className="created">
          <figcaption>Account the server created</figcaption>
          <pre className="user">{JSON.stringify(server.user, null, 2)}</pre>
        </figure>
      ) : null}
    </aside>
  );
}
