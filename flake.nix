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

      withEval = x: f: let try = tryEval x; in
        if try.success then f try.value else null;

      drvPathOrNull = system: x: withEval x (attrs:
        if isAttrs attrs && hasAttr system attrs
        then withEval (x.${system}) (drv:
          if isDerivation drv then withEval drv.drvPath id else null
        ) else null
      );

      release = import (nixpkgs + "/pkgs/top-level/release.nix") {
        inherit nixpkgs;
        supportedSystems = [ "x86_64-linux" ];
        nixpkgsArgs = {
          config = { allowUnfree = false; inHydra = true; };
          overlays = [
            (self: super: super.prefer-remote-fetch self super)
          ];
        };
      };

      allJobs = mapAttrsToList (name: drv: {
        inherit name;
        drvpath = drvPathOrNull "x86_64-linux" drv;
      }) release;

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

      jobs = groupCount: groupIdx:
        let
          totalJobCount = length allJobs;
          jobsPerGroup = totalJobCount / groupCount;
          jobCount =
            if groupIdx >= (groupCount - 1) then totalJobCount else jobsPerGroup;
          jobIdx = groupIdx * jobsPerGroup;
        in sublist jobIdx jobCount allJobs;

    };
}
