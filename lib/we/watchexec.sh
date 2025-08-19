#!/usr/bin/env bash
set -euo pipefail

# Compose WEX and CMD variables expected by Makefile
WEX_TEMPLATE() {
  # Check if watchexec is available in the system
  if command -v watchexec &> /dev/null; then
    echo "watchexec --restart --watch . --exts py --ignore .we --ignore .uu --ignore .git --ignore .venv --"
  else
    echo >&2 "ERROR: watchexec not found in PATH. Please install it or set RELOAD=0"
    exit 1
  fi
}

compose_watchexec_cmds(){
  WEX=$(WEX_TEMPLATE)
  CMD_RELOAD="cd \"$PROJECT\" && $WEX uv run --project \"$PROJECT\" -- $ENTRY"
  CMD_PLAIN="cd \"$PROJECT\" && uv run --project \"$PROJECT\" -- $ENTRY"
}
