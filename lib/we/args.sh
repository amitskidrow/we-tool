#!/usr/bin/env bash
set -euo pipefail

parse_args(){
  MODULE_ARG=""
  SERVICE=""
  ENTRY=""
  MAKEFILE_OUT="Makefile"
  README_OUT="README.md"
  MK_ONLY=0
  README_ONLY=0
  DRY_RUN=0
  YES=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --service) SERVICE="$2"; shift 2;;
      --entry) ENTRY="$2"; shift 2;;
      --makefile-out) MAKEFILE_OUT="$2"; shift 2;;
      --readme-out) README_OUT="$2"; shift 2;;
      --mk-only) MK_ONLY=1; shift;;
      --readme-only) README_ONLY=1; shift;;
      --dry-run) DRY_RUN=1; shift;;
      --yes) YES=1; shift;;
      -h|--help) usage; exit 0;;
      -V|--version) echo "we 1.0"; exit 0;;
      --) shift; break;;
      -*) echo "Unknown flag: $1"; usage; exit 1;;
      *)
        if [ -z "$MODULE_ARG" ]; then MODULE_ARG="$1"; else echo "Unexpected arg: $1"; usage; exit 1; fi
        shift;;
    esac
  done

  if [ -z "$MODULE_ARG" ]; then
    echo "module path required"; usage; exit 1
  fi
  MODULE_ARG_ABS=$(python -c "import os,sys; p=sys.argv[1] if len(sys.argv)>1 else '.'; print(os.path.abspath(p))" "$MODULE_ARG")
  TARGET_MODULE="$MODULE_ARG_ABS"
}
