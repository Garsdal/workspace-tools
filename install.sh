#!/usr/bin/env zsh
# install.sh — Install workspace-tools into your shell environment.
#
# Clones the repo to ~/.workspace-tools (if not already there) and adds a
# source line to ~/.zshrc.  To update later: git pull inside ~/.workspace-tools.

set -euo pipefail

INSTALL_DIR="$HOME/.workspace-tools"
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source ~/.workspace-tools/workspace-tools.zsh"

echo ""
echo "workspace-tools installer"
echo "────────────────────────────────"
echo ""

# ── 1. Clone repo if needed ──
if [[ -d "$INSTALL_DIR" ]]; then
  echo "✓ Already cloned  $INSTALL_DIR"
else
  git clone https://github.com/Garsdal/workspace-tools.git "$INSTALL_DIR"
  echo "✓ Cloned to  $INSTALL_DIR"
fi

# ── 2. Add source line to ~/.zshrc ──
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
