# sourced by scripts/update-agents.sh

declare -A TOKENSAVE_TRIPLES=(
  [x86_64-linux]="x86_64-linux"
  [aarch64-linux]="aarch64-linux"
  [aarch64-darwin]="aarch64-macos"
)

latest=$(gh api repos/aovestdipaperino/tokensave/releases/latest --jq '.tag_name' 2>/dev/null | sed 's/^v//' || true)

if [[ -z "$latest" ]]; then
  echo "⚠ tokensave: could not resolve latest release"
else
  for system in "${!TOKENSAVE_TRIPLES[@]}"; do
    current=$(current_version tokensave "$system" "$UTILS_VERSIONS_JSON")
    triple="${TOKENSAVE_TRIPLES[$system]}"
    if [[ "$current" == "$latest" ]]; then
      echo "✓ tokensave ($system): $current is up to date"
      check_drift tokensave "$system" \
        "$(recorded_hash tokensave "$system" "$UTILS_VERSIONS_JSON")" \
        "$(github_asset_digest_sri aovestdipaperino/tokensave "v$latest" "tokensave-v$latest-${triple}.tar.gz")"
      continue
    fi
    echo "↑ tokensave ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      echo "  fetching hash..."
      if hash=$(sri_hash_file "https://github.com/aovestdipaperino/tokensave/releases/download/v$latest/tokensave-v$latest-${triple}.tar.gz"); then
        update_platform tokensave "$system" "$latest" "$hash" "$UTILS_VERSIONS_JSON"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}tokensave ($system): $current → $latest\n"
  done
fi
