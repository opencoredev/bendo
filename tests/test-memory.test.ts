import { expect, test } from "bun:test";
import { cgroupMemoryFiles, memoryAllowance, testWorkers } from "../scripts/test-memory.ts";

test("cold workers share a memory budget and never exceed four or the CPU count", () => {
  const workers = (memory: number, cores = 4, override?: string) =>
    testWorkers({ memory, cores, override });
  expect(workers(6 * 1024 ** 3)).toBe(1);
  for (const { gib, count } of [
    { gib: 12.125, count: 2 },
    { gib: 18.125, count: 3 },
    { gib: 24.125, count: 4 },
  ]) {
    const threshold = gib * 1024 ** 3;
    expect(workers(threshold - 1)).toBe(count - 1);
    expect(workers(threshold)).toBe(count);
  }
  expect(workers(6.3 * 1024 ** 3)).toBe(1);
  expect(workers(15 * 1024 ** 3)).toBe(2);
  expect(workers(64 * 1024 ** 3)).toBe(4);
  expect(workers(64 * 1024 ** 3, 2)).toBe(2);
  expect(workers(0)).toBe(1);
  expect(workers(64 * 1024 ** 3, 4, "2")).toBe(2);
  expect(workers(6 * 1024 ** 3, 4, "99")).toBe(1);
  for (const override of ["0", "-1", "1.5", "many", "", "Infinity"]) {
    expect(() => workers(8 * 1024 ** 3, 4, override)).toThrow(
      "BENDO_TEST_WORKERS must be a positive integer",
    );
  }
});

test("cgroup remaining memory bounds host availability, with a host fallback", () => {
  const allowance = (limit?: string, used?: string) =>
    memoryAllowance({ hostAvailable: 1000, limit, used });
  expect(allowance("800", "300")).toBe(500);
  expect(allowance("800", "900")).toBe(0);
  expect(allowance("0", "0")).toBe(0);
  expect(allowance("2000", "100")).toBe(1000);
  expect(allowance("max", "100")).toBe(1000);
  expect(allowance()).toBe(1000);
  expect(allowance("broken", "100")).toBe(1000);
});

test("nested cgroup v2 membership checks every ancestor up to the mounted root", () => {
  expect(
    cgroupMemoryFiles(
      "0::/user.slice/app/worker\n",
      "36 27 0:30 / /sys/fs/cgroup rw - cgroup2 cgroup2 rw\n",
    ),
  ).toEqual([
    {
      limit: "/sys/fs/cgroup/user.slice/app/worker/memory.max",
      used: "/sys/fs/cgroup/user.slice/app/worker/memory.current",
    },
    {
      limit: "/sys/fs/cgroup/user.slice/app/memory.max",
      used: "/sys/fs/cgroup/user.slice/app/memory.current",
    },
    {
      limit: "/sys/fs/cgroup/user.slice/memory.max",
      used: "/sys/fs/cgroup/user.slice/memory.current",
    },
    { limit: "/sys/fs/cgroup/memory.max", used: "/sys/fs/cgroup/memory.current" },
  ]);
  let memory = 64;
  for (const [limit, used] of [
    ["max", "1"],
    ["60", "50"],
    ["max", "52"],
  ]) {
    memory = memoryAllowance({ hostAvailable: memory, limit, used });
  }
  expect(memory).toBe(10);
});

test("cgroup v1 mount roots map membership without escaping the visible hierarchy", () => {
  const mount = "36 27 0:30 /tenant /sys/fs/cgroup/memory rw - cgroup cgroup rw,memory\n";
  expect(cgroupMemoryFiles("4:cpu:/unrelated\n5:memory:/tenant/job\n", mount)).toEqual([
    {
      limit: "/sys/fs/cgroup/memory/job/memory.limit_in_bytes",
      used: "/sys/fs/cgroup/memory/job/memory.usage_in_bytes",
    },
    {
      limit: "/sys/fs/cgroup/memory/memory.limit_in_bytes",
      used: "/sys/fs/cgroup/memory/memory.usage_in_bytes",
    },
  ]);
  expect(cgroupMemoryFiles("5:memory:/elsewhere\n", mount)).toEqual([]);
  expect(cgroupMemoryFiles("", "")).toEqual([]);
});

test("colons in cgroup names remain part of the path", () => {
  expect(
    cgroupMemoryFiles(
      "0::/job:build/worker",
      "36 27 0:30 / /sys/fs/cgroup rw - cgroup2 cgroup2 rw",
    )[0],
  ).toEqual({
    limit: "/sys/fs/cgroup/job:build/worker/memory.max",
    used: "/sys/fs/cgroup/job:build/worker/memory.current",
  });
});
