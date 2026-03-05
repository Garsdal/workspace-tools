# workspace-tools

Agent-oriented VS Code workspace management for **git worktree** workflows.

Opens a clean VS Code window per task (branch), keeps worktrees tidy, and makes it easy to spin up, switch between, and tear down agent sessions.

## Install

```bash
git clone https://github.com/Garsdal/workspace-tools.git ~/.workspace-tools
echo 'source ~/.workspace-tools/workspace-tools.zsh' >> ~/.zshrc
source ~/.zshrc
```

To update later, just `git pull` inside `~/.workspace-tools`.

## Commands

```
Usage: agent <command> [args...]

Commands:
  new  <branch|.> [options]      Create worktree + workspace, open VS Code
  open [-n] [name]               Re-open an existing workspace
  rm   <branch>                  Remove worktree + workspace(s)
  list                           List all sessions
  term <name>                    Set terminal tab name (--reset to clear)
  help                           Show this help

Options for new:
  --base <ref>   Branch from a specific ref (default: current branch)
  --track        Check out an existing remote branch

Aliases: o → open, ls → list, t → term
```

## Examples

```bash
agent new feat-feature-store
agent new .                       # branch from current, prompt for name
agent new fix-api --base main
agent new feat-remote --track     # check out remote branch
agent open                        # interactive picker
agent rm feat-feature-store
agent rm a1b2                     # remove by hash from agent list
agent list
agent term my-session
```

## How it works

| Thing | Where |
|---|---|
| Worktrees | `<repo>.worktrees/<branch>/` |
| Workspace files | `~/Workspaces/<branch>_YYYYMMDD-HHMMSS.code-workspace` |
| Session IDs | 4-char hash derived from the workspace filename |

## Requirements

- macOS (uses `md5 -q`)
- [VS Code](https://code.visualstudio.com) with the `code` CLI on `$PATH`
- git ≥ 2.5 (worktree support)
- zsh
