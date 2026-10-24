import { createInterface } from "node:readline/promises";
import { relative } from "node:path";
import {
  checkTarget,
  create,
  isTemplate,
  TEMPLATE_SUMMARIES,
  TEMPLATES,
  type Created,
  type Template,
} from "./create.ts";

export const USAGE = `Usage: bun create bendo <dir> [--template api|fullstack]

Templates:
${TEMPLATES.map((name) => `  ${name.padEnd(10)} ${TEMPLATE_SUMMARIES[name]}`).join("\n")}

Options:
  -t, --template <name>  template to use (asked when interactive, otherwise api)
  -h, --help             show this help
`;

export class UsageError extends Error {
  override name = "UsageError";
}

export type Command =
  | { kind: "help" }
  | { kind: "create"; directory: string | undefined; template: Template | undefined };

function template(value: string | undefined): Template {
  if (value === undefined) throw new UsageError("--template needs a value: api or fullstack");
  if (!isTemplate(value))
    throw new UsageError(`Unknown template "${value}". Choose ${TEMPLATES.join(" or ")}.`);
  return value;
}

export function parseArgs(argv: readonly string[]): Command {
  let directory: string | undefined;
  let chosen: Template | undefined;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === undefined) continue;
    if (arg === "-h" || arg === "--help") return { kind: "help" };
    if (arg === "-t" || arg === "--template") chosen = template(argv[++i]);
    else if (arg.startsWith("--template=")) chosen = template(arg.slice("--template=".length));
    else if (arg.startsWith("-")) throw new UsageError(`Unknown option ${arg}`);
    else if (directory === undefined) directory = arg;
    else throw new UsageError(`Unexpected argument ${arg}`);
  }
  return { kind: "create", directory, template: chosen };
}

export type Io = {
  interactive: boolean;
  ask: (question: string) => Promise<string>;
  out: (text: string) => void;
};

async function askDirectory(io: Io): Promise<string> {
  const answer = (await io.ask("Project directory (bendo-app): ")).trim();
  return answer === "" ? "bendo-app" : answer;
}

async function askTemplate(io: Io): Promise<Template> {
  io.out("Templates:\n");
  TEMPLATES.forEach((name, i) =>
    io.out(`  ${i + 1}. ${name.padEnd(10)} ${TEMPLATE_SUMMARIES[name]}\n`),
  );
  for (;;) {
    const answer = (await io.ask("Template (1): ")).trim();
    if (answer === "") return "api";
    const picked = TEMPLATES[Number(answer) - 1];
    if (picked !== undefined) return picked;
    if (isTemplate(answer)) return answer;
    io.out(`Type 1 to ${TEMPLATES.length} or a template name.\n`);
  }
}

function shellPath(path: string): string {
  return /^[\w./-]+$/.test(path) ? path : `'${path.replaceAll("'", `'\\''`)}'`;
}

export function nextSteps(created: Created, cwd: string): string {
  const where = relative(cwd, created.target) || ".";
  const servers =
    created.template === "fullstack"
      ? "  bun run dev      # app on http://127.0.0.1:5173, API on :8787"
      : "  bun run dev      # API on http://127.0.0.1:8787";
  return `
Created ${where} from the ${created.template} template.

Next steps:
${where === "." ? "" : `  cd ${shellPath(where)}\n`}  bun install
${servers}

Building needs Bend ${created.bendVersion} and clang. Run \`bun run doctor\` to check your tools.
`;
}

/** Runs the CLI and returns its exit code. */
export async function main(argv: readonly string[], io: Io, cwd = process.cwd()): Promise<number> {
  const command = parseArgs(argv);
  if (command.kind === "help") {
    io.out(USAGE);
    return 0;
  }
  let directory = command.directory;
  if (directory === undefined) {
    if (!io.interactive) throw new UsageError(`Name a directory.\n\n${USAGE}`);
    directory = await askDirectory(io);
  }
  // Refuse before asking anything else.
  checkTarget(directory);
  const chosen = command.template ?? (io.interactive ? await askTemplate(io) : "api");
  io.out(nextSteps(create(directory, chosen), cwd));
  return 0;
}

export function terminal(): Io & { close: () => void } {
  const interactive = Boolean(process.stdin.isTTY && process.stdout.isTTY);
  const lines = interactive
    ? createInterface({ input: process.stdin, output: process.stdout })
    : undefined;
  return {
    interactive,
    ask: async (question) => {
      if (lines === undefined) throw new Error("cannot prompt without a terminal");
      return await lines.question(question);
    },
    out: (text) => process.stdout.write(text),
    close: () => lines?.close(),
  };
}
