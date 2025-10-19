{
  description = "Cross-platform dependency build environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          grpc = pkgs.callPackage ./nix/pkgs/grpc.nix { } {
            version = "1.56.0"; # Change as needed
          };
        };
        formatter = nixpkgs.legacyPackages.${system}.nixfmt-tree;
      }
    );
}
