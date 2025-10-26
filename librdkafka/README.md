## gRPC

### Windows

librdkafka windows build instructions can be found [here](https://github.com/confluentinc/librdkafka/tree/master/win32) and [here](https://github.com/confluentinc/librdkafka/blob/master/README.win32)

#### Prerequisites

- Git
- Visual Studio 2022
- CMake

#### Running

Build, install and create zip by running:

`./build-windows.ps1 -Version v2.12.0 -InstallRootDir ../.install -PackageRootDir ../.package`