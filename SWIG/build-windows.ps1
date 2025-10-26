# This script downloads the SWIG toolset and packages it into a package

# --- Script Parameters ---
param(
    [Parameter(Mandatory,
    HelpMessage="Version of SWIG, e.g., '4.3.1'")]
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
$sourceDir = "SWIG"
$baseName = "SWIG-$Version-windows-x64"
$buildDir = "$BuildRootDir/$baseName"
$installDir = "$InstallRootDir/$baseName"
$packagePath = "$PackageRootDir/$baseName.zip"

# --- Download SWIG for windows ---

if (-Not (Test-Path -Path $BuildRootDir)) {
    Write-Host "`n--- Creating BuildRootDir: $BuildRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BuildRootDir | Out-Null
}

if (-Not (Test-Path -Path $buildDir)) {
    Write-Host "`n--- Creating buildDir: $buildDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

$zipDownloadPath = "$buildDir\SWIG$Version.zip"
if (Test-Path $zipDownloadPath) {
    Write-Host "--- Skipping SWIG download, using existing zip ---" -ForegroundColor Yellow
} else {
    Write-Host "--- Downloading SWIG ---" -ForegroundColor Yellow
    Invoke-WebRequest -UserAgent "Wget" -Uri https://sourceforge.net/projects/swig/files/swigwin/swigwin-$Version/swigwin-$Version.zip/download -OutFile $zipDownloadPath
}

# --- Unzip download and create package ---

if (-Not (Test-Path -Path $InstallRootDir)) {
    Write-Host "`n--- Creating InstallRootDir: $InstallRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $InstallRootDir | Out-Null
}

if (Test-Path $installDir) {
    Write-Host "--- Cleaning existing install directory: $installDir ---" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $installDir
}
New-Item -ItemType Directory -Path $installDir | Out-Null
Expand-Archive $zipDownloadPath $installDir\SWIG
Copy-Item -Path "$installDir\SWIG\swigwin-$Version\*" -Destination "$installDir\SWIG" -Recurse
Remove-Item -Recurse -Force "$installDir\SWIG\swigwin-$Version"

& "$installDir\SWIG\swig.exe" -version | Out-Null
if ($LastExitCode -ne 0) {
    Write-Host "Error: '$installDir\SWIG\swig.exe --version' command failed - SWIG wasn't downloaded correctly - exiting" -ForegroundColor Red
    exit 1
}

# Add cmake file
New-Item -ItemType Directory -Path "$installDir\cmake" | Out-Null
Copy-Item -Path "SWIG.cmake" -Destination "$installDir\cmake\SWIG.cmake" -Force

# --- Packaging Step ---

if (-Not (Test-Path -Path $PackageRootDir)) {
    Write-Host "`n--- Creating PackageRootDir: $PackageRootDir ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $PackageRootDir | Out-Null
}

Write-Host "`n--- Creating the SWIG distributable package... ---" -ForegroundColor Yellow
Compress-Archive -Path $installDir -DestinationPath $packagePath -Force

Write-Host "`n--- SWIG Build Complete! ---" -ForegroundColor Green
Write-Host "Package ready for upload: $packagePath" -ForegroundColor Green