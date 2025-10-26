#!/bin/bash
# This script contains the specific logic for building gRPC on Linux.
set -e

# --- Script Parameters ---
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <Version> <Config>"
    echo "  Version        - Version of gRPC to build and package, e.g., 'v1.56.0'"
    echo "  Config         - Build configuration, either 'Debug' or 'Release'"
    exit 1
fi

Version=$1
Config=$2

if [ "$Config" != "Debug" ] && [ "$Config" != "Release" ]; then
    echo "Error: Config must be either 'Debug' or 'Release'"
    exit 1
fi

buildDir=".build/grpc-$Version-linux-$Config"
installDir=".install/grpc-$Version-linux-$Config"
packagePath=".package/grpc-$Version-linux-$Config.tar.gz"

# --- Clone gRPC Source Code ---
if [ -d "grpc" ]; then
    echo "--- Skipping git clone, using existing source directory ---"
else
    echo "--- Cloning gRPC repository ---"
    git clone --depth 1 --branch v$Version https://github.com/grpc/grpc --recursive
fi

# --- Build Steps ---
echo "--- Configuring build for gRPC version $Version ($Config) ---"
mkdir -p $buildDir
cmake -S grpc \
      -B $buildDir \
      -G "Ninja Multi-Config" \
      -DCMAKE_BUILD_TYPE=$Config \
      -DCMAKE_INSTALL_PREFIX=$installDir \
      -DCMAKE_CXX_STANDARD=20 \
      -DgRPC_INSTALL=ON \
      -DgRPC_BUILD_TESTS=OFF \
      -Dprotobuf_INSTALL=ON
echo "--- Building gRPC... ---"
cmake --build $buildDir --config $Config --parallel
echo "--- Installing gRPC to create the SDK directory... ---"
cmake --install $buildDir --config $Config
mkdir -p .package
tar -czf $packagePath -C $(dirname $installDir) $(basename $installDir)

echo "--- gRPC Build Complete! ---"
echo "Package ready for upload: $packagePath"