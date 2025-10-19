{ lib, callPackage }:
{
  version ? "1.74.1",
}:
rec {
  linux-debug = callPackage ./grpc-linux.nix { } {
    inherit version;
    buildType = "Debug";
  };
  linux-release = callPackage ./grpc-linux.nix { } {
    inherit version;
    buildType = "Release";
  };
  windows-debug = callPackage ./grpc-windows.nix { } {
    inherit version;
    buildType = "Debug";
  };
  windows-release = callPackage ./grpc-windows.nix { } {
    inherit version;
    buildType = "Release";
  };
}
