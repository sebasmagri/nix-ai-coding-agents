# sourced by scripts/update-agents.sh

declare -A RTK_TRIPLES=(
  [x86_64-linux]="x86_64-unknown-linux-musl"
  [aarch64-linux]="aarch64-unknown-linux-gnu"
  [aarch64-darwin]="aarch64-apple-darwin"
  [x86_64-darwin]="x86_64-apple-darwin"
)

latest=$(gh api repos/rtk-ai/rtk/releases/latest --jq '.tag_name' 2>/dev/null | sed 's/^v//' || true)

if [[ -z "$latest" ]]; then
  echo "⚠ rtk: could not resolve latest release"
else
  for system in "${!RTK_TRIPLES[@]}"; do
    current=$(current_version rtk "$system" "$UTILS_VERSIONS_JSON")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ rtk ($system): $current is up to date"
      continue
    fi
    echo "↑ rtk ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      triple="${RTK_TRIPLES[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "https://github.com/rtk-ai/rtk/releases/download/v$latest/rtk-${triple}.tar.gz"); then
        update_platform rtk "$system" "$latest" "$hash" "$UTILS_VERSIONS_JSON"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}rtk ($system): $current → $latest\n"
  done
fi
