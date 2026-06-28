{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.tokensave;

  tomlFormat = pkgs.formats.toml { };
  yamlFormat = pkgs.formats.yaml { };

  tokensaveBin = "${cfg.package}/bin/tokensave";

  mcpServerSpec = {
    command = tokensaveBin;
    args = [ "serve" ];
  };

  awarenessMarkdown = ''
    # tokensave

    Prefer the `tokensave_*` MCP tools for code research over grep,
    glob, or raw file reads. Useful entry points: `tokensave_context`,
    `tokensave_search`, `tokensave_callers`, `tokensave_callees`,
    `tokensave_impact`, `tokensave_node`, `tokensave_files`,
    `tokensave_affected`.

    The project must be indexed before tools return results: run
    `tokensave init` in the project root, then `tokensave sync` after
    significant changes.

    If a question cannot be answered through the MCP tools, query the
    SQLite index directly at `.tokensave/tokensave.db` (tables:
    `nodes`, `edges`, `files`).
  '';

in
{
  options.programs.tokensave = {
    enable = lib.mkEnableOption "tokensave, a semantic code-graph MCP server";

    package = lib.mkPackageOption pkgs "tokensave" { nullable = true; };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = ''
        Configuration for tokensave, written to
        {file}`$HOME/.tokensave/config.toml`. See
        <https://github.com/aovestdipaperino/tokensave> for available
        options.
      '';
      example = lib.literalExpression ''
        {
          upload_enabled = false;
          watcher_debounce = "2s";
          extraction_timeout_secs = 60;
        }
      '';
    };

    enableClaudeCodeIntegration = lib.mkEnableOption ''
      tokensave integration with Claude Code: registers the MCP server,
      installs PreToolUse, UserPromptSubmit, and Stop hooks, auto-allows
      every `tokensave_*` tool, and appends an awareness rule.
    '';

    enableCodexIntegration = lib.mkEnableOption ''
      tokensave integration with Codex. Registers the MCP server and
      auto-approves every `tokensave_*` tool by writing
      {file}`$HOME/.codex/config.toml`. Do not combine with another
      module that owns the same path.
    '';

    enableOpenCodeIntegration = lib.mkEnableOption ''
      tokensave integration with OpenCode. Registers the MCP server by
      writing {file}`$XDG_CONFIG_HOME/opencode/opencode.json`. Do not
      combine with another module that owns the same path.
    '';

    enableGooseIntegration = lib.mkEnableOption ''
      tokensave integration with goose. Registers the MCP server as a
      stdio extension by writing
      {file}`$XDG_CONFIG_HOME/goose/config.yaml`. Do not combine with
      another module that owns the same path.
    '';
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enableClaudeCodeIntegration -> config.programs.claude-code.enable;
          message = "programs.tokensave.enableClaudeCodeIntegration requires programs.claude-code.enable = true";
        }
        {
          assertion = cfg.enableCodexIntegration -> config.programs.codex.enable;
          message = "programs.tokensave.enableCodexIntegration requires programs.codex.enable = true";
        }
        {
          assertion = cfg.enableOpenCodeIntegration -> config.programs.opencode.enable;
          message = "programs.tokensave.enableOpenCodeIntegration requires programs.opencode.enable = true";
        }
      ];

      home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];
    }

    (lib.mkIf (cfg.settings != { }) {
      home.file.".tokensave/config.toml".source =
        tomlFormat.generate "tokensave-config" cfg.settings;
    })

    (lib.mkIf cfg.enableClaudeCodeIntegration {
      programs.claude-code.mcpServers.tokensave = mcpServerSpec;

      programs.claude-code.settings.hooks.PreToolUse = [
        {
          matcher = "Agent";
          hooks = [{
            type = "command";
            command = "${tokensaveBin} hook-pre-tool-use";
          }];
        }
      ];

      programs.claude-code.settings.hooks.UserPromptSubmit = [
        {
          hooks = [{
            type = "command";
            command = "${tokensaveBin} hook-prompt-submit";
          }];
        }
      ];

      programs.claude-code.settings.hooks.Stop = [
        {
          hooks = [{
            type = "command";
            command = "${tokensaveBin} hook-stop";
          }];
        }
      ];

      programs.claude-code.settings.permissions.allow = [ "mcp__tokensave__*" ];

      programs.claude-code.memory.text = awarenessMarkdown;
    })

    (lib.mkIf cfg.enableCodexIntegration {
      programs.codex.settings.mcp_servers.tokensave = mcpServerSpec // {
        default_tools_approval_mode = "auto";
      };

      programs.codex.custom-instructions = awarenessMarkdown;
    })

    (lib.mkIf cfg.enableOpenCodeIntegration {
      programs.opencode.settings.mcp.tokensave = {
        type = "local";
        command = [ tokensaveBin "serve" ];
      };
    })

    (lib.mkIf cfg.enableGooseIntegration {
      xdg.configFile."goose/config.yaml".source = yamlFormat.generate "goose-tokensave" {
        extensions.tokensave = {
          type = "stdio";
          name = "tokensave";
          cmd = tokensaveBin;
          args = [ "serve" ];
          enabled = true;
          timeout = 300;
          envs = { };
        };
      };
    })
  ]);
}
