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
        notion = "4.17.0";
        electron = "135";
        bettersqlite3 = "12.2.0";
        bufferutil = "4.0.9";
      };

      notionSetup = (pkgs.fetchurl {
        url = "https://desktop-release.notion-static.com/Notion%20Setup%20${versions.notion}.exe";
        hash = "sha256-5hXyUar1To5JvKYyGDSlK9QTXQkDSozG6cUe3ZTfuyU=";
      });

      bettersqlite3 = (pkgs.fetchzip {
        url = (let v = versions.bettersqlite3; in
          "https://github.com/WiseLibs/better-sqlite3/releases/download/" +
            "v${v}/better-sqlite3-v${v}-electron-v${versions.electron}-linux-x64.tar.gz"
        );
        hash = "sha256-wkGpUKkSpTj6wkwAo0Gwd8D8K46WVFM9t51g4rov0vs=";
        stripRoot = false;
      });

      bufferutil = (pkgs.fetchzip {
        url = (let v = versions.bufferutil; in
          "https://github.com/websockets/bufferutil/releases/download/" +
            "v${v}/v${v}-linux-x64.tar"
          );
        hash = "sha256-LWs2LuqI2uFuHmUWz1EyblTLNkdPIfKq6An7zjpZbyg=";
        stripRoot = false;
      });

      package = pkgs.stdenv.mkDerivation rec {
        pname = "notion-linux";
        version = versions.notion;
        src = ./.;

        buildInputs = with pkgs; [
          electron_36-bin
        ];

        nativeBuildInputs = with pkgs; [
          asar
          copyDesktopItems
          p7zip
        ];

        buildPhase = ''
          # Extract app.asar from installer
          7z x "${notionSetup}" "\$PLUGINSDIR/app-64.7z" -y -bse0 -bso0 || true
          7z x "./\$PLUGINSDIR/app-64.7z" "resources/app.asar" "resources/app.asar.unpacked" -y -bse0 -bso0 || true
          rm "./\$PLUGINSDIR/app-64.7z"

          # Extract resources from app.asar and patch
          asar e "./resources/app.asar" "./asar_patched"
          install -vDm644 "${bettersqlite3}/build/Release/better_sqlite3.node" -t "./asar_patched/node_modules/better-sqlite3/build/Release/"
          install -vDm644 "${bufferutil}/linux-x64/bufferutil.node" -t "./asar_patched/node_modules/bufferutil/build/Release/"

          # Add tray icon and right click menu
          install -vDm644 "./notion.png" "./asar_patched/.webpack/main/trayIcon.png"

          # Patches
          sed -f "./patches.sed" "./asar_patched/.webpack/main/index.js"

          # Pack
          asar p "./asar_patched" "./app.asar" --unpack '*.node'
        '';

        installPhase = ''
          mkdir -p $out/bin $out/libexec $out/share/icons/hicolor/256x256/apps
          cp notion.png $out/share/icons/hicolor/256x256/apps/notion.png
          cp app.asar $out/libexec
          cp -r app.asar.unpacked $out/libexec
          cat <<EOF > $out/bin/notion-app
          #!${pkgs.runtimeShell}

          XDG_CONFIG_HOME=\''${XDG_CONFIG_HOME:-~/.config}

          # Allow users to override command-line options
          if [[ -f \$XDG_CONFIG_HOME/notion-flags.conf ]]; then
              NOTION_USER_FLAGS="\$(grep -v '^#' \$XDG_CONFIG_HOME/notion-flags.conf)"
          fi

          exec ${pkgs.electron_36}/bin/electron $out/libexec/app.asar \$NOTION_USER_FLAGS "\$@"
          EOF

          chmod a+x $out/bin/notion-app
        '';

        desktopItems = [
          (pkgs.makeDesktopItem {
            type = "Application";
            name = "Notion";
            desktopName = "Notion";
            genericName = "Online Document Editor";
            comment = meta.description;
            exec = "notion-app %U";
            icon = "notion";
            categories = [ "Office" ];
            mimeTypes = [ "x-scheme-handler/notion" ];
            startupNotify = true;
            startupWMClass = "Notion";
            terminal = false;
          })
        ];

        meta = {
          description = "Your connected workspace for wiki, docs & projects";
          homepage = "https://notion.com/";
          license = lib.licenses.unfree;
          mainProgram = "notion-app";
          platforms = lib.platforms.linux;
        };
      };
    in {
      packages.default = package;
      devShells.default = pkgs.mkShell {
        packages = [ package ];
      };
    });
}
