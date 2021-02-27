# nixpkgs-ci

This project uses GitHub Actions and [nixbuild.net](https://nixbuild.net) to
create something similar (but not anywhere near as featureful or useful) to
[hydra.nixos.org](https://hydra.nixos.org/).

The main purpose of the project is to demonstrate how
nixbuild.net can be used to run very large number of
Nix builds, and to serve as an inspiration for how nixbuild.net can be
integrated into CI setups.

## Latest Build Results

|Total Derivation Count|                       42805|                                                     |
|:---------------------|------------------------------------------:|----------------------------------------------------:|
|**Failed Evaluations**|    **3243**|      **7.5 %**|
|**Attempted Builds**  |                 **39562**|                                                     |
|**Failed Builds**     |   **1949**|   **4.9 %**|
|**Succesful Builds**  |**770**|**1.9 %**|
|**Cached Builds**     |         **36843**|         **93.1 %**|
