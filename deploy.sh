#!/usr/bin/env bash
set -euo pipefail

# Get current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Add and commit all changes with timestamp
git add .
git commit -m "Auto deploy: $TIMESTAMP"
echo "Committed changes with timestamp: $TIMESTAMP"

# Push to GitHub
git push origin main
echo "Pushed to GitHub"

# Wait a bit for GitHub's cache to update
echo "Waiting for GitHub cache to update..."
sleep 15

# Install via curl and log version
echo "Installing via curl..."
INSTALL_OUTPUT=$(curl -sSL https://raw.githubusercontent.com/amitskidrow/we-tool/main/install.sh | bash)
echo "$INSTALL_OUTPUT"

# Extract version from the installation output
if echo "$INSTALL_OUTPUT" | grep -q "Installed 'we'"; then
    VERSION_LINE=$(echo "$INSTALL_OUTPUT" | grep "Installed 'we'")
    echo "Installation log: $VERSION_LINE"
else
    echo "Installation failed or version not found"
    echo "$INSTALL_OUTPUT"
fi

# Test the installed version directly
echo "Testing installed version..."
if command -v we >/dev/null 2>&1; then
    INSTALLED_VERSION=$(we --version 2>/dev/null || echo "Failed to get version")
    echo "Installed version: $INSTALLED_VERSION"
else
    echo "we command not found in PATH"
fi