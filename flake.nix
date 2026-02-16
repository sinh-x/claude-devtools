{
  description = "claude-devtools - Electron app that visualizes Claude Code sessions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Nix-provided Electron binary (avoids FHS/NixOS binary issues)
        electron = pkgs.electron_40;

        # Wrapper that adds NixOS-required flags (sandbox + GPU subprocess fixes)
        electronWrapper = pkgs.writeShellScriptBin "electron" ''
          exec ${electron}/libexec/electron/electron \
            --no-sandbox \
            --disable-gpu-sandbox \
            "$@"
        '';

        # Electron runtime libraries (Linux only)
        electronLibs = with pkgs; [
          libx11
          libxext
          libxrandr
          libxcomposite
          libxcursor
          libxdamage
          libxfixes
          libxi
          libxrender
          libxtst
          libxcb
          libxshmfence
          libdrm
          mesa
          nss
          nspr
          alsa-lib
          at-spi2-atk
          atk
          cups
          dbus
          expat
          glib
          gtk3
          pango
          cairo
          libxkbcommon
        ];

        # Dev helper scripts
        cd-dev = pkgs.writeShellScriptBin "cd-dev" ''
          echo "Starting dev server with hot reload..."
          pnpm dev
        '';

        cd-build = pkgs.writeShellScriptBin "cd-build" ''
          echo "Building production bundle..."
          pnpm build
        '';

        cd-test = pkgs.writeShellScriptBin "cd-test" ''
          echo "Running tests..."
          pnpm test
        '';

        cd-test-watch = pkgs.writeShellScriptBin "cd-test-watch" ''
          echo "Running tests in watch mode..."
          pnpm test:watch
        '';

        cd-check = pkgs.writeShellScriptBin "cd-check" ''
          echo "Running full quality check (typecheck + lint + test + build)..."
          pnpm check
        '';

        cd-fix = pkgs.writeShellScriptBin "cd-fix" ''
          echo "Auto-fixing lint and formatting..."
          pnpm fix
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          name = "claude-devtools-env";

          buildInputs = with pkgs; [
            # Core toolchain
            nodejs_22
            pnpm
            git
            gh

            # Electron from Nix (used via ELECTRON_OVERRIDE_DIST_PATH)
            electron

            # Native build dependencies
            gcc
            gnumake
            pkg-config
            python3

            # Dev commands
            cd-dev
            cd-build
            cd-test
            cd-test-watch
            cd-check
            cd-fix
          ] ++ electronLibs;

          # Tell electron-vite and Electron tooling to use Nix-provided binary
          # electronWrapper adds --no-sandbox which is required on NixOS
          ELECTRON_OVERRIDE_DIST_PATH = "${electron}/libexec/electron";
          ELECTRON_EXEC_PATH = "${electronWrapper}/bin/electron";

          # NixOS requires --no-sandbox for Electron (SUID sandbox incompatible)
          ELECTRON_DISABLE_SANDBOX = "1";

          shellHook = ''
            # Electron --no-sandbox flag for NixOS compatibility
            export ELECTRON_NO_SANDBOX=1

            echo ""
            echo "  claude-devtools dev shell"
            echo "  ────────────────────────────────"
            echo "  Node:     $(node --version)"
            echo "  pnpm:     $(pnpm --version)"
            echo "  Electron: ${electron.version}"
            echo ""
            echo "  Commands:"
            echo "    cd-dev         Start dev server with hot reload"
            echo "    cd-build       Production build"
            echo "    cd-test        Run all tests"
            echo "    cd-test-watch  Tests in watch mode"
            echo "    cd-check       Full quality check"
            echo "    cd-fix         Auto-fix lint + formatting"
            echo ""
          '';

          # Electron needs this to find shared libraries on Linux
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath electronLibs;
        };
      });
}
