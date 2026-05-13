{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  makeBinaryWrapper,
  ripgrep,
}:

let
  versions = builtins.fromJSON (builtins.readFile ../../versions.json);
  info = versions.opencode.${stdenvNoCC.hostPlatform.system}
    or (throw "opencode: unsupported platform ${stdenvNoCC.hostPlatform.system}");

  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x64";
  };

  platform = platformMap.${stdenvNoCC.hostPlatform.system};
  ext = if stdenvNoCC.hostPlatform.isDarwin then "zip" else "tar.gz";
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit (info) version;

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${info.version}/opencode-${platform}.${ext}";
    inherit (info) hash;
  };

  dontUnpack = true;
  # Bun standalone binaries embed the JS payload after the ELF and locate it
  # by offset from EOF. Stripping shifts file size and corrupts that offset.
  dontStrip = true;

  nativeBuildInputs = [
    makeBinaryWrapper
  ]
    ++ lib.optionals stdenvNoCC.hostPlatform.isElf [ autoPatchelfHook ]
    ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [ unzip ];

  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    ${if stdenvNoCC.hostPlatform.isDarwin then "unzip $src" else "tar xzf $src"}
    install -Dm755 opencode $out/bin/opencode
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  meta = {
    description = "A powerful AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    platforms = builtins.attrNames versions.opencode;
    mainProgram = "opencode";
  };
}
