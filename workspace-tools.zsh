#!/usr/bin/env zsh
# workspace-tools.zsh — entry point
# Source this file from ~/.zshrc:  source ~/.workspace-tools/workspace-tools.zsh
_WT_DIR="${0:A:h}"

source "$_WT_DIR/lib/config.zsh"
source "$_WT_DIR/lib/colors.zsh"
source "$_WT_DIR/lib/helpers.zsh"
source "$_WT_DIR/lib/terminal.zsh"

for cmd in "$_WT_DIR/commands/"*.zsh; do
  source "$cmd"
done

source "$_WT_DIR/completions/_agent.zsh"

agent() {
  local subcmd="${1:-help}"; shift 2>/dev/null
  case "$subcmd" in
    new)     _agent_new "$@" ;;
    open|o)  _agent_open "$@" ;;
    rm)      _agent_rm "$@" ;;
    list|ls) _agent_list "$@" ;;
    term|t)  _agent_term "$@" ;;
    help|*)  _agent_help ;;
  esac
}
