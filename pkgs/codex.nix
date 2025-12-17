{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libcap,
  openssl,
  zlib,
}:

let
  versions = builtins.fromJSON (builtins.readFile ../versions.json);
  info = versions.codex.${stdenv.hostPlatform.system}
    or (throw "codex: unsupported platform ${stdenv.hostPlatform.system}");

  platformMap = {
    "x86_64-linux" = "x86_64-unknown-linux-gnu";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
  };

  triple = platformMap.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "codex";
  inherit (info) version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${info.version}/codex-${triple}.tar.gz";
    inherit (info) hash;
  };

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ libcap openssl zlib stdenv.cc.cc.lib ];

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
