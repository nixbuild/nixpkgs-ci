{
  inputs = {
    nixpkgs.url = "nixpkgs/master";
  };

  outputs = { self, nixpkgs }:

    let

      inherit (nixpkgs.lib) concatLists mapAttrsToList isDerivation;
      inherit (builtins) elem isAttrs tryEval length;

      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      evalOr = def: x: f: let try = tryEval x; in
        if try.success then f try.value else def;

      # No amount of tryEval usage seems to get around the eval errors for these
      removed = [
        "lispPackages.cl-async-ssl"
        "lispPackages.wookie"
        "unstable"
        "lib-tests"
        "tarball"
      ];

      recurseEvalDrvs = system: name: attrs:
        if !(evalOr false attrs isAttrs) || elem name removed then [
          { inherit name;
            drvpath = null;
          }
        ] else if isDerivation attrs then [
          { inherit name;
            drvpath = attrs.drvPath;
          }
        ] else concatLists (
          mapAttrsToList (k: recurseEvalDrvs system "${name}.${k}") attrs
        );

      jobs = import (nixpkgs + "/pkgs/top-level/release.nix") {
        inherit nixpkgs;
        supportedSystems = [ "x86_64-linux" ];
        nixpkgsArgs = {
          config = { allowUnfree = false; inHydra = true; };
          overlays = [
            (self: super: super.prefer-remote-fetch self super)
          ];
        };
      };

    in {

      packages.x86_64-linux = rec {

        build-drvs = pkgs.writeShellScriptBin "build-drvs" ''
          set -euo pipefail

          concurrent_drvs="$1"
          PATH="${build-drv}/bin:$PATH"

          function gc_if_needed() {
            local pcent="$(df --output=pcent /nix/store | tail -n1 | tr -d ' %')"
            local used="$(df -B1 --output=used /nix/store | tail -n1 | tr -d ' ')"
            local total="$(df -B1 --output=size /nix/store | tail -n1 | tr -d ' ')"

            if ((pcent > 90)); then
              nix-collect-garbage --max-freed $((used - total / 2)) || true
            fi
          }

          # Run garbage collector every two minutes in the background to make
          # sure we don't run out of disk space
          while true; do
            gc_if_needed || true
            sleep 120
          done &
          gc_loop=$!

          function cleanup() {
            kill $gc_loop
          }

          trap cleanup EXIT

          xargs -d '\n' -n 1 -P $concurrent_drvs build-drv
        '';

        build-drv = pkgs.writeShellScriptBin "build-drv" ''
          set -euo pipefail

          drv="$1"
          name="$(jq -r .name <<<"$drv")"
          drvpath="$(jq -r .drvpath <<<"$drv")"
          log="logs/$name.log"

          function print_status() {
            jq -nc --arg status "$1" --argjson drv "$drv" '$drv + { status: $status }'
          }

          function will_build() {
            nix build --dry-run "$drvpath" 2>&1 | grep -q "will be built"
          }

          mkdir -p logs

          if [ "$drvpath" = "null" ]; then
            print_status fail-eval
          else
            if will_build; then
              if nix build -L --no-link "$drvpath" &> "$log"; then
                print_status built
              else
                print_status fail-build
              fi
            else
              print_status cached
            fi
          fi
        '';
      };

      derivations = concatLists (
        mapAttrsToList (name: job: recurseEvalDrvs "x86_64-linux" name job) jobs
      );
    };
}
