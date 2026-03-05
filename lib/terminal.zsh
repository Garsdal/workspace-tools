#!/usr/bin/env zsh
# lib/terminal.zsh — Terminal title persistence

# ─── Terminal title persistence ───────────────────────────────────────────────
_AGENT_TERM_TITLE=""
_agent_precmd_title() {
  [[ -n "$_AGENT_TERM_TITLE" ]] && printf '\e]2;%s\a' "$_AGENT_TERM_TITLE"
}
if (( ! ${precmd_functions[(Ie)_agent_precmd_title]} )); then
  precmd_functions+=(_agent_precmd_title)
fi
