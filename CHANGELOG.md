# Changelog

## v0.0.9

### Fix `.env` / `.vscode` copy prompt never triggering in `agent new`

Due to a zsh word-splitting quirk, `AGENT_COPY_PATHS` was being stored as a single-element array containing the string `.vscode .env .env.local` rather than three separate entries. The `-e` file-existence check therefore always failed (no file is literally named `.vscode .env .env.local`), so the copy prompt was silently skipped every time.

**Fix:** Use the `=` flag to force word-splitting on the default value.

**Files changed:**
- `lib/config.zsh` — `${AGENT_COPY_PATHS:-.vscode .env .env.local}` → `${=AGENT_COPY_PATHS:-.vscode .env .env.local}`

## v0.0.8

### Interactive copy of `.env` and `.vscode` in `agent new`
When creating a new worktree, `agent new` now checks the **current directory** for `.env`, `.env.local`, and `.vscode`. If any are found, the user is prompted before copying them to the new worktree. This replaces the previous automatic copy from the main repo directory, which was unreliable since these files are typically in `.gitignore` and not present in the bare repo.

**Files changed:**
- `commands/new.zsh` — Replaced automatic copy loop with interactive prompt; source is now `$PWD` instead of main repo dir
- `CHANGELOG.md` — Added v0.0.8 section

## v0.0.7

### Faster session list with `--all` flag
`agent list` is now significantly faster — workspace metadata (timestamps, hashes, counts) is cached in a single pass instead of re-scanning all files per branch (O(n) vs O(n×m)). A new `--all` / `-a` flag shows every session instead of only the last 5.

**Files changed:**
- `commands/list.zsh` — Single-pass workspace scan with associative-array caches; added `--all` / `-a` flag; updated truncation hint to show the flag
- `commands/help.zsh` — Documented `--all` flag in help output and examples
- `completions/_agent.zsh` — Updated list description

### Show copied files in `agent new` summary
Copied dev files (`.vscode`, `.env`, etc.) now appear as a dedicated `✓ Copied` line in the summary block instead of printing during the copy loop.

**Files changed:**
- `commands/new.zsh` — Collect copied items into an array; display as `✓ Copied .vscode, .env, …` after Worktree/Workspace/Folder lines

## v0.0.6

### Sort session list by newest session timestamp
`agent list` now orders sessions by the timestamp embedded in the workspace filename (`YYYYMMDD-HHMMSS`), so the most recently created session always appears first. Worktrees without a workspace file are sorted by directory modification time, and always appear below timestamped sessions.

### CI-based release workflow
Version stamping is now handled automatically by CI on tag push. See `AGENTS.md` for details.

**Files changed:**
- `commands/list.zsh` — Worktrees glob uses `Om` (newest mtime first); added re-sort of `ordered_branches` by best filename-embedded timestamp (descending) after the array is fully built
- `.github/workflows/release.yml` — New release workflow that stamps `_WT_VERSION` on tag push
- `AGENTS.md` — Versioning guide for contributors and AI agents

## v0.0.5

### Fix flat-naming with `/` in branch names
Branch names containing `/` (e.g. `mlg/XX`) are now flattened to `mlg-XX` for filesystem paths (worktree directories and workspace filenames), preventing nested subdirectory creation. Git branch names are preserved as-is for all git operations.

**Files changed:**
- `lib/helpers.zsh` — Added `_agent_flat_name()` helper that replaces `/` with `-`
- `commands/new.zsh` — Uses `flat_branch` for the worktree path and workspace filename; git operations still use the original branch name with `/`
- `commands/rm.zsh` — Resolves the actual git branch name (with `/`) from the worktree HEAD *before* removal, so `git branch -D` works correctly on branches like `mlg/XX`

### Session list limited to last 5 (configurable)
`agent list` now shows at most `AGENT_MAX_SESSIONS` (default: 5) most recent sessions. When truncated, a "… and N more" message is shown with instructions to customize.

**Files changed:**
- `lib/config.zsh` — Added `AGENT_MAX_SESSIONS=${AGENT_MAX_SESSIONS:-5}` (respects env override)
- `commands/list.zsh` — Truncates `ordered_branches` to `max_sessions` and shows overflow notice

### Fixed column widths in list output
Hashes, branch names, and timestamps are now aligned in fixed-width columns using `printf`, so the output is consistently readable regardless of name lengths.

**Files changed:**
- `commands/list.zsh` — Computes `max_name_len` across all entries, uses `printf '%-Ns'` for hash (4-char), name (dynamic), and timestamp (16-char) columns

### Auto-open Copilot Chat on new workspace
When creating a new workspace with `agent new`, the Copilot Chat panel is automatically opened via the `vscode://` URI scheme after a short delay.

**Files changed:**
- `commands/new.zsh` — Added `(sleep 3 && open "vscode://command/workbench.action.chat.open" 2>/dev/null) &!` after `code -n`

### Version bump
- `lib/config.zsh` — `_WT_VERSION` updated from `0.0.4` to `0.0.5`

### PR
- https://github.com/Garsdal/workspace-tools/pull/5
