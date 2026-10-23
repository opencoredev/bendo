#!/usr/bin/env bun
import pkg from "../package.json" with { type: "json" };
import { findBend } from "./bend.ts";

const USAGE = `bendo ${pkg.version}

Usage:
  bendo doctor     check that Bend is installed
  bendo --version  print the version`;

function doctor(): number {
  const bend = findBend();
  switch (bend.kind) {
    case "found":
      process.stdout.write(`bend ${bend.version} at ${bend.path}\n`);
      return 0;
    case "missing":
      process.stderr.write(
        "bend not found. Install it: curl -fsSL https://bend-lang.com/install.sh | sh\n",
      );
      return 1;
    default: {
      const _exhaustive: never = bend;
      return _exhaustive;
    }
  }
}

const command = process.argv[2];
if (command === "doctor") process.exit(doctor());
if (command === "--version" || command === "-v") {
  process.stdout.write(`${pkg.version}\n`);
  process.exit(0);
}
process.stdout.write(`${USAGE}\n`);
process.exit(command === undefined || command === "--help" ? 0 : 1);
