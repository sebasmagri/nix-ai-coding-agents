#!/usr/bin/env bash
# Updates AI agent versions in versions.json to the latest stable releases.
# Usage: ./scripts/update-agents.sh [--dry-run]

set -euo pipefail

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
DRY_RUN="${1:-}"
UPDATES=""

sri_hash_file() {
  nix hash convert --hash-algo sha256 --to sri \
    "$(nix-prefetch-url "$1" 2>/dev/null)"
}

current_version() {
  local agent="$1" system="$2"
  jq -r --arg a "$agent" --arg s "$system" '.[$a][$s].version' "$VERSIONS_JSON"
}

update_platform() {
  local agent="$1" system="$2" version="$3" hash="$4"
  local tmp
  tmp=$(mktemp)
  jq --arg a "$agent" --arg s "$system" --arg v "$version" --arg h "$hash" \
    '.[$a][$s] = {version: $v, hash: $h}' \
    "$VERSIONS_JSON" > "$tmp" && mv "$tmp" "$VERSIONS_JSON"
}

# --- claude-code ---
CLAUDE_BASE="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
declare -A CLAUDE_SLUGS=(
  [x86_64-linux]="linux-x64"
  [aarch64-linux]="linux-arm64"
  [aarch64-darwin]="darwin-arm64"
  [x86_64-darwin]="darwin-x64"
)

latest=$(gh api repos/anthropics/claude-code/releases/latest --jq '.tag_name' 2>/dev/null | sed 's/^v//' || true)

if [[ -z "$latest" ]]; then
  echo "⚠ claude-code: could not resolve latest release"
else
  for system in "${!CLAUDE_SLUGS[@]}"; do
    current=$(current_version claude-code "$system")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ claude-code ($system): $current is up to date"
      continue
    fi
    echo "↑ claude-code ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      slug="${CLAUDE_SLUGS[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "$CLAUDE_BASE/$latest/$slug/claude"); then
        update_platform claude-code "$system" "$latest" "$hash"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}claude-code ($system): $current → $latest\n"
  done
fi

# --- codex ---
declare -A CODEX_TRIPLES=(
  [x86_64-linux]="x86_64-unknown-linux-gnu"
  [aarch64-linux]="aarch64-unknown-linux-gnu"
  [aarch64-darwin]="aarch64-apple-darwin"
  [x86_64-darwin]="x86_64-apple-darwin"
)

latest=$(gh api repos/openai/codex/releases --jq \
  '[.[] | select(.prerelease == false and (.tag_name | startswith("rust-v")))] | .[0].tag_name // empty' \
  2>/dev/null | sed 's/^rust-v//' || true)

if [[ -z "$latest" ]]; then
  echo "⚠ codex: could not resolve latest release"
else
  for system in "${!CODEX_TRIPLES[@]}"; do
    current=$(current_version codex "$system")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ codex ($system): $current is up to date"
      continue
    fi
    echo "↑ codex ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      triple="${CODEX_TRIPLES[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "https://github.com/openai/codex/releases/download/rust-v$latest/codex-${triple}.tar.gz"); then
        update_platform codex "$system" "$latest" "$hash"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}codex ($system): $current → $latest\n"
  done
fi

# --- goose ---
declare -A GOOSE_TRIPLES=(
  [x86_64-linux]="x86_64-unknown-linux-gnu"
  [aarch64-linux]="aarch64-unknown-linux-gnu"
  [aarch64-darwin]="aarch64-apple-darwin"
  [x86_64-darwin]="x86_64-apple-darwin"
)

latest=$(gh api repos/block/goose/releases --jq \
  '[.[] | select(.prerelease == false and (.tag_name | startswith("v")))] | .[0].tag_name // empty' \
  2>/dev/null | sed 's/^v//' || true)

if [[ -z "$latest" ]]; then
  echo "⚠ goose: could not resolve latest release"
else
  for system in "${!GOOSE_TRIPLES[@]}"; do
    current=$(current_version goose "$system")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ goose ($system): $current is up to date"
      continue
    fi
    echo "↑ goose ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      triple="${GOOSE_TRIPLES[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "https://github.com/block/goose/releases/download/v$latest/goose-${triple}.tar.bz2"); then
        update_platform goose "$system" "$latest" "$hash"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}goose ($system): $current → $latest\n"
  done
fi

# --- opencode ---
declare -A OPENCODE_ASSETS=(
  [x86_64-linux]="opencode-linux-x64.tar.gz"
  [aarch64-linux]="opencode-linux-arm64.tar.gz"
  [aarch64-darwin]="opencode-darwin-arm64.zip"
  [x86_64-darwin]="opencode-darwin-x64.zip"
)

latest=$(gh api repos/anomalyco/opencode/releases --jq \
  '[.[] | select(.prerelease == false and (.tag_name | startswith("v")))] | .[0].tag_name // empty' \
  2>/dev/null | sed 's/^v//' || true)

if [[ -z "$latest" ]]; then
  echo "⚠ opencode: could not resolve latest release"
else
  for system in "${!OPENCODE_ASSETS[@]}"; do
    current=$(current_version opencode "$system")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ opencode ($system): $current is up to date"
      continue
    fi
    echo "↑ opencode ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      asset="${OPENCODE_ASSETS[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "https://github.com/anomalyco/opencode/releases/download/v$latest/$asset"); then
        update_platform opencode "$system" "$latest" "$hash"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}opencode ($system): $current → $latest\n"
  done
fi

# --- Summary ---
if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo -e "\nDry run — no changes made."
elif [[ -n "$UPDATES" ]]; then
  echo -e "\nUpdated:\n$UPDATES"
else
  echo -e "\nAll agents are up to date."
fi
