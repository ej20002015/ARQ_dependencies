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
        grpc = pkgs.callPackage ./nix/pkgs/grpc.nix { };
      in
      {
        packages = {
          grpc-linux-release = grpc { platform = "linux"; buildType = "Release"; };
          grpc-linux-debug = grpc { platform = "linux"; buildType = "Debug"; };
          grpc-windows-release = grpc { platform = "windows"; buildType = "Release"; };
          grpc-windows-debug = grpc { platform = "windows"; buildType = "Debug"; };
        };
        formatter = nixpkgs.legacyPackages.${system}.nixfmt-tree;
      }
    );
}
