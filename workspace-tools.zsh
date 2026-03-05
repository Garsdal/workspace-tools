#!/usr/bin/env zsh
# workspace-tools.zsh — Manage VS Code workspaces, git worktrees, and agent sessions.
# Source this file from ~/.zshrc:  source ~/.zsh/workspace-tools.zsh

# ─── Configuration ────────────────────────────────────────────────────────────
AGENT_WORKSPACES_DIR="$HOME/Workspaces"

# ─── Colors ───────────────────────────────────────────────────────────────────
_C_GREEN=$'\e[32m'
_C_YELLOW=$'\e[33m'
_C_CYAN=$'\e[36m'
_C_MAGENTA=$'\e[35m'
_C_DIM=$'\e[2m'
_C_BOLD=$'\e[1m'
_C_RESET=$'\e[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
_agent_repo_dir() {
  local dir
  dir=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$dir" ]]; then
    echo "${_C_YELLOW}✗ Not inside a git repository${_C_RESET}" >&2
    return 1
  fi
  echo "$dir"
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

# ─── Terminal title persistence ───────────────────────────────────────────────
_AGENT_TERM_TITLE=""
_agent_precmd_title() {
  [[ -n "$_AGENT_TERM_TITLE" ]] && printf '\e]2;%s\a' "$_AGENT_TERM_TITLE"
}
if (( ! ${precmd_functions[(Ie)_agent_precmd_title]} )); then
  precmd_functions+=(_agent_precmd_title)
fi

# ─── Main command ─────────────────────────────────────────────────────────────
agent() {
  local subcmd="${1:-help}"
  shift 2>/dev/null

  case "$subcmd" in
    new)     _agent_new "$@" ;;
    open|o)  _agent_open "$@" ;;
    rm)      _agent_rm "$@" ;;
    list|ls) _agent_list "$@" ;;
    term|t)  _agent_term "$@" ;;
    help|*)  _agent_help ;;
  esac
}

# ─── Subcommands ──────────────────────────────────────────────────────────────

_agent_new() {
  if [[ -z "$1" ]]; then
    echo "Usage: ${_C_BOLD}agent new${_C_RESET} <branch|.> [--base <ref>] [--track]"
    echo ""
    echo "Creates a worktree + workspace and opens VS Code."
    echo "Use ${_C_CYAN}.${_C_RESET} to branch from the current branch (prompts for name)."
    echo "Use ${_C_CYAN}--track${_C_RESET} to check out an existing remote branch."
    echo ""
    echo "Examples:"
    echo "  ${_C_CYAN}agent new feat-feature-store${_C_RESET}"
    echo "  ${_C_CYAN}agent new .${_C_RESET}"
    echo "  ${_C_CYAN}agent new fix-loader --base main${_C_RESET}"
    echo "  ${_C_CYAN}agent new feat-remote --track${_C_RESET}"
    return 1
  fi

  local branch="$1"; shift
  local base_ref=""
  local track_remote=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base) base_ref="$2"; shift 2 ;;
      --track) track_remote=true; shift ;;
      *) echo "${_C_YELLOW}✗ Unknown option: $1${_C_RESET}"; return 1 ;;
    esac
  done

  local repo_dir
  repo_dir=$(_agent_repo_dir) || return 1

  # Resolve the main repository directory (works from worktrees too)
  local main_repo_dir
  main_repo_dir="$(git -C "$repo_dir" rev-parse --path-format=absolute --git-common-dir)"
  main_repo_dir="${main_repo_dir%/.git}"

  # ── Handle "." — prompt for branch name ──
  if [[ "$branch" == "." ]]; then
    if $track_remote; then
      echo "${_C_YELLOW}✗ Cannot use . with --track${_C_RESET}"
      return 1
    fi
    local default_name="agent/$(date +%m%d)"
    echo -n "Branch name [${_C_CYAN}$default_name${_C_RESET}]: "
    read user_name
    branch="${user_name:-$default_name}"
  fi

  # Strip remote prefix for --track (e.g., origin/feat-x → feat-x)
  if $track_remote; then
    branch="${branch#origin/}"
  fi

  local wt_dir="${repo_dir}.worktrees"
  local worktree_path="$wt_dir/$branch"

  if [[ -d "$worktree_path" ]]; then
    echo "${_C_YELLOW}⚠  Worktree already exists: $worktree_path${_C_RESET}"
    return 1
  fi

  # ── Create worktree ──
  mkdir -p "$wt_dir"
  local ok=false

  if $track_remote; then
    # ── Track an existing remote branch ──
    echo "${_C_DIM}Fetching origin/$branch...${_C_RESET}"
    if ! git -C "$repo_dir" fetch origin "$branch" 2>/dev/null; then
      echo "${_C_YELLOW}✗ Failed to fetch remote branch '$branch'${_C_RESET}"
      return 1
    fi
    git -C "$repo_dir" worktree add --track -b "$branch" "$worktree_path" "origin/$branch" 2>/dev/null && ok=true
    if ! $ok; then
      # Local branch may already exist; just check it out
      git -C "$repo_dir" worktree add "$worktree_path" "$branch" 2>/dev/null && ok=true
    fi
  else
    # ── Create a new branch ──
    if [[ -z "$base_ref" ]]; then
      local current_branch
      current_branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)

      if [[ "$current_branch" != "main" && "$current_branch" != "master" ]]; then
        echo "${_C_YELLOW}⚠  Current branch: ${_C_BOLD}$current_branch${_C_RESET}${_C_YELLOW} (not main/master)${_C_RESET}"
        echo -n "Branch from ${_C_CYAN}$current_branch${_C_RESET}? [Y/n] "
        read branch_confirm
        [[ "$branch_confirm" == [nN] ]] && echo "Aborted." && return 0
      fi

      base_ref="$current_branch"
    fi

    if [[ -n "$base_ref" ]]; then
      git -C "$repo_dir" worktree add -b "$branch" "$worktree_path" "$base_ref" 2>/dev/null && ok=true
    fi
    if ! $ok; then
      git -C "$repo_dir" worktree add -b "$branch" "$worktree_path" 2>/dev/null && ok=true
    fi
    if ! $ok; then
      git -C "$repo_dir" worktree add "$worktree_path" "$branch" 2>/dev/null && ok=true
    fi
  fi

  if ! $ok; then
    echo "${_C_YELLOW}✗ Failed to create worktree for '$branch'${_C_RESET}"
    return 1
  fi

  # ── Copy .vscode settings from main repo (for --track) ──
  if $track_remote && [[ -d "$main_repo_dir/.vscode" ]]; then
    rm -rf "$worktree_path/.vscode"
    cp -R "$main_repo_dir/.vscode" "$worktree_path/.vscode"
    echo "${_C_GREEN}✓ .vscode${_C_RESET}    ${_C_DIM}copied from main repo${_C_RESET}"
  fi

  # ── Compute workspace folder (map cwd into worktree) ──
  local cwd="$PWD"
  local workspace_folder="$worktree_path"
  if [[ "$cwd" == "$repo_dir"* ]]; then
    local rel="${cwd#$repo_dir}"
    workspace_folder="$worktree_path$rel"
  fi

  # ── Create workspace file with timestamp ──
  mkdir -p "$AGENT_WORKSPACES_DIR"
  local ts=$(date +%Y%m%d-%H%M%S)
  # Use the last path component as a clean workspace name
  local clean_name="${branch##*/}"
  local workspace_file="$AGENT_WORKSPACES_DIR/${clean_name}_${ts}.code-workspace"

  # Use repo name for --track, branch name otherwise
  local folder_display_name="$branch"
  if $track_remote; then
    folder_display_name="$(basename "$main_repo_dir")"
  fi

  cat > "$workspace_file" <<EOF
{
  "folders": [
    { "name": "$folder_display_name", "path": "$workspace_folder" }
  ],
  "settings": {
    "git.openRepositoryInParentFolders": "never",
    "window.title": "\${dirty}\${activeEditorShort}\${separator}$clean_name"
  }
}
EOF

  echo ""
  echo "${_C_GREEN}✓ Worktree${_C_RESET}   ${_C_DIM}$worktree_path${_C_RESET}"
  echo "${_C_GREEN}✓ Workspace${_C_RESET}  ${_C_DIM}${workspace_file:t}${_C_RESET}"
  echo "${_C_GREEN}✓ Folder${_C_RESET}     ${_C_DIM}$workspace_folder${_C_RESET}"

  code -n "$workspace_file"
}

_agent_open() {
  local new_window=false
  if [[ "$1" == "-n" ]]; then
    new_window=true
    shift
  fi

  local name="$1"
  mkdir -p "$AGENT_WORKSPACES_DIR"

  # No argument: interactive picker (newest first)
  if [[ -z "$name" ]]; then
    local workspaces=("$AGENT_WORKSPACES_DIR"/*.code-workspace(NOm))
    if [[ ${#workspaces[@]} -eq 0 ]]; then
      echo "${_C_YELLOW}No workspaces found in $AGENT_WORKSPACES_DIR${_C_RESET}"
      return 1
    fi

    echo "${_C_BOLD}Workspaces:${_C_RESET}"
    local i=1
    local pick_hashes=()
    for ws in "${workspaces[@]}"; do
      local base="${ws:t:r}"
      local h=$(_agent_hash "$base")
      pick_hashes+=("$h")
      if _agent_ws_has_ts "$base"; then
        local ts_part=$(_agent_ws_ts "$base")
        local branch_part=$(_agent_ws_branch "$base")
        local display_ts="${ts_part:0:4}-${ts_part:4:2}-${ts_part:6:2} ${ts_part:9:2}:${ts_part:11:2}"
        echo "  ${_C_CYAN}$i)${_C_RESET} ${_C_MAGENTA}$h${_C_RESET} ${_C_BOLD}$branch_part${_C_RESET}  ${_C_DIM}$display_ts${_C_RESET}"
      else
        echo "  ${_C_CYAN}$i)${_C_RESET} ${_C_MAGENTA}$h${_C_RESET} ${_C_BOLD}$base${_C_RESET}"
      fi
      ((i++))
    done

    echo -n "Pick (number, hash, or name): "
    read choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#workspaces[@]} )); then
      local workspace_file="${workspaces[$choice]}"
    else
      local workspace_file
      workspace_file=$(_agent_resolve_workspace "$choice") || return 1
    fi
  else
    local workspace_file
    workspace_file=$(_agent_resolve_workspace "$name") || return 1
  fi

  if $new_window; then
    code -n "$workspace_file"
  else
    code "$workspace_file"
  fi
  echo "${_C_GREEN}✓ Opened: ${_C_BOLD}${workspace_file:t:r}${_C_RESET}"
}

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
  local wt_dir="${repo_dir}.worktrees"

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

_agent_term() {
  if [[ -z "$1" ]]; then
    echo "Usage: ${_C_BOLD}agent term${_C_RESET} <name>"
    echo "Use ${_C_CYAN}agent term --reset${_C_RESET} to restore default."
    return 1
  fi
  if [[ "$1" == "--reset" ]]; then
    _AGENT_TERM_TITLE=""
    printf '\e]2;%s\a' ""
    echo "${_C_GREEN}✓ Terminal title reset${_C_RESET}"
    return
  fi
  _AGENT_TERM_TITLE="$1"
  printf '\e]2;%s\a' "$1"
}

_agent_help() {
  cat <<EOF
Usage: ${_C_BOLD}agent${_C_RESET} <command> [args...]

${_C_BOLD}Commands:${_C_RESET}
  ${_C_CYAN}new${_C_RESET}  <branch|.> [options]      Create worktree + workspace, open VS Code
  ${_C_CYAN}open${_C_RESET} [-n] [name]               Re-open an existing workspace
  ${_C_CYAN}rm${_C_RESET}   <branch>                  Remove worktree + workspace(s)
  ${_C_CYAN}list${_C_RESET}                           List all sessions
  ${_C_CYAN}term${_C_RESET} <name>                    Set terminal tab name (--reset to clear)
  ${_C_CYAN}help${_C_RESET}                           Show this help

${_C_BOLD}Options for new:${_C_RESET}
  ${_C_CYAN}--base${_C_RESET} <ref>   Branch from a specific ref (default: current branch)
  ${_C_CYAN}--track${_C_RESET}        Check out an existing remote branch

Aliases: ${_C_DIM}o → open, ls → list, t → term${_C_RESET}

${_C_BOLD}Examples:${_C_RESET}
  ${_C_CYAN}agent new feat-feature-store${_C_RESET}
  ${_C_CYAN}agent new .${_C_RESET}                     ${_C_DIM}# branch from current, prompt for name${_C_RESET}
  ${_C_CYAN}agent new fix-api --base main${_C_RESET}
  ${_C_CYAN}agent new feat-remote --track${_C_RESET}   ${_C_DIM}# check out remote branch${_C_RESET}
  ${_C_CYAN}agent open${_C_RESET}                     ${_C_DIM}# interactive picker${_C_RESET}
  ${_C_CYAN}agent rm feat-feature-store${_C_RESET}
  ${_C_CYAN}agent rm a1b2${_C_RESET}                   ${_C_DIM}# remove by hash from agent list${_C_RESET}
  ${_C_CYAN}agent list${_C_RESET}
  ${_C_CYAN}agent term my-session${_C_RESET}
EOF
}

# ─── Completion ───────────────────────────────────────────────────────────────

_agent_completion() {
  local -a subcmds
  subcmds=(
    'new:Create worktree + workspace, open VS Code'
    'open:Re-open an existing workspace'
    'rm:Remove a worktree'
    'list:List worktrees and workspaces'
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
