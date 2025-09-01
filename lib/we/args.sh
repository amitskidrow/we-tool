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
      -V|--version) echo "we 0.2.7"; exit 0;;
      --) shift; break;;
      -*) echo "Unknown flag: $1"; usage; exit 1;;
      *)
        if [ -z "$MODULE_ARG" ]; then MODULE_ARG="$1"; else echo "Unexpected arg: $1"; usage; exit 1; fi
        shift;;
    esac
  done

  # Enforce a single, strict invocation form: we ./<target_dir_with_main_pythonfile>
  if [ -z "$MODULE_ARG" ]; then
    echo "ERROR: target directory is required." >&2
    echo "Use: we ./<target_dir_with_main_pythonfile> (see 'we --help')" >&2
    exit 1
  fi

  # Reject '.' and any form not starting with './'
  case "$MODULE_ARG" in
    .|./) echo "ERROR: '.' is not allowed. Provide a specific subdirectory under the current directory." >&2; exit 1;;
    ./*) : ;; # ok
    *) echo "ERROR: Invalid target '$MODULE_ARG'. Use: we ./<target_dir_with_main_pythonfile>" >&2; exit 1;;
  esac

  # Must be an existing directory
  if [ ! -d "$MODULE_ARG" ]; then
    echo "ERROR: Target is not a directory: $MODULE_ARG" >&2
    exit 1
  fi

  # Validate presence of a main Python file in the target directory
  local has_main=0
  for f in __main__.py main.py run.py app.py index.py start.py; do
    if [ -f "$MODULE_ARG/$f" ]; then has_main=1; break; fi
  done
  if [ "$has_main" -ne 1 ]; then
    echo "ERROR: '$MODULE_ARG' does not contain a main Python file (one of: __main__.py, main.py, run.py, app.py, index.py, start.py)." >&2
    echo "Use: we ./<target_dir_with_main_pythonfile>" >&2
    exit 1
  fi

  MODULE_ARG_ABS=$(python -c "import os,sys; p=sys.argv[1]; print(os.path.abspath(p))" "$MODULE_ARG")
  TARGET_MODULE="$MODULE_ARG_ABS"
}
