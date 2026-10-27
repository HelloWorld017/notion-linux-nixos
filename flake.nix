{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    systems = {
      url = "github:nix-systems/default-linux";
    };
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.${system};
      versions = {
        notion = "7.41.0";
        electron = "43";
        bettersqlite3 = "13.0.1";
        bufferutil = "4.0.9";
        pipewire = "1.1.0";
      };
      electron = pkgs."electron_${versions.electron}-bin";

      notionSetup = (pkgs.fetchurl {
        url = "https://desktop-release.notion-static.com/Notion%20Setup%20${versions.notion}.exe";
        sha256 = "23e9b0f45c30e302dad47c8ea6620eb3d49aff5dcc23a1f90f50c357e4508e97";
      });

      bettersqlite3 = (pkgs.fetchurl {
        url = "https://registry.npmjs.org/better-sqlite3/-/better-sqlite3-${versions.bettersqlite3}.tgz";
        sha256 = "92935ff8280f933aff78f87e04eb718a21af003aec4e5bd0076f287aa1709da4";
      });

      nodePipewire = pkgs.fetchurl {
        url = "https://registry.npmjs.org/node-pipewire/-/node-pipewire-${versions.pipewire}.tgz";
        sha256 = "ed7425c2f287df8e192656f89b5c6645f67837aaaba64692e493dc8e8e0d55fe";
      };

      nodePipewireNative = pkgs.fetchurl {
        url = "https://github.com/kakxem/node-pipewire/releases/download/${versions.pipewire}/napi-v6-linux-x64.tar.gz";
        sha256 = "ec6ea34a3c1ce1cf71bd1c88fe70eb11f26330d33a44e7051f2b37a53e008200";
      };

      bufferutil = (pkgs.fetchzip {
        url = (let v = versions.bufferutil; in
          "https://github.com/websockets/bufferutil/releases/download/" +
            "v${v}/v${v}-linux-x64.tar"
          );
        hash = "sha256-LWs2LuqI2uFuHmUWz1EyblTLNkdPIfKq6An7zjpZbyg=";
        stripRoot = false;
      });

      package = pkgs.stdenv.mkDerivation {
        pname = "notion-linux-nixos";
        version = versions.notion;
        src = ./.;

        buildInputs = with pkgs; [
          pipewire
          stdenv.cc.cc.lib
        ];

        nativeBuildInputs = with pkgs; [
          asar
          ast-grep
          autoPatchelfHook
          copyDesktopItems
          makeWrapper
          p7zip
        ];

        buildPhase = ''
          runHook preBuild

          # Extract app.asar from installer
          7z x "${notionSetup}" "\$PLUGINSDIR/app-64.7z" -y -bse0 -bso0 || true
          7z x "./\$PLUGINSDIR/app-64.7z" "resources/app.asar" "resources/app.asar.unpacked" -y -bse0 -bso0 || true
          rm "./\$PLUGINSDIR/app-64.7z"

          # Extract resources from app.asar and patch
          asar e "./resources/app.asar" "./asar_patched"
          tar -xOf "${bettersqlite3}" package/prebuilds/linux-x64.node \
            > ./asar_patched/node_modules/better-sqlite3/build/Release/better_sqlite3.node
          install -vDm644 "${bufferutil}/linux-x64/bufferutil.node" -t "./asar_patched/node_modules/bufferutil/build/Release/"

          # Remove native modules that cannot load on Linux.
          rm -f \
            ./asar_patched/.webpack/main/native_modules/build/Release/winregistry.node \
            ./asar_patched/.webpack/main/native_modules/adjust_get_current_system_volume_vista_plus.exe \
            ./asar_patched/node_modules/@notionhq/desktop-native/build/Release/win_utils.node \
            ./asar_patched/node_modules/better-sqlite3/build/Release/test_extension.node \
            ./asar_patched/node_modules/@jasonscheirer/native-progress-bar/build/Release/progress_bar.node
          rm -rf ./asar_patched/node_modules/cf-prefs ./asar_patched/node_modules/node-mac-window

          # Supply the Linux audio detection implementation.
          pipewire_dir=./asar_patched/node_modules/node-pipewire
          mkdir -p "$pipewire_dir/dist/binding/napi-v6"
          tar -xf "${nodePipewire}" -C "$pipewire_dir" --strip-components=1 \
            package/package.json package/LICENSE package/dist/index.js
          tar -xOf "${nodePipewireNative}" napi-v6/index.node \
            > "$pipewire_dir/dist/binding/napi-v6/index.node"

          # Add tray icon and right click menu
          install -vDm644 "./notion.png" "./asar_patched/.webpack/main/trayIcon.png"

          # Patches
          source ./patches.sh

          # Pack
          asar p "./asar_patched" "./app.asar" --unpack '*.node'

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin $out/share/notion-linux $out/share/icons/hicolor/256x256/apps
          cp notion.png $out/share/icons/hicolor/256x256/apps/notion.png
          cp app.asar $out/share/notion-linux
          cp -r app.asar.unpacked $out/share/notion-linux
          cp ./asar_patched/package.json $out/share/notion-linux
          makeWrapper '${lib.getExe electron}' "$out/bin/notion-linux" \
            --add-flags "$out/share/notion-linux/app.asar" \
            --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
            --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
            --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ] }" \
            --inherit-argv0

          runHook postInstall
        '';

        desktopItems = [
          (pkgs.makeDesktopItem {
            type = "Application";
            name = "notion-linux";
            desktopName = "Notion Linux";
            genericName = "Online Document Editor";
            comment = "Your connected workspace for wiki, docs & projects";
            exec = "notion-linux %U";
            icon = "notion";
            categories = [ "Office" ];
            mimeTypes = [ "x-scheme-handler/notion" ];
            startupNotify = true;
            startupWMClass = "Notion";
            terminal = false;
          })
        ];

        meta.platforms = [ "x86_64-linux" ];
      };
    in {
      packages.default = package;
      devShells.default = pkgs.mkShell {
        packages = [ package ];
      };
    });
}
