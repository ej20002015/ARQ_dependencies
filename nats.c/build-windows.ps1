# This script builds both Debug and Release configurations of nats.c
# and assembles them into a single, config-aware package.

# --- Script Parameters (received from the orchestrator) ---
param(
    [Parameter(Mandatory,
    HelpMessage="Version of nats.c to build and package, e.g., 'v3.11.0'")]
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
$sourceDir = "nats.c"
$baseName = "nats.c-$Version-windows-x64"
$buildDir = "$BuildRootDir/$baseName"
$installDir = "$InstallRootDir/$baseName"
$packagePath = "$PackageRootDir/$baseName.zip"
$cmakeModule = "nats.c.cmake"

# --- Clone nats.c Source Code ---
if (Test-Path $sourceDir) {
    Write-Host "--- Skipping git clone, using existing source directory ---" -ForegroundColor Yellow
} else {
    Write-Host "--- Cloning nats.c repository ---" -ForegroundColor Yellow
    git clone -b $Version git@github.com:nats-io/nats.c.git
}

# --- Create directories if missing ---

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

if (-Not (Test-Path -Path $PackageRootDir)) {
    Write-Host "`n--- Creating PackageRootDir: $PackageRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $PackageRootDir | Out-Null
}

$buildDirDebug = "$buildDir/build_debug"
$buildDirRelease = "$buildDir/build_release"
$tempInstallDirDebug = "$buildDir/install_debug"
$tempInstallDirRelease = "$buildDir/install_release"

# --- Config cmake ---

Write-Host "--- Running cmake configure (Debug)... ---" -ForegroundColor Yellow
cmake -S $sourceDir -B $buildDirDebug -G "Visual Studio 17 2022" -DNATS_BUILD_EXAMPLES=OFF -DNATS_BUILD_LIB_SHARED=OFF -DCMAKE_BUILD_TYPE=Debug "-DCMAKE_INSTALL_PREFIX=$tempInstallDirDebug"
Write-Host "--- Running cmake configure (Release)... ---" -ForegroundColor Yellow
cmake -S $sourceDir -B $buildDirRelease -G "Visual Studio 17 2022" -DNATS_BUILD_EXAMPLES=OFF -DNATS_BUILD_LIB_SHARED=OFF -DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX=$tempInstallDirRelease"

# --- Build Steps ---

Write-Host "--- Build and installing to temp location (Debug) ---" -ForegroundColor Yellow
cmake --build $buildDirDebug --config "Debug" --target install
Write-Host "--- Build and installing to temp location (Release) ---" -ForegroundColor Yellow
cmake --build $buildDirRelease --config "Release" --target install

# --- Install ---

Write-Host "`n--- Assembling unified package: $installDir ---" -ForegroundColor Yellow

if (Test-Path $installDir) {
    Write-Host "--- Cleaning existing install directory: $installDir ---" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $installDir
}

# Create the unified directory structure
New-Item -ItemType Directory -Path "$installDir\include" | Out-Null
New-Item -ItemType Directory -Path "$installDir\cmake" | Out-Null
New-Item -ItemType Directory -Path "$installDir\debug\lib" | Out-Null
New-Item -ItemType Directory -Path "$installDir\release\lib" | Out-Null

# --- Copy Libs ---
Write-Host "--- Copying Debug files... ---" -ForegroundColor Yellow
Copy-Item -Path "$tempInstallDirDebug\lib\nats_staticd.lib" -Destination "$installDir\debug\lib\" -Force
Write-Host "--- Copying Release files... ---" -ForegroundColor Yellow
Copy-Item -Path "$tempInstallDirRelease\lib\nats_static.lib" -Destination "$installDir\release\lib\" -Force

# --- Copy include and cmake files ---
Write-Host "--- Copying include and cmake files... ---" -ForegroundColor Yellow
Copy-Item -Path "$tempInstallDirRelease\include\*" -Destination "$installDir\include\" -Force -Recurse
$cmakeModulePath = (Resolve-Path $cmakeModule).Path
if (-Not (Test-Path $cmakeModulePath)) {
    Write-Error "Could not find '$cmakeModule'. Make sure it's in the same directory as this script."
    exit 1
}
Copy-Item -Path $cmakeModulePath -Destination "$installDir\cmake\nats.c.cmake" -Force

# --- Packaging Step ---

Write-Host "`n--- Creating the nats.c distributable package... ---" -ForegroundColor Yellow
Compress-Archive -Path $installDir -DestinationPath $packagePath -Force

Write-Host "`n--- nats.c Build Complete! ---" -ForegroundColor Green
Write-Host "Package ready for upload: $packagePath" -ForegroundColor Green