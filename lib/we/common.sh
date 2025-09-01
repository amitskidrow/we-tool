#!/usr/bin/env bash
set -euo pipefail

abs_path() {
  python - <<'PY'
import os,sys
p=sys.argv[1]
print(os.path.abspath(os.path.expanduser(p)))
PY
}

confirm(){
  local msg=${1:-Are you sure?}
  read -r -p "$msg [y/N]: " ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0;;
    *) return 1;;
  esac
}

need_tool(){
  local t=$1
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "Missing required tool: $t" >&2
    return 1
  fi
}

usage(){
  cat <<'EOF'
we - generate Makefile and README blocks for a Python module/service

Usage (only allowed form):
  we ./<target_dir_with_main_pythonfile> [options]

Strict rule:
  - Only the above form is supported. '.' (current dir), absolute paths,
    and other variants are rejected to avoid confusion.
  - The target directory must contain one of: __main__.py, main.py, run.py,
    app.py, index.py, start.py.

Options:
  --service NAME        Service name (defaults to basename of module path)
  --entry CMD           Entry command (auto-detected if omitted)
  --makefile-out FILE   Output Makefile path (default: <module>/Makefile)
  --readme-out FILE     Output README path (default: README.md)
  --mk-only             Generate only the Makefile block
  --readme-only         Generate only the README block
  --dry-run             Show what would be generated, do not write
  --yes                 Write files without confirmation prompt
  -h, --help            Show this help and exit
  -V, --version         Show version and exit

Behavior:
  - When targeting a directory (e.g., "we ./service"), confirmation is auto-accepted
    and files are written immediately. Pass --dry-run to preview.

Generated Make targets (after running 'we'):
  make up         Start the service (idempotent)
  make watch      Up/restart-if-active and follow logs
  make launch     Up/restart-if-active and show recent logs (alias: run)
  make follow     Tail and follow logs
  make logs       Show last N lines (TAIL=100)
  make down       Stop tracked unit
  make kill       Stop all we-<service>-* units for this user
  make ps         Show one-line status
  make unit       Show detailed systemd unit status
  make journal    Show full systemd journal for the unit

Examples:
  we ./trading-authentication
  we ./service --service api --entry "python main.py"
EOF
}
