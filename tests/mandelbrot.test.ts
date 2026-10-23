import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("examples/mandelbrot/main.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
});

const MODES = ["single", "cpu", "gpu"] as const;
type Mode = (typeof MODES)[number];

type Bmp = { width: number; height: number; rowSize: number; pixels: Uint8Array };

/** Parses a bottom-up 24-bit BMP, checking every header field the example writes. */
function parseBmp(bytes: Uint8Array): Bmp {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  expect(String.fromCharCode(bytes[0] ?? 0, bytes[1] ?? 0)).toBe("BM");
  expect(view.getUint32(2, true)).toBe(bytes.byteLength);
  expect(view.getUint32(10, true)).toBe(54);
  expect(view.getUint32(14, true)).toBe(40);
  const width = view.getInt32(18, true);
  const height = view.getInt32(22, true);
  expect(view.getUint16(26, true)).toBe(1);
  expect(view.getUint16(28, true)).toBe(24);
  expect(view.getUint32(30, true)).toBe(0);
  const rowSize = Math.ceil((width * 3) / 4) * 4;
  expect(view.getUint32(34, true)).toBe(rowSize * height);
  expect(bytes.byteLength).toBe(54 + rowSize * height);
  return { width, height, rowSize, pixels: bytes.subarray(54) };
}

/** Blue, green, red at column x of row y, counted from the bottom as BMP stores rows. */
function pixel(bmp: Bmp, x: number, y: number): [number, number, number] {
  const at = y * bmp.rowSize + x * 3;
  return [bmp.pixels[at] ?? -1, bmp.pixels[at + 1] ?? -1, bmp.pixels[at + 2] ?? -1];
}

async function render(query: string): Promise<{ response: Response; bytes: Uint8Array }> {
  const response = await fetch(`${server.url}/mandelbrot.bmp?${query}`, {
    signal: AbortSignal.timeout(20_000),
  });
  return { response, bytes: new Uint8Array(await response.arrayBuffer()) };
}

describe("examples/mandelbrot", () => {
  test("serves the index page with one image per mode", async () => {
    const response = await fetch(`${server.url}/`, { signal: AbortSignal.timeout(5000) });
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("text/html; charset=utf-8");
    const html = await response.text();
    for (const mode of MODES) expect(html).toContain(`/mandelbrot.bmp?mode=${mode}&amp;`);
  });

  test("every mode returns the same valid BMP with Server-Timing", async () => {
    // 13 columns force 1 byte of row padding; 7 rows exercise a ragged fork tree.
    const images = new Map<Mode, Uint8Array>();
    for (const mode of MODES) {
      const { response, bytes } = await render(`mode=${mode}&w=13&h=7&iter=64`);
      expect(response.status).toBe(200);
      expect(response.headers.get("content-type")).toBe("image/bmp");
      expect(response.headers.get("cache-control")).toBe("no-store");
      expect(response.headers.get("server-timing")).toMatch(
        new RegExp(`^compute;dur=\\d+;desc="${mode}", encode;dur=\\d+$`),
      );
      const bmp = parseBmp(bytes);
      expect([bmp.width, bmp.height, bmp.rowSize]).toEqual([13, 7, 40]);
      for (let y = 0; y < 7; y++) expect(bmp.pixels[y * bmp.rowSize + 39]).toBe(0);
      images.set(mode, bytes);
    }
    expect(images.get("cpu")).toEqual(images.get("single"));
    expect(images.get("gpu")).toEqual(images.get("single"));
  });

  test("draws the set: inside is black, the far corner is not", async () => {
    const outputs: Uint8Array[] = [];
    for (const mode of MODES) {
      const { response, bytes } = await render(`mode=${mode}&w=64&h=48&iter=128`);
      expect(response.status).toBe(200);
      outputs.push(bytes);
    }
    const [single, ...rest] = outputs;
    if (single === undefined) throw new Error("no single-mode image");
    for (const other of rest) expect(other).toEqual(single);
    const bmp = parseBmp(single);
    // Pixel (39, 24) maps to about -0.18 + 0i, inside the main cardioid.
    expect(pixel(bmp, 39, 24)).toEqual([0, 0, 0]);
    expect(pixel(bmp, 0, 0)).not.toEqual([0, 0, 0]);
  });

  test("defaults to a 512x512 cpu render", async () => {
    const { response, bytes } = await render("");
    expect(response.status).toBe(200);
    expect(response.headers.get("server-timing")).toContain(`desc="cpu"`);
    const bmp = parseBmp(bytes);
    expect([bmp.width, bmp.height]).toEqual([512, 512]);
  });

  test("rejects bad parameters with 400", async () => {
    for (const query of [
      "mode=fast",
      "mode=",
      "w=0",
      "h=1025",
      "iter=0",
      "iter=2000",
      "w=abc",
      "w=-4",
      "w=00512",
      "h=4294967297",
    ]) {
      const { response } = await render(query);
      expect({ query, status: response.status }).toEqual({ query, status: 400 });
    }
  });
});
