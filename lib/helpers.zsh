#!/usr/bin/env zsh
# lib/helpers.zsh — Shared helper functions

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Flatten branch names for filesystem use (e.g. mlg/XX → mlg-XX)
_agent_flat_name() {
  echo "${1//\//-}"
}

_agent_repo_dir() {
  local dir
  dir=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$dir" ]]; then
    echo "${_C_YELLOW}✗ Not inside a git repository${_C_RESET}" >&2
    return 1
  fi
  echo "$dir"
}

# Resolve the main (non-worktree) repository directory.
# Works correctly whether called from the main repo or any worktree.
_agent_main_repo_dir() {
  local repo_dir="$1"
  local main_dir
  # Primary: git worktree list always shows the main worktree first
  main_dir="$(git -C "$repo_dir" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')"
  if [[ -z "$main_dir" || ! -d "$main_dir" ]]; then
    # Fallback: derive from git-common-dir
    main_dir="$(git -C "$repo_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
    main_dir="${main_dir%/.git}"
  fi
  if [[ -z "$main_dir" || ! -d "$main_dir" ]]; then
    echo "${_C_YELLOW}✗ Could not resolve main repository directory${_C_RESET}" >&2
    return 1
  fi
  echo "$main_dir"
}

# Generate a stable 4-char hash ID from a string
_agent_hash() {
  echo -n "$1" | md5 -q 2>/dev/null | head -c 4
}

# Extract branch name from workspace basename (supports both formats)
# New: name_YYYYMMDD-HHMMSS  Old: YYYYMMDD-HHMMSS_name
_agent_ws_branch() {
  local base="$1"
  # New format: name_YYYYMMDD-HHMMSS (timestamp is last 15 chars)
  local ts="${base: -15}"
  if [[ "$ts" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
    echo "${base:0:-16}"
    return
  fi
  # Old format: YYYYMMDD-HHMMSS_name
  local ts_old="${base%%_*}"
  if [[ "$ts_old" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
    echo "${base#*_}"
    return
  fi
  echo "$base"
}

# Extract timestamp from workspace basename
_agent_ws_ts() {
  local base="$1"
  local ts="${base: -15}"
  if [[ "$ts" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
    echo "$ts"
    return
  fi
  local ts_old="${base%%_*}"
  if [[ "$ts_old" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
    echo "$ts_old"
    return
  fi
}

# Check if workspace basename has a valid timestamp
_agent_ws_has_ts() {
  local base="$1"
  local ts="${base: -15}"
  [[ "$ts" =~ ^[0-9]{8}-[0-9]{6}$ ]] && return 0
  local ts_old="${base%%_*}"
  [[ "$ts_old" =~ ^[0-9]{8}-[0-9]{6}$ ]] && return 0
  return 1
}

# Resolve a name-or-hash to a workspace file path.
# Checks: exact filename match, hash match, then fuzzy glob.
_agent_resolve_workspace() {
  local query="$1"
  mkdir -p "$AGENT_WORKSPACES_DIR"

  # 1. Exact match
  local exact="$AGENT_WORKSPACES_DIR/$query.code-workspace"
  [[ -f "$exact" ]] && echo "$exact" && return 0

  # 2. Hash match (check all workspaces)
  for f in "$AGENT_WORKSPACES_DIR"/*.code-workspace(N); do
    local h=$(_agent_hash "${f:t:r}")
    if [[ "$h" == "$query" ]]; then
      echo "$f" && return 0
    fi
  done

  # 3. Fuzzy glob
  local matches=("$AGENT_WORKSPACES_DIR"/*${query}*.code-workspace(N))
  if [[ ${#matches[@]} -eq 1 ]]; then
    echo "${matches[1]}" && return 0
  elif [[ ${#matches[@]} -gt 1 ]]; then
    echo "${_C_YELLOW}Multiple matches for '$query':${_C_RESET}" >&2
    for m in "${matches[@]}"; do echo "  ${m:t:r}" >&2; done
    return 1
  fi

  echo "${_C_YELLOW}✗ No workspace matching '$query'${_C_RESET}" >&2
  return 1
}

# Resolve a name-or-hash to a branch name for rm (checks worktrees + workspaces)
_agent_resolve_branch() {
  local query="$1"
  local repo_dir="$2"
  local wt_dir="${repo_dir}.worktrees"

  # 1. Direct worktree match
  [[ -d "$wt_dir/$query" ]] && echo "$query" && return 0

  # 2. Hash match against workspace files → extract branch name
  for f in "$AGENT_WORKSPACES_DIR"/*.code-workspace(N); do
    local base="${f:t:r}"
    local h=$(_agent_hash "$base")
    if [[ "$h" == "$query" ]]; then
      if _agent_ws_has_ts "$base"; then
        echo "$(_agent_ws_branch "$base")" && return 0
      else
        echo "$base" && return 0
      fi
    fi
  done

  # 3. Fuzzy match against workspace branch names
  local -a branch_matches
  for f in "$AGENT_WORKSPACES_DIR"/*.code-workspace(N); do
    local base="${f:t:r}"
    local branch_part=$(_agent_ws_branch "$base")
    if [[ "$branch_part" == *${query}* ]]; then
      if (( ! ${branch_matches[(Ie)$branch_part]} )); then
        branch_matches+=("$branch_part")
      fi
    fi
  done
  if [[ ${#branch_matches[@]} -eq 1 ]]; then
    echo "${branch_matches[1]}" && return 0
  fi

  echo "$query" && return 0
}
