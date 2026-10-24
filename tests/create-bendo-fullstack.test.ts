import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { CREATE_TEST_TIMEOUT_MS, scaffoldAndBuild, serve } from "./create-bendo.ts";

const TEMPLATE = resolve(import.meta.dir, "../packages/create-bendo/templates/fullstack");

describe("bun create bendo --template fullstack", () => {
  test(
    "builds the API, route types and web app, and serves both",
    async () => {
      const { app, scaffold, build } = scaffoldAndBuild("fullstack");
      expect(scaffold).toContain("Created app from the fullstack template.");
      // The build regenerated .bendo/, then ran vite build and tsc.
      expect(build).toContain("generate: wrote .bendo/routes.ts");
      expect(build).toContain("dist/web/index.html");
      // The template ships the generated files, so they must match main.bend.
      for (const file of ["routes.ts", "routes.schemas.ts"])
        expect(readFileSync(join(app, ".bendo", file), "utf8")).toBe(
          readFileSync(join(TEMPLATE, ".bendo", file), "utf8"),
        );

      await using server = await serve(app);
      const hello = await fetch(`${server.url}/api/hello?name=Ada`);
      expect(await hello.json()).toEqual({ message: "Hello, Ada!" });
      const fallback = await fetch(`${server.url}/api/hello`);
      expect(await fallback.json()).toEqual({ message: "Hello, world!" });

      const added = await fetch(`${server.url}/api/notes`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ text: "first" }),
      });
      expect(added.status).toBe(201);
      expect(await added.json()).toEqual({ id: 1, text: "first" });
      const notes = await fetch(`${server.url}/api/notes`);
      expect(await notes.json()).toEqual({ notes: [{ id: 1, text: "first" }] });

      // shared/notes.bend sets the limit the server checks.
      const long = await fetch(`${server.url}/api/notes`, {
        method: "POST",
        headers: { "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({ text: "x".repeat(141) }),
      });
      expect(long.status).toBe(422);

      const missing = await fetch(`${server.url}/api/nope`);
      expect(missing.status).toBe(404);

      // Every other GET path gets the page, so router links survive a reload.
      for (const path of ["/", "/about"]) {
        const page = await fetch(`${server.url}${path}`);
        expect(page.headers.get("content-type")).toStartWith("text/html");
        const html = await page.text();
        expect(html).toContain('<div id="root"></div>');
        const script = html.match(/src="(\/assets\/[^"]+\.js)"/)?.[1];
        expect(script).toBeDefined();
        const asset = await fetch(`${server.url}${script}`);
        expect(asset.status).toBe(200);
        expect(asset.headers.get("cache-control")).toContain("immutable");
      }
    },
    CREATE_TEST_TIMEOUT_MS,
  );
});
