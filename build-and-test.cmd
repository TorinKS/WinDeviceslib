@echo off
REM ============================================================================
REM WinDevices Build and Test Script
REM ============================================================================
REM This script configures, builds, and runs tests for the WinDevices project
REM including both native C++ and .NET components.
REM
REM Usage:
REM   build-and-test.cmd [debug|release] [options]
REM
REM Arguments:
REM   debug|release - Build configuration (default: debug)
REM
REM Options:
REM   --clean       - Clean before building
REM   --no-test     - Skip running tests
REM   --no-dotnet   - Skip .NET build and tests
REM   --coverage    - Run code coverage after tests
REM   --e2e         - Run E2E tests (requires USB devices)
REM   --install     - Install libraries to CMake install prefix
REM   --help        - Show this help message
REM
REM Examples:
REM   build-and-test.cmd
REM   build-and-test.cmd release
REM   build-and-test.cmd debug --clean --coverage
REM   build-and-test.cmd release --no-test
REM   build-and-test.cmd debug --no-dotnet
REM   build-and-test.cmd release --install
REM ============================================================================

setlocal enabledelayedexpansion

REM Default values
set BUILD_TYPE=debug
set CLEAN_BUILD=0
set RUN_TESTS=1
set RUN_COVERAGE=0
set RUN_E2E=0
set BUILD_DOTNET=1
set RUN_INSTALL=0

REM Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="debug" (
    set BUILD_TYPE=debug
    shift
    goto :parse_args
)
if /i "%~1"=="release" (
    set BUILD_TYPE=release
    shift
    goto :parse_args
)
if /i "%~1"=="--clean" (
    set CLEAN_BUILD=1
    shift
    goto :parse_args
)
if /i "%~1"=="--no-test" (
    set RUN_TESTS=0
    shift
    goto :parse_args
)
if /i "%~1"=="--no-dotnet" (
    set BUILD_DOTNET=0
    shift
    goto :parse_args
)
if /i "%~1"=="--coverage" (
    set RUN_COVERAGE=1
    shift
    goto :parse_args
)
if /i "%~1"=="--e2e" (
    set RUN_E2E=1
    shift
    goto :parse_args
)
if /i "%~1"=="--install" (
    set RUN_INSTALL=1
    shift
    goto :parse_args
)
if /i "%~1"=="--help" (
    echo.
    echo WinDevices Build and Test Script
    echo.
    echo Usage: build-and-test.cmd [debug^|release] [options]
    echo.
    echo Arguments:
    echo   debug^|release - Build configuration (default: debug)
    echo.
    echo Options:
    echo   --clean       - Clean before building
    echo   --no-test     - Skip running tests
    echo   --no-dotnet   - Skip .NET build and tests
    echo   --coverage    - Run code coverage after tests
    echo   --e2e         - Run E2E tests (requires USB devices)
    echo   --install     - Install libraries to CMake install prefix
    echo   --help        - Show this help message
    echo.
    echo Examples:
    echo   build-and-test.cmd
    echo   build-and-test.cmd release
    echo   build-and-test.cmd debug --clean --coverage
    echo   build-and-test.cmd release --no-test
    echo   build-and-test.cmd debug --no-dotnet
    echo   build-and-test.cmd release --install
    echo.
    exit /b 0
)
echo Unknown argument: %~1
exit /b 1

:args_done

REM Set preset name and config
if /i "%BUILD_TYPE%"=="debug" (
    set PRESET=windows-debug
    set CONFIG=Debug
) else (
    set PRESET=windows-release
    set CONFIG=Release
)

echo.
echo ============================================================================
echo WinDevices Build and Test
echo ============================================================================
echo Configuration: %BUILD_TYPE% (%CONFIG%)
echo Clean build:   %CLEAN_BUILD%
echo Run tests:     %RUN_TESTS%
echo Run E2E:       %RUN_E2E%
echo Build .NET:    %BUILD_DOTNET%
echo Coverage:      %RUN_COVERAGE%
echo Install:       %RUN_INSTALL%
echo ============================================================================
echo.

REM Step 1: Configure
echo [1/7] Configuring CMake...
cmake --preset %PRESET%
if errorlevel 1 (
    echo ERROR: CMake configuration failed!
    exit /b 1
)
echo.

REM Step 2: Build Native
echo [2/7] Building native C++ library...
if %CLEAN_BUILD%==1 (
    echo Cleaning previous build...
    cmake --build build\%PRESET% --config %CONFIG% --clean-first
) else (
    cmake --build build\%PRESET% --config %CONFIG%
)
if errorlevel 1 (
    echo ERROR: Native build failed!
    exit /b 1
)
echo Native build completed successfully!
echo.

REM Step 3: Run Native Tests
if %RUN_TESTS%==1 (
    echo [3/7] Running native unit tests...
    build\%PRESET%\bin\%CONFIG%\WinDevicesTests.exe
    if errorlevel 1 (
        echo ERROR: Native unit tests failed!
        exit /b 1
    )
    echo Native unit tests passed!
    echo.

    if %RUN_E2E%==1 (
        echo Running native E2E tests...
        build\%PRESET%\bin\%CONFIG%\WinDevicesE2ETests.exe
        if errorlevel 1 (
            echo ERROR: Native E2E tests failed!
            exit /b 1
        )
        echo Native E2E tests passed!
        echo.
    )
) else (
    echo [3/7] Skipping native tests (--no-test specified)
    echo.
)

REM Step 4: Build .NET Library
if %BUILD_DOTNET%==1 (
    echo [4/7] Building .NET library...

    REM Check if dotnet CLI is available
    where dotnet >nul 2>&1
    if errorlevel 1 (
        echo WARNING: .NET SDK not found. Skipping .NET build.
        echo Install .NET SDK from https://dotnet.microsoft.com/download
        goto :skip_dotnet
    )

    REM Copy native DLL to .NET output directories for P/Invoke
    set NATIVE_DLL=build\!PRESET!\bin\!CONFIG!\WinDevices.dll
    if not exist "!NATIVE_DLL!" (
        echo ERROR: Native DLL not found at !NATIVE_DLL!
        exit /b 1
    )

    REM Build .NET library
    pushd dotnet\WinDevicesNet
    if !CLEAN_BUILD!==1 (
        dotnet clean -c !CONFIG!
    )
    dotnet build -c !CONFIG!
    if errorlevel 1 (
        popd
        echo ERROR: .NET library build failed!
        exit /b 1
    )
    popd
    echo .NET library build completed!

    REM Copy native DLL to .NET output directory
    echo Copying native DLL to .NET output...
    copy /Y "!NATIVE_DLL!" "dotnet\WinDevicesNet\bin\!CONFIG!\net8.0-windows\" >nul
    if errorlevel 1 (
        echo WARNING: Could not copy native DLL to .NET library output
    )

    REM Build .NET tests
    echo Building .NET tests...
    pushd dotnet\WinDevicesNet.Tests
    if !CLEAN_BUILD!==1 (
        dotnet clean -c !CONFIG!
    )
    dotnet build -c !CONFIG!
    if errorlevel 1 (
        popd
        echo ERROR: .NET test build failed!
        exit /b 1
    )
    popd

    REM Copy native DLL to test output directory
    copy /Y "!NATIVE_DLL!" "dotnet\WinDevicesNet.Tests\bin\!CONFIG!\net8.0-windows\" >nul
    if errorlevel 1 (
        echo WARNING: Could not copy native DLL to test output
    )

    echo .NET build completed successfully!
    echo.
) else (
    echo [4/7] Skipping .NET build (--no-dotnet specified)
    echo.
)

REM Step 5: Run .NET Tests
if %BUILD_DOTNET%==1 (
    if !RUN_TESTS!==1 (
        echo [5/7] Running .NET tests...
        pushd dotnet\WinDevicesNet.Tests
        dotnet test -c !CONFIG! --no-build --verbosity normal
        if errorlevel 1 (
            popd
            echo ERROR: .NET tests failed!
            exit /b 1
        )
        popd
        echo .NET tests passed!
        echo.
    ) else (
        echo [5/7] Skipping .NET tests --no-test specified
        echo.
    )
) else (
    echo [5/7] Skipping .NET tests --no-dotnet specified
    echo.
)
goto :after_dotnet

:skip_dotnet
echo [4/7] Skipped .NET build (SDK not found)
echo [5/7] Skipped .NET tests (SDK not found)
echo.

:after_dotnet

REM Step 6: Code Coverage
if %RUN_COVERAGE%==1 (
    echo [6/7] Running code coverage...
    if %RUN_E2E%==1 (
        cmake --build build\%PRESET% --target coverage-all --config %CONFIG%
        if errorlevel 1 (
            echo WARNING: Coverage analysis encountered errors (continuing...)
        )
        echo.
        echo Coverage report generated at:
        echo   build\%PRESET%\coverage\all\index.html
        echo.
        echo Opening coverage report...
        start build\%PRESET%\coverage\all\index.html
    ) else (
        cmake --build build\%PRESET% --target coverage --config %CONFIG%
        if errorlevel 1 (
            echo WARNING: Coverage analysis encountered errors (continuing...)
        )
        echo.
        echo Coverage report generated at:
            echo   build\%PRESET%\coverage\index.html
        echo.
        echo Opening coverage report...
        start build\%PRESET%\coverage\index.html
    )
) else (
    echo [6/7] Skipping coverage (--coverage not specified)
)

REM Step 7: Install
if %RUN_INSTALL%==1 (
    echo.
    echo [7/7] Installing libraries...

    REM Install native library via CMake
    echo Installing native library...
    cmake --install build\%PRESET% --config %CONFIG%
    if errorlevel 1 (
        echo ERROR: Native library installation failed!
        exit /b 1
    )
    echo Native library installed successfully!

    REM Install .NET library if it was built
    if %BUILD_DOTNET%==1 (
        REM Get install prefix from CMake cache
        for /f "tokens=2 delims==" %%a in ('findstr "CMAKE_INSTALL_PREFIX:PATH" build\%PRESET%\CMakeCache.txt') do set INSTALL_PREFIX=%%a

        if defined INSTALL_PREFIX (
            echo Installing .NET library to !INSTALL_PREFIX!\dotnet...
            if not exist "!INSTALL_PREFIX!\dotnet" mkdir "!INSTALL_PREFIX!\dotnet"

            REM Copy .NET DLL
            copy /Y "dotnet\WinDevicesNet\bin\%CONFIG%\net8.0-windows\WinDevicesNet.dll" "!INSTALL_PREFIX!\dotnet\" >nul
            if errorlevel 1 (
                echo WARNING: Could not copy WinDevicesNet.dll
            )

            REM Copy XML documentation if it exists
            if exist "dotnet\WinDevicesNet\bin\%CONFIG%\net8.0-windows\WinDevicesNet.xml" (
                copy /Y "dotnet\WinDevicesNet\bin\%CONFIG%\net8.0-windows\WinDevicesNet.xml" "!INSTALL_PREFIX!\dotnet\" >nul
            )

            REM Copy native DLL to .NET directory for self-contained deployment
            copy /Y "build\%PRESET%\bin\%CONFIG%\WinDevices.dll" "!INSTALL_PREFIX!\dotnet\" >nul
            if errorlevel 1 (
                echo WARNING: Could not copy native DLL to .NET directory
            )

            echo .NET library installed successfully!
        ) else (
            echo WARNING: Could not determine install prefix, skipping .NET installation
        )
    )
    echo.
) else (
    echo [7/7] Skipping installation (--install not specified)
)

echo.
echo ============================================================================
echo Build and test completed successfully!
echo ============================================================================
echo.
echo Build outputs:
echo   Native DLL:  build\%PRESET%\bin\%CONFIG%\WinDevices.dll
if %BUILD_DOTNET%==1 (
    echo   .NET DLL:    dotnet\WinDevicesNet\bin\%CONFIG%\net8.0-windows\WinDevicesNet.dll
)
if %RUN_INSTALL%==1 (
    echo.
    echo Installed to: CMake install prefix (see CMakeCache.txt)
    echo   Native:      lib\WinDevices.dll, include\WinDevices\
    if %BUILD_DOTNET%==1 (
        echo   .NET:        dotnet\WinDevicesNet.dll, dotnet\WinDevices.dll
    )
)
echo.
echo Next steps:
if %RUN_INSTALL%==0 (
    echo   - Run 'build-and-test.cmd %BUILD_TYPE% --install' to install libraries
)
if %RUN_COVERAGE%==0 (
    echo   - Run 'build-and-test.cmd %BUILD_TYPE% --coverage' to generate code coverage
)
echo   - Run 'cmake --build build\%PRESET% --config %CONFIG%' to rebuild native
if %BUILD_DOTNET%==1 (
    echo   - Run 'dotnet build dotnet\WinDevicesNet -c %CONFIG%' to rebuild .NET
)
echo   - Run 'build\%PRESET%\bin\%CONFIG%\WinDevicesTests.exe' to run native tests
if %BUILD_DOTNET%==1 (
    echo   - Run 'dotnet test dotnet\WinDevicesNet.Tests -c %CONFIG%' to run .NET tests
)
echo.

exit /b 0
