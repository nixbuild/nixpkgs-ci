# nixpkgs-ci

This project uses GitHub Actions and [nixbuild.net](https://nixbuild.net) to
create something similar (but not anywhere near as featureful or useful) to
[hydra.nixos.org](https://hydra.nixos.org/).

The main purpose of the project is to demonstrate how
nixbuild.net can be used to run very large number of
Nix builds, and to serve as an inspiration for how nixbuild.net can be
integrated into CI setups.

## Latest Build Results

|Total Derivation Count|                       42655|                                                     |
|:---------------------|------------------------------------------:|----------------------------------------------------:|
|**Failed Evaluations**|    **3394**|      **7.9 %**|
|**Attempted Builds**  |                 **39261**|                                                     |
|**Failed Builds**     |   **862**|   **2.1 %**|
|**Succesful Builds**  |**169**|**0.4 %**|
|**Cached Builds**     |         **38230**|         **97.3 %**|
