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
          if isDerivation drv then withEval drv.drvPath (x: x) else null
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

    in {

      packages.x86_64-linux = {

        nix-build-uncached = import nix-build-uncached {
          inherit pkgs;
        };

        build-drv = pkgs.writeShellScriptBin "build-drv" ''
          PATH="${makeBinPath (with pkgs; [
            coreutils nix self.packages.x86_64-linux.nix-build-uncached
          ])}"

          mkdir -p logs

          if nix-build-uncached -build-flags "--no-link" "$2" &> "logs/$1.log"; then
            mv "logs/$1.log" "logs/pass-$1.log"
            echo >&2 "PASS: $1"
          else
            mv "logs/$1.log" "logs/fail-$1.log"
            echo >&2 "FAIL: $1"
          fi
        '';

      };

      jobs = mapAttrs (_: drvPathOrNull "x86_64-linux") release;

    };
}
