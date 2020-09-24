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

      withEval = def: x: f: let try = tryEval x; in
        if try.success then f try.value else def;

      removed = [
        "lispPackages.cl-async-ssl"
        "lispPackages.wookie"
      ];

      evalErr = name: [ { inherit name; drvpath = null; } ];

      recurseEvalDrvs = system: name: attrs:
        if !(isAttrs attrs) || elem name removed then evalErr name
        else if isDerivation attrs
        then singleton {
          inherit name;
          drvpath = withEval null attrs.drvPath id;
        } else concatLists (
          mapAttrsToList (k: v: let name' = "${name}.${k}"; in
            withEval (evalErr name') v (recurseEvalDrvs system name')
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

      packages.x86_64-linux = {

        build-drv = pkgs.writeShellScriptBin "build-drv" ''
          set -euo pipefail

          mkdir -p logs

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

      jobSubset = groupCount: groupIdx:
        let
          allNames = attrNames jobs;
          totalJobCount = length allNames;
          jobsPerGroup = totalJobCount / groupCount;
          jobCount =
            if groupIdx >= (groupCount - 1) then totalJobCount else jobsPerGroup;
          jobIdx = groupIdx * jobsPerGroup;
        in concatMap (name:
          recurseEvalDrvs "x86_64-linux" name jobs.${name}
        ) (sublist jobIdx jobCount allNames);

    };
}
