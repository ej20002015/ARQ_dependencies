#!/bin/bash
#
# This script builds both Debug and Release configurations of nats.c
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
    echo "  -v    Version of nats.c to build, e.g., 'v3.11.0'"
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
for cmd in git cmake ninja gcc tar; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: Required command '$cmd' is not found. Please install it.${RESET}"
        exit 1
    fi
done

# --- Configuration ---
scriptDir=$(dirname "$(realpath "$0")")
sourceDir="nats.c"
baseName="nats.c-$Version-linux-x64"
cmakeModule="nats.c.cmake" # Assumes this file is in the script's directory

# Absolute paths for safety
buildDirAbs=$(realpath "$BuildRootDir")
installDirAbs=$(realpath "$InstallRootDir")
packageDirAbs=$(realpath "$PackageRootDir")

# Build directories
buildDir="$buildDirAbs/$baseName"
buildDirDebug="$buildDir/build_debug"
buildDirRelease="$buildDir/build_release"

# Temporary install directories
tempInstallDirDebug="$buildDir/install_debug"
tempInstallDirRelease="$buildDir/install_release"

# Final package layout path
installDir="$installDirAbs/$baseName"
packagePath="$packageDirAbs/$baseName.tar.gz"


# --- Clone nats.c Source Code ---
if [ -d "$sourceDir" ]; then
    echo -e "${YELLOW}--- Skipping git clone, using existing source directory ---${RESET}"
else
    echo -e "${YELLOW}--- Cloning nats.c repository ---${RESET}"
    # Use HTTPS for robustness in scripts
    git clone -b "$Version" https://github.com/nats-io/nats.c.git
fi

# --- Create directories if missing ---
echo -e "${YELLOW}\n--- Creating BuildRootDir: $buildDirAbs ---${RESET}"
mkdir -p "$buildDirAbs"
echo -e "${YELLOW}--- Creating buildDir: $buildDir ---${RESET}"
mkdir -p "$buildDir"
echo -e "${YELLOW}--- Creating InstallRootDir: $installDirAbs ---${RESET}"
mkdir -p "$installDirAbs"
echo -e "${YELLOW}--- Creating PackageRootDir: $packageDirAbs ---${RESET}"
mkdir -p "$packageDirAbs"


# --- Configure CMake (Debug) ---
echo -e "${YELLOW}\n--- Running cmake configure (Debug)... ---${RESET}"
mkdir -p "$buildDirDebug" # Ensure build dir exists
cmakeArgsDebug=(
    "-S" "$sourceDir"
    "-B" "$buildDirDebug"
    "-G" "Ninja"
    "-DCMAKE_BUILD_TYPE=Debug"
    "-DCMAKE_INSTALL_PREFIX=$tempInstallDirDebug"
    "-DNATS_BUILD_EXAMPLES=OFF"
    "-DNATS_BUILD_LIB_SHARED=OFF"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON" # Crucial for linking .a into .so
)
cmake "${cmakeArgsDebug[@]}"

# --- Configure CMake (Release) ---
echo -e "${YELLOW}\n--- Running cmake configure (Release)... ---${RESET}"
mkdir -p "$buildDirRelease" # Ensure build dir exists
cmakeArgsRelease=(
    "-S" "$sourceDir"
    "-B" "$buildDirRelease"
    "-G" "Ninja"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_INSTALL_PREFIX=$tempInstallDirRelease"
    "-DNATS_BUILD_EXAMPLES=OFF"
    "-DNATS_BUILD_LIB_SHARED=OFF"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON" # Crucial for linking .a into .so
)
cmake "${cmakeArgsRelease[@]}"

# --- Build Steps ---

echo -e "${YELLOW}\n--- Build and installing to temp location (Debug) ---${RESET}"
cmake --build "$buildDirDebug" --target install

echo -e "${YELLOW}\n--- Build and installing to temp location (Release) ---${RESET}"
cmake --build "$buildDirRelease" --target install

# --- Install ---

echo -e "${YELLOW}\n--- Assembling unified package: $installDir ---${RESET}"

if [ -d "$installDir" ]; then
    echo "--- Cleaning existing install directory: $installDir ---"
    rm -rf "$installDir"
fi

# Create the unified directory structure
mkdir -p "$installDir/include"
mkdir -p "$installDir/cmake"
mkdir -p "$installDir/debug/lib"
mkdir -p "$installDir/release/lib"

# --- Copy Libs ---
echo "--- Copying Debug files... ---"
# nats.c auto-appends 'd' for debug static libs
cp "$tempInstallDirDebug/lib/libnats_staticd.a" "$installDir/debug/lib/"

echo "--- Copying Release files... ---"
cp "$tempInstallDirRelease/lib/libnats_static.a" "$installDir/release/lib/"

# --- Copy include and cmake files ---
echo "--- Copying include and cmake files... ---"
cp -r "$tempInstallDirRelease/include/"* "$installDir/include/"

cmakeModulePath="$scriptDir/$cmakeModule"
if [ ! -f "$cmakeModulePath" ]; then
    echo -e "${RED}Error: Could not find '$cmakeModule'. Make sure it's in the same directory as this script.${RESET}"
    exit 1
fi
cp "$cmakeModulePath" "$installDir/cmake/nats.c.cmake"

# --- Packaging Step ---

echo -e "${YELLOW}\n--- Creating the nats.c distributable package... ---${RESET}"
# -C changes directory *before* tarring, so the tarball has $baseName as the root folder
tar -czf "$packagePath" -C "$installDirAbs" "$baseName"

# --- Optional Cleanup ---
echo -e "${YELLOW}\n--- Cleaning up temporary build directories ---${RESET}"
rm -rf "$tempInstallDirDebug"
rm -rf "$tempInstallDirRelease"
# rm -rf "$buildDirDebug" "$buildDirRelease" # Uncomment to clean up builds too

echo -e "${GREEN}\n--- nats.c Build Complete! ---${RESET}"
echo -e "${GREEN}Package ready for upload: $packagePath${RESET}"
