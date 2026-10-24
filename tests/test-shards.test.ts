import { expect, test } from "bun:test";
import {
  guardAssignment,
  selectedTestFiles,
  shardPlan,
  testFiles,
} from "../scripts/test-shards.ts";

test("all discovered files run exactly once in a deterministic shard", () => {
  const files = testFiles();
  const plan = shardPlan(files);
  expect(() => guardAssignment(files, plan)).not.toThrow();
  expect(shardPlan([...files].reverse())).toEqual(plan);
  expect(plan.flat().sort()).toEqual(files);
});

test("the assignment guard rejects dropped, duplicated and unknown files", () => {
  const files = ["a.test.ts", "b.test.ts", "c.test.ts", "d.test.ts"];
  expect(() =>
    guardAssignment(files, [[files[0] ?? ""], ["b.test.ts"], ["c.test.ts"], []]),
  ).toThrow();
  expect(() =>
    guardAssignment(files, [["a.test.ts"], ["b.test.ts"], ["c.test.ts"], ["a.test.ts"]]),
  ).toThrow();
  expect(() =>
    guardAssignment(files, [["a.test.ts"], ["b.test.ts"], ["c.test.ts"], ["other.test.ts"]]),
  ).toThrow();
});

test("the shard selection is the same plan used by the guard", () => {
  const previous = process.env.BENDO_TEST_SHARD;
  try {
    for (const [index, files] of shardPlan().entries()) {
      process.env.BENDO_TEST_SHARD = String(index + 1);
      expect(selectedTestFiles()).toEqual(files);
    }
    process.env.BENDO_TEST_SHARD = "0";
    expect(() => selectedTestFiles()).toThrow("BENDO_TEST_SHARD");
  } finally {
    if (previous === undefined) delete process.env.BENDO_TEST_SHARD;
    else process.env.BENDO_TEST_SHARD = previous;
  }
});
