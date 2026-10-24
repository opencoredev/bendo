// `bun run dev`: the Bendo API (rebuilt on every .bend save) and Vite, which
// proxies /api to it. Stopping either one stops both.
const apiPort = process.env.API_PORT ?? "8787";

const children = [
  Bun.spawn(["bendo", "dev"], {
    env: { ...process.env, PORT: apiPort },
    stdio: ["inherit", "inherit", "inherit"],
  }),
  Bun.spawn(["bun", "--bun", "vite"], {
    env: { ...process.env, API_PORT: apiPort },
    stdio: ["inherit", "inherit", "inherit"],
  }),
];

function stop(): void {
  for (const child of children) child.kill("SIGTERM");
}

process.on("SIGINT", stop);
process.on("SIGTERM", stop);

const code = await Promise.race(children.map((child) => child.exited));
stop();
await Promise.all(children.map((child) => child.exited));
process.exit(code);
