import { readFile } from "node:fs/promises";
import { basename } from "node:path";

function object(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value))
    throw new Error("Expected results object");
  return Object.fromEntries(Object.entries(value));
}
function text(value: unknown): string {
  if (typeof value !== "string") throw new Error("Expected label");
  return value;
}
function metric(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0)
    throw new Error("Invalid metric");
  return value;
}
function escape(value: string) {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll('"', "&quot;");
}
const input = process.argv[2];
if (!input) throw new Error("Usage: bun bench/chart.ts bench/results/<run>.json [output.svg]");
const data = object(JSON.parse(await readFile(input, "utf8")));
if (data.schemaVersion !== 2 || !Array.isArray(data.results))
  throw new Error("Expected benchmark schema v2");
const method = object(data.method);
const subtitle = `${metric(method.connections)} connections · ${metric(method.durationSeconds)} seconds × ${metric(method.repetitions)} · ${method.keepAlive === true ? "keep-alive" : "new connections"} · CPUs server ${text(method.serverCpus)} / oha ${text(method.loadCpus)}`;
const rows = data.results.map((value: unknown) => {
  const row = object(value);
  const summary = object(row.summary);
  const rps = object(summary.requestsPerSecond);
  return {
    scenario: text(row.scenario),
    framework: text(row.framework),
    variant: text(row.variant),
    rps: metric(rps.median),
    min: metric(rps.min),
    max: metric(rps.max),
    p50: metric(object(summary.p50Ms).median),
    p99: metric(object(summary.p99Ms).median),
    errors: metric(summary.errorCount),
  };
});
const totalErrors = rows.reduce((sum, row) => sum + row.errors, 0);
const ceiling = Math.max(1, ...rows.filter((row) => row.errors === 0).map((row) => row.max));
const height = 150 + rows.length * 38;
const body = rows
  .map((row, i) => {
    const y = 114 + i * 38;
    const color =
      row.framework === "bendo"
        ? row.variant === "default"
          ? "#137b70"
          : "#85b9b2"
        : row.framework === "hono"
          ? "#c96820"
          : "#7354b3";
    const x = (n: number) => 305 + (n / ceiling) * 415;
    return `<text x="20" y="${y + 15}" font-size="13">${escape(`${row.scenario} · ${row.framework} ${row.variant}${row.errors ? " INVALID" : ""}`)}</text><rect x="305" y="${y}" width="${row.errors ? 0 : x(row.rps) - 305}" height="23" fill="${color}"/>${row.errors ? "" : `<path d="M${x(row.min)} ${y + 11}H${x(row.max)}" stroke="#172b36" stroke-width="2"/>`}<text x="740" y="${y + 15}">${Math.round(row.rps).toLocaleString("en-US")}</text><text x="850" y="${y + 15}">${row.p50.toFixed(2)}</text><text x="940" y="${y + 15}">${row.p99.toFixed(2)}</text>`;
  })
  .join("\n");
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1040" height="${height}" viewBox="0 0 1040 ${height}" role="img" aria-labelledby="title desc"><title id="title">Bendo, Hono and Elysia benchmark</title><desc id="desc">Median throughput, min/max whiskers, and median p50/p99 latency. Source ${escape(basename(input))}. ${rows.reduce((sum, r) => sum + r.errors, 0)} errors.</desc><rect width="1040" height="${height}" fill="#fafaf7"/><g font-family="system-ui,sans-serif" fill="#172b36"><text x="20" y="32" font-size="22" font-weight="700">Bendo · Hono · Elysia</text><text x="20" y="58" font-size="13">${escape(subtitle)}</text><text x="20" y="80" font-size="12">Bars: median requests/s. Whiskers: min–max. ${totalErrors} errors; rows with errors are INVALID and have no bar.</text><g font-size="12" font-weight="700"><text x="740" y="103">requests/s</text><text x="850" y="103">p50 ms</text><text x="940" y="103">p99 ms</text></g>${body}<text x="20" y="${height - 16}" font-size="11">Source: ${escape(basename(input))} · ${escape(text(data.measuredAt))} · See bench/README.md for middleware differences and limits.</text></g></svg>\n`;
const output = process.argv[3] ?? input.replace(/\.json$/, ".svg");
if (output === input) throw new Error("Output must differ from input");
await Bun.write(output, svg);
process.stdout.write(output + "\n");
