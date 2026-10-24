import { readFileSync } from "node:fs";

/** A 1-based position in a Bend source file. */
export type Location = { file: string; line: number; column: number };

/** A compile failure in the shape Vite's error overlay reads. */
export type Diagnostic = { message: string; frame: string; loc: Location };

const FRAME_LINE = /^ *(\d+)(>| ?)\| ?(.*)$/;
const CARET_LINE = /^ *\|( *)(\^+)/;
const DEF_NAME = /^Location: (\S+)\s*$/m;

type Frame = {
  lines: { number: number; text: string; marked: boolean }[];
  column: number;
  text: string[];
};

/** The first code frame of a Bend diagnostic, such as `4>|   5` with its `^` line. */
function firstFrame(output: string): Frame | undefined {
  const lines: Frame["lines"] = [];
  const text: string[] = [];
  let column = 1;
  for (const raw of output.split("\n")) {
    const numbered = FRAME_LINE.exec(raw);
    if (numbered !== null) {
      lines.push({
        number: Number(numbered[1]),
        marked: numbered[2] === ">",
        text: numbered[3] ?? "",
      });
      text.push(raw);
      continue;
    }
    const caret = CARET_LINE.exec(raw);
    if (caret !== null && lines.length > 0) {
      column = (caret[1] ?? " ").length;
      text.push(raw);
      continue;
    }
    if (lines.length > 0) break;
  }
  return lines.length === 0 ? undefined : { lines, column: Math.max(column, 1), text };
}

function fileLines(file: string): string[] {
  try {
    return readFileSync(file, "utf8").split("\n");
  } catch {
    return [];
  }
}

function defines(file: string, name: string): boolean {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`^def ${escaped}\\b`, "m").test(fileLines(file).join("\n"));
}

/**
 * Bend 2.0.38 prints a code frame and, for type errors, the def name, but not
 * the file. The file is the one in the entry's import graph whose lines match
 * every line of the frame; the def name and then the entry break ties.
 */
export function locate(output: string, entry: string, files: readonly string[]): Diagnostic {
  const frame = firstFrame(output);
  const name = DEF_NAME.exec(output)?.[1];
  const message = output
    .split("\n")
    .filter(
      (line) => line !== "SOME PROOFS FAIL" && line !== "Error:" && !frame?.text.includes(line),
    )
    .join("\n")
    .trim();
  const byName = name === undefined ? [] : files.filter((file) => defines(file, name));
  if (frame === undefined)
    return { message, frame: "", loc: { file: byName[0] ?? entry, line: 1, column: 1 } };
  const matching = files.filter((file) => {
    const lines = fileLines(file);
    return frame.lines.every(
      (line) => (lines[line.number - 1] ?? "").trimEnd() === line.text.trimEnd(),
    );
  });
  const file =
    matching.find((candidate) => byName.includes(candidate)) ??
    (matching.includes(entry) ? entry : matching[0]) ??
    byName[0] ??
    entry;
  const marked = frame.lines.find((line) => line.marked) ?? frame.lines[0];
  return {
    message,
    frame: frame.text.join("\n"),
    loc: { file, line: marked?.number ?? 1, column: frame.column },
  };
}

/** Points an IO refusal at the first offending def's header. */
export function ioDiagnostic(message: string, entry: string, defs: readonly string[]): Diagnostic {
  const lines = fileLines(entry);
  const first = defs[0] ?? "";
  const index = lines.findIndex((line) => line.startsWith(`def ${first}(`));
  return {
    message,
    frame: "",
    loc: { file: entry, line: index < 0 ? 1 : index + 1, column: 1 },
  };
}
