{
  description = "Nix overlay for AI coding agents";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems f;
      pkgsFor = system: (import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      }).extend self.overlays.default;

      tokensaveIntegrationCheck = system:
        let
          p = pkgsFor system;
          home = home-manager.lib.homeManagerConfiguration {
            pkgs = p;
            modules = [
              self.homeManagerModules.tokensave
              {
                home.username = "test";
                home.homeDirectory = if p.stdenv.isDarwin then "/Users/test" else "/home/test";
                home.stateVersion = "25.11";

                programs.claude-code = { enable = true; package = p.claude-code; };
                programs.codex = { enable = true; package = p.codex; };
                programs.opencode = { enable = true; package = p.opencode; };

                programs.tokensave = {
                  enable = true;
                  package = p.tokensave;
                  enableClaudeCodeIntegration = true;
                  enableCodexIntegration = true;
                  enableOpenCodeIntegration = true;
                };
              }
            ];
          };

          codexConfig = home.config.home.file.".codex/config.toml".source;
          claudeSettings = home.config.home.file.".claude/settings.json".source;
        in
        p.runCommand "tokensave-integration-check"
          { nativeBuildInputs = [ p.tokensave ]; }
          ''
            export HOME="$TMPDIR"
            tokensave tool 2>/dev/null \
              | grep -E '^  [a-z]' | awk '{print $1}' | sort -u > tools.txt
            count=$(wc -l < tools.txt)
            echo "packaged tokensave exposes $count tools"

            fail=0

            if grep -q 'default_tools_approval_mode = "auto"' ${codexConfig}; then
              echo "codex: server-level approval present"
            else
              echo "codex: no server-level approval, checking per-tool coverage"
              while read -r t; do
                grep -q "tokensave_$t\]" ${codexConfig} \
                  || { echo "  codex MISSING approval for: $t"; fail=1; }
              done < tools.txt
            fi

            if grep -qE '"mcp__tokensave(__\*)?"' ${claudeSettings}; then
              echo "claude-code: server-wide allow present"
            else
              echo "claude-code: no wildcard, checking per-tool coverage"
              while read -r t; do
                grep -q "mcp__tokensave__tokensave_$t\"" ${claudeSettings} \
                  || { echo "  claude-code MISSING allow for: $t"; fail=1; }
              done < tools.txt
            fi

            if [ "$fail" -ne 0 ]; then
              echo "FAIL: generated agent config does not cover every packaged tokensave tool"
              exit 1
            fi
            echo "PASS: every packaged tokensave tool is auto-approved"
            touch "$out"
          '';
    in {
      overlays.default = final: prev: {
        claude-code = final.callPackage ./pkgs/claude-code {};
        codex       = final.callPackage ./pkgs/codex {};
        goose       = final.callPackage ./pkgs/goose {};
        opencode    = final.callPackage ./pkgs/opencode {};
        pi          = final.callPackage ./pkgs/pi {};
        rtk         = final.callPackage ./pkgs/utils/rtk {};
        tokensave   = final.callPackage ./pkgs/utils/tokensave {};
      };

      packages = forEachSystem (system: let p = pkgsFor system; in {
        claude-code = p.claude-code;
        codex       = p.codex;
        goose       = p.goose;
        opencode    = p.opencode;
        pi          = p.pi;
        rtk         = p.rtk;
      } // nixpkgs.lib.optionalAttrs (system != "x86_64-darwin") {
        tokensave = p.tokensave;
      });

      checks = forEachSystem (system: let p = pkgsFor system; in {
        claude-code = p.claude-code;
        codex       = p.codex;
        goose       = p.goose;
        opencode    = p.opencode;
        pi          = p.pi;
        rtk         = p.rtk;
      } // nixpkgs.lib.optionalAttrs (system != "x86_64-darwin") {
        tokensave = p.tokensave;
        tokensave-integration = tokensaveIntegrationCheck system;
      });

      homeManagerModules = {
        rtk = import ./modules/programs/rtk.nix;
        tokensave = import ./modules/programs/tokensave.nix;
      };

      devShells = forEachSystem (system: let p = pkgsFor system; in {
        default = p.mkShellNoCC {
          packages = [ p.jq p.gh p.nixfmt-rfc-style ];
        };
      });
    };
}
