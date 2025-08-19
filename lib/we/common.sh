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
  cat <<EOF
we <module-dir | module.py> [--service NAME] [--entry CMD] [--makefile-out FILE] [--readme-out FILE] [--mk-only] [--readme-only] [--dry-run] [--yes] [-h|--help]
EOF
}
