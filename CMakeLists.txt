cmake_minimum_required(VERSION 3.20)

# Git-based versioning
option(REQUIRE_GIT_TAG "Require Git tag for versioning" OFF)

find_package(Git QUIET)
if(GIT_FOUND AND REQUIRE_GIT_TAG)
  execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --tags --abbrev=0
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_TAG
    ERROR_VARIABLE GIT_ERROR
    RESULT_VARIABLE GIT_RESULT
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  if(NOT GIT_RESULT EQUAL 0)
    message(FATAL_ERROR "Git tag not found. Please create a Git tag for versioning.")
  else()
    message(STATUS "Git tag found: ${GIT_TAG}")
    string(REGEX REPLACE "^v" "" GIT_TAG ${GIT_TAG})
  endif()
elseif(GIT_FOUND)
  # Try to get tag, but use fallback if not found
  execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --tags --abbrev=0
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_TAG
    ERROR_VARIABLE GIT_ERROR
    RESULT_VARIABLE GIT_RESULT
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  if(NOT GIT_RESULT EQUAL 0)
    message(WARNING "Git tag not found. Using default version 0.1.0")
    set(GIT_TAG "0.1.0")
  else()
    message(STATUS "Git tag found: ${GIT_TAG}")
    string(REGEX REPLACE "^v" "" GIT_TAG ${GIT_TAG})
  endif()
else()
  message(WARNING "Git not found. Using default version 0.1.0")
  set(GIT_TAG "0.1.0")
endif()

# Parse version components
string(REPLACE "." ";" VERSION_LIST ${GIT_TAG})
list(GET VERSION_LIST 0 PROJECT_VERSION_MAJOR)
list(GET VERSION_LIST 1 PROJECT_VERSION_MINOR)
list(LENGTH VERSION_LIST VERSION_LIST_LENGTH)
if(VERSION_LIST_LENGTH GREATER 2)
  list(GET VERSION_LIST 2 PROJECT_VERSION_PATCH)
else()
  set(PROJECT_VERSION_PATCH 0)
endif()

project(WinDevices
  VERSION ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}
  LANGUAGES CXX C)

message(STATUS "${PROJECT_NAME} version: ${PROJECT_VERSION}")

# Set install prefix
#
# User-writable by default, not Program Files. Building a library should not
# require administrator rights, and a machine-global prefix holds exactly one
# version, so two projects on different versions cannot coexist. It also
# pushes consumers into absolute paths: an artifact outside the project can
# only be named absolutely, which is how HintPath entries to
# C:\Program Files\WinDevices ended up in this repository and downstream.
#
# This follows what the surrounding ecosystem does. NuGet resolves to
# %USERPROFILE%\.nuget\packages, its caches to %LOCALAPPDATA%, none of them
# elevated, all of them side-by-side per version.
#
# A machine-wide install remains available, but as a deliberate choice:
#   cmake --install build --prefix "C:/Program Files/WinDevices"
#   install.cmd --prefix "C:\Program Files\WinDevices"
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  if(WIN32)
    if(DEFINED ENV{LOCALAPPDATA})
      set(_wd_default_prefix "$ENV{LOCALAPPDATA}/${PROJECT_NAME}")
    else()
      set(_wd_default_prefix "$ENV{USERPROFILE}/.local/${PROJECT_NAME}")
    endif()
    set(CMAKE_INSTALL_PREFIX "${_wd_default_prefix}" CACHE PATH "Installation directory" FORCE)
    unset(_wd_default_prefix)
  elseif(UNIX AND NOT APPLE)
    set(CMAKE_INSTALL_PREFIX "$ENV{HOME}/.local" CACHE PATH "Installation directory" FORCE)
  endif()
endif()

message(STATUS "Installation directory: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  (override with -DCMAKE_INSTALL_PREFIX=<path>; no elevation is required for the default)")

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Options
option(BUILD_TESTS "Build unit tests" ON)
option(BUILD_E2E_TESTS "Build end-to-end tests" ON)
option(BUILD_SHARED_LIBS "Build shared libraries" OFF)
option(ENABLE_COVERAGE "Enable code coverage" ON)

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# MSVC specific flags
if(MSVC)
    add_compile_options(/W4 /WX- /permissive- /Zc:__cplusplus)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS UNICODE _UNICODE)

    # Enable debug information for code coverage
    # Debug builds already have debug info, but Release builds need explicit flags
    if(ENABLE_COVERAGE AND CMAKE_BUILD_TYPE STREQUAL "Release")
        add_compile_options(/Zi)
        add_link_options(/DEBUG /OPT:REF /OPT:ICF)
    endif()
endif()

# Include FetchContent for dependencies
include(FetchContent)

# Set extern directory as the base for all fetched content
set(FETCHCONTENT_BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/extern)

# Save CMAKE_INSTALL_PREFIX to restore after FetchContent
set(ORIGINAL_CMAKE_INSTALL_PREFIX ${CMAKE_INSTALL_PREFIX})

# Fetch spdlog for logging
FetchContent_Declare(
    spdlog
    GIT_REPOSITORY https://github.com/gabime/spdlog.git
    GIT_TAG v1.15.0
    SOURCE_DIR ${FETCHCONTENT_BASE_DIR}/spdlog
)
set(SPDLOG_INSTALL OFF CACHE BOOL "Disable installation of spdlog" FORCE)
FetchContent_MakeAvailable(spdlog)

# Fetch WIL (Windows Implementation Libraries) for modern C++ Windows wrappers
FetchContent_Declare(
    wil
    GIT_REPOSITORY https://github.com/microsoft/wil.git
    GIT_TAG v1.0.250325.1
    SOURCE_DIR ${FETCHCONTENT_BASE_DIR}/wil
)
# WIL is header-only, configure it appropriately
set(WIL_BUILD_PACKAGING OFF CACHE BOOL "" FORCE)
set(WIL_BUILD_TESTS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(wil)

# Fetch Google Test if building tests
if(BUILD_TESTS OR BUILD_E2E_TESTS)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.15.2
        SOURCE_DIR ${FETCHCONTENT_BASE_DIR}/googletest
    )
    # For Windows: Prevent overriding the parent project's compiler/linker settings
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of Google Test" FORCE)
    FetchContent_MakeAvailable(googletest)

    enable_testing()
    include(GoogleTest)
endif()

# Restore CMAKE_INSTALL_PREFIX
set(CMAKE_INSTALL_PREFIX ${ORIGINAL_CMAKE_INSTALL_PREFIX})

# Add subdirectories
add_subdirectory(src/WinDevices)

if(BUILD_TESTS OR BUILD_E2E_TESTS)
    add_subdirectory(tests)
endif()

# OpenCppCoverage integration for code coverage
if(ENABLE_COVERAGE)
    set(OPENCPPCOVERAGE_SEARCH_PATHS
        "$ENV{ProgramFiles}/OpenCppCoverage"
        "$ENV{ProgramFiles\(x86\)}/OpenCppCoverage"
        "$ENV{ProgramW6432}/OpenCppCoverage"
        "$ENV{LOCALAPPDATA}/Programs/OpenCppCoverage"
        "$ENV{ChocolateyInstall}/lib/opencppcoverage/tools"
    )

    if(DEFINED ENV{OPENCPPCOVERAGE_PATH})
        set(OpenCppCoverage_EXECUTABLE "$ENV{OPENCPPCOVERAGE_PATH}")
    else()
        foreach(SEARCH_PATH ${OPENCPPCOVERAGE_SEARCH_PATHS})
            if(EXISTS "${SEARCH_PATH}/OpenCppCoverage.exe")
                set(OpenCppCoverage_EXECUTABLE "${SEARCH_PATH}/OpenCppCoverage.exe")
                break()
            endif()
        endforeach()

        if(NOT DEFINED OpenCppCoverage_EXECUTABLE)
            find_program(OpenCppCoverage_EXECUTABLE "OpenCppCoverage.exe")
        endif()
    endif()

    if(OpenCppCoverage_EXECUTABLE)
        message(STATUS "Found OpenCppCoverage: ${OpenCppCoverage_EXECUTABLE}")
        string(REPLACE "/" "\\" SOURCES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/WinDevices")
        string(REPLACE "/" "\\" INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include/WinDevices")
        string(REPLACE "/" "\\" COVERAGE_DIR "${CMAKE_BINARY_DIR}/coverage")
        string(REPLACE "/" "\\" OPENCPPCOVERAGE_PATH "${OpenCppCoverage_EXECUTABLE}")

        # Coverage target for unit tests
        if(BUILD_TESTS)
            add_custom_target(coverage
                COMMAND ${OPENCPPCOVERAGE_PATH}
                    --export_type=html:${COVERAGE_DIR}
                    --sources=${SOURCES_DIR}
                    --sources=${INCLUDE_DIR}
                    --verbose
                    --cover_children
                    --
                    "$<TARGET_FILE:WinDevicesTests>" || (exit 0)
                DEPENDS WinDevicesTests
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                COMMENT "Running code coverage analysis for unit tests..."
                VERBATIM
            )
            message(STATUS "Coverage target 'coverage' configured for unit tests")
        endif()

        # Coverage target for E2E tests
        if(BUILD_E2E_TESTS)
            add_custom_target(coverage-e2e
                COMMAND ${OPENCPPCOVERAGE_PATH}
                    --export_type=html:${COVERAGE_DIR}/e2e
                    --sources=${SOURCES_DIR}
                    --sources=${INCLUDE_DIR}
                    --verbose
                    --cover_children
                    --
                    "$<TARGET_FILE:WinDevicesE2ETests>" || (exit 0)
                DEPENDS WinDevicesE2ETests
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                COMMENT "Running code coverage analysis for E2E tests..."
                VERBATIM
            )
            message(STATUS "Coverage target 'coverage-e2e' configured for E2E tests")
        endif()

        # Combined coverage target (both unit and E2E tests)
        if(BUILD_TESTS AND BUILD_E2E_TESTS)
            add_custom_target(coverage-all
                COMMAND ${OPENCPPCOVERAGE_PATH}
                    --export_type=html:${COVERAGE_DIR}/all
                    --export_type=cobertura:${COVERAGE_DIR}/all/coverage.xml
                    --sources=${SOURCES_DIR}
                    --sources=${INCLUDE_DIR}
                    --verbose
                    --cover_children
                    --
                    "$<TARGET_FILE:WinDevicesTests>"
                COMMAND ${OPENCPPCOVERAGE_PATH}
                    --export_type=html:${COVERAGE_DIR}/all
                    --export_type=cobertura:${COVERAGE_DIR}/all/coverage.xml
                    --sources=${SOURCES_DIR}
                    --sources=${INCLUDE_DIR}
                    --verbose
                    --cover_children
                    --continue_after_cpp_exception
                    --
                    "$<TARGET_FILE:WinDevicesE2ETests>" || (exit 0)
                DEPENDS WinDevicesTests WinDevicesE2ETests
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                COMMENT "Running combined code coverage analysis (unit + E2E tests)..."
                VERBATIM
            )
            message(STATUS "Coverage target 'coverage-all' configured for combined unit and E2E tests")
        endif()
    else()
        message(WARNING "OpenCppCoverage not found. Coverage targets will not be available.")
        message(WARNING "To enable coverage, install OpenCppCoverage from: https://github.com/OpenCppCoverage/OpenCppCoverage/releases")
        message(WARNING "Or install via Chocolatey: choco install opencppcoverage")
    endif()
endif()

# =============================================================================
# Installation Configuration
# =============================================================================

include(CMakePackageConfigHelpers)

# Configure version header
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/include/WinDevices/Version.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/include/WinDevices/Version.h"
    @ONLY
)

# Install generated version header
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/include/WinDevices/Version.h"
    DESTINATION include/WinDevices
    COMPONENT WinDevices
)

# Configure package config file
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/WinDevicesConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/WinDevicesConfig.cmake"
    INSTALL_DESTINATION lib/cmake/WinDevices
)

# Generate version file
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/WinDevicesConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

# Install package config files
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/WinDevicesConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/WinDevicesConfigVersion.cmake"
    DESTINATION lib/cmake/WinDevices
    COMPONENT WinDevices
)

# Export targets for build tree
export(EXPORT WinDevicesTargets
    FILE "${CMAKE_CURRENT_BINARY_DIR}/WinDevicesTargets.cmake"
    NAMESPACE WinDevices::
)

# Install exported targets
install(EXPORT WinDevicesTargets
    FILE WinDevicesTargets.cmake
    NAMESPACE WinDevices::
    DESTINATION lib/cmake/WinDevices
    COMPONENT WinDevices
)

# Component-specific install target
add_custom_target(install_WinDevices
    COMMAND ${CMAKE_COMMAND}
        -DCMAKE_INSTALL_COMPONENT=WinDevices
        -DCMAKE_INSTALL_CONFIG_NAME=$<CONFIG>
        -P "${CMAKE_BINARY_DIR}/cmake_install.cmake"
    COMMENT "Installing WinDevices components only"
)
