{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  ripgrep,
}:

let
  versions = builtins.fromJSON (builtins.readFile ../../versions.json);
  info = versions.claude-code.${stdenvNoCC.hostPlatform.system}
    or (throw "claude-code: unsupported platform ${stdenvNoCC.hostPlatform.system}");

  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x64";
  };

  platform = platformMap.${stdenvNoCC.hostPlatform.system};
  baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
in
stdenvNoCC.mkDerivation {
  pname = "claude-code";
  inherit (info) version;

  src = fetchurl {
    url = "${baseUrl}/${info.version}/${platform}/claude";
    inherit (info) hash;
  };

  dontUnpack = true;
  # Bun standalone binaries embed JS after ELF sections; any ELF
  # patching (autoPatchelfHook, patchelf, strip) corrupts the payload.
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -Dm755 $src $out/lib/claude-code/claude
    makeWrapper $out/lib/claude-code/claude $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --suffix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  meta = {
    description = "An agentic coding tool that lives in your terminal";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    platforms = builtins.attrNames versions.claude-code;
    mainProgram = "claude";
  };
}
