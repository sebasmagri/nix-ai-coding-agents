{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  glibc,
  unzip,
  makeWrapper,
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

  isLinux = stdenvNoCC.hostPlatform.isLinux;

  loaderMap = {
    "x86_64-linux" = "${glibc}/lib/ld-linux-x86-64.so.2";
    "aarch64-linux" = "${glibc}/lib/ld-linux-aarch64.so.1";
  };
  runtimeLibs = [ glibc stdenv.cc.cc.lib ];
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit (info) version;

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${info.version}/opencode-${platform}.${ext}";
    inherit (info) hash;
  };

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = [ makeWrapper ]
    ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [ unzip ];

  installPhase = ''
    ${if stdenvNoCC.hostPlatform.isDarwin then "unzip $src" else "tar xzf $src"}
    install -Dm755 opencode $out/lib/opencode/opencode
  '' + (if isLinux then ''
    makeWrapper ${loaderMap.${stdenvNoCC.hostPlatform.system}} $out/bin/opencode \
      --add-flags "--library-path ${lib.makeLibraryPath runtimeLibs}" \
      --add-flags "$out/lib/opencode/opencode" \
      --suffix PATH : ${lib.makeBinPath [ ripgrep ]}
  '' else ''
    makeWrapper $out/lib/opencode/opencode $out/bin/opencode \
      --suffix PATH : ${lib.makeBinPath [ ripgrep ]}
  '');

  meta = {
    description = "A powerful AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    platforms = builtins.attrNames versions.opencode;
    mainProgram = "opencode";
  };
}
