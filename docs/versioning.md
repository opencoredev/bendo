# Versioning

Bendo ships four things under one version number: the npm packages `bendo`,
`create-bendo` and `vite-plugin-bendo`, and the Bend library on BendHub. This
page says what a version number promises and how the four relate.
[Releasing](./releasing.md) covers the release itself.

## One version for everything

The three npm packages always carry the same version. They form a `fixed`
group in `.changeset/config.json`, so a changeset that bumps one of them bumps
all three, and packages with no changes are still released at the new number.
`vite-plugin-bendo` depends on `bendo` at `^<version>`.

The Bend library goes to BendHub as `bendo@<major>.<minor>.<patch>.0`. BendHub
names take four numbers, and the fourth is always `0`. Version `0.1.0` on npm is
`bendo@0.1.0.0` on BendHub, and an app imports it as:

```python
import bendo@0.1.0.0/main.bend as B
import bendo@0.1.0.0/validated.bend as V
```

The library ships in two places. `create-bendo` copies it into every new app's
`bendo/` directory, and BendHub serves the same files. Both come from `src/` at
the same commit, so `create-bendo@0.1.0` and `bendo@0.1.0.0` contain the same
Bend code. A fix to the library is a new patch release of all four. Bendo never
republishes the library alone under a new fourth number.

The `bendo` CLI reads the route manifest that a compiled app prints with
`--bendo-routes`. Its `version` field changes only in a minor release (before
1.0) or a major release (after), and the `bendo` package of that release
understands it.

## What a bump means

Bendo follows [Semantic Versioning](https://semver.org). The public API is
what the docs site documents: the exports of `bendo`, `bendo/client`,
`bendo/query` and `bendo/shared`, the CLI commands and flags, the plugin
options, the `create-bendo` arguments and templates, and the Bend names that
`main.bend` and the documented opt-in modules export.

Before 1.0, the minor number is the breaking one:

| Change | Before 1.0 | From 1.0 |
| --- | --- | --- |
| Removes or changes a documented API, the manifest format, or the pinned Bend version | minor (`0.1.0` → `0.2.0`) | major |
| Adds an API, a middleware, an option or a template | minor or patch | minor |
| Fixes a bug, with no API change | patch | patch |

npm's caret ranges treat `0.x` the same way: `^0.1.0` accepts `0.1.5` but not
`0.2.0`. An app on `^0.1.0` gets fixes and never a breaking change.

Changing a law in `LAWS.bend` is a breaking change even when no signature
changes, because a law is a promise about behavior. Adding a law is not.

Prerelease versions such as `0.2.0-next.1` are not used. BendHub names have no
prerelease part, and before 1.0 a minor release already marks a break.

## The pinned toolchain

Each release pins one Bend version (`.bend-version`) and one Lean toolchain
(`lean-toolchain`). `create-bendo` copies both into new apps, and `bendo
doctor` checks them. Moving the Bend pin is a breaking change before 1.0,
because the new compiler may reject code the old one accepted.

## BendHub is permanent

A BendHub publish is public and cannot be withdrawn or replaced, under
[BendHub's terms](https://bend-lang.com/bendai/terms#s18). A name such as
`bendo@0.1.0.0` points at one content hash for good, and that hash covers
every file including `LICENSE`. A mistake in a published version is fixed by
publishing the next patch version, never by editing the old one. For that
reason the release script publishes to npm first and to BendHub last: an npm
version can be deprecated, or unpublished within 72 hours.

## Changesets

A pull request that changes what a user of the npm packages or the Bend
library can notice adds a changeset: run `bun changeset`, pick the bump from
the table above, and write a sentence or two for the changelog. Changes to
`src/` count, because `create-bendo` ships the library. Docs, tests, proofs
and CI need none. `bun run version-packages` applies the pending changesets,
writes each package's `CHANGELOG.md` and updates `bun.lock`.
