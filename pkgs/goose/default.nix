{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  openssl,
  zlib,
}:

let
  versions = builtins.fromJSON (builtins.readFile ../../versions.json);
  info = versions.goose.${stdenv.hostPlatform.system}
    or (throw "goose: unsupported platform ${stdenv.hostPlatform.system}");

  platformMap = {
    "x86_64-linux" = "x86_64-unknown-linux-gnu";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
  };

  triple = platformMap.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "goose";
  inherit (info) version;

  src = fetchurl {
    url = "https://github.com/block/goose/releases/download/v${info.version}/goose-${triple}.tar.bz2";
    inherit (info) hash;
  };

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ openssl zlib stdenv.cc.cc.lib ];

  installPhase = ''
    tar xjf $src
    install -Dm755 goose $out/bin/goose
  '';

  meta = {
    description = "An open-source AI coding agent from Block";
    homepage = "https://github.com/block/goose";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames versions.goose;
    mainProgram = "goose";
  };
}
