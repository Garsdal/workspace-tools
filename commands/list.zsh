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

  # Worktrees that don't have a workspace yet (sorted newest-first by mtime)
  if [[ -d "$wt_dir" ]]; then
    for d in "$wt_dir"/*(N/Om); do
      local name="${d:t}"
      if [[ -z "${seen_branches[$name]}" ]]; then
        seen_branches[$name]=1
        ordered_branches+=("$name")
      fi
    done
  fi

  # Re-sort ordered_branches by newest filename-embedded timestamp (newest first).
  # Branches with no workspace timestamp (worktree-only) sort to the bottom.
  if [[ ${#ordered_branches[@]} -gt 1 ]]; then
    local -a _ts_pairs=()
    for _b in "${ordered_branches[@]}"; do
      local _best="00000000-000000"
      for _ws in "${workspaces[@]}"; do
        local _base="${_ws:t:r}"
        local _wbranch=$(_agent_ws_branch "$_base")
        local _wts=$(_agent_ws_ts "$_base")
        if [[ "$_wbranch" == "$_b" && -n "$_wts" && "$_wts" > "$_best" ]]; then
          _best="$_wts"
        fi
      done
      _ts_pairs+=("${_best} ${_b}")
    done
    ordered_branches=()
    while IFS= read -r _line; do
      ordered_branches+=("${_line#* }")
    done < <(printf '%s\n' "${_ts_pairs[@]}" | sort -r)
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

  # Limit to most recent sessions
  local max_sessions="${AGENT_MAX_SESSIONS:-5}"
  local total_branches=${#ordered_branches[@]}
  local truncated=false
  if [[ $total_branches -gt $max_sessions ]]; then
    ordered_branches=("${ordered_branches[@]:0:$max_sessions}")
    truncated=true
  fi

  # ── Fixed-width column layout ──
  # Measure the longest branch name for alignment
  local max_name_len=0
  for branch in "${ordered_branches[@]}"; do
    (( ${#branch} > max_name_len )) && max_name_len=${#branch}
  done
  for ws in "${manual_workspaces[@]}"; do
    local base="${ws:t:r}"
    (( ${#base} > max_name_len )) && max_name_len=${#base}
  done
  # Minimum width
  (( max_name_len < 20 )) && max_name_len=20

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
    local display_ts="                "
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

    # Build the line with fixed-width columns
    local hash_col=$(printf '%-4s' "${newest_hash:-    }")
    local name_col=$(printf "%-${max_name_len}s" "$branch")
    local extra=""
    [[ $ws_count -gt 1 ]] && extra="  ${_C_DIM}(${ws_count} sessions)${_C_RESET}"
    echo "  $indicator ${_C_MAGENTA}${hash_col}${_C_RESET} ${_C_CYAN}${_C_BOLD}${name_col}${_C_RESET}  ${_C_YELLOW}${display_ts}${_C_RESET}${extra}"
  done

  # Manual workspaces (not created by agent)
  for ws in "${manual_workspaces[@]}"; do
    local h=$(_agent_hash "${ws:t:r}")
    local base="${ws:t:r}"
    local hash_col=$(printf '%-4s' "$h")
    local name_col=$(printf "%-${max_name_len}s" "$base")
    echo "  ${_C_DIM}◆${_C_RESET} ${_C_MAGENTA}${hash_col}${_C_RESET} ${_C_CYAN}${name_col}${_C_RESET}  ${_C_DIM}(manual)${_C_RESET}"
  done

  if $truncated; then
    echo ""
    echo "  ${_C_DIM}… and $((total_branches - max_sessions)) more (set AGENT_MAX_SESSIONS to show more)${_C_RESET}"
  fi

  echo ""
  echo "${_C_DIM}● active  ○ removed  Use hash with: agent rm <hash>${_C_RESET}"
}
