import { createHash } from "node:crypto";
import { chmod, mkdir, mkdtemp, readFile, lstat, readlink, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve, sep } from "node:path";
import { command } from "./process.ts";

export async function snapshot(root: string, directory: string) {
  const commit = await command(["git", "rev-parse", "HEAD"], { cwd: root });
  const dirty = (await command(["git", "status", "--porcelain"], { cwd: root })).length > 0;
  const files = (
    await command(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], {
      cwd: root,
    })
  )
    .split("\0")
    .filter((name) => name !== "" && !name.startsWith("bench/results/"));
  const hash = createHash("sha256");
  for (const name of [...new Set(files)].sort()) {
    const path = join(root, name);
    const metadata = await lstat(path).catch((error: unknown) => {
      if (error instanceof Error && "code" in error && error.code === "ENOENT") return null;
      throw error;
    });
    if (metadata === null) continue;
    if (metadata.isSymbolicLink()) {
      const target = await readlink(path);
      if (!resolve(dirname(path), target).startsWith(root + sep))
        throw new Error(`Source symlink leaves repo: ${name}`);
      hash.update(JSON.stringify([name, "symlink", target]) + "\n");
      const destination = join(directory, name);
      await mkdir(dirname(destination), { recursive: true });
      await symlink(target, destination);
      continue;
    }
    if (!metadata.isFile()) throw new Error(`Unsupported source entry: ${name}`);
    const bytes = await readFile(path);
    const mode = metadata.mode & 0o777;
    hash.update(JSON.stringify([name, mode, bytes.length]) + "\n");
    hash.update(bytes);
    const destination = join(directory, name);
    await mkdir(dirname(destination), { recursive: true });
    await Bun.write(destination, bytes);
    await chmod(destination, mode);
  }
  return {
    commit,
    dirty,
    sha256: hash.digest("hex"),
    hashMethod:
      "sorted git-listed paths excluding bench/results; JSON [path, mode, byteLength] plus newline then bytes; symlinks use JSON [path, symlink, target] plus newline",
  };
}

export function sourceDirectory() {
  return mkdtemp(join(tmpdir(), "bendo-bench-source-"));
}
