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
3. Runs `npm publish --dry-run` on each tarball to confirm that npm reads the
   same name, version and file count, and `npm view` to check that the version
   is not already on npm. Neither one writes anything.
4. Writes `.cache/release/bendhub/src/bendhub.bend`, an entry that imports
   every public module of `src/`, beside a copy of `LICENSE`, and runs the real
   `bend bendhub.bend --publish` with `BEND_HUB` and `BEND_ORIGIN` pointed at a
   stub hub on `127.0.0.1`. The stub checks the upload's hash the way BendHub
   does and keeps it in memory, so the report lists exactly the files, sizes and
   SHA-256 sums that `bend` would send, and the package hash.
5. Compiles a small consumer that imports `bendo@<version>/main.bend` and
   `validated.bend` by name, served by the stub from the captured upload.
6. Lists what would stop a real publish right now.

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
share one version that is not on npm yet, `npm publish --dry-run` agrees with
every tarball, the BendHub import check passes, and npm and bend are logged in.

Then it runs, in order, printing each command first:

```sh
npm publish .cache/release/tarballs/bendo-0.1.0.tgz --registry https://registry.npmjs.org/ --access public --tag latest
npm publish .cache/release/tarballs/vite-plugin-bendo-0.1.0.tgz --registry https://registry.npmjs.org/ --access public --tag latest
npm publish .cache/release/tarballs/create-bendo-0.1.0.tgz --registry https://registry.npmjs.org/ --access public --tag latest
(cd .cache/release/bendhub/src && bend bendhub.bend --publish bendo@0.1.0.0)
```

npm publishes the same tarballs the report describes. The `bend` command
uploads the listed files with a proof-of-work nonce to `hub.bend-lang.com`,
then registers the name `bendo` if it is free and links `bendo@0.1.0.0` to the
hash. It stops at the first failure and says that earlier steps did publish;
rerun the failed step by hand from the printed command.

Afterwards, tag the release and push the tags:

```sh
bunx changeset tag
git push --follow-tags
```

The packages are published from a laptop, so they carry no npm provenance.
Moving the publish to a GitHub Actions workflow with npm trusted publishing is
a later change.
