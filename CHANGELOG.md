# Changelog

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
