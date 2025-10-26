#!/bin/bash
#
# This script builds SWIG from source and packages it into a distributable
# tar.gz file with a specific, clean directory structure for CMake.

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
    echo "  -v    Version of SWIG to build, e.g., '4.3.1'"
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
for cmd in wget tar make gcc; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: Required command '$cmd' is not found. Please install it.${RESET}"
        exit 1
    fi
done

# --- Configuration ---
# Use 'v' prefix for package name, but not for source URL/paths
versionNumber="${Version#v}" # Removes leading 'v' if present (e.g., v4.3.1 -> 4.3.1)
baseName="SWIG-$Version-linux-x64"
cmakeFile="SWIG.cmake" # Assumes this file is in the script's directory

# Build-related paths
buildDirAbs=$(realpath "$BuildRootDir")
tarballName="swig-$versionNumber.tar.gz"
tarballPath="$buildDirAbs/$tarballName"
sourceDir="$buildDirAbs/swig-$versionNumber"
tempInstallDir="$buildDirAbs/swig_install_raw" # Prefix for 'make install'

# Final package layout paths
installDirAbs=$(realpath "$InstallRootDir")
installDir="$installDirAbs/$baseName"

# Final tarball path
packageDirAbs=$(realpath "$PackageRootDir")
packagePath="$packageDirAbs/$baseName.tar.gz"

# --- 1. Download SWIG ---
echo -e "${YELLOW}--- Configuring Build Directory: $buildDirAbs ---${RESET}"
mkdir -p "$buildDirAbs"

if [ -f "$tarballPath" ]; then
    echo -e "${YELLOW}--- Skipping SWIG download, using existing tarball ---${RESET}"
else
    echo -e "${YELLOW}--- Downloading SWIG $versionNumber ---${RESET}"
    wget -O "$tarballPath" "http://downloads.sourceforge.net/project/swig/swig/swig-$versionNumber/$tarballName"
fi

# --- 2. Build from Source ---
echo -e "${YELLOW}--- Extracting SWIG source ---${RESET}"
if [ -d "$sourceDir" ]; then
    echo "--- Cleaning existing source directory ---"
    rm -rf "$sourceDir"
fi
tar -xzf "$tarballPath" -C "$buildDirAbs"

echo -e "${YELLOW}--- Building SWIG (this may take a few minutes) ---${RESET}"
cd "$sourceDir"

mkdir -p "$tempInstallDir" # Create the raw install prefix
echo "Configuring with prefix: $tempInstallDir"
./configure --without-pcre --prefix="$tempInstallDir"

make
make install

echo -e "${YELLOW}--- SWIG build and 'make install' complete ---${RESET}"
cd - > /dev/null # Go back to original directory

# --- 3. Restructure for Final Package ---
echo -e "${YELLOW}--- Assembling final package structure at: $installDir ---${RESET}"
if [ -d "$installDir" ]; then
    echo "--- Cleaning existing install directory: $installDir ---"
    rm -rf "$installDir"
fi

# Create the desired package structure
mkdir -p "$installDir/SWIG/Lib"
mkdir -p "$installDir/cmake"

# Move the executable
echo "Moving SWIG executable..."
mv "$tempInstallDir/bin/swig" "$installDir/SWIG/swig"

# Move the library files
echo "Moving SWIG library files..."
# This moves the *contents* of the versioned dir (e.g., .../4.3.1/*) into /SWIG/Lib/
mv "$tempInstallDir/share/swig/$versionNumber"/* "$installDir/SWIG/Lib/"

# Check executable
echo "Verifying SWIG executable..."
"$installDir/SWIG/swig" -version > /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: '$installDir/SWIG/swig -version' command failed - package was not assembled correctly.${RESET}"
    exit 1
fi

# Add cmake file
echo "Copying $cmakeFile..."
scriptDir=$(dirname "$(realpath "$0")")
cp "$scriptDir/$cmakeFile" "$installDir/cmake/SWIG.cmake"

# --- 4. Packaging Step ---
echo -e "${YELLOW}--- Creating Package Root Directory: $packageDirAbs ---${RESET}"
mkdir -p "$packageDirAbs"

echo -e "${YELLOW}--- Creating the SWIG distributable package... ---${RESET}"
# -C changes directory *before* tarring, so the tarball has $baseName as the root
tar -czf "$packagePath" -C "$installDirAbs" "$baseName"

echo -e "${GREEN}\n--- SWIG Build Complete! ---${RESET}"
echo -e "${GREEN}Package ready for upload: $packagePath${RESET}"
