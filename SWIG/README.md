## SWIG

Create zipped packages for the SWIG executable and toolset

### Windows

#### Running

Build, install and create SWIG zip by running:

`./build-windows.ps1 -Version 4.3.1 -BuildRootDir ../.build -InstallRootDir ../.install -PackageRootDir ../.package`

### Linux

**NOTE:** The linux build does not include the PCRE2 library. As such, the regular expression functionality that SWIG offers should not be used as it won't work on Linux!

#### Running

Build, install and create SWIG tarball by running:

`./build-linux.sh -v 4.3.1 -b ../.build -i ../.install -p ../.package`