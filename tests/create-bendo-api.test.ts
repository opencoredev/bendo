import { describe, expect, test } from "bun:test";
import { CREATE_TEST_TIMEOUT_MS, scaffoldAndBuild, serve } from "./create-bendo.ts";

describe("bun create bendo --template api", () => {
  test(
    "scaffolds outside the checkout, installs, builds and serves its routes",
    async () => {
      const { app, scaffold, build } = scaffoldAndBuild("api");
      expect(scaffold).toContain("Created app from the api template.");
      expect(scaffold).toContain("bun install");
      expect(build).toContain("build: dist/server");

      await using server = await serve(app);
      const home = await fetch(`${server.url}/`);
      expect(await home.text()).toBe("Hello from Bendo!");

      const hello = await fetch(`${server.url}/hello/Ada`);
      expect(hello.status).toBe(200);
      expect(await hello.json()).toEqual({ message: "Hello, Ada!" });

      const echo = await fetch(`${server.url}/echo`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ message: "hi" }),
      });
      expect(await echo.json()).toEqual({ message: "hi" });

      const invalid = await fetch(`${server.url}/echo`, {
        method: "POST",
        headers: { "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({ message: "" }),
      });
      expect(invalid.status).toBe(422);
    },
    CREATE_TEST_TIMEOUT_MS,
  );
});
