# nix-ai-coding-agents — Design Document

Standalone Nix flake overlay packaging AI coding agents from prebuilt binaries,
with GitHub Actions nightly auto-update PRs.

## Design Decisions

### versions.json as single source of truth

Version and hash data is decoupled from derivation logic into `versions.json`.
The update script writes JSON via `jq` instead of fragile positional `sed` on
`.nix` files. Each platform has its own version+hash pair, so a failed hash
fetch for one platform doesn't block updates for the others.

### fetchurl with manual extraction

All agents use `fetchurl` with hashes computed by `sri_hash_file`, a shell
helper that runs `nix-prefetch-url` (without `--unpack`) and converts the
result to SRI format via `nix hash convert`. Archives are extracted manually in `installPhase` with
`dontUnpack = true`. This avoids hash mismatches between `nix-prefetch-url --unpack`
and `fetchzip`'s permission normalization.

### No flake-utils

Uses a 3-line `forEachSystem` with `nixpkgs.lib.genAttrs` instead of depending
on `flake-utils`.

## Release Sources

| Agent       | Version resolution                                                    | Download URL pattern                                                                    |
|-------------|-----------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| claude-code | `gh api repos/anthropics/claude-code/releases/latest` → `.tag_name`  | `https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/{version}/{platform}/claude` |
| codex       | `gh api repos/openai/codex/releases` → first non-prerelease `rust-v*` (note: Codex publishes both JS `v*` and Rust `rust-v*` tags; we filter for `rust-v*` and strip the prefix for the version) | `https://github.com/openai/codex/releases/download/rust-v{version}/codex-{triple}.tar.gz` |
| opencode    | `gh api repos/anomalyco/opencode/releases` → first non-prerelease `v*` | `https://github.com/anomalyco/opencode/releases/download/v{version}/opencode-{platform}.{tar.gz,zip}` |

### Platform mappings

| Nix system | Claude Code slug | Codex triple | OpenCode asset suffix |
|---|---|---|---|
| `x86_64-linux` | `linux-x64` | `x86_64-unknown-linux-gnu` | `linux-x64.tar.gz` |
| `aarch64-linux` | `linux-arm64` | `aarch64-unknown-linux-gnu` | `linux-arm64.tar.gz` |
| `aarch64-darwin` | `darwin-arm64` | `aarch64-apple-darwin` | `darwin-arm64.zip` |
| `x86_64-darwin` | `darwin-x64` | `x86_64-apple-darwin` | `darwin-x64.zip` |

## CI/CD

### Nightly update workflow (.github/workflows/update.yml)

- **Trigger**: `schedule: cron "0 6 * * *"` + `workflow_dispatch`
- **Steps**: checkout → install Nix → run update script → `nix flake check --no-build` → create/update PR
- **Branch strategy**: single rolling `auto-update/agents` branch, force-pushed each run → at most one open PR
- **PR handling**: creates new PR if none open; updates body of existing PR if one exists
- **Permissions**: `contents: write`, `pull-requests: write` (uses `GITHUB_TOKEN`)

### PR validation (.github/workflows/ci.yml)

- **Trigger**: `pull_request` to `main`
- **Matrix**: `ubuntu-latest` (x86_64-linux) + `macos-latest` (aarch64-darwin)
- **Steps**: `nix flake check --no-build`, then builds each agent individually
- Sets `NIXPKGS_ALLOW_UNFREE=1` for claude-code