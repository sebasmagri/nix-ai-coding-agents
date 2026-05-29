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

recorded_hash() {
  local pkg="$1" system="$2" file="$3"
  jq -r --arg a "$pkg" --arg s "$system" '.[$a][$s].hash' "$file"
}

declare -A _RELEASE_JSON_CACHE

# SRI form of the sha256 digest GitHub publishes for a release asset.
# Prints nothing when the release, asset, or digest is unavailable, so a
# caller can treat empty as "cannot verify" rather than "drift". The release
# response is cached per repo+tag: a sweep touches each release once instead
# of once per platform, which keeps bursts under GitHub's secondary limit.
github_asset_digest_sri() {
  local repo="$1" tag="$2" asset="$3" json digest
  local key="$repo@$tag"
  if [[ -n "${_RELEASE_JSON_CACHE[$key]+set}" ]]; then
    json="${_RELEASE_JSON_CACHE[$key]}"
  else
    json=$(gh api "repos/$repo/releases/tags/$tag" 2>/dev/null) || json=""
    _RELEASE_JSON_CACHE[$key]="$json"
  fi
  [[ -n "$json" ]] || return 0
  digest=$(jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .digest // empty' <<<"$json" 2>/dev/null) || true
  digest="${digest#sha256:}"
  [[ -n "$digest" ]] || return 0
  nix hash convert --hash-algo sha256 --to sri "$digest" 2>/dev/null || true
  return 0
}

# Compares the recorded hash of an unchanged version against the bytes
# upstream currently serves. A mismatch means the artifact was re-uploaded
# under a stable tag: the pin is never rewritten automatically (that needs
# human review), it is recorded in DRIFT and reported at the end of the run.
check_drift() {
  local pkg="$1" system="$2" recorded="$3" upstream="$4"
  if [[ -z "$upstream" ]]; then
    echo "    drift check skipped ($system): no upstream digest"
    return 0
  fi
  if [[ "$recorded" != "$upstream" ]]; then
    echo "  ‼ DRIFT $pkg ($system): recorded $recorded, upstream now serves $upstream"
    DRIFT="${DRIFT}${pkg} (${system}): ${recorded} → ${upstream}\n"
  fi
  return 0
}

update_platform() {
  local pkg="$1" system="$2" version="$3" hash="$4" file="$5"
  local tmp
  tmp=$(mktemp)
  jq --arg a "$pkg" --arg s "$system" --arg v "$version" --arg h "$hash" \
    '.[$a][$s] = {version: $v, hash: $h}' \
    "$file" > "$tmp" && mv "$tmp" "$file"
}
