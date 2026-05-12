{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  ripgrep,
  fd,
}:

let
  versions = builtins.fromJSON (builtins.readFile ../../versions.json);
  info = versions.pi.${stdenv.hostPlatform.system}
    or (throw "pi: unsupported platform ${stdenv.hostPlatform.system}");

  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x64";
  };

  platform = platformMap.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "pi";
  inherit (info) version;

  src = fetchurl {
    url = "https://github.com/badlogic/pi-mono/releases/download/v${info.version}/pi-${platform}.tar.gz";
    inherit (info) hash;
  };

  dontUnpack = true;
  # Node single-executable application: the JS payload is appended after the
  # ELF. strip shifts section offsets and corrupts that payload.
  dontStrip = true;

  nativeBuildInputs = [ makeWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    tar xzf $src
    rm -rf pi/docs pi/examples
    mkdir -p $out/lib/pi
    cp -r pi/. $out/lib/pi/
    makeWrapper $out/lib/pi/pi $out/bin/pi \
      --suffix PATH : ${lib.makeBinPath [ ripgrep fd ]}
  '';

  meta = {
    description = "Minimal, customizable terminal coding agent harness";
    longDescription = ''
      Pi is a Node-based AI coding harness by Mario Zechner. This package
      ships the upstream standalone bundle with ripgrep and fd placed on the
      wrapper PATH so pi's grep and file-search tools work without pi
      attempting to download its own binaries on first use.

      Note: pi prefers its own writable cache directory (~/.config/pi/bin)
      over $PATH when locating rg and fd. If pi previously downloaded those
      binaries into that cache, the cached copies shadow the ones provided
      here. Remove the cached binaries to fall back to the Nix-managed ones.
    '';
    homepage = "https://github.com/badlogic/pi-mono";
    license = lib.licenses.mit;
    platforms = builtins.attrNames versions.pi;
    mainProgram = "pi";
  };
}
