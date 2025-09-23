# This script contains the specific logic for building gRPC.
# It is called by the main build.ps1 orchestrator.

# --- Script Parameters (received from the orchestrator) ---
param(
    [Parameter(Mandatory,
    HelpMessage="Version of gRPC to build and package, e.g., 'v1.56.0'")]
    [string]$Version,
    [ValidateSet('Debug','Release')]
    [Parameter(Mandatory,
    HelpMessage="Build configuration, either 'Debug' or 'Release'")]
    [string]$Config,
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
$sourceDir = "grpc"
$buildDir = "$BuildRootDir/grpc-$Version-windows-$Config"
$installDir = "$InstallRootDir/grpc-$Version-windows-$Config"
$packagePath = "$PackageRootDir/grpc-$Version-windows-$Config.zip"

# --- Clone gRPC Source Code ---
if (Test-Path $sourceDir) {
    Write-Host "--- Skipping git clone, using existing source directory ---" -ForegroundColor Yellow
} else {
    Write-Host "--- Cloning gRPC repository ---" -ForegroundColor Yellow
    git clone -b $Version https://github.com/grpc/grpc --recursive
}

# --- Build Steps ---

Write-Host "--- Configuring build for gRPC version $Version ($Config) ---" -ForegroundColor Yellow

$cmakeArgs = @(
    "-S", $sourceDir,
    "-B", $buildDir,
    "-G", "Visual Studio 17 2022",
    "-DCMAKE_BUILD_TYPE=$Config",
    "-DCMAKE_INSTALL_PREFIX=$installDir",
    # gRPC-specific flags:
    "-DCMAKE_CXX_STANDARD=20",
    "-DgRPC_INSTALL=ON",
    "-DgRPC_BUILD_TESTS=OFF",
    "-Dprotobuf_INSTALL=ON"
)

cmake $cmakeArgs

Write-Host "`n--- Building gRPC... ---" -ForegroundColor Yellow
cmake --build $buildDir --config $Config --parallel

Write-Host "`n--- Installing gRPC to create the SDK directory... ---" -ForegroundColor Yellow
cmake --install $buildDir --config $Config

if (-Not (Test-Path -Path $PackageRootDir)) {
    Write-Host "`n--- Creating PackageRootDir: $PackageRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $PackageRootDir | Out-Null
}

Write-Host "`n--- Creating the gRPC distributable package... ---" -ForegroundColor Yellow
Compress-Archive -Path $installDir -DestinationPath $packagePath -Force

Write-Host "`n--- gRPC Build Complete! ---" -ForegroundColor Green
Write-Host "Package ready for upload: $packagePath" -ForegroundColor Green