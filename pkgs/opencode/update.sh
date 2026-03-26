# sourced by scripts/update-agents.sh

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
    current=$(current_version opencode "$system" "$VERSIONS_JSON")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ opencode ($system): $current is up to date"
      continue
    fi
    echo "↑ opencode ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      asset="${OPENCODE_ASSETS[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "https://github.com/anomalyco/opencode/releases/download/v$latest/$asset"); then
        update_platform opencode "$system" "$latest" "$hash" "$VERSIONS_JSON"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}opencode ($system): $current → $latest\n"
  done
fi
