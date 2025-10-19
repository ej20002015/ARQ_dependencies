# gRPC Build Environment with Nix

This document describes how to use the Nix flake for building gRPC. The environment is designed to work natively on both Linux and Windows, building packages for the platform you're running on.

## Directory Structure

```
/nix
  /pkgs            # Package definitions
    grpc-base.nix  # Common base implementation
    grpc-linux.nix # Linux-specific implementation
    grpc-windows.nix # Windows-specific implementation
    grpc.nix       # Unified module exposing all variants
flake.nix          # Main flake file
```

## Prerequisites

Install Nix.

Use the [Determinate Nix installer](https://zero-to-nix.com/start/install/) (reccomended),
or the upstream:

- [Nix package manager](https://nixos.org/download.html) with flakes enabled
- Add to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`:
  ```
  experimental-features = nix-command flakes
  ```

## Using the Flake

### Building gRPC

The flake exposes a `grpc` module with various build variants. You can build different variants using:

```bash
# Build the default variant (based on current platform)
nix build

# Access specific variants using the grpc module
nix build .#grpc.linux-debug
nix build .#grpc.linux-release
nix build .#grpc.windows-debug
nix build .#grpc.windows-release
```

For custom version or build configuration:

```bash
# Using the getGrpc function with custom parameters
nix build --expr '(builtins.getFlake "/path/to/repo").packages.x86_64-linux.grpc.getGrpc { version = "1.57.0"; platform = "linux"; buildType = "Debug"; }'
```

The output will be in `./result/dist/` with the appropriate archive:
- Linux: `grpc-<version>-linux-<buildType>.tar.gz`
- Windows: `grpc-<version>-windows-<buildType>.zip`

## Customizing the Build

### Changing gRPC Version

To change the gRPC version:

1. Update the `grpcVersion` variable in `flake.nix` to your desired version
2. Run the build once - it will fail with a hash error message that looks like:
   ```
   error: hash mismatch in fixed-output derivation '/nix/store/...-source':
     wanted: sha256-oldHashValue
     got:    sha256-newVersionsHashValue
   ```
3. Copy the "got" hash value from the error message
4. Update the `hash` value in `./nix/pkgs/grpc-base.nix`
5. Run the build again, and it should succeed

## Adding Other Dependencies

To add more dependencies:

1. Create a similar layered structure in `/nix/pkgs/`
   - Base implementation for common code
   - Platform-specific implementations
   - Unified module exposing variants
2. Update `flake.nix` to include the new packages

## Notes for Windows Users

If using Windows, you'll need to have the appropriate Visual Studio build tools installed. The Windows build is configured for Visual Studio 2022.