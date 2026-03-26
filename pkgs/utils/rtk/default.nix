{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  versions = builtins.fromJSON (builtins.readFile ../../../utils-versions.json);
  info = versions.rtk.${stdenv.hostPlatform.system}
    or (throw "rtk: unsupported platform ${stdenv.hostPlatform.system}");

  platformMap = {
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
  };

  triple = platformMap.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "rtk";
  inherit (info) version;

  src = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${info.version}/rtk-${triple}.tar.gz";
    inherit (info) hash;
  };

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    tar xzf $src
    install -Dm755 rtk $out/bin/rtk
  '';

  meta = {
    description = "CLI proxy that reduces LLM token consumption on dev commands";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames versions.rtk;
    mainProgram = "rtk";
  };
}
