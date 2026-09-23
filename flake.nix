{
  description = "Blip - Send files to people and devices around the world";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      version = "1.2.2";

      mkBlip = pkgs:
        let
          # Generated per release: local relative paths, or fetchurl
          # calls pinned to the published tarball hashes.
          srcs = {
            x86_64-linux = pkgs.fetchurl {
              url = "https://static.blip.net/linux/blip-1.2.2-linux-amd64.tar.gz";
              sha256 = "0dcb662b4279b94f7913efa3177c5c9a1f0f3431b9089411165f5fafb2309cf4";
            };
            aarch64-linux = pkgs.fetchurl {
              url = "https://static.blip.net/linux/blip-1.2.2-linux-aarch64.tar.gz";
              sha256 = "38283f68e5c382f04d5a5bfb91f1cc849680ad1b437c7d4b9411f219129f0bae";
            };
          };

          nativeLibs = with pkgs; [
            alsa-lib
            fontconfig
            freetype
            libGL
            stdenv.cc.cc.lib  # libstdc++.so.6
            wayland           # libwayland-client.so.0, libwayland-cursor.so.0
            libx11
            libxext
            libxi
            libxrender
            libxtst
            libxkbcommon
            zlib
          ];
        in
        pkgs.stdenv.mkDerivation {
          pname = "blipnet";
          inherit version;

          src = srcs.${pkgs.stdenv.hostPlatform.system};
          sourceRoot = "blip-${version}";

          nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];

          # Native libraries needed by ELF binaries and by JNA at runtime.
          # Defined as a let-binding (nativeLibs) above so the same list can be
          # passed to both buildInputs and the wrapProgram LD_LIBRARY_PATH.
          #
          # Must be buildInputs (not runtimeDependencies): autoPatchelfHook needs
          # the .so files present inside the build sandbox to resolve and embed
          # their store paths. runtimeDependencies are propagated to consumers but
          # not admitted to the sandbox, so autoPatchelf cannot find them.
          #
          # To regenerate: run ldd across every ELF in the unpacked tarball and
          # collect the "not found" entries, then map each .so name to its nixpkgs
          # package via `nix-locate --top-level 'lib/libfoo.so'`. Libs bundled
          # inside lib/runtime/ and found via addAutoPatchelfSearchPath (see
          # postInstall) should be excluded.
          #
          #   find . -type f | while read f; do
          #     file "$f" | grep -q ELF && ldd "$f" 2>/dev/null
          #   done | grep "not found" | awk '{print $1}' | sort -u
          buildInputs = nativeLibs;

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            install -d $out/opt/blip
            cp -r bin lib $out/opt/blip/

            install -d $out/bin
            ln -s $out/opt/blip/bin/blip $out/bin/blip

            cp -r share $out/

            runHook postInstall
          '';

          # Expose the bundled JBR lib dirs to autoPatchelfHook so it can
          # resolve libjvm.so (and other JBR-internal .so files) when
          # rewriting RPATHs. Must run before the fixup phase.
          #
          # Also wrap the binary with LD_LIBRARY_PATH. autoPatchelfHook sets
          # DT_RUNPATH (not DT_RPATH) on the ELFs, and DT_RUNPATH is not
          # inherited by dlopen() calls made from loaded code. JNA (Java Native
          # Access) uses dlopen() directly to load libraries like libX11.so, so
          # it bypasses the patched RPATHs entirely. LD_LIBRARY_PATH is searched
          # by dlopen() and solves this.
          postInstall = ''
            addAutoPatchelfSearchPath "$out/opt/blip/lib/runtime/lib"
            addAutoPatchelfSearchPath "$out/opt/blip/lib/runtime/lib/server"

            wrapProgram $out/opt/blip/bin/blip \
              --set BLIP_LAUNCHER "$out/bin/blip" \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath nativeLibs}
          '';

          meta = with pkgs.lib; {
            description = "Send files to people and devices around the world";
            homepage = "https://blip.net";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" "aarch64-linux" ];
            mainProgram = "blip";
            sourceProvenance = [ sourceTypes.binaryNativeCode ];
          };
        };

      # Shared module for NixOS and home manager.
      # Allow for potential future service definitions etc.
      mkModule = installPath: { config, lib, pkgs, ... }:
        let
          cfg = config.programs.blip;
        in
        {
          options.programs.blip = {
            enable = lib.mkEnableOption "Blip";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              defaultText = lib.literalExpression "blip.packages.\${pkgs.system}.default";
              description = "The Blip package to use.";
            };
          };

          config = lib.mkIf cfg.enable (lib.setAttrByPath installPath [ cfg.package ]);
        };

      # Package is unfree.
      # Config change here does not affect the rest of the system
      pkgsFor = system: import nixpkgs { inherit system; config.allowUnfree = true; };
    in
    {
      packages.x86_64-linux.default  = mkBlip (pkgsFor "x86_64-linux");
      packages.aarch64-linux.default = mkBlip (pkgsFor "aarch64-linux");

      # NixOS: installs into environment.systemPackages.
      nixosModules.default = mkModule [ "environment" "systemPackages" ];

      # Home Manager (for non-NixOS distros): installs into home.packages.
      homeModules.default = mkModule [ "home" "packages" ];
    };
}
