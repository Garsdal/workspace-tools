#!/usr/bin/env zsh
# lib/config.zsh — Configuration variables

# ─── Configuration ────────────────────────────────────────────────────────────
AGENT_WORKSPACES_DIR="$HOME/Workspaces"
AGENT_MAX_SESSIONS=${AGENT_MAX_SESSIONS:-5}
AGENT_COPY_PATHS=(${=AGENT_COPY_PATHS:-.vscode .env .env.local})
_WT_VERSION="0.0.8"
