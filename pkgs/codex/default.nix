{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  versions = builtins.fromJSON (builtins.readFile ../../versions.json);
  info = versions.codex.${stdenvNoCC.hostPlatform.system}
    or (throw "codex: unsupported platform ${stdenvNoCC.hostPlatform.system}");

  platformMap = {
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
  };

  triple = platformMap.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit (info) version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${info.version}/codex-${triple}.tar.gz";
    inherit (info) hash;
  };

  dontUnpack = true;

  installPhase = ''
    tar xzf $src
    install -Dm755 codex-${triple} $out/bin/codex
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames versions.codex;
    mainProgram = "codex";
  };
}
