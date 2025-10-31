## gRPC

Build instructions can be found [here](https://github.com/grpc/grpc/blob/master/BUILDING.md) for both windows and linux.

### Windows

#### Prerequisites

- Git
- CMake
- Visual Studio 2022
- Ninja (much faster to compile using ninja than VS build system)
- nasm
  - Can be installed via the chocolately package manager: `choco install nasm`
- 7zip (needed because package size is greater than what Compress-Archive can handle)
  - Can be installed via the chocolately package manager: `choco install 7zip`

#### Building

Build by running:

`./build-windows.ps1 -Version v1.76.0 -BuildRootDir ../.build -InstallRootDir ../.install -PackageRootDir ../.package`

### Linux

#### Prerequisites

- Git
- CMake
- GCC
- tar
- Ninja (much faster to compile using ninja than VS build system)

#### Building

Build by running:

`./build-linux.sh -v v1.76.0 -b ../.build -i ../.install -p ../.package`