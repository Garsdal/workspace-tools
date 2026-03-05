#!/usr/bin/env zsh
# install.sh — Install workspace-tools into your shell environment.
#
# Run from anywhere:  ./install.sh          (clones from GitHub)
# Run from the repo:  ./install.sh --local  (symlinks current directory)
# Reinstall:          ./install.sh          (safe to re-run)

set -euo pipefail

INSTALL_DIR="$HOME/.workspace-tools"
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source ~/.workspace-tools/workspace-tools.zsh"
REPO_URL="https://github.com/Garsdal/workspace-tools.git"
SCRIPT_DIR="${0:A:h}"

echo ""
echo "workspace-tools installer"
echo "────────────────────────────────"
echo ""

# ── 1. Determine install mode ──
local_install=false
if [[ "${1:-}" == "--local" ]]; then
  local_install=true
fi

# ── 2. Set up ~/.workspace-tools ──
if $local_install; then
  # Remove old install (clone or symlink) and symlink to current repo
  if [[ -L "$INSTALL_DIR" ]]; then
    rm "$INSTALL_DIR"
  elif [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
  fi
  ln -s "$SCRIPT_DIR" "$INSTALL_DIR"
  echo "✓ Symlinked  $INSTALL_DIR → $SCRIPT_DIR"
else
  if [[ -L "$INSTALL_DIR" ]]; then
    rm "$INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
    echo "✓ Cloned to  $INSTALL_DIR  (replaced symlink)"
  elif [[ -d "$INSTALL_DIR" ]]; then
    echo "✓ Already installed  $INSTALL_DIR"
  else
    git clone "$REPO_URL" "$INSTALL_DIR"
    echo "✓ Cloned to  $INSTALL_DIR"
  fi
fi

# ── 3. Add source line to ~/.zshrc ──
if grep -qF "$SOURCE_LINE" "$ZSHRC" 2>/dev/null; then
  echo "✓ Already sourced  in ~/.zshrc"
else
  echo "" >> "$ZSHRC"
  echo "# Workspace & agent tooling" >> "$ZSHRC"
  echo "$SOURCE_LINE" >> "$ZSHRC"
  echo "✓ Added source line to ~/.zshrc"
fi

echo ""
echo "Done! Run: source ~/.zshrc && agent help"
echo ""
