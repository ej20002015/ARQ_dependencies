# This script builds both Debug and Release configurations of grpc (and libprotobuf)
# and assembles them into a single, config-aware package.

# --- Script Parameters ---
param(
    [Parameter(Mandatory,
    HelpMessage="Version of grpc to build and package, e.g., 'v1.76.0'")]
    [string]$Version,

    [Parameter(Mandatory,
    HelpMessage="Root directory for the build output")]
    [string]$BuildRootDir,

    [Parameter(Mandatory,
    HelpMessage="Root directory for the install output")]
    [string]$InstallRootDir,

    [Parameter(Mandatory,
    HelpMessage="Root directory for the Zipped package output")]
    [string]$PackageRootDir
)

# Stop the script if any command fails
$ErrorActionPreference = "Stop"

# --- Configuration ---
$scriptDir = $PSScriptRoot
$sourceDir = "grpc"
$baseName = "grpc-$Version-windows-x64"
$buildDir = "$BuildRootDir/$baseName"
$installDir = "$InstallRootDir/$baseName"
$packagePath = "$PackageRootDir/$baseName.zip"
$cmakeModule = "grpc.cmake"

# --- Define Lib List Files ---
$debugListFile = (Resolve-Path (Join-Path $scriptDir "grpc_debug_libs_windows.txt")).Path
$releaseListFile = (Resolve-Path (Join-Path $scriptDir "grpc_release_libs_windows.txt")).Path
if ((-Not (Test-Path $debugListFile)) -or (-Not (Test-Path $releaseListFile))) {
    Write-Error "Could not find grpc_debug_libs.txt or grpc_release_libs.txt. Make sure they are in the same directory as this script."
    exit 1
}

# --- Clone librdkafka Source Code ---
if (Test-Path $sourceDir) {
    Write-Host "--- Skipping git clone, using existing source directory ---" -ForegroundColor Yellow
} else {
    Write-Host "--- Cloning gRPC repository ---" -ForegroundColor Yellow
    git clone -b $Version https://github.com/grpc/grpc --recursive
}

# --- Make sure build and install directories are there ---

if (-Not (Test-Path -Path $BuildRootDir)) {
    Write-Host "`n--- Creating BuildRootDir: $BuildRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BuildRootDir | Out-Null
}

if (-Not (Test-Path -Path $buildDir)) {
    Write-Host "`n--- Creating buildDir: $buildDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

if (-Not (Test-Path -Path $InstallRootDir)) {
    Write-Host "`n--- Creating InstallRootDir: $InstallRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $InstallRootDir | Out-Null
}

# --- Configure CMake (debug) ---

Write-Host "--- Configuring gRPC build for debug ---" -ForegroundColor Yellow

$buildDirDebug = "$buildDir/debug"
$tempInstallDirDebug = "$buildDir/debug_install"

$cmakeArgs = @(
    "-DCMAKE_BUILD_TYPE=Debug"
    "-S", $sourceDir,
    "-B", $buildDirDebug,
    "-G", "Ninja", # Ninja is much faster to build than vs for grpc!
    "-DCMAKE_INSTALL_PREFIX=$tempInstallDirDebug",
    # gRPC-specific flags:
    "-DCMAKE_CXX_STANDARD=20",
    "-DgRPC_INSTALL=ON",
    "-DgRPC_BUILD_TESTS=OFF",
    "-Dprotobuf_INSTALL=ON"
)

cmake $cmakeArgs

# --- Build and install to temp directory (debug) ---

Write-Host "--- Build and installing gRPC for debug ---" -ForegroundColor Yellow
cmake --build $buildDirDebug --config "Debug" --target install

# --- Configure CMake (release) ---

Write-Host "--- Configuring gRPC build for release ---" -ForegroundColor Yellow

$buildDirRelease = "$buildDir/release"
$tempInstallDirRelease = "$buildDir/release_install"

$cmakeArgs = @(
    "-DCMAKE_BUILD_TYPE=Release"
    "-S", $sourceDir,
    "-B", $buildDirRelease,
    "-G", "Ninja", # Ninja is much faster to build than vs for grpc!
    "-DCMAKE_INSTALL_PREFIX=$tempInstallDirRelease",
    # gRPC-specific flags:
    "-DCMAKE_CXX_STANDARD=20",
    "-DgRPC_INSTALL=ON",
    "-DgRPC_BUILD_TESTS=OFF",
    "-Dprotobuf_INSTALL=ON"
)

cmake $cmakeArgs

# --- Build and install to temp directory (release) ---

Write-Host "--- Build and installing gRPC for release ---" -ForegroundColor Yellow
cmake --build $buildDirRelease --config "Release" --target install

# --- Create install directory structure

Write-Host "`n--- Assembling unified package: $installDir ---" -ForegroundColor Yellow
if (Test-Path $installDir) {
    Write-Host "--- Cleaning existing install directory: $installDir ---" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $installDir
}
New-Item -ItemType Directory -Path "$installDir\include" -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\cmake" -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\bin" -Force | Out-Null # Bin output only contains protoc executable and plugins that are for codegen so can use release exes for all configurations
New-Item -ItemType Directory -Path "$installDir\debug\lib" -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\release\lib" -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\share\grpc" -Force | Out-Null

# --- Copy Header, cmake and lib list files ---
Write-Host "--- Copying include, cmake and lib list files ---" -ForegroundColor Yellow
Copy-Item -Path "$tempInstallDirRelease\include\*" -Destination "$installDir\include\" -Force -Recurse
$cmakeModulePath = (Resolve-Path $cmakeModule).Path
if (-Not (Test-Path $cmakeModulePath)) {
    Write-Error "Could not find '$cmakeModule'. Make sure it's in the same directory as this script."
    exit 1
}
Copy-Item -Path $cmakeModulePath -Destination "$installDir\cmake\grpc.cmake" -Force
Copy-Item -Path $debugListFile -Destination "$installDir\cmake\" -Force
Copy-Item -Path $releaseListFile -Destination "$installDir\cmake\" -Force
Write-Host "--- Copying protobuf CMake support files ---"
Copy-Item -Path "$tempInstallDirRelease\lib\cmake\protobuf\protobuf-generate.cmake" -Destination "$installDir\cmake\" -Recurse -Force

# --- Copy all libs specified in files ---

Write-Host "--- Copying all Debug libraries from list ---"
$srcDebugLibDir = "$tempInstallDirDebug\lib"
foreach ($libName in (Get-Content $debugListFile)) {
    Copy-Item -Path (Join-Path $srcDebugLibDir $libName) -Destination "$installDir\debug\lib\"
}

Write-Host "--- Copying all Release libraries from list ---"
$srcReleaseLibDir = "$tempInstallDirRelease\lib"
foreach ($libName in (Get-Content $releaseListFile)) {
    Copy-Item -Path (Join-Path $srcReleaseLibDir $libName) -Destination "$installDir\release\lib\"
}

# --- Copy Protoc and Plugin exes ---
Write-Host "--- Copying protoc and plugin exes ---" -ForegroundColor Yellow
$pluginSourceDir = "$tempInstallDirRelease\bin"
Get-ChildItem -Path $pluginSourceDir -Filter "*.exe" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination "$installDir\bin\" -Force
}

# --- Copy certificate in share directory ---
Write-Host "--- Copying roots.pem ---" -ForegroundColor Yellow
Copy-Item -Path "$tempInstallDirRelease\share\grpc\roots.pem" -Destination "$installDir\share\grpc\roots.pem" -Force

# --- Packaging Step ---

if (-Not (Test-Path -Path $PackageRootDir)) {
    Write-Host "`n--- Creating PackageRootDir: $PackageRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $PackageRootDir | Out-Null
}

Write-Host "`n--- Creating the grpc distributable package (using 7-Zip) ---" -ForegroundColor Yellow

# 'a' = add to archive
# '-tzip' = force it to be a standard .zip file
# '-r' = recurse subdirectories
# We cd into the install root so the zip doesn't contain the full C:\... path

$parentDir = (Get-Item -Path $installDir).Parent.FullName
$dirName = (Get-Item -Path $installDir).Name

Push-Location -Path $parentDir
& 7z.exe a -tzip -r "$packagePath" "$dirName"
Pop-Location

Write-Host "`n--- grpc Build Complete! ---" -ForegroundColor Green
Write-Host "Package ready for upload: $packagePath" -ForegroundColor Green