#!/usr/bin/env zsh
# install.sh — Install workspace-tools into your shell environment.
#
# Creates a symlink from ~/.zsh/workspace-tools.zsh to this repo so that
# `git pull` automatically picks up changes without re-running install.

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
_GREEN=$'\e[32m'
_CYAN=$'\e[36m'
_YELLOW=$'\e[33m'
_BOLD=$'\e[1m'
_DIM=$'\e[2m'
_RESET=$'\e[0m'

# ─── Paths ────────────────────────────────────────────────────────────────────
REPO_DIR="${0:A:h}"
ZSH_DIR="$HOME/.zsh"
TARGET="$ZSH_DIR/workspace-tools.zsh"
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source ~/.zsh/workspace-tools.zsh"

echo ""
echo "${_BOLD}workspace-tools installer${_RESET}"
echo "${_DIM}────────────────────────────────${_RESET}"
echo ""

# ── 1. Create ~/.zsh/ if needed ──
if [[ ! -d "$ZSH_DIR" ]]; then
  mkdir -p "$ZSH_DIR"
  echo "${_GREEN}✓ Created   ${_RESET}$ZSH_DIR"
fi

# ── 2. Symlink workspace-tools.zsh → repo ──
if [[ -L "$TARGET" ]]; then
  rm "$TARGET"
elif [[ -f "$TARGET" ]]; then
  echo "${_YELLOW}⚠  Backing up${_RESET} $TARGET → ${TARGET}.bak"
  mv "$TARGET" "${TARGET}.bak"
fi

ln -s "$REPO_DIR/workspace-tools.zsh" "$TARGET"
echo "${_GREEN}✓ Symlinked ${_RESET}$TARGET"
echo "            ${_DIM}→ $REPO_DIR/workspace-tools.zsh${_RESET}"

# ── 3. Add source line to ~/.zshrc ──
if grep -qF "$SOURCE_LINE" "$ZSHRC" 2>/dev/null; then
  echo "${_GREEN}✓ Already   ${_RESET}source line present in ~/.zshrc"
else
  echo "" >> "$ZSHRC"
  echo "# Workspace & agent tooling" >> "$ZSHRC"
  echo "$SOURCE_LINE" >> "$ZSHRC"
  echo "${_GREEN}✓ Added     ${_RESET}source line to ~/.zshrc"
fi

echo ""
echo "${_BOLD}Done!${_RESET} Activate with ${_CYAN}source ~/.zshrc${_RESET}, then try ${_CYAN}agent help${_RESET}."
echo ""
