#!/usr/bin/env zsh
# commands/main.zsh — Open the main worktree in VS Code

_agent_main() {
  local repo_dir
  repo_dir=$(_agent_repo_dir) || return 1

  local main_repo_dir
  main_repo_dir=$(_agent_main_repo_dir "$repo_dir") || return 1

  local branch
  branch="$(git -C "$main_repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"

  echo "${_C_GREEN}✓ Main worktree:${_C_RESET} ${_C_DIM}$main_repo_dir${_C_RESET} ${_C_DIM}($branch)${_C_RESET}"
  code "$main_repo_dir"
}
