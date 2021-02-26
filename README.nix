with builtins;

let

  buildCounts = {
    cached = 0;
    eval_failed = 0;
    build_failed = 0;
    build_succeeded = 0;
  } // fromJSON (readFile ./build_counts.json);

  drvCount = foldl' add 0 (attrValues buildCounts);

  buildCount = drvCount - buildCounts.eval_failed;

  percent = x: y:
    replaceStrings ["00000"] [""] "${toString (((x * 1000) / y) / 10.0)} %";

  withPercent = x: y: "${toString x} / **${percent x y}**";

in ''
  # nixpkgs-ci

  This project uses GitHub Actions and [nixbuild.net](https://nixbuild.net) to
  create something similar (but not anywhere near as featureful or useful) to
  [hydra.nixos.org](https://hydra.nixos.org/).

  The main purpose of the project is to demonstrate how
  nixbuild.net can be used to run very large number of
  Nix builds, and to serve as an inspiration for how nixbuild.net can be
  integrated into CI setups.

  ## Latest Build Results

  |Total Derivation Count|                       ${toString drvCount}|                                                     |
  |:---------------------|------------------------------------------:|----------------------------------------------------:|
  |**Failed Evaluations**|    **${toString buildCounts.eval_failed}**|      **${percent buildCounts.eval_failed drvCount}**|
  |**Attempted Builds**  |                 **${toString buildCount}**|                                                     |
  |**Failed Builds**     |   **${toString buildCounts.build_failed}**|   **${percent buildCounts.build_failed buildCount}**|
  |**Succesful Builds**  |**${toString buildCounts.build_succeeded}**|**${percent buildCounts.build_succeeded buildCount}**|
  |**Cached Builds**     |         **${toString buildCounts.cached}**|         **${percent buildCounts.cached buildCount}**|
''
