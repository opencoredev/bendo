import { expect, test } from "bun:test";
import { command } from "./process.ts";

test("timeout stops descendants holding pipes after their parent exits", async () => {
  const started = performance.now();
  await expect(command(["bash", "-c", "sleep 2 & exit 0"], { timeoutMs: 100 })).rejects.toThrow(
    "timed out",
  );
  expect(performance.now() - started).toBeLessThan(1500);
});

test("abort stops descendants holding pipes after their parent exits", async () => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(new Error("interrupted")), 100);
  const started = performance.now();
  try {
    await expect(
      command(["bash", "-c", "sleep 2 & exit 0"], { signal: controller.signal }),
    ).rejects.toThrow("interrupted");
    expect(performance.now() - started).toBeLessThan(1500);
  } finally {
    clearTimeout(timer);
  }
});
