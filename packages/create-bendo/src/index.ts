#!/usr/bin/env bun
import { main, terminal, UsageError } from "./cli.ts";
import { TargetNotEmpty } from "./create.ts";

const io = terminal();
try {
  process.exitCode = await main(process.argv.slice(2), io);
} catch (error) {
  if (!(error instanceof UsageError || error instanceof TargetNotEmpty)) throw error;
  process.stderr.write(`create-bendo: ${error.message}\n`);
  process.exitCode = 1;
} finally {
  io.close();
}
