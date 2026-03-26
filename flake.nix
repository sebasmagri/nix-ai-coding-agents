{
  description = "Nix overlay for AI coding agents";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems f;
      pkgsFor = system: (import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      }).extend self.overlays.default;
    in {
      overlays.default = final: prev: {
        claude-code = final.callPackage ./pkgs/claude-code.nix {};
        codex       = final.callPackage ./pkgs/codex.nix {};
        goose       = final.callPackage ./pkgs/goose.nix {};
        opencode    = final.callPackage ./pkgs/opencode.nix {};
      };

      packages = forEachSystem (system: let p = pkgsFor system; in {
        claude-code = p.claude-code;
        codex       = p.codex;
        goose       = p.goose;
        opencode    = p.opencode;
      });

      checks = forEachSystem (system: let p = pkgsFor system; in {
        claude-code = p.claude-code;
        codex       = p.codex;
        goose       = p.goose;
        opencode    = p.opencode;
      });

      devShells = forEachSystem (system: let p = pkgsFor system; in {
        default = p.mkShellNoCC {
          packages = [ p.jq p.gh p.nixfmt-rfc-style ];
        };
      });
    };
}
