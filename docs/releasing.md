# Releasing

`bun run release` publishes `bendo`, `vite-plugin-bendo` and `create-bendo`
to npm and the Bend library to BendHub. The real publish is Leo's step. Anyone
can run the dry run, which sends nothing. [Versioning](./versioning.md) says
which version to release.

## See what would publish

```sh
bun run release --dry-run
```

The dry run copies the three packages, the Bend library and the toolchain pins
into `.cache/release/` and applies any pending changesets there, as
`bun run version-packages` would. The repository is not modified. Then it:

1. Packs each package with `bun pm pack`, which runs `create-bendo`'s prepack
   and turns `workspace:^` into a real version range.
2. Reads each tarball and prints its name, version, size, shasum, integrity,
   access, `bin`, `exports`, dependencies after the workspace replacement, and
   every file with its size.
3. Runs `npm publish --dry-run --offline` on each tarball to confirm that npm
   reads the same name, version, file count and integrity, and
   `npm view <name>@<version> dist.integrity --registry https://registry.npmjs.org/`
   to see whether that version is already on npm. Neither one writes anything.
4. Writes `.cache/release/bendhub/src/bendhub.bend`, an entry that imports
   every public module of `src/`, beside a copy of `LICENSE`, and runs the real
   `bend bendhub.bend --publish` with `BEND_HUB` and `BEND_ORIGIN` set to a
   stub hub on `127.0.0.1`. The stub checks the upload's hash the way BendHub
   does and keeps it in memory, so the report lists exactly the files, sizes and
   SHA-256 sums that `bend` would send, and the package hash.
5. Compiles a small consumer that imports `bendo@<version>/main.bend` and
   `validated.bend` by name, served by the stub from the captured upload.
6. Asks `hub.bend-lang.com/name/bendo@<version>.0` whether the name already
   links to a hash. This is a read.
7. Lists what would stop a real publish right now.

`--only=npm` or `--only=bendhub` limits it to one target, and `--json`
prints the report as JSON. The dry run takes about 20 seconds.

Without `--dry-run` or `--confirm`, the script refuses before doing anything.

## Publish (Leo)

Once, before the first release:

1. `npm login` as the account that will own the three packages.
2. `bend login`, which opens a BendAI login in the browser and stores the key
   in `~/.bend/bendai.json`.

For each release:

1. Merge the release's changesets to `main`. Run `bun run version-packages`,
   check the version bumps and `CHANGELOG.md` files, commit, and push `main`.
2. Run `bun run release --dry-run` and read the report. Its last section
   should say nothing would stop the publish.
3. Run `bun run release --confirm=<version>`, for example `--confirm=0.1.0`.

The confirmed run fetches `origin/main`, stages and checks everything again,
and stops with the list of reasons unless all of these hold: the confirmed
version is the version being released, the branch is `main` with a clean
working tree at `origin/main`, no changesets are pending, the three packages
share one version, `npm publish --dry-run` agrees with every tarball, the
BendHub import check passes, npm and bend are logged in, and neither registry
holds that version with different contents. It also stops if `BEND_HUB`,
`BEND_ORIGIN` or `NODE_TLS_REJECT_UNAUTHORIZED=0` is set in your shell. `bend`
has no flag for the hub and reads both variables from the environment, so the
script sets them itself and refuses to let a leftover override from local
testing send the upload, or your BendAI key, somewhere else.

Then it runs, in order, printing each command first:

```sh
npm publish .cache/release/tarballs/bendo-0.1.0.tgz --registry https://registry.npmjs.org/ --access public --tag latest
npm publish .cache/release/tarballs/vite-plugin-bendo-0.1.0.tgz --registry https://registry.npmjs.org/ --access public --tag latest
npm publish .cache/release/tarballs/create-bendo-0.1.0.tgz --registry https://registry.npmjs.org/ --access public --tag latest
(cd .cache/release/bendhub/src && BEND_HUB=https://hub.bend-lang.com BEND_ORIGIN=https://bend-lang.com bend bendhub.bend --publish bendo@0.1.0.0)
```

npm publishes the same tarballs the report describes. The `bend` command
uploads the listed files with a proof-of-work nonce to `hub.bend-lang.com`,
then registers the name `bendo` if it is free and links `bendo@0.1.0.0` to the
hash. The script stops at the first failure.

## Finish a partial release

If a step fails, fix the cause (a lost login, a network error) and run the same
command again:

```sh
bun run release --confirm=0.1.0
```

Packing is deterministic, so the rerun stages byte-identical tarballs and the
same BendHub hash. Each package already on npm with the same `dist.integrity`
is reported as already published and skipped, and so is `bendo@0.1.0.0` if
BendHub already links it to the same hash. The rest publish as usual. If a
registry holds the version with different contents, the run stops before
publishing anything and names the package: the staged code is not what was
released, so find out why before going on. Never bump the version just to get
past that stop. The dry run shows the same skip and stop lines, so run it first
when you are unsure what landed.

Afterwards, tag the release and push the tags:

```sh
bunx changeset tag
git push --follow-tags
```

The packages are published from a laptop, so they carry no npm provenance.
Moving the publish to a GitHub Actions workflow with npm trusted publishing is
a later change.
