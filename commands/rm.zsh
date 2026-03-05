#!/usr/bin/env zsh
# commands/rm.zsh — Remove worktree + workspace(s)

_agent_rm() {
  if [[ -z "$1" ]]; then
    echo "Usage: ${_C_BOLD}agent rm${_C_RESET} <branch|hash>"
    echo ""
    echo "Removes the worktree, workspace(s), and optionally the branch."
    echo "Use the hash ID from ${_C_CYAN}agent list${_C_RESET} for easy reference."
    return 1
  fi

  local query="$1"
  local repo_dir
  repo_dir=$(_agent_repo_dir) || return 1

  local main_repo_dir
  main_repo_dir=$(_agent_main_repo_dir "$repo_dir") || return 1
  local wt_dir="${main_repo_dir}.worktrees"

  # Resolve query (could be a hash, branch name, or fuzzy match)
  local name
  name=$(_agent_resolve_branch "$query" "$repo_dir")
  local worktree_path="$wt_dir/$name"

  # Find matching workspace files (by branch name AND by hash)
  local -a ws_matches
  local -A ws_seen
  # By branch name (new format: name_TIMESTAMP)
  for f in "$AGENT_WORKSPACES_DIR"/${name}_????????-??????.code-workspace(N); do
    if [[ -z "${ws_seen[$f]}" ]]; then
      ws_matches+=("$f")
      ws_seen[$f]=1
    fi
  done
  # By branch name (old format: TIMESTAMP_name)
  for f in "$AGENT_WORKSPACES_DIR"/????????-??????_${name}.code-workspace(N); do
    if [[ -z "${ws_seen[$f]}" ]]; then
      ws_matches+=("$f")
      ws_seen[$f]=1
    fi
  done
  # By hash (in case the query was a hash for a manual workspace)
  for f in "$AGENT_WORKSPACES_DIR"/*.code-workspace(N); do
    local h=$(_agent_hash "${f:t:r}")
    if [[ "$h" == "$query" && -z "${ws_seen[$f]}" ]]; then
      ws_matches+=("$f")
      ws_seen[$f]=1
    fi
  done

  local has_worktree=false
  [[ -d "$worktree_path" ]] && has_worktree=true

  if ! $has_worktree && [[ ${#ws_matches[@]} -eq 0 ]]; then
    echo "${_C_YELLOW}✗ Nothing found for '$query'${_C_RESET}"
    return 1
  fi

  echo "This will remove:"
  $has_worktree && echo "  ${_C_CYAN}worktree${_C_RESET}    $worktree_path"
  for ws in "${ws_matches[@]}"; do
    local h=$(_agent_hash "${ws:t:r}")
    echo "  ${_C_CYAN}workspace${_C_RESET}   ${_C_MAGENTA}$h${_C_RESET} ${ws:t}"
  done

  echo -n "Confirm? [y/N] "
  read confirm
  [[ "$confirm" != [yY] ]] && echo "Aborted." && return 0

  # Remove worktree
  if $has_worktree; then
    git -C "$repo_dir" worktree remove "$worktree_path" --force 2>/dev/null
    if [[ $? -eq 0 ]]; then
      echo "${_C_GREEN}✓ Worktree removed${_C_RESET}"
    else
      echo "${_C_YELLOW}⚠  git worktree remove failed, cleaning up manually...${_C_RESET}"
      rm -rf "$worktree_path"
      git -C "$repo_dir" worktree prune
      echo "${_C_GREEN}✓ Removed and pruned${_C_RESET}"
    fi
  fi

  # Remove workspace files
  for ws in "${ws_matches[@]}"; do
    rm "$ws"
    echo "${_C_GREEN}✓ Workspace removed:${_C_RESET} ${ws:t}"
  done

  # Optionally delete branch
  echo -n "Also delete the branch '$name'? [y/N] "
  read del_branch
  if [[ "$del_branch" == [yY] ]]; then
    git -C "$repo_dir" branch -D "$name" 2>/dev/null \
      && echo "${_C_GREEN}✓ Branch deleted${_C_RESET}" \
      || echo "${_C_YELLOW}⚠  Branch not found${_C_RESET}"
  fi
}
