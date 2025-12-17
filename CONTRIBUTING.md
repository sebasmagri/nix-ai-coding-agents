# Contributing

## Development

Enter the dev shell (provides `jq`, `gh`, `nixfmt-rfc-style`):

```sh
nix develop
```

Update all agent versions locally:

```sh
bash scripts/update-agents.sh
```

Dry run (check for updates without modifying anything):

```sh
bash scripts/update-agents.sh --dry-run
```

Validate the flake:

```sh
nix flake check --no-build
```

Build and test all agents on the current platform:

```sh
nix build .#claude-code .#codex .#opencode
```
