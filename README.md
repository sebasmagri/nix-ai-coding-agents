# nix-ai-coding-agents

Nix flake overlay packaging AI coding agents and related utilities from
prebuilt binaries.

## Agents

| Agent | Description | License |
|-------|-------------|---------|
| [Claude Code](https://github.com/anthropics/claude-code) | Anthropic's agentic coding tool | Unfree |
| [Codex](https://github.com/openai/codex) | OpenAI's lightweight coding agent | Apache 2.0 |
| [Goose](https://github.com/block/goose) | Block's open-source AI coding agent | Apache 2.0 |
| [OpenCode](https://github.com/anomalyco/opencode) | Terminal-native AI coding agent | MIT |

## Utilities

| Utility | Description | License |
|---------|-------------|---------|
| [rtk](https://github.com/rtk-ai/rtk) | CLI proxy that reduces LLM token consumption | Apache 2.0 |

All packages are built for `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`,
and `x86_64-darwin`.

## Usage

### Direct run

```sh
nix run github:sebasmagri/nix-ai-coding-agents#claude-code
nix run github:sebasmagri/nix-ai-coding-agents#codex
nix run github:sebasmagri/nix-ai-coding-agents#goose
nix run github:sebasmagri/nix-ai-coding-agents#opencode
nix run github:sebasmagri/nix-ai-coding-agents#rtk
```

### As a flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nix-ai-coding-agents = {
      url = "github:sebasmagri/nix-ai-coding-agents";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix-ai-coding-agents, ... }:
    let
      pkgs = (import nixpkgs { system = "x86_64-linux"; }).extend
        nix-ai-coding-agents.overlays.default;
    in {
      # pkgs.claude-code, pkgs.codex, pkgs.goose, pkgs.opencode, pkgs.rtk are now available
    };
}
```

### With NixOS or nix-darwin

```nix
{ nixpkgs.overlays = [ nix-ai-coding-agents.overlays.default ]; }
```

### With home-manager

```nix
home.packages = with pkgs; [ claude-code codex goose opencode rtk ];
```

For declarative agent configuration (settings, MCP servers, instructions),
use [home-manager's built-in `programs.claude-code`, `programs.codex`, and
`programs.opencode` modules](https://github.com/nix-community/home-manager/tree/master/modules/programs).

### Unfree license note

Claude Code has an unfree license. Consumers need to allow it explicitly:

```nix
{ nixpkgs.config.allowUnfree = true; }
```

Or with a specific predicate:

```nix
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "claude-code" ];
}
```

## How it works

Each package is a `stdenv.mkDerivation` that downloads a prebuilt binary via
`fetchurl`. Version and hash metadata lives in `versions.json` (agents) and
`utils-versions.json` (utilities), keyed per package and per platform.

A GitHub Actions workflow runs `scripts/update-agents.sh` every 8 hours to
check upstream releases, fetch new hashes, and open a PR with the changes.

See [docs/DESIGN.md](docs/DESIGN.md) for the full design document.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).