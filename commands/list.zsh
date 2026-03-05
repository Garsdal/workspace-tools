#!/usr/bin/env zsh
# commands/list.zsh — List all sessions

_agent_list() {
  local repo_dir
  repo_dir=$(_agent_repo_dir) || return 1
  local wt_dir="${repo_dir}.worktrees"
  local repo_name=$(basename "$repo_dir")

  echo "${_C_BOLD}── Sessions ($repo_name) ──${_C_RESET}"
  echo ""

  # Collect all known branch names from worktrees + workspaces
  local -A seen_branches  # branch -> 1
  local -a ordered_branches

  # Workspaces sorted newest-first by modification time
  local workspaces=("$AGENT_WORKSPACES_DIR"/*.code-workspace(NOm))
  for ws in "${workspaces[@]}"; do
    local base="${ws:t:r}"
    local branch_part=$(_agent_ws_branch "$base")
    # Only process timestamped workspace files
    if _agent_ws_has_ts "$base" && [[ -z "${seen_branches[$branch_part]}" ]]; then
      seen_branches[$branch_part]=1
      ordered_branches+=("$branch_part")
    fi
  done

  # Worktrees that don't have a workspace yet
  if [[ -d "$wt_dir" ]]; then
    for d in "$wt_dir"/*(N/); do
      local name="${d:t}"
      if [[ -z "${seen_branches[$name]}" ]]; then
        seen_branches[$name]=1
        ordered_branches+=("$name")
      fi
    done
  fi

  # Also show non-timestamped workspaces (manual ones)
  local -a manual_workspaces
  for ws in "${workspaces[@]}"; do
    local base="${ws:t:r}"
    if ! _agent_ws_has_ts "$base"; then
      manual_workspaces+=("$ws")
    fi
  done

  if [[ ${#ordered_branches[@]} -eq 0 && ${#manual_workspaces[@]} -eq 0 ]]; then
    echo "  ${_C_DIM}(none)${_C_RESET}"
    return
  fi

  # Print each branch with its status
  for branch in "${ordered_branches[@]}"; do
    local has_wt=false
    [[ -d "$wt_dir/$branch" ]] && has_wt=true

    # Find newest workspace timestamp + hash for this branch
    local newest_ts=""
    local newest_hash=""
    local ws_count=0
    for ws in "${workspaces[@]}"; do
      local base="${ws:t:r}"
      local ws_branch=$(_agent_ws_branch "$base")
      local ws_ts=$(_agent_ws_ts "$base")
      if [[ "$ws_branch" == "$branch" && -n "$ws_ts" ]]; then
        ((ws_count++))
        if [[ -z "$newest_ts" ]]; then
          newest_ts="$ws_ts"
          newest_hash=$(_agent_hash "$base")
        fi
      fi
    done

    # Format timestamp
    local display_ts=""
    if [[ -n "$newest_ts" ]]; then
      display_ts="${newest_ts:0:4}-${newest_ts:4:2}-${newest_ts:6:2} ${newest_ts:9:2}:${newest_ts:11:2}"
    fi

    # Status indicator
    local indicator=""
    if $has_wt; then
      indicator="${_C_GREEN}●${_C_RESET}"
    else
      indicator="${_C_DIM}○${_C_RESET}"
    fi

    # Build the line
    local line="  $indicator ${_C_MAGENTA}${newest_hash:-    }${_C_RESET} ${_C_CYAN}${_C_BOLD}$branch${_C_RESET}"
    [[ -n "$display_ts" ]] && line="$line  ${_C_YELLOW}$display_ts${_C_RESET}"
    [[ $ws_count -gt 1 ]] && line="$line  ${_C_DIM}(${ws_count} sessions)${_C_RESET}"
    echo "$line"
  done

  # Manual workspaces (not created by agent)
  for ws in "${manual_workspaces[@]}"; do
    local h=$(_agent_hash "${ws:t:r}")
    echo "  ${_C_DIM}◆${_C_RESET} ${_C_MAGENTA}$h${_C_RESET} ${_C_CYAN}${ws:t:r}${_C_RESET}  ${_C_DIM}(manual)${_C_RESET}"
  done

  echo ""
  echo "${_C_DIM}● active  ○ removed  Use hash with: agent rm <hash>${_C_RESET}"
}
