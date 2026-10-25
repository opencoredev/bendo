# Changesets

A change that a user of `bendo`, `create-bendo`, `vite-plugin-bendo` or the
Bend library in `src/` can notice needs a changeset. Run `bun changeset`, pick
the bump and write one or two sentences for the changelog. The three packages
share one version (`fixed` in `config.json`), so a bump to any of them bumps
all three.

[docs/versioning.md](../docs/versioning.md) says which bump to pick, and
[docs/releasing.md](../docs/releasing.md) covers the release.
