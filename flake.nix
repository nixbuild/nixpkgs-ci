{
  inputs = {
    nixpkgs.url = "nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:

    with nixpkgs.lib;
    with builtins;

    let

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

      evalErr = name: [ { inherit name; drvpath = null; } ];

      recurseEvalDrvs = system: name: attrs:
        if !(isAttrs attrs) || elem name removed then evalErr name
        else if isDerivation attrs
        then [
          { inherit name;
            drvpath = evalOr null attrs.drvPath id;
          }
        ] else concatLists (
          mapAttrsToList (k: v: let name' = "${name}.${k}"; in
            evalOr (evalErr name') v (recurseEvalDrvs system name')
          ) attrs
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

          drvs="$(mktemp)"

          while true; do
            > "$drvs"
            for i in $(seq 1 $concurrent_drvs); do
              read drv && echo "$drv" >> "$drvs"
            done

            test -s "$drvs" || break

            xargs -d '\n' -n 1 -P 0 build-drv < "$drvs"

            gc_if_needed
          done
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
              if nix build --no-link "$drvpath" &> "$log"; then
                print_status built
                nix log "$drvpath" >> "$log" || true
              else
                print_status fail-build
                nix log "$drvpath" >> "$log" || true
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
