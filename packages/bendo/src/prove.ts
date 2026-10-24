import { stripVTControlCharacters } from "node:util";
import { findBend } from "./bend.ts";

export function prove(file: string): number {
  const bend = findBend();
  if (bend.kind === "missing")
    throw new Error("bend not found. Run bendo doctor for installation commands.");
  const run = Bun.spawnSync([bend.path, file, "--verdict"], {
    stdout: "pipe",
    stderr: "pipe",
    timeout: 600_000,
  });
  const output = stripVTControlCharacters(`${run.stdout}${run.stderr}`).trim();
  if (run.exitCode === 0) console.log(`${file}: ALL PROOFS CHECK`);
  else {
    // Keep law names and Bend's Location/source excerpts; omit runtime stacks.
    const lines = output
      .split("\n")
      .filter((line) => !/^\s*at\s+/.test(line) && !/^\s*Stack trace:/i.test(line));
    console.error(
      `${file}: proof check failed (exit ${run.exitCode})\n${lines.join("\n") || "No diagnostics from Bend"}`,
    );
  }
  return run.exitCode === 0 ? 0 : run.exitCode > 0 ? run.exitCode : 1;
}
