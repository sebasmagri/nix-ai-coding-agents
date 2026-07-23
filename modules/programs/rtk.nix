{
  config,
  options,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.rtk;

  # home-manager 26.05 renamed these; set whichever the consumer's
  # home-manager provides. optionalAttrs (not mkIf) keeps the attribute
  # undefined when the option is absent, which the module system's
  # unmatched-option check requires.
  hasCodexContext = options.programs.codex ? context;
  hasClaudeCodeContext = options.programs.claude-code ? context;

  tomlFormat = pkgs.formats.toml { };

  rtkBin = "${cfg.package}/bin/rtk";

  rtkAwarenessMarkdown = ''
    # rtk

    rtk is installed as a transparent command proxy. When you run shell
    commands, they may be automatically rewritten to use rtk for more
    concise output. You do not need to prefix commands with `rtk` manually.

    If you need the raw, unfiltered output of a command, prefix it with
    `command` to bypass rtk (e.g. `command git status`).

    Additional rtk commands available:
    - `rtk gain` — show token savings statistics
    - `rtk discover` — list supported command rewrites
    - `rtk tee` — recover full output from the last filtered command
  '';

  openCodePluginScript = ''
    import { Plugin } from "@opencode-ai/plugin"

    export default Plugin.create({
      name: "rtk",
      version: "1.0.0",
      hooks: {
        "tool.execute.before": async (params) => {
          const { name, input } = params
          if (name !== "bash" && name !== "shell") return params

          const command = input?.command
          if (!command) return params

          try {
            const proc = Bun.spawn(["${rtkBin}", "rewrite", command], {
              stdout: "pipe",
              stderr: "pipe",
            })
            const output = await new Response(proc.stdout).text()
            const exitCode = await proc.exited

            if (exitCode === 0 && output.trim()) {
              return { ...params, input: { ...input, command: output.trim() } }
            }
          } catch {}

          return params
        },
      },
    })
  '';

  codexInstructions = ''
    # rtk

    rtk is a CLI proxy that reduces token consumption by filtering and
    compressing shell command output.

    Always prefix shell commands with `rtk` when available. Examples:

    - `rtk git status` instead of `git status`
    - `rtk git diff` instead of `git diff`
    - `rtk cargo test` instead of `cargo test`
    - `rtk find . -name "*.rs"` instead of `find . -name "*.rs"`

    Run `rtk discover` to see all supported commands.
  '';
in
{
  options.programs.rtk = {
    enable = lib.mkEnableOption "rtk, a CLI proxy that reduces LLM token consumption";

    package = lib.mkPackageOption pkgs "rtk" { nullable = true; };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = ''
        Configuration for rtk, written to
        {file}`$XDG_CONFIG_HOME/rtk/config.toml`.

        See <https://github.com/rtk-ai/rtk> for available options.
      '';
      example = lib.literalExpression ''
        {
          display = {
            colors = true;
            emoji = true;
            max_width = 120;
          };
          tracking = {
            enabled = true;
            history_days = 90;
          };
          telemetry.enabled = false;
        }
      '';
    };

    enableClaudeCodeIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to integrate rtk with Claude Code.

        When enabled, installs a PreToolUse hook that transparently rewrites
        Bash commands through rtk, and adds an awareness rule so the agent
        understands the proxy.
      '';
    };

    enableCodexIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to integrate rtk with Codex.

        When enabled, installs a skill that instructs Codex to prefix shell
        commands with `rtk` for reduced token output.
      '';
    };

    enableOpenCodeIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to integrate rtk with OpenCode.

        When enabled, installs a TypeScript plugin that transparently rewrites
        shell commands through rtk before execution.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enableClaudeCodeIntegration -> config.programs.claude-code.enable;
          message = "programs.rtk.enableClaudeCodeIntegration requires programs.claude-code.enable = true";
        }
        {
          assertion = cfg.enableCodexIntegration -> config.programs.codex.enable;
          message = "programs.rtk.enableCodexIntegration requires programs.codex.enable = true";
        }
        {
          assertion = cfg.enableOpenCodeIntegration -> config.programs.opencode.enable;
          message = "programs.rtk.enableOpenCodeIntegration requires programs.opencode.enable = true";
        }
      ];

      home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];
    }

    (lib.mkIf (cfg.settings != { }) {
      xdg.configFile."rtk/config.toml".source =
        tomlFormat.generate "rtk-config" cfg.settings;
    })

    (lib.mkIf cfg.enableClaudeCodeIntegration (lib.mkMerge [
      {
        programs.claude-code.settings.hooks.PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "${rtkBin} hook claude";
              }
            ];
          }
        ];
      }

      (lib.optionalAttrs hasClaudeCodeContext {
        programs.claude-code.context = rtkAwarenessMarkdown;
      })

      (lib.optionalAttrs (!hasClaudeCodeContext) {
        programs.claude-code.memory.text = rtkAwarenessMarkdown;
      })
    ]))

    (lib.mkIf cfg.enableCodexIntegration (lib.mkMerge [
      (lib.optionalAttrs hasCodexContext {
        programs.codex.context = codexInstructions;
      })

      (lib.optionalAttrs (!hasCodexContext) {
        programs.codex.custom-instructions = codexInstructions;
      })
    ]))

    (lib.mkIf cfg.enableOpenCodeIntegration {
      xdg.configFile."opencode/plugins/rtk.ts".text = openCodePluginScript;
    })
  ]);
}
