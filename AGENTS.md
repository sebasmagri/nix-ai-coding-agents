# Agent instructions

This is a Nix flake that packages AI coding agents from prebuilt binaries.

## Repository layout

- `flake.nix` — flake definition exporting `overlays.default`, `packages`, `checks`, and `devShells`
- `versions.json` — per-agent, per-platform version and hash data (single source of truth for mutable data)
- `pkgs/` — one derivation file per agent (`claude-code.nix`, `codex.nix`, `opencode.nix`)
- `scripts/update-agents.sh` — fetches latest upstream versions and updates `versions.json`
- `.github/workflows/update.yml` — nightly CI that runs the update script and opens a PR
- `.github/workflows/ci.yml` — PR build validation (builds all agents on Linux and macOS)
- `docs/DESIGN.md` — full design document with architecture decisions and rationale

## Key conventions

- All agents use `fetchurl` with `dontUnpack = true`. Archives are extracted
  manually in `installPhase`. This avoids hash mismatches between
  `nix-prefetch-url` and `fetchzip`'s permission normalization.
- Version and hash data is never hardcoded in `.nix` files. Derivations read
  from `versions.json` via `builtins.fromJSON (builtins.readFile ../versions.json)`.
- Platform support is derived from `versions.json` keys:
  `platforms = builtins.attrNames versions.<agent>;`
- The update script uses `sri_hash_file` (i.e. `nix-prefetch-url` without
  `--unpack`) for all agents, matching the `fetchurl` fetcher.
- Per-platform version+hash pairs allow partial updates when a hash fetch
  fails for one platform.

## Supported platforms

`x86_64-linux`, `aarch64-linux`, `aarch64-darwin`, `x86_64-darwin`.

## Adding a new agent

1. Add a new derivation file under `pkgs/<agent>.nix` following the pattern
   of the existing ones (read from `versions.json`, use `fetchurl`, set
   `meta.mainProgram`).
2. Add the agent to `versions.json` with placeholder entries for all four
   platforms (`{ "version": "0.0.0", "hash": "" }`).
3. Add the agent to `flake.nix` in the overlay, packages, and checks outputs.
4. Add the update logic to `scripts/update-agents.sh` (version resolution
   via `gh api`, hash fetching via `sri_hash_file`, `update_platform` calls).
5. Run `bash scripts/update-agents.sh` to populate real versions and hashes.
6. Verify with `nix flake check --no-build` and `nix build .#<agent>`.

## Validation

```sh
nix flake check --no-build   # evaluation check (all platforms)
nix build .#claude-code .#codex .#opencode  # build on current host
bash scripts/update-agents.sh --dry-run     # verify version resolution
```
