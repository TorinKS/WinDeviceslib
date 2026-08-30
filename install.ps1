<#
.SYNOPSIS
    Builds and installs the WinDevices library.

.DESCRIPTION
    Configures and builds the native library with CMake, optionally builds the
    .NET wrapper, and installs both to a prefix.

    The default prefix is user-writable and needs no elevation. It is chosen by
    CMakeLists.txt, not repeated here: this script reads back what CMake
    actually configured, so the two cannot drift apart.

    For consuming the library, prefer not installing at all:
      .NET  - dotnet add package WinDevicesNet
      CMake - FetchContent against a release tag

    This script exists for native C/C++ consumers who want find_package, and to
    run the bundled tools against a local build.

.PARAMETER Prefix
    Installation directory. Defaults to the user-writable location chosen by
    CMakeLists.txt. A system-wide prefix such as "C:\Program Files\WinDevices"
    works too, but requires an elevated shell.

.PARAMETER Config
    Build configuration, Debug or Release. Defaults to Debug.

.PARAMETER BuildOnly
    Build without installing.

.PARAMETER Clean
    Remove the build directory before configuring.

.PARAMETER NoDotnet
    Skip the .NET wrapper entirely.

.EXAMPLE
    .\install.ps1
    Build and install Debug to the default user-writable prefix.

.EXAMPLE
    .\install.ps1 -Config Release
    Build and install Release.

.EXAMPLE
    .\install.ps1 -Prefix C:\SDK\WinDevices -Config Release

.EXAMPLE
    .\install.ps1 -Config Release -BuildOnly
    Build without installing.
#>

[CmdletBinding()]
param(
    [string] $Prefix,
    [ValidateSet('Debug', 'Release')]
    [string] $Config = 'Debug',
    [switch] $BuildOnly,
    [switch] $Clean,
    [switch] $NoDotnet,

    # The batch installer this replaces took GNU-style flags, and callers
    # still spell them that way. Collect anything PowerShell could not bind
    # and translate it below, so `--prefix x --config Release` keeps working.
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $LegacyArgs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($LegacyArgs) {
    for ($i = 0; $i -lt $LegacyArgs.Count; $i++) {
        $arg = $LegacyArgs[$i]
        switch -regex ($arg) {
            '^--prefix$'     { $Prefix    = $LegacyArgs[++$i]; continue }
            '^--config$'     { $Config    = $LegacyArgs[++$i]; continue }
            '^--build-only$' { $BuildOnly = $true;             continue }
            '^--clean$'      { $Clean     = $true;             continue }
            '^--no-dotnet$'  { $NoDotnet  = $true;             continue }
            '^--help$'       { Get-Help $PSCommandPath -Detailed; exit 0 }
            default          { throw "Unknown option '$arg'. Run with -? for usage." }
        }
    }
    # ValidateSet ran before the translation, so check the late assignment too.
    if ($Config -notin @('Debug', 'Release')) {
        throw "Invalid -Config '$Config'. Expected Debug or Release."
    }
}

$RepoRoot = $PSScriptRoot
$BuildDir = Join-Path $RepoRoot 'build'

function Write-Section {
    param([string] $Text)
    Write-Host ''
    Write-Host '============================================'
    Write-Host " $Text"
    Write-Host '============================================'
    Write-Host ''
}

# Native tools report failure through the exit code, not through exceptions,
# so every invocation has to be checked explicitly.
function Invoke-Checked {
    param(
        [Parameter(Mandatory)] [string]   $What,
        [Parameter(Mandatory)] [scriptblock] $Command
    )
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$What failed with exit code $LASTEXITCODE."
    }
}

function Get-CMakeCacheValue {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $CacheDir
    )
    $cache = Join-Path $CacheDir 'CMakeCache.txt'
    if (-not (Test-Path $cache)) { return $null }
    # Entries look like: CMAKE_INSTALL_PREFIX:PATH=C:/Users/x/AppData/Local/WinDevices
    $line = Select-String -Path $cache -Pattern "^$([regex]::Escape($Name)):" -SimpleMatch:$false |
            Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Line -split '=', 2)[1]
}

Write-Section 'WinDevices Library Installation'

# --- Prerequisites -----------------------------------------------------------

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    throw 'CMake was not found on PATH. Install it from https://cmake.org/download/'
}

if (-not (Get-Command cl -ErrorAction SilentlyContinue)) {
    Write-Warning 'The MSVC compiler (cl.exe) is not on PATH. If configuration fails, run this from a Visual Studio Developer PowerShell.'
}

$dotnetAvailable = [bool] (Get-Command dotnet -ErrorAction SilentlyContinue)
if (-not $NoDotnet -and -not $dotnetAvailable) {
    Write-Warning 'The .NET SDK was not found on PATH. Skipping the .NET wrapper. Install it from https://dotnet.microsoft.com/download'
    $NoDotnet = $true
}

# --- Configure ---------------------------------------------------------------

if ($Clean -and (Test-Path $BuildDir)) {
    Write-Host "Cleaning $BuildDir ..."
    Remove-Item -Recurse -Force $BuildDir
}

Write-Host 'Configuring CMake ...'
Write-Host "  Build type   : $Config"

$configureArgs = @(
    '-B', $BuildDir,
    "-DCMAKE_BUILD_TYPE=$Config",
    '-DBUILD_TESTS=OFF',
    '-DBUILD_E2E_TESTS=OFF'
)
if ($Prefix) {
    Write-Host "  Install prefix: $Prefix"
    $configureArgs += "-DCMAKE_INSTALL_PREFIX=$Prefix"
} else {
    Write-Host '  Install prefix: default (chosen by CMakeLists.txt, user-writable)'
}

Invoke-Checked 'CMake configuration' { cmake @configureArgs }

# Report the prefix CMake actually settled on rather than a copy of the default
# kept in this script. Duplicating it is how the old installer came to advertise
# a path it no longer used.
$resolvedPrefix = Get-CMakeCacheValue -Name 'CMAKE_INSTALL_PREFIX' -CacheDir $BuildDir
if ($resolvedPrefix) {
    Write-Host "  Resolved to  : $resolvedPrefix"
}

# --- Build native ------------------------------------------------------------

Write-Host ''
Write-Host "Building the native library ($Config) ..."
Invoke-Checked 'Native build' { cmake --build $BuildDir --config $Config --parallel }
Write-Host 'Native build completed.'

$nativeDll = Join-Path $BuildDir "bin\$Config\WinDevices.dll"
if (-not (Test-Path $nativeDll)) {
    throw "The native build reported success but $nativeDll is missing."
}

# --- Build .NET wrapper ------------------------------------------------------

$managedOutDir = $null
if (-not $NoDotnet) {
    Write-Host ''
    Write-Host 'Building the .NET wrapper ...'

    $wrapperProject = Join-Path $RepoRoot 'dotnet\WinDevicesNet\WinDevicesNet.csproj'
    if ($Clean) {
        Invoke-Checked 'dotnet clean' { dotnet clean $wrapperProject -c $Config }
    }
    Invoke-Checked 'dotnet build' { dotnet build $wrapperProject -c $Config }

    # Locate the output by searching rather than by hard-coding the target
    # framework. The old installer spelled out net8.0 in eight places, and every
    # one of them broke silently when the project moved to net8.0-windows.
    $managedDll = Get-ChildItem -Path (Join-Path $RepoRoot "dotnet\WinDevicesNet\bin\$Config") `
                                -Filter 'WinDevicesNet.dll' -Recurse -File |
                  Select-Object -First 1
    if (-not $managedDll) {
        throw "dotnet build reported success but WinDevicesNet.dll was not found under dotnet\WinDevicesNet\bin\$Config."
    }
    $managedOutDir = $managedDll.Directory.FullName

    # The wrapper P/Invokes WinDevices.dll, so put it beside the assembly for
    # local runs. Package consumers do not need this: the NuGet package carries
    # the native library under runtimes/win-x64/native/.
    Copy-Item $nativeDll $managedOutDir -Force

    Write-Host ".NET wrapper built: $($managedDll.FullName)"
}

# --- Install -----------------------------------------------------------------

if ($BuildOnly) {
    Write-Section 'Build complete (install skipped)'
    Write-Host "Native artifacts: $(Join-Path $BuildDir "bin\$Config")"
    if ($managedOutDir) { Write-Host "Managed artifacts: $managedOutDir" }
    exit 0
}

Write-Host ''
Write-Host 'Installing ...'
Invoke-Checked 'CMake install' { cmake --install $BuildDir --config $Config }
Write-Host 'Native library installed.'

if (-not $NoDotnet) {
    $dotnetTarget = Join-Path $resolvedPrefix 'dotnet'
    New-Item -ItemType Directory -Force -Path $dotnetTarget | Out-Null

    Copy-Item (Join-Path $managedOutDir 'WinDevicesNet.dll') $dotnetTarget -Force

    $xmlDoc = Join-Path $managedOutDir 'WinDevicesNet.xml'
    if (Test-Path $xmlDoc) { Copy-Item $xmlDoc $dotnetTarget -Force }

    Copy-Item $nativeDll $dotnetTarget -Force

    Write-Host ".NET wrapper installed to: $dotnetTarget"
}

# --- Summary -----------------------------------------------------------------

Write-Section 'Installation complete'

Write-Host "Installed to: $resolvedPrefix"
Write-Host ''
Write-Host 'Installed files:'
Write-Host '  bin\WinDevices.dll     - Runtime library'
Write-Host '  lib\WinDevices.lib     - Import library'
Write-Host '  lib\cmake\WinDevices\  - CMake package configuration'
Write-Host '  include\WinDevices\    - Public headers'
if (-not $NoDotnet) {
    Write-Host '  dotnet\WinDevicesNet.dll - .NET wrapper'
    Write-Host '  dotnet\WinDevices.dll    - Native library for the wrapper'
}

Write-Host ''
Write-Host 'To consume from CMake:'
Write-Host "  cmake -DCMAKE_PREFIX_PATH=`"$resolvedPrefix`" ..."
Write-Host '  find_package(WinDevices REQUIRED)'
Write-Host '  target_link_libraries(your_target PRIVATE WinDevices::API)'

if (-not $NoDotnet) {
    Write-Host ''
    Write-Host 'To consume from .NET, do not use this install. The package carries'
    Write-Host 'the native library and needs nothing on the machine:'
    Write-Host '  dotnet add package WinDevicesNet'
}
Write-Host ''
