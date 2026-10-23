import { expect, test } from "bun:test";
import { build, start } from "./harness.ts";

const binary = build("tests/servers/router-compose.bend");

const expectedRoutes = [
  { method: "GET", path: "/outside", params: [] },
  { method: "GET", path: "/api/v1/sibling", params: [] },
  { method: "GET", path: "/api/v1/items/:id{int}", params: ["id"] },
  { method: "GET", path: "/api/v1/fail", params: [] },
  { method: "GET", path: "/api/v1/", params: [] },
  { method: "POST", path: "/api/v1/guarded", params: [] },
  { method: "GET", path: "/:tenant/users/:id", params: ["tenant", "id"] },
  { method: "GET", path: "/one/two/three/deep", params: [] },
  { method: "GET", path: "/outer/inner/items/:id{int}", params: ["id"] },
  { method: "GET", path: "/outer/inner/fail", params: [] },
  { method: "GET", path: "/outer/inner/", params: [] },
  { method: "POST", path: "/outer/inner/guarded", params: [] },
  { method: "GET", path: "/wild/*", params: ["*"] },
  { method: "GET", path: "/named/*tail", params: ["tail"] },
  { method: "GET", path: "/groupwild/*", params: ["*"] },
  { method: "GET", path: "/identity", params: [] },
];

test("mounted routes answer only beneath their segment prefix and retain captures", async () => {
  await using server = await start(binary);
  for (const path of ["/api/v1/items/42", "/outer/inner/items/42"]) {
    const res = await fetch(server.url + path);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("-:42:-");
    expect(res.headers.get("x-child")).toBe("yes");
    expect(res.headers.get("x-item")).toBe("yes");
    expect(res.headers.get("x-before")).toBe("yes");
  }
  for (const path of ["/items/42", "/apix/v1/items/42", "/api/v1x/items/42", "/inner/items/42"]) {
    const res = await fetch(server.url + path);
    expect(res.status, path).toBe(404);
    expect(await res.text()).toBe("parent missing");
    expect(res.headers.get("x-child")).toBeNull();
    expect(res.headers.get("x-before")).toBeNull();
  }
  const tenant = await fetch(`${server.url}/acme/users/A%20B`);
  expect(await tenant.text()).toBe("acme:A B:-");
  const named = await fetch(`${server.url}/named/a/b`);
  expect(await named.text()).toBe("-:-:a/b");
});

test("groups nest three levels, normalize one join slash, and retain root identities", async () => {
  await using server = await start(binary);
  for (const path of ["/one/two/three/deep", "/identity", "/api/v1/", "/outer/inner/"]) {
    expect((await fetch(server.url + path)).status, path).toBe(200);
  }
  for (const path of ["/one/two/deep", "/one/two//three/deep", "/api/v1"]) {
    expect((await fetch(server.url + path)).status, path).toBe(404);
  }
});

test("bare wildcard mounting and grouping never become prefix wildcards", async () => {
  await using server = await start(binary);
  for (const prefix of ["/wild", "/groupwild"]) {
    for (const suffix of ["", "/", "/a/b"]) {
      expect((await fetch(server.url + prefix + suffix)).status).toBe(200);
    }
    expect((await fetch(`${server.url}${prefix}x/a`)).status).toBe(404);
  }
});

test("mounts carry guards and errors; parent owns misses and middleware retains path scope", async () => {
  await using server = await start(binary);
  for (const prefix of ["/api/v1", "/outer/inner"]) {
    const guarded = await fetch(`${server.url}${prefix}/guarded`, { method: "POST" });
    expect(guarded.status).toBe(200);
    expect(guarded.headers.get("x-guard")).toBe("yes");
    expect(guarded.headers.get("x-item")).toBeNull();
    const failure = await fetch(`${server.url}${prefix}/fail`);
    expect(failure.status).toBe(202);
    expect(await failure.text()).toBe("child recovered");
    const missing = await fetch(`${server.url}${prefix}/missing`);
    expect(missing.status).toBe(404);
    expect(await missing.text()).toBe("parent missing");
    expect(missing.headers.get("x-child")).toBe("yes");
    expect(missing.headers.get("x-before")).toBeNull();
    const wrong = await fetch(`${server.url}${prefix}/items/42`, { method: "POST" });
    expect(wrong.status).toBe(405);
    expect(wrong.headers.get("allow")).toBe("GET, HEAD");
  }
  const sibling = await fetch(`${server.url}/api/v1/sibling`);
  expect(sibling.headers.get("x-child")).toBe("yes");
  expect(sibling.headers.get("x-before")).toBeNull();
  const outside = await fetch(`${server.url}/outside`);
  expect(outside.headers.get("x-child")).toBeNull();
  expect(outside.headers.get("x-before")).toBeNull();
});

test("manifest lists exactly the full composed paths and param names before listening", () => {
  const run = Bun.spawnSync([binary, "--bendo-routes"], {
    stdout: "pipe",
    stderr: "pipe",
    timeout: 5000,
  });
  expect(run.exitCode).toBe(0);
  expect(run.stderr.toString()).toBe("");
  const manifest: unknown = JSON.parse(run.stdout.toString());
  expect(manifest).toEqual({ bendo: 1, routes: expectedRoutes });
});

test("show_routes prints the same explicit method/path rows as the manifest", () => {
  const run = Bun.spawnSync([binary, "--show-routes"], {
    stdout: "pipe",
    stderr: "pipe",
    timeout: 5000,
  });
  expect(run.exitCode).toBe(0);
  expect(run.stdout.toString()).toBe(
    "METHOD\tPATH\n" + expectedRoutes.map((r) => `${r.method}\t${r.path}`).join("\n") + "\n",
  );
});

const driver = build("tests/router-compose-driver.bend");
test("composition validates combined patterns and exports normalized methods and capture kinds", () => {
  const run = Bun.spawnSync([driver], { stdout: "pipe", stderr: "pipe", timeout: 5000 });
  expect(run.exitCode).toBe(0);
  const lines = run.stdout.toString().trim().split("\n");
  expect(lines.slice(0, 4)).toEqual([
    "0:bad/x:MissingSlash",
    "0:/:id/:id:DuplicateName",
    "0:/:tenant?/required:OptionalNotLast",
    "0:/api/:bad{unknown}:UnknownConstraint",
  ]);
  expect(lines.slice(5)).toEqual(["found", "found", "missing", "/a//x", "/a/x"]);
  const manifest: unknown = JSON.parse(lines[4] ?? "");
  expect(manifest).toEqual({
    bendo: 1,
    routes: [
      { method: "GET", path: "/api/:id?", params: ["id"] },
      { method: "POST", path: "/api/:id?", params: ["id"] },
      { method: "GET", path: "/api/:id?", params: ["id"] },
      { method: "ALL", all: true, path: "/api/files/*tail", params: ["tail"] },
      { method: "GET", path: "/api/:span{.+}/end", params: ["span"] },
      { method: "GET", path: "/api/a/*/b/assets*", params: [] },
      { method: "GET", path: "/api/same", params: [] },
      { method: "GET", path: "/api/same", params: [] },
    ],
  });
});
