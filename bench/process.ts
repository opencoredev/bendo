export async function command(
  args: string[],
  options: { cwd?: string; timeoutMs?: number; signal?: AbortSignal } = {},
): Promise<string> {
  options.signal?.throwIfAborted();
  const child = Bun.spawn(args, {
    stdout: "pipe",
    stderr: "pipe",
    detached: true,
    ...(options.cwd === undefined ? {} : { cwd: options.cwd }),
  });
  const stop = () => {
    // Descendants can hold output pipes after the group leader exits.
    try {
      process.kill(-child.pid, "SIGKILL");
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ESRCH")) throw error;
    }
  };
  options.signal?.addEventListener("abort", stop, { once: true });
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    stop();
  }, options.timeoutMs ?? 300_000);
  try {
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(child.stdout).text(),
      new Response(child.stderr).text(),
      child.exited,
    ]);
    options.signal?.throwIfAborted();
    if (timedOut) throw new Error(`${args[0]} timed out`);
    if (exitCode !== 0) throw new Error(`${args[0]} exited ${exitCode}\n${stderr}\n${stdout}`);
    return stdout.trim();
  } finally {
    clearTimeout(timer);
    options.signal?.removeEventListener("abort", stop);
  }
}
