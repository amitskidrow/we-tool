#!/usr/bin/env bash
set -euo pipefail
FILE=${1:-Makefile}
missing=0
check(){
  grep -q "$1" "$FILE" || { echo "Missing: $1"; missing=1; }
}
check "BEGIN: we-managed-block"
check "unsuffixed guard"
check "check-service"
check "WE_SERVICES"
check "KEEP_N"
check "LOGDIR"
if [ $missing -ne 0 ]; then
  echo "Validation failed"; exit 2
fi
echo "Makefile looks ok"
