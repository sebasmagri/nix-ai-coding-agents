# sourced by scripts/update-agents.sh

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
    current=$(current_version codex "$system" "$VERSIONS_JSON")
    if [[ "$current" == "$latest" ]]; then
      echo "✓ codex ($system): $current is up to date"
      continue
    fi
    echo "↑ codex ($system): $current → $latest"
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      triple="${CODEX_TRIPLES[$system]}"
      echo "  fetching hash..."
      if hash=$(sri_hash_file "https://github.com/openai/codex/releases/download/rust-v$latest/codex-${triple}.tar.gz"); then
        update_platform codex "$system" "$latest" "$hash" "$VERSIONS_JSON"
        echo "  ✓ $hash"
      else
        echo "  ⚠ hash fetch failed, skipping"
      fi
    fi
    UPDATES="${UPDATES}codex ($system): $current → $latest\n"
  done
fi
