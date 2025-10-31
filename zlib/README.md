## zlib

### Windows

#### Prerequisites

- Git
- Visual Studio 2022
- 7zip
  - Can be installed via the chocolately package manager: `choco install 7zip`
- (Opt) vcpkg
  - Either specify the path to vcpkg in the command below using the `-VcpkgRootDir` argument, or omit it and the script will automatically install vcpkg locally

#### Running

(install vcpkg), install zlib and create zip by running:

`./build-windows.ps1 -InstallRootDir ../.install -PackageRootDir ../.package`

### Linux

#### Running

Install and create tarball package by running:

