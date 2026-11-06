{
  lib,
  stdenv,
  swift,
  swiftpm,
  makeWrapper,
}:

stdenv.mkDerivation {
  pname = "snowyseason";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Package.swift
      ../Sources
      ../Tests
      ../Resources
    ];
  };

  # The demo recorder isn't part of the app.
  swiftpmFlags = [
    "--product"
    "SnowySeason"
  ];

  nativeBuildInputs = [
    swift
    swiftpm
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    app=$out/Applications/SnowySeason.app
    mkdir -p $app/Contents/MacOS $out/bin
    cp "$(swiftpmBinPath)/SnowySeason" $app/Contents/MacOS/
    cp Resources/Info.plist $app/Contents/

    # Launch through the bundle so the app picks up its Info.plist.
    makeWrapper $app/Contents/MacOS/SnowySeason $out/bin/snowyseason

    runHook postInstall
  '';

  meta = {
    description = "Snow and autumn leaves that fall across your Mac desktop and settle on your windows";
    homepage = "https://github.com/dahaoxx/snowyseason";
    platforms = lib.platforms.darwin;
    license = lib.licenses.mit;
    mainProgram = "snowyseason";
  };
}
