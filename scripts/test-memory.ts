import { readFileSync } from "node:fs";
import { freemem } from "node:os";
import { dirname, join, relative, resolve } from "node:path";

const GiB = 1024 ** 3;
// Large compiles finish before workers start; the largest
// .mjs test heaps run in separate serial processes. Remaining cold compiles
// peaked at 1.68 GiB on Boat, leaving about 330 MiB of scheduling headroom for
// Bun and its servers. This allowance schedules processes; it is not a heap limit.
export const WORKER_MEMORY_BYTES = 2 * GiB;
const RUNNER_RESERVE_BYTES = GiB / 8;

function read(path: string): string | undefined {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return undefined;
  }
}

export function memoryAllowance({
  hostAvailable,
  limit,
  used,
}: {
  hostAvailable: number;
  limit: string | undefined;
  used: string | undefined;
}): number {
  const maximum = Number(limit);
  const current = Number(used);
  if (
    limit?.trim() &&
    used?.trim() &&
    Number.isFinite(maximum) &&
    maximum >= 0 &&
    Number.isFinite(current) &&
    current >= 0
  ) {
    return Math.min(hostAvailable, Math.max(0, maximum - current));
  }
  return hostAvailable;
}

export function cgroupMemoryFiles(
  membership: string,
  mounts: string,
): { limit: string; used: string }[] {
  const files: { limit: string; used: string }[] = [];
  const unescape = (path: string) =>
    path.replace(/\\([0-7]{3})/g, (_, octal: string) => String.fromCharCode(parseInt(octal, 8)));
  for (const mount of mounts.trim().split("\n")) {
    const [before, after] = mount.split(" - ");
    if (before === undefined || after === undefined) continue;
    const [type, , options] = after.split(" ");
    const fields = before.split(" ");
    const root = fields[3];
    const mountpoint = fields[4];
    if (root === undefined || mountpoint === undefined) continue;
    if (type !== "cgroup2" && !(type === "cgroup" && options?.split(",").includes("memory")))
      continue;
    for (const entry of membership.trim().split("\n")) {
      const [, controllers, path] = /^[^:]*:([^:]*):(.*)$/.exec(entry) ?? [];
      if (path === undefined || controllers === undefined) continue;
      if (type === "cgroup2" ? controllers !== "" : !controllers.split(",").includes("memory"))
        continue;
      const suffix = relative(unescape(root), path);
      if (suffix === ".." || suffix.startsWith("../")) continue;
      const top = resolve(unescape(mountpoint));
      let directory = resolve(top, suffix);
      for (;;) {
        files.push({
          limit: join(directory, type === "cgroup2" ? "memory.max" : "memory.limit_in_bytes"),
          used: join(directory, type === "cgroup2" ? "memory.current" : "memory.usage_in_bytes"),
        });
        if (directory === top) break;
        directory = dirname(directory);
      }
    }
  }
  return files;
}

export function availableMemory(): number {
  const available = read("/proc/meminfo")?.match(/^MemAvailable:\s+(\d+) kB$/m)?.[1];
  let memory = available === undefined ? freemem() : Number(available) * 1024;
  for (const files of cgroupMemoryFiles(
    read("/proc/self/cgroup") ?? "",
    read("/proc/self/mountinfo") ?? "",
  )) {
    memory = memoryAllowance({
      hostAvailable: memory,
      limit: read(files.limit),
      used: read(files.used),
    });
  }
  return memory;
}

export function testWorkers({
  memory,
  cores,
  override,
}: {
  memory: number;
  cores: number;
  override: string | undefined;
}): number {
  const requested = override === undefined ? 4 : Number(override);
  if (!Number.isSafeInteger(requested) || requested < 1) {
    throw new Error("BENDO_TEST_WORKERS must be a positive integer");
  }
  // One worker is the irreducible minimum, even on machines below the budget.
  // The override can reduce concurrency but cannot bypass the memory cap.
  return Math.max(
    1,
    Math.min(
      4,
      cores,
      requested,
      Math.floor((memory - RUNNER_RESERVE_BYTES) / WORKER_MEMORY_BYTES),
    ),
  );
}
