{
  inputs = {
    nixpkgs.url = "nixpkgs/master";

    flake-utils.url = "github:numtide/flake-utils";

    nix-build-uncached = {
      url = "github:Mic92/nix-build-uncached";
      flake = false;
    };
  };

  outputs = {
    self, nixpkgs, flake-utils, nix-build-uncached
  }:

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

        nix-build-uncached = import nix-build-uncached {
          inherit pkgs;
        };

        build-drv = pkgs.writeShellScriptBin "build-drv" ''
          set -euo pipefail

          PATH="${makeBinPath (with pkgs; [
            self.packages.x86_64-linux.nix-build-uncached
          ])}:$PATH"

          mkdir -p logs

          drv="$1"
          name="$(jq -r .name <<<"$drv")"
          drvpath="$(jq -r .drvpath <<<"$drv")"
          log="logs/$name.log"

          function status() {
            jq -nc --arg status "$1" --argjson drv "$drv" '$drv + { status: $status }'
          }

          if [ "$drvpath" = "null" ]; then
            status fail-eval
          else
            if nix-build-uncached -build-flags "-o res-$name" "$drvpath" &> "$log"; then
              set -- "res-$name"*
              if [ -h "$1" ]; then
                status built
                nix log "$drvpath" >> "$log" || true
                rm "res-$name"*
              else
                status cached
              fi
            else
              status fail-build
              nix log "$drvpath" >> "$log" || true
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
