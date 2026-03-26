# sourced by scripts/update-agents.sh

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
    current=$(current_version claude-code "$system" "$VERSIONS_JSON")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ claude-code ($system): $current is up to date"
      continue
    fi
    echo "↑ claude-code ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      slug="${CLAUDE_SLUGS[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "$CLAUDE_BASE/$latest/$slug/claude"); then
        update_platform claude-code "$system" "$latest" "$hash" "$VERSIONS_JSON"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}claude-code ($system): $current → $latest\n"
  done
fi
