#!/usr/bin/env bash
set -euo pipefail
# Simple fixture runner: creates a temp module and runs make targets to smoke test generated Makefile
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/app"
cat > "$TMPDIR/app/main.py" <<'PY'
print('hello')
PY
pushd "$TMPDIR/app" >/dev/null
# run 'we' to generate Makefile
WE_BIN="$(pwd)/../../we"
if [ ! -x "$WE_BIN" ]; then WE_BIN="we"; fi
$WE_BIN . --yes
make up || { echo "up failed"; exit 1; }
make ps || { echo "ps failed"; exit 1; }
make down || true
popd >/dev/null
