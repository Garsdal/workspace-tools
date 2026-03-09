#!/usr/bin/env zsh
# completions/_agent.zsh — Zsh completion for agent command

_agent_completion() {
  local -a subcmds
  subcmds=(
    'new:Create worktree + workspace, open VS Code'
    'open:Re-open an existing workspace'
    'main:Open the main worktree in VS Code'
    'rm:Remove a worktree'
    'list:List sessions (--all to show all)'
    'term:Set terminal tab name'
    'help:Show help'
  )

  if (( CURRENT == 2 )); then
    _describe 'agent commands' subcmds
  elif (( CURRENT == 3 )); then
    case "${words[2]}" in
      open|o)
        local -a ws_names
        for f in "$AGENT_WORKSPACES_DIR"/*.code-workspace(N); do
          local base="${f:t:r}"
          local h=$(_agent_hash "$base")
          ws_names+=("${h}:${base}")
          ws_names+=("${base}")
        done
        _describe 'workspaces' ws_names
        ;;
      rm)
        local -a rm_names
        # Add hash IDs from workspaces
        for f in "$AGENT_WORKSPACES_DIR"/*.code-workspace(N); do
          local base="${f:t:r}"
          local h=$(_agent_hash "$base")
          local branch=$(_agent_ws_branch "$base")
          if _agent_ws_has_ts "$base"; then
            rm_names+=("${h}:${branch}")
          else
            rm_names+=("${h}:${base}")
          fi
        done
        # Add worktree directory names
        local repo_dir
        repo_dir=$(git rev-parse --show-toplevel 2>/dev/null)
        if [[ -n "$repo_dir" ]]; then
          local wt_dir="${repo_dir}.worktrees"
          if [[ -d "$wt_dir" ]]; then
            for d in "$wt_dir"/*(N/); do
              rm_names+=("${d:t}")
            done
          fi
        fi
        _describe 'worktrees/hashes' rm_names
        ;;
    esac
  fi
}

compdef _agent_completion agent
