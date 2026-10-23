import { expect, test } from "bun:test";
import { FIXTURE, fuzz } from "../../scripts/fuzz-http.ts";
import { build } from "../harness.ts";

// Short fixed-seed run for `bun run check`. Long runs go to a Boat sandbox:
// see docs/http-conformance.md.
const binary = build(FIXTURE);

test("1500 fixed-seed fuzz cases never crash, hang or break response framing", async () => {
  const report = await fuzz({ seed: 20261023, cases: 1500, concurrency: 8, binary });
  expect(report.failure).toBeUndefined();
  expect(report.cases).toBe(1500);
  // The generator must reach handlers and every rejection path, not just 400.
  for (const status of ["200", "400", "404", "413", "417", "431"])
    expect(report.statuses[status] ?? 0).toBeGreaterThan(0);
}, 30_000);
