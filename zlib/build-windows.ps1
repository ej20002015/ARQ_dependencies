# This script uses vcpkg to build zlib (Debug/Release, Shared)
# and assembles the results into a custom package structure.

# --- Script Parameters ---
param(
    [Parameter(Mandatory,
    HelpMessage="Root directory for the install output")]
    [string]$InstallRootDir,

    [Parameter(Mandatory,
    HelpMessage="Root directory for the Zipped package output")]
    [string]$PackageRootDir,

    [string]$VcpkgRootDir = "$PSScriptRoot\vcpkg" # Default vcpkg location relative to script
)

# Stop the script if any command fails
$ErrorActionPreference = "Stop"

# --- Configuration ---
$scriptDir = $PSScriptRoot
$vcpkgTriplet = "x64-windows" # Build for 64-bit Windows Shared DLLs

$baseName = "zlib-windows-x64"
$installDir = "$InstallRootDir/$baseName"
$packagePath = "$PackageRootDir/$baseName.zip"
$cmakeModule = "zlib.cmake" # Assumes this file is in the script's directory

# --- 1. Setup vcpkg ---
Write-Host "--- Setting up vcpkg ---" -ForegroundColor Yellow
if (-not (Test-Path "$VcpkgRootDir\vcpkg.exe")) {
    if (Test-Path $VcpkgRootDir) {
        Write-Host "--- Bootstrapping existing vcpkg clone ---"
        Push-Location $VcpkgRootDir
        .\bootstrap-vcpkg.bat -disableMetrics
        Pop-Location
    } else {
        Write-Host "--- Cloning vcpkg repository ---" -ForegroundColor Yellow
        git clone https://github.com/microsoft/vcpkg.git $VcpkgRootDir
        Push-Location $VcpkgRootDir
        .\bootstrap-vcpkg.bat -disableMetrics
        Pop-Location
    }
} else {
     Write-Host "--- Using existing vcpkg installation at $VcpkgRootDir ---" -ForegroundColor Yellow
}

# --- 2. Install zlib using vcpkg ---
Write-Host "--- Installing zlib using vcpkg (Triplet: $vcpkgTriplet)... ---" -ForegroundColor Yellow
# This command builds both Debug and Release shared libraries by default
& "$VcpkgRootDir\vcpkg.exe" install "zlib:$vcpkgTriplet" --recurse

# --- 3. Locate Installed Files ---
$vcpkgInstallDir = "$VcpkgRootDir\installed\$vcpkgTriplet"
$vcpkgIncludeDir = "$vcpkgInstallDir\include"
$vcpkgDebugBinDir = "$vcpkgInstallDir\debug\bin"
$vcpkgDebugLibDir = "$vcpkgInstallDir\debug\lib"
$vcpkgReleaseBinDir = "$vcpkgInstallDir\bin"       # Release DLLs are in bin
$vcpkgReleaseLibDir = "$vcpkgInstallDir\lib"       # Release LIBs are in lib

if (-not (Test-Path $vcpkgInstallDir)) {
    Write-Error "vcpkg installation directory not found after install: $vcpkgInstallDir"
    exit 1
}

# --- 4. Create Package Structure ---
Write-Host "`n--- Assembling unified package: $installDir ---" -ForegroundColor Yellow
if (Test-Path $installDir) {
    Write-Host "--- Cleaning existing install directory: $installDir ---" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $installDir
}
New-Item -ItemType Directory -Path "$installDir\include" -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\cmake" -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\debug\bin" -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\debug\lib" -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\release\bin" -Force | Out-Null
New-Item -ItemType Directory -Path "$installDir\release\lib" -Force | Out-Null

# --- 5. Copy Files ---
Write-Host "--- Copying include files... ---" -ForegroundColor Yellow
Copy-Item -Path "$vcpkgIncludeDir\*" -Destination "$installDir\include\" -Recurse -Force

Write-Host "--- Copying Debug libraries (.lib)... ---" -ForegroundColor Yellow
Copy-Item -Path "$vcpkgDebugLibDir\zlibd.lib" -Destination "$installDir\debug\lib\" -Force # vcpkg names it zlibd.lib
# Copy PDBs if they exist
Copy-Item -Path "$vcpkgDebugLibDir\*.pdb" -Destination "$installDir\debug\lib\" -ErrorAction SilentlyContinue

Write-Host "--- Copying Debug binaries (.dll)... ---" -ForegroundColor Yellow
Copy-Item -Path "$vcpkgDebugBinDir\zlibd1.dll" -Destination "$installDir\debug\bin\" -Force # vcpkg names it zlibd1.dll
# Copy PDBs if they exist
Copy-Item -Path "$vcpkgDebugBinDir\*.pdb" -Destination "$installDir\debug\bin\" -ErrorAction SilentlyContinue

Write-Host "--- Copying Release libraries (.lib)... ---" -ForegroundColor Yellow
Copy-Item -Path "$vcpkgReleaseLibDir\zlib.lib" -Destination "$installDir\release\lib\" -Force # vcpkg names it zlib.lib

Write-Host "--- Copying Release binaries (.dll)... ---" -ForegroundColor Yellow
Copy-Item -Path "$vcpkgReleaseBinDir\zlib1.dll" -Destination "$installDir\release\bin\" -Force # vcpkg names it zlib1.dll

# --- 6. Copy Custom CMake Module ---
Write-Host "--- Copying custom zlib.cmake module... ---" -ForegroundColor Yellow
$cmakeModulePath = (Resolve-Path (Join-Path $scriptDir $cmakeModule)).Path
if (-Not (Test-Path $cmakeModulePath)) {
    Write-Error "Could not find '$cmakeModule'. Make sure it's in the same directory as this script."
    exit 1
}
Copy-Item -Path $cmakeModulePath -Destination "$installDir\cmake\zlib.cmake" -Force

# --- 7. Packaging Step ---
Write-Host "`n--- Creating PackageRootDir: $PackageRootDir ---" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $PackageRootDir -ErrorAction SilentlyContinue | Out-Null

Write-Host "`n--- Creating the zlib distributable package (using 7-Zip)... ---" -ForegroundColor Yellow
$parentDir = (Get-Item -Path $installDir).Parent.FullName
$dirName = (Get-Item -Path $installDir).Name
Push-Location -Path $parentDir
& 7z.exe a -tzip -r "$packagePath" "$dirName"
Pop-Location

Write-Host "`n--- zlib Package Complete! ---" -ForegroundColor Green
Write-Host "Package ready for upload: $packagePath" -ForegroundColor Green