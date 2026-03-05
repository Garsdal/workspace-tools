#!/usr/bin/env zsh
# commands/term.zsh — Set terminal tab name

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
