{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  versions = builtins.fromJSON (builtins.readFile ../../../utils-versions.json);
  info = versions.tokensave.${stdenv.hostPlatform.system}
    or (throw "tokensave: unsupported platform ${stdenv.hostPlatform.system} (no prebuilt published upstream)");

  platformMap = {
    "x86_64-linux" = "x86_64-linux";
    "aarch64-linux" = "aarch64-linux";
    "aarch64-darwin" = "aarch64-macos";
  };

  triple = platformMap.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "tokensave";
  inherit (info) version;

  src = fetchurl {
    url = "https://github.com/aovestdipaperino/tokensave/releases/download/v${info.version}/tokensave-v${info.version}-${triple}.tar.gz";
    inherit (info) hash;
  };

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    tar xzf $src
    install -Dm755 tokensave $out/bin/tokensave
  '';

  meta = {
    description = "Semantic code-graph MCP server for AI coding agents";
    homepage = "https://tokensave.dev/";
    license = lib.licenses.mit;
    platforms = builtins.attrNames versions.tokensave;
    mainProgram = "tokensave";
  };
}
