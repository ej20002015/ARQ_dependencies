#!/bin/bash
#
# This script builds both Debug and Release configurations of gRPC (and libprotobuf)
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
    echo "  -v    Version of gRPC to build, e.g., 'v1.76.0'"
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
sourceDir="grpc"
baseName="grpc-$Version-linux-x64"
cmakeModule="grpc.cmake" # Assumes this file is in the script's directory

# Absolute paths for safety
buildDirAbs=$(realpath "$BuildRootDir")
installDirAbs=$(realpath "$InstallRootDir")
packageDirAbs=$(realpath "$PackageRootDir")

# Build directories
buildDir="$buildDirAbs/$baseName"
buildDirDebug="$buildDir/debug"
buildDirRelease="$buildDir/release"

# Temporary install directories
tempInstallDirDebug="$buildDir/debug_install"
tempInstallDirRelease="$buildDir/release_install"

# Final package layout path
installDir="$installDirAbs/$baseName"
packagePath="$packageDirAbs/$baseName.tar.gz"

# Library list files
debugListFile="$scriptDir/grpc_debug_libs_linux.txt"
releaseListFile="$scriptDir/grpc_release_libs_linux.txt"
if [ ! -f "$debugListFile" ] || [ ! -f "$releaseListFile" ]; then
    echo -e "${RED}Error: Could not find grpc_debug_libs_linux.txt or grpc_release_libs_linux.txt in $scriptDir ${RESET}"
    exit 1
fi

# --- Clone gRPC Source Code ---
if [ -d "$sourceDir" ]; then
    echo -e "${YELLOW}--- Skipping git clone, using existing source directory ---${RESET}"
else
    echo -e "${YELLOW}--- Cloning gRPC repository ---${RESET}"
    git clone -b "$Version" https://github.com/grpc/grpc --recursive
fi

# --- Make sure build and install directories are there ---
echo -e "${YELLOW}\n--- Creating BuildRootDir: $buildDirAbs ---${RESET}"
mkdir -p "$buildDirAbs"
echo -e "${YELLOW}--- Creating buildDir: $buildDir ---${RESET}"
mkdir -p "$buildDir"
echo -e "${YELLOW}--- Creating InstallRootDir: $installDirAbs ---${RESET}"
mkdir -p "$installDirAbs"

# --- Configure CMake (Debug) ---
echo -e "${YELLOW}\n--- Configuring gRPC build for debug ---${RESET}"
mkdir -p "$buildDirDebug" # Ensure build dir exists
cmakeArgsDebug=(
    "-DCMAKE_BUILD_TYPE=Debug"
    "-S" "$sourceDir"
    "-B" "$buildDirDebug"
    "-G" "Ninja"
    "-DCMAKE_INSTALL_PREFIX=$tempInstallDirDebug"
    # gRPC-specific flags:
    "-DCMAKE_CXX_STANDARD=20"
    "-DgRPC_INSTALL=ON"
    "-DgRPC_BUILD_TESTS=OFF"
    "-Dprotobuf_INSTALL=ON"
)
cmake "${cmakeArgsDebug[@]}"

# --- Build and install to temp directory (Debug) ---
echo -e "${YELLOW}\n--- Build and installing gRPC for debug ---${RESET}"
cmake --build "$buildDirDebug" --target install --config "Debug"

# --- Configure CMake (Release) ---
echo -e "${YELLOW}\n--- Configuring gRPC build for release ---${RESET}"
mkdir -p "$buildDirRelease" # Ensure build dir exists
cmakeArgsRelease=(
    "-DCMAKE_BUILD_TYPE=Release"
    "-S" "$sourceDir"
    "-B" "$buildDirRelease"
    "-G" "Ninja"
    "-DCMAKE_INSTALL_PREFIX=$tempInstallDirRelease"
    # gRPC-specific flags:
    "-DCMAKE_CXX_STANDARD=20"
    "-DgRPC_INSTALL=ON"
    "-DgRPC_BUILD_TESTS=OFF"
    "-Dprotobuf_INSTALL=ON"
)
cmake "${cmakeArgsRelease[@]}"

# --- Build and install to temp directory (Release) ---
echo -e "${YELLOW}\n--- Build and installing gRPC for release ---${RESET}"
cmake --build "$buildDirRelease" --target install --config "Release"

# --- Create install directory structure ---
echo -e "${YELLOW}\n--- Assembling unified package: $installDir ---${RESET}"
if [ -d "$installDir" ]; then
    echo "--- Cleaning existing install directory: $installDir ---"
    rm -rf "$installDir"
fi
mkdir -p "$installDir/include"
mkdir -p "$installDir/cmake"
mkdir -p "$installDir/bin"
mkdir -p "$installDir/debug/lib"
mkdir -p "$installDir/release/lib"
mkdir -p "$installDir/share/grpc"

# --- Copy Header, cmake and lib list files ---
echo -e "${YELLOW}\n--- Copying include, cmake and lib list files ---${RESET}"
# Headers are the same, copy from release temp install
cp -r "$tempInstallDirRelease/include/"* "$installDir/include/"

cmakeModulePath="$scriptDir/$cmakeModule"
if [ ! -f "$cmakeModulePath" ]; then
    echo -e "${RED}Error: Could not find '$cmakeModule'. Make sure it's in the same directory as this script.${RESET}"
    exit 1
fi
cp "$cmakeModulePath" "$installDir/cmake/grpc.cmake"
cp "$debugListFile" "$installDir/cmake/"
cp "$releaseListFile" "$installDir/cmake/"

echo "--- Copying protobuf CMake support files ---"
cp "$tempInstallDirRelease/lib/cmake/protobuf/protobuf-generate.cmake" "$installDir/cmake/"

# --- Copy all libs specified in files ---
echo -e "${YELLOW}\n--- Copying all Debug libraries from list ---${RESET}"
srcDebugLibDir="$tempInstallDirDebug/lib"
while IFS= read -r libName || [[ -n "$libName" ]]; do
    # Skip empty lines or comments
    [[ -z "$libName" || "$libName" =~ ^# ]] && continue
    # Use find to handle potential variations like .a, .so, symlinks
    find "$srcDebugLibDir" -maxdepth 1 -name "$libName*" -exec cp -Pdp {} "$installDir/debug/lib/" \;
done < "$debugListFile"

echo -e "${YELLOW}\n--- Copying all Release libraries from list ---${RESET}"
srcReleaseLibDir="$tempInstallDirRelease/lib"
while IFS= read -r libName || [[ -n "$libName" ]]; do
    # Skip empty lines or comments
    [[ -z "$libName" || "$libName" =~ ^# ]] && continue
    # Use find to handle potential variations like .a, .so, symlinks
    find "$srcReleaseLibDir" -maxdepth 1 -name "$libName*" -exec cp -Pdp {} "$installDir/release/lib/" \;
done < "$releaseListFile"


# --- Copy Protoc and Plugin executables ---
echo -e "${YELLOW}\n--- Copying protoc and plugin executables ---${RESET}"
# Binaries are platform executables, copy from release build
pluginSourceDir="$tempInstallDirRelease/bin"
cp "$pluginSourceDir"/* "$installDir/bin/"


# --- Copy certificate in share directory ---
echo -e "${YELLOW}\n--- Copying roots.pem ---${RESET}"
cp "$tempInstallDirRelease/share/grpc/roots.pem" "$installDir/share/grpc/roots.pem"


# --- Packaging Step ---
echo -e "${YELLOW}\n--- Creating PackageRootDir: $packageDirAbs ---${RESET}"
mkdir -p "$packageDirAbs"

echo -e "${YELLOW}\n--- Creating the grpc distributable package ---${RESET}"
# -C changes directory *before* tarring, so the tarball has $baseName as the root folder
tar -czf "$packagePath" -C "$installDirAbs" "$baseName"

echo -e "${GREEN}\n--- gRPC Build Complete! ---${RESET}"
echo -e "${GREEN}Package ready for upload: $packagePath${RESET}"