# workspace-tools

Agent-oriented VS Code workspace management for **git worktree** workflows.

Opens a clean VS Code window per task (branch), keeps worktrees tidy, and makes it easy to spin up, switch between, and tear down agent sessions.

---

## Install

```bash
git clone https://github.com/Garsdal/workspace-tools.git ~/Projects/workspace-tools
chmod +x ~/Projects/workspace-tools/install.sh
~/Projects/workspace-tools/install.sh
source ~/.zshrc
```

The installer creates a **symlink** from `~/.zsh/workspace-tools.zsh` → this repo, so `git pull` always picks up updates automatically.

---

## Commands

```ansi
Usage: [1magent[0m <command> [args...]

[1mCommands:[0m
  [36mnew[0m  <branch|.> [options]      Create worktree + workspace, open VS Code
  [36mopen[0m [-n] [name]               Re-open an existing workspace
  [36mrm[0m   <branch>                  Remove worktree + workspace(s)
  [36mlist[0m                           List all sessions
  [36mterm[0m <name>                    Set terminal tab name (--reset to clear)
  [36mhelp[0m                           Show this help

[1mOptions for new:[0m
  [36m--base[0m <ref>   Branch from a specific ref (default: current branch)
  [36m--track[0m        Check out an existing remote branch

Aliases: [2mo → open, ls → list, t → term[0m

[1mExamples:[0m
  [36magent new feat-feature-store[0m
  [36magent new .[0m                     [2m# branch from current, prompt for name[0m
  [36magent new fix-api --base main[0m
  [36magent new feat-remote --track[0m   [2m# check out remote branch[0m
  [36magent open[0m                      [2m# interactive picker[0m
  [36magent rm feat-feature-store[0m
  [36magent rm a1b2[0m                   [2m# remove by hash from agent list[0m
  [36magent list[0m
  [36magent term my-session[0m
```

---

## Workflow

Start a new task from the current branch — use `.` to be prompted for a name:

```ansi
[2m$ agent new .[0m
Branch name [[36magent/0305[0m]: [36mfeat-new-parser[0m

[32m✓ Worktree[0m   [2m/Users/you/Projects/myrepo.worktrees/feat-new-parser[0m
[32m✓ Workspace[0m  [2mfeat-new-parser_20260305-163000.code-workspace[0m
[32m✓ Folder[0m     [2m/Users/you/Projects/myrepo.worktrees/feat-new-parser[0m
```

Track an existing remote branch (copies `.vscode` from the main repo):

```ansi
[2m$ agent new some-feature --track[0m
[2mFetching origin/some-feature...[0m

[32m✓ Worktree[0m   [2m/Users/you/Projects/myrepo.worktrees/some-feature[0m
[32m✓ .vscode[0m    [2mcopied from main repo[0m
[32m✓ Workspace[0m  [2msome-feature_20260305-163015.code-workspace[0m
[32m✓ Folder[0m     [2m/Users/you/Projects/myrepo.worktrees/some-feature[0m
```

List all sessions across the repo:

```ansi
[2m$ agent list[0m
[1m── Sessions (myrepo) ──[0m

  [32m●[0m [35ma1b2[0m [1m[36mfeat-new-parser[0m    [33m2026-03-05 16:30[0m
  [32m●[0m [35mc3d4[0m [1m[36msome-feature[0m      [33m2026-03-05 16:30[0m
  [2m○[0m [35me5f6[0m [1m[36mold-experiment[0m    [33m2026-02-18 09:30[0m  [2m(2 sessions)[0m

[2m● active  ○ removed  Use hash with: agent rm <hash>[0m
```

Clean up by branch name or 4-char hash:

```ansi
[2m$ agent rm e5f6[0m
This will remove:
  [36mworktree[0m    /Users/you/Projects/myrepo.worktrees/old-experiment
  [36mworkspace[0m   [35me5f6[0m old-experiment_20260218-093045.code-workspace

Confirm? [y/N] y
[32m✓ Worktree removed[0m
[32m✓ Workspace removed:[0m old-experiment_20260218-093045.code-workspace
Also delete the branch 'old-experiment'? [y/N]
```

---

## How it works

| Thing | Where |
|---|---|
| Worktrees | `<repo-dir>.worktrees/<branch>/` |
| Workspace files | `~/Workspaces/<branch>_YYYYMMDD-HHMMSS.code-workspace` |
| Session IDs | 4-char hash derived from the workspace filename |

The workspace `"name"` shown in VS Code is set to the branch name for `agent new`, and the repo name for `agent new --track`.  
The `window.title` setting shows the branch name so tabs stay identifiable without a file open.

---

## Requirements

- macOS (uses `md5 -q`)
- [VS Code](https://code.visualstudio.com) with the `code` CLI on `$PATH`
- git ≥ 2.5 (worktree support)
- zsh
