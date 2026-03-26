#!/usr/bin/env bash
# Updates package versions to the latest stable releases.
# Usage: ./scripts/update-agents.sh [--dry-run]

set -euo pipefail
shopt -s globstar

if (( BASH_VERSINFO[0] < 4 )); then
  echo "error: bash 4+ required (associative arrays). Found: $BASH_VERSION" >&2
  echo "  On macOS, use bash from nixpkgs or Homebrew." >&2
  exit 1
fi

for cmd in gh jq nix-prefetch-url nix; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "error: required command '$cmd' not found" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_JSON="$REPO_DIR/versions.json"
UTILS_VERSIONS_JSON="$REPO_DIR/utils-versions.json"
DRY_RUN="${1:-}"
UPDATES=""

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

for update_script in "$REPO_DIR"/pkgs/**/update.sh; do
  # shellcheck source=/dev/null
  source "$update_script"
done

# --- Summary ---
if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo -e "\nDry run — no changes made."
elif [[ -n "$UPDATES" ]]; then
  echo -e "\nUpdated:\n$UPDATES"
else
  echo -e "\nAll packages are up to date."
fi
