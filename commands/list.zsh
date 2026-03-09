#!/usr/bin/env zsh
# commands/list.zsh — List all sessions

_agent_list() {
  # ── Parse flags ──
  local show_all=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all|-a) show_all=true; shift ;;
      *) echo "${_C_YELLOW}✗ Unknown option: $1${_C_RESET}"; return 1 ;;
    esac
  done

  local repo_dir
  repo_dir=$(_agent_repo_dir) || return 1
  local wt_dir="${repo_dir}.worktrees"
  local repo_name=$(basename "$repo_dir")

  echo "${_C_BOLD}── Sessions ($repo_name) ──${_C_RESET}"
  echo ""

  # ── Single-pass workspace scan: build caches ──
  local -A branch_best_ts    # branch -> newest timestamp
  local -A branch_best_hash  # branch -> hash of newest workspace
  local -A branch_ws_count   # branch -> workspace count
  local -A seen_branches     # branch -> 1
  local -a ordered_branches
  local -a manual_workspaces

  local workspaces=("$AGENT_WORKSPACES_DIR"/*.code-workspace(NOm))
  for ws in "${workspaces[@]}"; do
    local base="${ws:t:r}"
    if ! _agent_ws_has_ts "$base"; then
      manual_workspaces+=("$ws")
      continue
    fi
    local bp=$(_agent_ws_branch "$base")
    local ts=$(_agent_ws_ts "$base")

    # Track this branch
    if [[ -z "${seen_branches[$bp]}" ]]; then
      seen_branches[$bp]=1
      ordered_branches+=("$bp")
      branch_best_ts[$bp]="$ts"
      branch_best_hash[$bp]=$(_agent_hash "$base")
      branch_ws_count[$bp]=1
    else
      branch_ws_count[$bp]=$(( ${branch_ws_count[$bp]} + 1 ))
      # Keep the newest timestamp
      if [[ "$ts" > "${branch_best_ts[$bp]}" ]]; then
        branch_best_ts[$bp]="$ts"
        branch_best_hash[$bp]=$(_agent_hash "$base")
      fi
    fi
  done

  # Worktrees that don't have a workspace yet (sorted newest-first by mtime)
  if [[ -d "$wt_dir" ]]; then
    for d in "$wt_dir"/*(N/Om); do
      local name="${d:t}"
      if [[ -z "${seen_branches[$name]}" ]]; then
        seen_branches[$name]=1
        ordered_branches+=("$name")
        branch_best_ts[$name]="00000000-000000"
      fi
    done
  fi

  # ── Sort by newest timestamp (descending) ──
  if [[ ${#ordered_branches[@]} -gt 1 ]]; then
    local -a _ts_pairs=()
    for _b in "${ordered_branches[@]}"; do
      _ts_pairs+=("${branch_best_ts[$_b]} ${_b}")
    done
    ordered_branches=()
    while IFS= read -r _line; do
      ordered_branches+=("${_line#* }")
    done < <(printf '%s\n' "${_ts_pairs[@]}" | sort -r)
  fi

  if [[ ${#ordered_branches[@]} -eq 0 && ${#manual_workspaces[@]} -eq 0 ]]; then
    echo "  ${_C_DIM}(none)${_C_RESET}"
    return
  fi

  # ── Apply session limit (unless --all) ──
  local max_sessions="${AGENT_MAX_SESSIONS:-5}"
  local total_branches=${#ordered_branches[@]}
  local truncated=false
  if ! $show_all && [[ $total_branches -gt $max_sessions ]]; then
    ordered_branches=("${ordered_branches[@]:0:$max_sessions}")
    truncated=true
  fi

  # ── Fixed-width column layout ──
  local max_name_len=0
  for branch in "${ordered_branches[@]}"; do
    (( ${#branch} > max_name_len )) && max_name_len=${#branch}
  done
  for ws in "${manual_workspaces[@]}"; do
    local base="${ws:t:r}"
    (( ${#base} > max_name_len )) && max_name_len=${#base}
  done
  (( max_name_len < 20 )) && max_name_len=20

  # ── Print each branch using cached data ──
  for branch in "${ordered_branches[@]}"; do
    local has_wt=false
    [[ -d "$wt_dir/$branch" ]] && has_wt=true

    local newest_ts="${branch_best_ts[$branch]}"
    local newest_hash="${branch_best_hash[$branch]}"
    local ws_count="${branch_ws_count[$branch]:-0}"

    # Format timestamp
    local display_ts="                "
    if [[ -n "$newest_ts" && "$newest_ts" != "00000000-000000" ]]; then
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
    echo "  ${_C_DIM}… and $((total_branches - max_sessions)) more (use ${_C_RESET}${_C_CYAN}agent list --all${_C_RESET}${_C_DIM} to show all)${_C_RESET}"
  fi

  echo ""
  echo "${_C_DIM}● active  ○ removed  Use hash with: agent rm <hash>${_C_RESET}"
}
