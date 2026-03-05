#!/usr/bin/env zsh
# commands/help.zsh — Show help

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
