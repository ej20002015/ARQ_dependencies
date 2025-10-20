# ARQ_dependencies
Contains nix pkgs for building dependencies for the ARQ trading system. Published releases contain pre-built binaries used by the main ARQ repo.

## Prerequisites

Install Nix.

Use the [Determinate Nix installer](https://zero-to-nix.com/start/install/) (reccomended)

...or the upstream [Nix package manager](https://nixos.org/download.html) with flakes enabled (e.g. Add to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`):
  ```
  experimental-features = nix-command flakes
  ```

## Building

The flake exposes a `grpc` module with various build variants. You can build different variants using:

```bash
nix build .#grpc.linux-debug
nix build .#grpc.linux-release
nix build .#grpc.windows-debug
nix build .#grpc.windows-release
```

The output will be in `./result/dist/` with the appropriate archive:
- Linux: `grpc-<version>-linux-<buildType>.tar.gz`
- Windows: `grpc-<version>-windows-<buildType>.zip`