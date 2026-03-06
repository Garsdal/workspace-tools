# AGENTS.md

## Versioning

**Do NOT manually edit `_WT_VERSION` in `lib/config.zsh`.** It is stamped automatically by CI.

### Release flow

1. Merge your PR to `main`.
2. Tag the release on main: `git fetch origin main && git tag v0.0.7 origin/main && git push origin v0.0.7`
3. CI (`.github/workflows/release.yml`) triggers on **tag push** (not on PR merge) and will:
   - Write the version from the tag into `lib/config.zsh`
   - Commit the change back to `main`
   - Create a GitHub Release with auto-generated notes

### Version format

Semver: `MAJOR.MINOR.PATCH` (e.g. `0.0.7`). Tags are prefixed with `v` (e.g. `v0.0.7`).

### Where the version is used

- `lib/config.zsh` → `_WT_VERSION` — read at runtime by the shell plugin
- `commands/help.zsh` — displayed in `agent help` output

### Changelog

Update `CHANGELOG.md` with a new `## vX.Y.Z` section in your PR. CI does not auto-generate the changelog file.
