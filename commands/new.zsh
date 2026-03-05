#!/usr/bin/env zsh
# commands/new.zsh — Create worktree + workspace, open VS Code

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
  main_repo_dir=$(_agent_main_repo_dir "$repo_dir") || return 1

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

  local wt_dir="${main_repo_dir}.worktrees"
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

  # ── Checkout the branch in the new worktree ──
  git -C "$worktree_path" checkout "$branch" 2>/dev/null

  # ── Copy .vscode settings from main repo ──
  if [[ -d "$main_repo_dir/.vscode" ]]; then
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

  # Always use repo name as folder display name
  local folder_display_name="$(basename "$main_repo_dir")"

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
