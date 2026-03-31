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
        claude-code = final.callPackage ./pkgs/claude-code {};
        codex       = final.callPackage ./pkgs/codex {};
        goose       = final.callPackage ./pkgs/goose {};
        opencode    = final.callPackage ./pkgs/opencode {};
        rtk         = final.callPackage ./pkgs/utils/rtk {};
      };

      packages = forEachSystem (system: let p = pkgsFor system; in {
        claude-code = p.claude-code;
        codex       = p.codex;
        goose       = p.goose;
        opencode    = p.opencode;
        rtk         = p.rtk;
      });

      checks = forEachSystem (system: let p = pkgsFor system; in {
        claude-code = p.claude-code;
        codex       = p.codex;
        goose       = p.goose;
        opencode    = p.opencode;
        rtk         = p.rtk;
      });

      homeManagerModules = {
        rtk = import ./modules/programs/rtk.nix;
      };

      devShells = forEachSystem (system: let p = pkgsFor system; in {
        default = p.mkShellNoCC {
          packages = [ p.jq p.gh p.nixfmt-rfc-style ];
        };
      });
    };
}
