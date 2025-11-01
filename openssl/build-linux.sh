#!/bin/bash
#
# This script builds both Debug and Release configurations of OpenSSL
# from source and assembles them into a single, config-aware package for Linux.

# --- Error Handling ---
set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error
set -o pipefail # Fail if any command in a pipe fails

# --- ANSI Color Codes ---
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[0;31m'
RESET='\033[0m'

# --- Usage Function ---
usage() {
    echo "Usage: $0 -v <version> -b <build_root> -i <install_root> -p <package_root>"
    echo
    echo "  -v    Version of OpenSSL to build, e.g., '3.3.0'"
    echo "  -b    Root directory for build outputs (downloading/compiling)"
    echo "  -i    Root directory for the final package structure"
    echo "  -p    Root directory for the final .tar.gz package"
    exit 1
}

# --- Parse Script Parameters ---
while getopts "v:b:i:p:" opt; do
  case $opt in
    v) Version="$OPTARG" ;;
    b) BuildRootDir="$OPTARG" ;;
    i) InstallRootDir="$OPTARG" ;;
    p) PackageRootDir="$OPTARG" ;;
    *) usage ;;
  esac
done

# Check if all mandatory parameters are set
if [ -z "${Version-}" ] || [ -z "${BuildRootDir-}" ] || [ -z "${InstallRootDir-}" ] || [ -z "${PackageRootDir-}" ]; then
    echo -e "${RED}Error: All parameters (-v, -b, -i, -p) are mandatory.${RESET}"
    usage
fi

# --- Check for Dependencies ---
for cmd in git wget tar make gcc; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: Required command '$cmd' is not found. Please install it.${RESET}"
        exit 1
    fi
done

# --- Configuration ---
scriptDir=$(dirname "$(realpath "$0")")
sourceDirName="openssl-$Version"
baseName="openssl-$Version-linux-x64"
cmakeModule="openssl.cmake" # Assumes this file is in the script's directory
tarballName="openssl-$Version.tar.gz"

# Absolute paths for safety
buildDirAbs=$(realpath "$BuildRootDir")
installDirAbs=$(realpath "$InstallRootDir")
packageDirAbs=$(realpath "$PackageRootDir")

# Build directories
sourceDir="$buildDirAbs/$sourceDirName"
tarballPath="$buildDirAbs/$tarballName"

# Temporary install directories
tempInstallDirDebug="$buildDirAbs/install_debug"
tempInstallDirRelease="$buildDirAbs/install_release"

# Final package layout path
installDir="$installDirAbs/$baseName"
packagePath="$packageDirAbs/$baseName.tar.gz"

# Get number of CPU cores for parallel make
if command -v nproc &> /dev/null; then
    MAKE_JOBS=$(nproc)
else
    MAKE_JOBS=4 # Default to 4
fi

# --- 1. Download OpenSSL ---
echo -e "${YELLOW}--- Creating BuildRootDir: $buildDirAbs ---${RESET}"
mkdir -p "$buildDirAbs"

if [ -f "$tarballPath" ]; then
    echo -e "${YELLOW}--- Skipping OpenSSL download, using existing tarball ---${RESET}"
else
    echo -e "${YELLOW}--- Downloading OpenSSL $Version ---${RESET}"
    wget -O "$tarballPath" "https://www.openssl.org/source/$tarballName"
fi

# --- 2. Extract ---
echo -e "${YELLOW}--- Extracting OpenSSL source ---${RESET}"
if [ -d "$sourceDir" ]; then
    echo "--- Cleaning existing source directory ---"
    rm -rf "$sourceDir"
fi
tar -xzf "$tarballPath" -C "$buildDirAbs"
cd "$sourceDir"

# --- 3. Build and Install (Release) ---
echo -e "${YELLOW}--- Configuring OpenSSL (Release)... ---${RESET}"
mkdir -p "$tempInstallDirRelease"
# 'shared' builds .so files, 'no-tests' speeds up the build
./config --prefix="$tempInstallDirRelease" --release no-tests
echo -e "${YELLOW}--- Building and Installing OpenSSL (Release)... ---${RESET}"
make -j$MAKE_JOBS
make install_sw # 'install_sw' installs software only (no man pages)

# --- 4. Build and Install (Debug) ---
echo -e "${YELLOW}--- Configuring OpenSSL (Debug)... ---${RESET}"
make clean # Clean the previous release build
mkdir -p "$tempInstallDirDebug"
# 'enable-debug' adds debug symbols, 'shared' builds .so
./config --prefix="$tempInstallDirDebug" --debug no-tests
echo -e "${YELLOW}--- Building and Installing OpenSSL (Debug)... ---${RESET}"
make -j$MAKE_JOBS
make install_sw

cd "$scriptDir" # Go back to original directory

# --- 5. Create Install Directory Structure ---
echo -e "${YELLOW}\n--- Assembling unified package: $installDir ---${RESET}"
if [ -d "$installDir" ]; then
    echo "--- Cleaning existing install directory: $installDir ---"
    rm -rf "$installDir"
fi
mkdir -p "$installDir/include"
mkdir -p "$installDir/cmake"
mkdir -p "$installDir/debug/lib"
mkdir -p "$installDir/release/lib"
# Note: On Linux, .so files (binaries) and .a files (static) are all kept in lib/

# --- 6. Copy Header, cmake, and Lib Files ---
echo -e "${YELLOW}--- Copying include and cmake files... ---${RESET}"
# Headers are the same, copy from release temp install
cp -r "$tempInstallDirRelease/include/"* "$installDir/include/"

cmakeModulePath="$scriptDir/$cmakeModule"
if [ ! -f "$cmakeModulePath" ]; then
    echo -e "${RED}Error: Could not find '$cmakeModule'. Make sure it's in the same directory as this script.${RESET}"
    exit 1
fi
cp "$cmakeModulePath" "$installDir/cmake/openssl.cmake"

# --- Copy Debug Libraries ---
# Find the actual lib directory (could be 'lib' or 'lib64')
debugLibDir=$(find "$tempInstallDirDebug" -maxdepth 1 -type d -name "lib*")
if [ -z "$debugLibDir" ]; then echo -e "${RED}Could not find Debug lib directory in $tempInstallDirDebug${RESET}"; exit 1; fi
echo "--- Copying Debug libraries from $debugLibDir... ---"
# Copy all .so files (and their symlinks) and .a files
cp -Pdp "$debugLibDir"/*.so* "$installDir/debug/lib/"
cp -Pdp "$debugLibDir"/*.a "$installDir/debug/lib/"

# --- Copy Release Libraries ---
releaseLibDir=$(find "$tempInstallDirRelease" -maxdepth 1 -type d -name "lib*")
if [ -z "$releaseLibDir" ]; then echo -e "${RED}Could not find Release lib directory in $tempInstallDirRelease${RESET}"; exit 1; fi
echo "--- Copying Release libraries from $releaseLibDir... ---"
# Copy all .so files (and their symlinks) and .a files
cp -Pdp "$releaseLibDir"/*.so* "$installDir/release/lib/"
cp -Pdp "$releaseLibDir"/*.a "$installDir/release/lib/"

# --- 7. Packaging Step ---
echo -e "${YELLOW}\n--- Creating PackageRootDir: $packageDirAbs ---${RESET}"
mkdir -p "$packageDirAbs"

echo -e "${YELLOW}\n--- Creating the OpenSSL distributable package... ---${RESET}"
# -C changes directory *before* tarring, so the tarball has $baseName as the root folder
tar -czf "$packagePath" -C "$installDirAbs" "$baseName"

# --- Optional Cleanup ---
echo -e "${YELLOW}\n--- Cleaning up temporary build directories ---${RESET}"
rm -rf "$tempInstallDirDebug"
rm -rf "$tempInstallDirRelease"
# rm -rf "$sourceDir" # Uncomment to clean up source too

echo -e "${GREEN}\n--- OpenSSL Build Complete! ---${RESET}"
echo -e "${GREEN}Package ready for upload: $packagePath${RESET}"
