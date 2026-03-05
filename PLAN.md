# Improvement Plan for workspace-tools

## Current State

[workspace-tools.zsh](workspace-tools.zsh) is a single 690-line monolithic file containing:

| Section | Lines | Description |
|---------|-------|-------------|
| Configuration | 6 | `AGENT_WORKSPACES_DIR` |
| Colors | 9–15 | ANSI escape codes |
| Helpers | 18–155 | `_agent_repo_dir`, `_agent_hash`, `_agent_ws_branch`, `_agent_ws_ts`, `_agent_ws_has_ts`, `_agent_resolve_workspace`, `_agent_resolve_branch` |
| Terminal title | 157–163 | `precmd` hook for persistent titles |
| Main dispatcher | 166–177 | `agent()` case statement |
| Subcommand: new | 182–330 | ~150 lines |
| Subcommand: open | 332–397 | ~65 lines |
| Subcommand: rm | 399–479 | ~80 lines |
| Subcommand: list | 481–590 | ~110 lines |
| Subcommand: term | 592–605 | ~15 lines |
| Subcommand: help | 607–639 | ~30 lines |
| Completion | 643–690 | Zsh `compdef` |

---

## Problem 1: Monolithic file is hard to maintain

Everything lives in one file. As commands grow or new commands are added, this will become increasingly difficult to navigate, review, and test.

### Proposed Structure

Split into a directory layout where each concern is a separate file:

```
workspace-tools.zsh          ← slim loader (sources everything below)
lib/
  config.zsh                 ← AGENT_WORKSPACES_DIR + any future config
  colors.zsh                 ← ANSI color variables
  helpers.zsh                ← _agent_repo_dir, _agent_hash, _agent_ws_*, _agent_resolve_*
  terminal.zsh               ← _AGENT_TERM_TITLE + precmd hook
commands/
  new.zsh                    ← _agent_new
  open.zsh                   ← _agent_open
  rm.zsh                     ← _agent_rm
  list.zsh                   ← _agent_list
  term.zsh                   ← _agent_term
  help.zsh                   ← _agent_help
completions/
  _agent.zsh                 ← _agent_completion + compdef
install.sh                   ← unchanged (already standalone)
README.md
```

**Loader (`workspace-tools.zsh`)** would become ~20 lines:

```zsh
#!/usr/bin/env zsh
# workspace-tools.zsh — entry point
_WT_DIR="${0:A:h}"

source "$_WT_DIR/lib/config.zsh"
source "$_WT_DIR/lib/colors.zsh"
source "$_WT_DIR/lib/helpers.zsh"
source "$_WT_DIR/lib/terminal.zsh"

for cmd in "$_WT_DIR/commands/"*.zsh; do
  source "$cmd"
done

source "$_WT_DIR/completions/_agent.zsh"

agent() {
  local subcmd="${1:-help}"; shift 2>/dev/null
  case "$subcmd" in
    new)     _agent_new "$@" ;;
    open|o)  _agent_open "$@" ;;
    rm)      _agent_rm "$@" ;;
    list|ls) _agent_list "$@" ;;
    term|t)  _agent_term "$@" ;;
    help|*)  _agent_help ;;
  esac
}
```

### Benefits

- **Focused diffs** — PRs touch only the file for the command being changed.
- **Easier navigation** — jump to `commands/new.zsh` instead of scrolling to line 182.
- **Extensibility** — new commands are added as new files, zero merge conflicts.
- **Testability** — individual files can be sourced in isolation for testing.

---

## Problem 2: `agent new X` names the workspace folder after the branch, not the repo

### Current Behavior

In `_agent_new` ([workspace-tools.zsh lines 304–309](workspace-tools.zsh#L304-L309)):

```zsh
local folder_display_name="$branch"
if $track_remote; then
  folder_display_name="$(basename "$main_repo_dir")"
fi
```

The `"name"` field in the `.code-workspace` JSON is set to the **branch name** (e.g. `feat-feature-store`), so VS Code's sidebar shows the branch name as the folder label. Only when `--track` is used does it show the repo name.

### Desired Behavior

The folder in VS Code should **always** be named after the repository (e.g. `my-project`), regardless of whether `--track` is used. This matches the mental model: you're always working in the same repo — the branch is secondary context and already visible in the VS Code title bar and git status.

### Fix

Change the `folder_display_name` assignment so it always uses the repo name:

```zsh
# Before (current):
local folder_display_name="$branch"
if $track_remote; then
  folder_display_name="$(basename "$main_repo_dir")"
fi

# After (proposed):
local folder_display_name="$(basename "$main_repo_dir")"
```

This is a 3-line deletion, 1-line replacement. The `main_repo_dir` variable is already computed earlier in the function (line 218) and is always available.

---

## Implementation Order

1. **Fix the `agent new` folder name bug** — small, safe, independent change.
2. **Create `lib/` and `commands/` and `completions/` directories** and split the code.
3. **Rewrite `workspace-tools.zsh`** as a slim loader.
4. **Update `install.sh`** if needed (currently it just sources the top-level file, so no change required — the loader handles the rest).
5. **Smoke test** — run `agent new`, `agent list`, `agent open`, `agent rm`, `agent term`, `agent help` to verify nothing broke.
