function object(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("Expected oha JSON object");
  }
  return Object.fromEntries(Object.entries(value));
}

function number(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw new Error("Expected finite nonnegative oha metric");
  }
  return value;
}

export function parseOha(input: unknown) {
  const root = object(input);
  const summary = object(root.summary);
  const percentiles = object(root.latencyPercentiles);
  const errors = object(root.errorDistribution);
  const statuses = object(root.statusCodeDistribution);
  let errorCount = Object.values(errors).reduce<number>((sum, count) => sum + number(count), 0);
  for (const [status, count] of Object.entries(statuses)) {
    if (!/^\d{3}$/.test(status)) throw new Error("Invalid oha HTTP status");
    if (Number(status) < 200 || Number(status) >= 300) errorCount += number(count);
    else number(count);
  }
  const requestsPerSecond = number(summary.requestsPerSec);
  if (requestsPerSecond === 0) throw new Error("oha completed no requests");
  return {
    requestsPerSecond,
    p50Ms: number(percentiles.p50) * 1000,
    p99Ms: number(percentiles.p99) * 1000,
    errorCount,
  };
}
