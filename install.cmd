@echo off
setlocal enabledelayedexpansion

:: WinDevices Library Installation Script
:: ======================================
:: This script builds and installs the WinDevices library.
::
:: Usage:
::   install.cmd [options]
::
:: Options:
::   --prefix PATH     Installation directory (default: C:\Program Files\WinDevices)
::   --config TYPE     Build configuration: Debug or Release (default: Debug)
::   --build-only      Build without installing
::   --clean           Clean build directory before building
::   --no-dotnet       Skip .NET library build and installation
::   --help            Show this help message

set "INSTALL_PREFIX="
set "BUILD_CONFIG=Debug"
set "BUILD_ONLY=0"
set "CLEAN_BUILD=0"
set "BUILD_DIR=build"
set "BUILD_DOTNET=1"

:: Parse command line arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--prefix" (
    set "INSTALL_PREFIX=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--config" (
    set "BUILD_CONFIG=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--build-only" (
    set "BUILD_ONLY=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--clean" (
    set "CLEAN_BUILD=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--no-dotnet" (
    set "BUILD_DOTNET=0"
    shift
    goto :parse_args
)
if /i "%~1"=="--help" (
    goto :show_help
)
echo Unknown option: %~1
goto :show_help

:args_done

echo.
echo ============================================
echo  WinDevices Library Installation
echo ============================================
echo.

:: Check for CMake
where cmake >nul 2>&1
if errorlevel 1 (
    echo ERROR: CMake not found in PATH.
    echo Please install CMake from https://cmake.org/download/
    exit /b 1
)

:: Check for Visual Studio
where cl >nul 2>&1
if errorlevel 1 (
    echo WARNING: Visual Studio compiler not found in PATH.
    echo Please run this script from a Visual Studio Developer Command Prompt.
    echo.
)

:: Clean build if requested
if "%CLEAN_BUILD%"=="1" (
    echo Cleaning build directory...
    if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
)

:: Configure CMake
echo.
echo Configuring CMake...
echo   Build type: %BUILD_CONFIG%
if defined INSTALL_PREFIX (
    echo   Install prefix: %INSTALL_PREFIX%
    cmake -B "%BUILD_DIR%" -DCMAKE_BUILD_TYPE=%BUILD_CONFIG% -DCMAKE_INSTALL_PREFIX="%INSTALL_PREFIX%" -DBUILD_TESTS=OFF -DBUILD_E2E_TESTS=OFF
) else (
    echo   Install prefix: Default ^(C:\Program Files\WinDevices^)
    cmake -B "%BUILD_DIR%" -DCMAKE_BUILD_TYPE=%BUILD_CONFIG% -DBUILD_TESTS=OFF -DBUILD_E2E_TESTS=OFF
)

if errorlevel 1 (
    echo.
    echo ERROR: CMake configuration failed.
    exit /b 1
)

:: Build
echo.
echo Building %BUILD_CONFIG% configuration...
cmake --build "%BUILD_DIR%" --config %BUILD_CONFIG%

if errorlevel 1 (
    echo.
    echo ERROR: Build failed.
    exit /b 1
)

echo.
echo Native build completed successfully.

:: Build .NET library
if "%BUILD_DOTNET%"=="1" (
    echo.
    echo Building .NET library...

    where dotnet >nul 2>&1
    if errorlevel 1 (
        echo WARNING: .NET SDK not found. Skipping .NET build.
        echo Install .NET SDK from https://dotnet.microsoft.com/download
        set "BUILD_DOTNET=0"
        goto :skip_dotnet_build
    )

    pushd dotnet\WinDevicesNet
    if "%CLEAN_BUILD%"=="1" (
        dotnet clean -c %BUILD_CONFIG%
    )
    dotnet build -c %BUILD_CONFIG%
    if errorlevel 1 (
        popd
        echo ERROR: .NET library build failed!
        exit /b 1
    )
    popd

    :: Copy native DLL to .NET output for build verification
    copy /Y "%BUILD_DIR%\bin\%BUILD_CONFIG%\WinDevices.dll" "dotnet\WinDevicesNet\bin\%BUILD_CONFIG%\net8.0-windows\" >nul

    echo .NET library built successfully.
)
:skip_dotnet_build

:: Install if not build-only
if "%BUILD_ONLY%"=="1" (
    echo.
    echo Build-only mode: Skipping installation.
    echo Artifacts are available in: %BUILD_DIR%\bin\%BUILD_CONFIG%
    goto :success
)

echo.
echo Installing...
echo NOTE: Installation to Program Files requires Administrator privileges.
echo.

cmake --install "%BUILD_DIR%" --config %BUILD_CONFIG%

if errorlevel 1 (
    echo.
    echo ERROR: Native installation failed.
    echo Try running this script as Administrator.
    exit /b 1
)

echo Native library installed successfully.

:: Install .NET library
if "%BUILD_DOTNET%"=="1" (
    echo.
    echo Installing .NET library...

    :: Determine install prefix
    if defined INSTALL_PREFIX (
        set "DOTNET_INSTALL_DIR=!INSTALL_PREFIX!\dotnet"
    ) else (
        set "DOTNET_INSTALL_DIR=C:\Program Files\WinDevices\dotnet"
    )

    :: Create dotnet directory
    if not exist "!DOTNET_INSTALL_DIR!" mkdir "!DOTNET_INSTALL_DIR!"

    :: Copy .NET DLL
    copy /Y "dotnet\WinDevicesNet\bin\%BUILD_CONFIG%\net8.0-windows\WinDevicesNet.dll" "!DOTNET_INSTALL_DIR!\" >nul
    if errorlevel 1 (
        echo ERROR: Could not copy WinDevicesNet.dll
        exit /b 1
    )

    :: Copy XML documentation if it exists
    if exist "dotnet\WinDevicesNet\bin\%BUILD_CONFIG%\net8.0-windows\WinDevicesNet.xml" (
        copy /Y "dotnet\WinDevicesNet\bin\%BUILD_CONFIG%\net8.0-windows\WinDevicesNet.xml" "!DOTNET_INSTALL_DIR!\" >nul
    )

    :: Copy native DLL to .NET directory for self-contained deployment
    copy /Y "%BUILD_DIR%\bin\%BUILD_CONFIG%\WinDevices.dll" "!DOTNET_INSTALL_DIR!\" >nul
    if errorlevel 1 (
        echo WARNING: Could not copy native DLL to .NET directory
    )

    echo .NET library installed to: !DOTNET_INSTALL_DIR!
)

:success
echo.
echo ============================================
echo  Installation Complete!
echo ============================================
echo.
if "%BUILD_ONLY%"=="0" (
    if defined INSTALL_PREFIX (
        echo Installed to: %INSTALL_PREFIX%
    ) else (
        echo Installed to: C:\Program Files\WinDevices
    )
    echo.
    echo Installed files:
    echo   bin\WinDevices.dll     - Runtime library
    echo   lib\WinDevices.lib     - Import library
    echo   lib\cmake\WinDevices\  - CMake configuration
    echo   include\WinDevices\    - Header files
    if "%BUILD_DOTNET%"=="1" (
        echo   dotnet\WinDevicesNet.dll - .NET wrapper library
        echo   dotnet\WinDevices.dll    - Native DLL for .NET
    )
    echo.
    echo To use in your CMake project:
    echo   find_package(WinDevices REQUIRED^)
    echo   target_link_libraries(your_target PRIVATE WinDevices::WinDevicesAPI^)
    if "%BUILD_DOTNET%"=="1" (
        echo.
        echo To use from .NET, prefer the NuGet package - it carries the
        echo native WinDevices.dll and needs no installed copy at all:
        echo   dotnet add package WinDevicesNet
        echo.
        echo This machine-wide install is only needed for native C/C++
        echo consumers, or to run the bundled tools against a local build.
    )
)
echo.
exit /b 0

:show_help
echo.
echo WinDevices Library Installation Script
echo ======================================
echo.
echo Usage:
echo   install.cmd [options]
echo.
echo Options:
echo   --prefix PATH     Installation directory
echo                     Default: C:\Program Files\WinDevices
echo   --config TYPE     Build configuration: Debug or Release
echo                     Default: Debug
echo   --build-only      Build without installing
echo   --clean           Clean build directory before building
echo   --no-dotnet       Skip .NET library build and installation
echo   --help            Show this help message
echo.
echo Examples:
echo   install.cmd
echo       Build and install with defaults (native + .NET)
echo.
echo   install.cmd --prefix "C:\SDK\WinDevices"
echo       Install to custom directory
echo.
echo   install.cmd --config Release --build-only
echo       Build release version without installing
echo.
echo   install.cmd --clean --config Release
echo       Clean rebuild and install
echo.
echo   install.cmd --no-dotnet
echo       Build and install native library only
echo.
exit /b 0
