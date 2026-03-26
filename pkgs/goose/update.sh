# sourced by scripts/update-agents.sh

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
    current=$(current_version goose "$system" "$VERSIONS_JSON")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ goose ($system): $current is up to date"
      continue
    fi
    echo "↑ goose ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      triple="${GOOSE_TRIPLES[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "https://github.com/block/goose/releases/download/v$latest/goose-${triple}.tar.bz2"); then
        update_platform goose "$system" "$latest" "$hash" "$VERSIONS_JSON"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}goose ($system): $current → $latest\n"
  done
fi
