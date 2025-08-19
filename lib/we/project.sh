#!/usr/bin/env bash
set -euo pipefail

resolve_project(){
  MODULE="$TARGET_MODULE"
  if [ -d "$MODULE" ]; then
    PROJECT="$MODULE"
  else
    PROJECT="$(dirname "$MODULE")"
  fi

  # service name from basename
  if [ -n "${SERVICE:-}" ]; then
    :
  else
    SERVICE="$(basename "$MODULE")"
  fi

  # default ENTRY
  if [ -n "${ENTRY:-}" ]; then
    :
  else
    if [ -f "$MODULE" ] && [[ "$MODULE" == *.py ]]; then
      ENTRY="python $(basename "$MODULE")"
    elif [ -f "$PROJECT/main.py" ]; then
      ENTRY="python main.py"
    else
      ENTRY="python -m ${SERVICE}"
    fi
  fi

  # unit suffix
  UNIT_SUFFIX=$(python -c "import hashlib,os,sys; p=sys.argv[1]; ab=os.path.abspath(p); print(hashlib.sha1(ab.encode()).hexdigest()[:8])" "$PROJECT")
}

compute_defaults(){
  STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/we"
  LOGDIR="$STATE_DIR/$SERVICE/logs"
  RUNDIR="$PROJECT/.we/$SERVICE"
  mkdir -p "$LOGDIR" "$RUNDIR"
  TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
  HASH=$(python -c "import hashlib,sys; print(hashlib.sha1((sys.argv[1]).encode()).hexdigest()[:8])" "$PROJECT")
  RUNLOG="$RUNDIR/run.log"
  ARCHIVE="$LOGDIR/${SERVICE}-${TIMESTAMP}-${HASH}.log"
  UNIT="we-${SERVICE}-${UNIT_SUFFIX}"
  
  # Set default values for Makefile variables
  RELOAD=${RELOAD:-1}
  KEEP_N=${KEEP_N:-10}
  SECURE=${SECURE:-0}
  TAIL=${TAIL:-100}
}
