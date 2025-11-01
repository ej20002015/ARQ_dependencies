#!/bin/bash
#
# This script builds both Debug and Release configurations of librdkafka
# from source and assembles them into a single, config-aware package.

# --- Error Handling ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error
set -u
# Fail if any command in a pipe fails
set -o pipefail

# --- ANSI Color Codes ---
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[0;31m'
RESET='\033[0m'

# --- Usage Function ---
usage() {
    echo "Usage: $0 -v <version> -b <build_root> -i <install_root> -p <package_root>"
    echo
    echo "  -v    Version of librdkafka, e.g., 'v2.12.0'"
    echo "  -b    Root directory for build outputs (compiling, temp installs)"
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
sourceDir="librdkafka"
baseName="librdkafka-$Version-linux-x64"
cmakeModule="librdkafka.cmake" # Assumes this file is in the script's directory

# Absolute paths for safety
buildDirAbs=$(realpath "$BuildRootDir")
installDirAbs=$(realpath "$InstallRootDir")
packageDirAbs=$(realpath "$PackageRootDir")

# Path for the final, clean package structure
installDir="$installDirAbs/$baseName"
packagePath="$packageDirAbs/$baseName.tar.gz"

# Temporary install directories
tempInstallRelease="$buildDirAbs/temp-install-release"
tempInstallDebug="$buildDirAbs/temp-install-debug"
sourceDirFull="$buildDirAbs/$sourceDir"


# --- Clone librdkafka Source Code ---
if [ -d "$sourceDirFull" ]; then
    echo -e "${YELLOW}--- Skipping git clone, using existing source directory ---${RESET}"
else
    echo -e "${YELLOW}--- Cloning librdkafka repository ---${RESET}"
    git clone -b "$Version" https://github.com/confluentinc/librdkafka.git "$sourceDirFull"
fi

# --- Build Steps ---
MAKE_JOBS=8

cd "$sourceDirFull"

# --- Build Release ---
echo -e "${YELLOW}--- Building librdkafka (Release)... ---${RESET}"
# Clean any previous build artifacts
git clean -fdx
mkdir -p "$tempInstallRelease"
./configure --install-deps --prefix="$tempInstallRelease"
make -j$MAKE_JOBS
make install

# --- Build Debug ---
echo -e "${YELLOW}--- Building librdkafka (Debug)... ---${RESET}"
# Clean out release build
git clean -fdx
mkdir -p "$tempInstallDebug"
# Set CFLAGS for a debug build
./configure --install-deps --prefix="$tempInstallDebug" --CPPFLAGS=-DDEBUG --CFLAGS="-g -O0"
make -j$MAKE_JOBS
make install

cd "$scriptDir" # Go back to original directory

# --- Install Steps ---

echo -e "${YELLOW}--- Creating InstallRootDir: $installDirAbs ---${RESET}"
mkdir -p "$installDirAbs"

echo -e "${YELLOW}\n--- Assembling unified package: $installDir ---${RESET}"
if [ -d "$installDir" ]; then
    echo "--- Cleaning existing install directory: $installDir ---"
    rm -rf "$installDir"
fi

# Create the unified directory structure
echo "--- Creating package structure ---"
mkdir -p "$installDir/include"
mkdir -p "$installDir/cmake"
mkdir -p "$installDir/debug/lib"
mkdir -p "$installDir/release/lib"

# --- Copy Debug Files ---
echo "--- Copying Debug files... ---"
# Copy all .so files (and their symlinks) from the temp install lib
cp -P -r "$tempInstallDebug"/lib/*.so* "$installDir/debug/lib/"

# --- Copy Release Files ---
echo "--- Copying Release files... ---"
# Copy all .so files (and their symlinks) from the temp install lib
cp -P -r "$tempInstallRelease"/lib/*.so* "$installDir/release/lib/"

# --- Copy Include and CMake Files ---
echo "--- Copying include and cmake files... ---"
# Include files are identical, just grab them from one install
cp -r "$tempInstallRelease"/include/* "$installDir/include/"

cmakeModulePath="$scriptDir/$cmakeModule"
if [ ! -f "$cmakeModulePath" ]; then
    echo -e "${RED}Error: Could not find '$cmakeModule'. Make sure it's in the same directory as this script.${RESET}"
    exit 1
fi
cp "$cmakeModulePath" "$installDir/cmake/$cmakeModule"

# --- Packaging Step ---
echo -e "${YELLOW}--- Creating PackageRootDir: $packageDirAbs ---${RESET}"
mkdir -p "$packageDirAbs"

echo -e "${YELLOW}\n--- Creating the librdkafka distributable package... ---${RESET}"
# -C changes directory *before* tarring, so the tarball has $baseName as the root
tar -czf "$packagePath" -C "$installDirAbs" "$baseName"

# --- Final Cleanup ---
echo -e "${YELLOW}\n--- Cleaning up temporary build directories ---${RESET}"
rm -rf "$tempInstallRelease"
rm -rf "$tempInstallDebug"

echo -e "${GREEN}\n--- librdkafka Build Complete! ---${RESET}"
echo -e "${GREEN}Package ready for upload: $packagePath${RESET}"