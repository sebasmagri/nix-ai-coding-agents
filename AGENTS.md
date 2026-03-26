# Agent instructions

This is a Nix flake that packages AI coding agents and related utilities from prebuilt binaries.

## Repository layout

- `flake.nix` — flake definition exporting `overlays.default`, `packages`, `checks`, and `devShells`
- `versions.json` — per-agent, per-platform version and hash data (single source of truth for mutable data)
- `utils-versions.json` — per-utility, per-platform version and hash data
- `pkgs/<name>/` — per-agent directory with `default.nix` and `update.sh`
- `pkgs/utils/<name>/` — per-utility directory with `default.nix` and `update.sh`
- `scripts/update-agents.sh` — thin orchestrator that sources `scripts/lib.sh` and each `pkgs/**/update.sh`
- `scripts/lib.sh` — shared helpers for update scripts (`sri_hash_file`, `current_version`, `update_platform`)
- `.github/workflows/update.yml` — CI that runs the update script every 8 hours and opens a PR
- `.github/workflows/ci.yml` — PR build validation (builds all packages on Linux and macOS)
- `docs/DESIGN.md` — full design document with architecture decisions and rationale

## Key conventions

- All agents use `fetchurl` with `dontUnpack = true`. Archives are extracted
  manually in `installPhase`. This avoids hash mismatches between
  `nix-prefetch-url` and `fetchzip`'s permission normalization.
- Version and hash data is never hardcoded in `.nix` files. Agent derivations
  read from `versions.json`, utility derivations read from `utils-versions.json`.
- Platform support is derived from `versions.json` keys:
  `platforms = builtins.attrNames versions.<agent>;`
- The update script uses `sri_hash_file` (i.e. `nix-prefetch-url` without
  `--unpack`) for all agents, matching the `fetchurl` fetcher.
- Per-platform version+hash pairs allow partial updates when a hash fetch
  fails for one platform.

## Supported platforms

`x86_64-linux`, `aarch64-linux`, `aarch64-darwin`, `x86_64-darwin`.

## Adding a new agent

1. Create `pkgs/<agent>/default.nix` following the existing pattern (read
   from `../../versions.json`, use `fetchurl`, set `meta.mainProgram`).
2. Create `pkgs/<agent>/update.sh` with version resolution and hash fetching
   logic. The script is sourced by the orchestrator and has access to helpers
   from `scripts/lib.sh` and variables `$VERSIONS_JSON`, `$DRY_RUN`, `$UPDATES`.
3. Add the agent to `versions.json` with placeholder entries for all four
   platforms (`{ "version": "0.0.0", "hash": "" }`).
4. Add the agent to `flake.nix` in the overlay, packages, and checks outputs.
5. Run `bash scripts/update-agents.sh` to populate real versions and hashes.
6. Verify with `nix flake check --no-build` and `nix build .#<agent>`.

## Adding a new utility

Same steps as adding an agent, but:
- Directory goes under `pkgs/utils/<util>/`
- Version data goes in `utils-versions.json`; derivation reads from `../../../utils-versions.json`
- Use `$UTILS_VERSIONS_JSON` in `update.sh` instead of `$VERSIONS_JSON`

## Validation

```sh
nix flake check --no-build   # evaluation check (all platforms)
nix build .#claude-code .#codex .#goose .#opencode .#rtk  # build on current host
bash scripts/update-agents.sh --dry-run     # verify version resolution
```
