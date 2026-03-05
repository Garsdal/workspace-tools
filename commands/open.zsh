#!/usr/bin/env zsh
# commands/open.zsh — Re-open an existing workspace

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
