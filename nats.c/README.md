## nats.c

****NOTE:**** YOU MUST ensure that the version of openssl that nats.c builds against is the same version as we distribute as part of ARQ_dependencies

Build instructions can be found [here](https://github.com/nats-io/nats.c?tab=readme-ov-file#building)

### Windows

#### Prerequisites

- Git
- CMake
- Visual Studio 2022

#### Building

Build by running:

`./build-windows.ps1 -Version v3.11.0 -BuildRootDir ../.build -InstallRootDir ../.install -PackageRootDir ../.package`