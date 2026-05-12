# sourced by scripts/update-agents.sh

declare -A PI_ASSETS=(
  [x86_64-linux]="pi-linux-x64.tar.gz"
  [aarch64-linux]="pi-linux-arm64.tar.gz"
  [aarch64-darwin]="pi-darwin-arm64.tar.gz"
  [x86_64-darwin]="pi-darwin-x64.tar.gz"
)

latest=$(gh api repos/badlogic/pi-mono/releases --jq \
  '[.[] | select(.prerelease == false and (.tag_name | startswith("v")))] | .[0].tag_name // empty' \
  2>/dev/null | sed 's/^v//' || true)

if [[ -z "$latest" ]]; then
  echo "⚠ pi: could not resolve latest release"
else
  for system in "${!PI_ASSETS[@]}"; do
    current=$(current_version pi "$system" "$VERSIONS_JSON")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ pi ($system): $current is up to date"
      continue
    fi
    echo "↑ pi ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      asset="${PI_ASSETS[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "https://github.com/badlogic/pi-mono/releases/download/v$latest/$asset"); then
        update_platform pi "$system" "$latest" "$hash" "$VERSIONS_JSON"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}pi ($system): $current → $latest\n"
  done
fi
