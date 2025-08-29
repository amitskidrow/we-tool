#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

# Bump patch version in pyproject.toml and lib/we/args.sh
bump_version() {
  local pyproject="$ROOT_DIR/pyproject.toml"
  local args_sh="$ROOT_DIR/lib/we/args.sh"
  if [[ ! -f "$pyproject" || ! -f "$args_sh" ]]; then
    echo "pyproject.toml or lib/we/args.sh not found; skipping version bump"
    return 0
  }

  # Extract current version from pyproject.toml
  local current
  current=$(sed -nE 's/^version = "([^"]+)"/\1/p' "$pyproject" | head -n1)
  if [[ -z "$current" ]]; then
    echo "Could not determine current version from pyproject.toml; skipping version bump"
    return 0
  fi

  IFS='.' read -r MAJOR MINOR PATCH <<< "$current"
  if [[ -z "${MAJOR:-}" || -z "${MINOR:-}" || -z "${PATCH:-}" ]]; then
    echo "Unexpected version format: $current; skipping version bump"
    return 0
  fi
  local next_patch
  next_patch=$((PATCH + 1))
  local next_version
  next_version="${MAJOR}.${MINOR}.${next_patch}"

  # Update pyproject.toml
  sed -i -E "s/^version = \"${current}\"/version = \"${next_version}\"/" "$pyproject"

  # Update args.sh version string used by `we --version`
  sed -i -E "s/( -V\|--version\) echo \"we )[0-9]+\.[0-9]+\.[0-9]+(\"; exit 0;\)/\1${next_version}\2/" "$args_sh"

  echo "Bumped version: ${current} -> ${next_version}"
}

commit_and_push() {
  local ts
  ts=$(timestamp)
  # Stage changes
  git add -A
  # Commit only if there are staged changes
  if ! git diff --staged --quiet; then
    # Try to extract version for a nicer message
    local v
    v=$(sed -nE 's/^version = "([^"]+)"/\1/p' "$ROOT_DIR/pyproject.toml" | head -n1 || true)
    if [[ -n "$v" ]]; then
      git commit -m "chore(release): v${v} (${ts})"
    else
      git commit -m "Auto deploy: ${ts}"
    fi
    echo "Committed changes"
  else
    echo "No changes to commit"
  fi

  # Push regardless; if nothing to push, Git will say up to date
  git push origin main
  echo "Pushed to GitHub"
}

install_remote() {
  echo "Waiting for GitHub cache to update..."
  sleep 15
  echo "Installing via curl..."
  INSTALL_OUTPUT=$(curl -sSL https://raw.githubusercontent.com/amitskidrow/we-tool/main/install.sh | bash)
  echo "$INSTALL_OUTPUT"

  if echo "$INSTALL_OUTPUT" | grep -q "Installed 'we'"; then
      VERSION_LINE=$(echo "$INSTALL_OUTPUT" | grep "Installed 'we'")
      echo "Installation log: $VERSION_LINE"
  else
      echo "Installation failed or version not found"
      echo "$INSTALL_OUTPUT"
  fi

  echo "Testing installed version..."
  if command -v we >/dev/null 2>&1; then
      INSTALLED_VERSION=$(we --version 2>/dev/null || echo "Failed to get version")
      echo "Installed version: $INSTALLED_VERSION"
  else
      echo "we command not found in PATH"
  fi
}

main() {
  bump_version
  commit_and_push
  install_remote
}

main "$@"
