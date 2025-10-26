# This script builds both Debug and Release configurations of librdkafka
# and assembles them into a single, config-aware package.

# --- Script Parameters (received from the orchestrator) ---
param(
    [Parameter(Mandatory,
    HelpMessage="Version of librdkafka to build and package, e.g., 'v2.12.0'")]
    [string]$Version,

    [Parameter(Mandatory,
    HelpMessage="Root directory for the install output")]
    [string]$InstallRootDir,

    [Parameter(Mandatory,
    HelpMessage="Root directory for the Zipped package output")]
    [string]$PackageRootDir,
    
    [string]$PlatformToolset = "v143"
)

# Stop the script if any command fails
$ErrorActionPreference = "Stop"

# --- Configuration ---
$sourceDir = "librdkafka"
$baseName = "librdkafka-$Version-windows-x64"
$installDir = "$InstallRootDir/$baseName"
$packagePath = "$PackageRootDir/$baseName.zip"
$cmakeModule = "librdkafka.cmake"

# --- Clone librdkafka Source Code ---
if (Test-Path $sourceDir) {
    Write-Host "--- Skipping git clone, using existing source directory ---" -ForegroundColor Yellow
} else {
    Write-Host "--- Cloning librdkafka repository ---" -ForegroundColor Yellow
    git clone -b $Version git@github.com:confluentinc/librdkafka.git
}

# --- Build Steps ---

Write-Host "--- Setting up vcpkg and pulling dependencies ---" -ForegroundColor Yellow

if (Test-Path "vcpkg") {
    Write-Host "--- Skipping vcpkg clone, using existing vcpkg directory ---" -ForegroundColor Yellow
} else {
    Write-Host "--- Cloning vcpkg repository ---" -ForegroundColor Yellow
    git clone https://github.com/microsoft/vcpkg.git
    cd vcpkg; .\bootstrap-vcpkg.bat
    .\vcpkg.exe integrate install
    cd ..
}

$env:VCPKG_ROOT = "$PWD\vcpkg"
$env:PATH = "$env:VCPKG_ROOT;$env:PATH"
cd librdkafka\win32
vcpkg --feature-flags=versions install

# --- Build Debug ---
Write-Host "--- Building librdkafka (Debug)... ---" -ForegroundColor Yellow
msbuild librdkafka.sln /p:Configuration=Debug /p:Platform=x64 /p:PlatformToolset=$PlatformToolset /p:VcpkgEnableManifest=true /t:Clean
msbuild librdkafka.sln /p:Configuration=Debug /p:Platform=x64 /p:PlatformToolset=$PlatformToolset /p:VcpkgEnableManifest=true

# --- Build Release ---
Write-Host "--- Building librdkafka (Release)... ---" -ForegroundColor Yellow
msbuild librdkafka.sln /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=$PlatformToolset /p:VcpkgEnableManifest=true /t:Clean
msbuild librdkafka.sln /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=$PlatformToolset /p:VcpkgEnableManifest=true

cd ../..

# --- Install Steps ---

if (-Not (Test-Path -Path $InstallRootDir)) {
    Write-Host "`n--- Creating InstallRootDir: $InstallRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $InstallRootDir | Out-Null
}

Write-Host "`n--- Assembling unified package: $installDir ---" -ForegroundColor Yellow

if (Test-Path $installDir) {
    Write-Host "--- Cleaning existing install directory: $installDir ---" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $installDir
}

# Create the unified directory structure
New-Item -ItemType Directory -Path "$installDir\include" | Out-Null
New-Item -ItemType Directory -Path "$installDir\cmake" | Out-Null
New-Item -ItemType Directory -Path "$installDir\debug\bin" | Out-Null
New-Item -ItemType Directory -Path "$installDir\debug\lib" | Out-Null
New-Item -ItemType Directory -Path "$installDir\release\bin" | Out-Null
New-Item -ItemType Directory -Path "$installDir\release\lib" | Out-Null

# --- Copy Debug Files ---
Write-Host "--- Copying Debug files... ---" -ForegroundColor Yellow
$srcDebugDir = "librdkafka\win32\outdir\$PlatformToolset\x64\Debug"
Copy-Item -Path "$srcDebugDir\librdkafkacpp.dll" -Destination "$installDir\debug\bin\" -Force
Copy-Item -Path "$srcDebugDir\libcrypto-3-x64.dll" -Destination "$installDir\debug\bin\" -Force
Copy-Item -Path "$srcDebugDir\libcurl-d.dll" -Destination "$installDir\debug\bin\" -Force
Copy-Item -Path "$srcDebugDir\librdkafka.dll" -Destination "$installDir\debug\bin\" -Force
Copy-Item -Path "$srcDebugDir\libssl-3-x64.dll" -Destination "$installDir\debug\bin\" -Force
Copy-Item -Path "$srcDebugDir\zlibd1.dll" -Destination "$installDir\debug\bin\" -Force
Copy-Item -Path "$srcDebugDir\zstd.dll" -Destination "$installDir\debug\bin\" -Force
Copy-Item -Path "$srcDebugDir\librdkafkacpp.lib" -Destination "$installDir\debug\lib\" -Force
Copy-Item -Path "$srcDebugDir\librdkafka.lib" -Destination "$installDir\debug\lib\" -Force

# --- Copy Release Files ---
Write-Host "--- Copying Release files... ---" -ForegroundColor Yellow
$srcReleaseDir = "librdkafka\win32\outdir\$PlatformToolset\x64\Release"
Copy-Item -Path "$srcReleaseDir\librdkafkacpp.dll" -Destination "$installDir\release\bin\" -Force
Copy-Item -Path "$srcReleaseDir\libcrypto-3-x64.dll" -Destination "$installDir\release\bin\" -Force
Copy-Item -Path "$srcReleaseDir\libcurl.dll" -Destination "$installDir\release\bin\" -Force
Copy-Item -Path "$srcReleaseDir\librdkafka.dll" -Destination "$installDir\release\bin\" -Force
Copy-Item -Path "$srcReleaseDir\libssl-3-x64.dll" -Destination "$installDir\release\bin\" -Force
Copy-Item -Path "$srcReleaseDir\zlib1.dll" -Destination "$installDir\release\bin\" -Force
Copy-Item -Path "$srcReleaseDir\zstd.dll" -Destination "$installDir\release\bin\" -Force
Copy-Item -Path "$srcReleaseDir\librdkafkacpp.lib" -Destination "$installDir\release\lib\" -Force
Copy-Item -Path "$srcReleaseDir\librdkafka.lib" -Destination "$installDir\release\lib\" -Force

# --- Copy Include and CMake Files ---
Write-Host "--- Copying include and cmake files... ---" -ForegroundColor Yellow
New-Item -ItemType Directory -Path "$installDir\include\librdkafka" | Out-Null
Copy-Item -Path "librdkafka\src-cpp\rdkafkacpp.h" -Destination "$installDir\include\librdkafka\rdkafkacpp.h" -Force

$cmakeModulePath = (Resolve-Path $cmakeModule).Path
if (-Not (Test-Path $cmakeModulePath)) {
    Write-Error "Could not find '$cmakeModule'. Make sure it's in the same directory as this script."
    exit 1
}
Copy-Item -Path $cmakeModulePath -Destination "$installDir\cmake\librdkafka.cmake" -Force

# --- Packaging Step ---

if (-Not (Test-Path -Path $PackageRootDir)) {
    Write-Host "`n--- Creating PackageRootDir: $PackageRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $PackageRootDir | Out-Null
}

Write-Host "`n--- Creating the librdkafka distributable package... ---" -ForegroundColor Yellow
Compress-Archive -Path $installDir -DestinationPath $packagePath -Force

Write-Host "`n--- librdkafka Build Complete! ---" -ForegroundColor Green
Write-Host "Package ready for upload: $packagePath" -ForegroundColor Green