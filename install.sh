#!/usr/bin/env bash
set -euo pipefail
DEST_BIN="${HOME}/.local/bin"
DEST_LIB="${HOME}/.local/lib/we"
mkdir -p "$DEST_BIN" "$DEST_LIB"
cp we "$DEST_BIN/we"
chmod +x "$DEST_BIN/we"
cp -r lib/we/* "$DEST_LIB/"
chmod -R +r "$DEST_LIB"

# Update the LIB_DIR path in the installed script
sed -i "s|LIB_DIR=\"\$ROOT_DIR/lib/we\"|LIB_DIR=\"$DEST_LIB\"|" "$DEST_BIN/we"

# Get the version by running the installed script
VERSION=$("$DEST_BIN/we" --version 2>/dev/null || echo "unknown")

cat <<EOF
Installed 'we' ($VERSION) to $DEST_BIN/we and libs to $DEST_LIB
Make sure $DEST_BIN is in your PATH. Run 'we --help' for usage.
EOF
