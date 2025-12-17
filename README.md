# nix-ai-coding-agents

Nix flake overlay packaging AI coding agents from prebuilt binaries.

## Agents

| Agent | Description | License |
|-------|-------------|---------|
| [Claude Code](https://github.com/anthropics/claude-code) | Anthropic's agentic coding tool | Unfree |
| [Codex](https://github.com/openai/codex) | OpenAI's lightweight coding agent | Apache 2.0 |
| [OpenCode](https://github.com/anomalyco/opencode) | Terminal-native AI coding agent | MIT |

All agents are packaged for `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`,
and `x86_64-darwin`.

## Usage

### Direct run

```sh
nix run github:sebasmagri/nix-ai-coding-agents#claude-code
nix run github:sebasmagri/nix-ai-coding-agents#codex
nix run github:sebasmagri/nix-ai-coding-agents#opencode
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
      # pkgs.claude-code, pkgs.codex, pkgs.opencode are now available
    };
}
```

### With NixOS or nix-darwin

```nix
{ nixpkgs.overlays = [ nix-ai-coding-agents.overlays.default ]; }
```

### With home-manager

```nix
home.packages = with pkgs; [ claude-code codex opencode ];
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

Each agent is packaged as a `stdenv.mkDerivation` that downloads a prebuilt
binary via `fetchurl`. Version and hash metadata lives in `versions.json`,
keyed per agent and per platform.

A nightly GitHub Actions workflow runs `scripts/update-agents.sh` to check
upstream releases, fetch new hashes, and open a PR with the changes.

See [docs/DESIGN.md](docs/DESIGN.md) for the full design document.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).