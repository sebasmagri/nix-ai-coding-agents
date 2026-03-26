#!/usr/bin/env bash
# Shared helpers for per-package update scripts.
# Sourced by scripts/update-agents.sh — not executed directly.

sri_hash_file() {
  nix hash convert --hash-algo sha256 --to sri \
    "$(nix-prefetch-url "$1" 2>/dev/null)"
}

current_version() {
  local pkg="$1" system="$2" file="$3"
  jq -r --arg a "$pkg" --arg s "$system" '.[$a][$s].version' "$file"
}

update_platform() {
  local pkg="$1" system="$2" version="$3" hash="$4" file="$5"
  local tmp
  tmp=$(mktemp)
  jq --arg a "$pkg" --arg s "$system" --arg v "$version" --arg h "$hash" \
    '.[$a][$s] = {version: $v, hash: $h}' \
    "$file" > "$tmp" && mv "$tmp" "$file"
}
