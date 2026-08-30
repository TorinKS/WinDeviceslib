# WinDevices

A Windows library for USB device enumeration. Provides both a native C/C++ API and a .NET wrapper.

## Features

- Enumerate USB devices connected to the system
- Query device properties (VID, PID, serial number, manufacturer, product name)
- Enumerate devices by Windows Device Setup Class (keyboards, mice, disk drives, etc.)
- Filter USB mass storage devices
- Query USB hub and port information

## Requirements

### Build Requirements
- Windows 10/11
- Visual Studio 2022 (v143 toolset)
- CMake 3.20+
- .NET 8.0 SDK (optional, for .NET wrapper)

### Runtime Requirements
- Windows 10/11
- Visual C++ Redistributable 2022

## Quick Start

### Building

```cmd
# Build and test (debug configuration)
build-and-test.cmd

# Build release configuration
build-and-test.cmd release

# Build with installation
build-and-test.cmd release --install
```

### Installation

```cmd
# Install to default location (C:\Program Files\WinDevices)
install.cmd

# Install to custom location
install.cmd --prefix "C:\SDK\WinDevices"

# Release build with installation
install.cmd --config Release
```

## Usage

### C/C++ API

```cpp
#include <WinDevices/WinDevicesAPI.h>

// Create device manager
WdDeviceManagerHandle handle;
WD_CreateDeviceManager(&handle);

// Enumerate USB devices
WD_EnumerateUsbDevices(handle);

// Get device count
int count;
WD_GetDeviceCount(handle, &count);

// Get device info
for (int i = 0; i < count; i++) {
    WdDeviceInfo info;
    WD_GetDeviceInfo(handle, i, &info);
    printf("Device: %s (VID=%04X, PID=%04X)\n",
           info.Product, info.VendorId, info.ProductId);
}

// Cleanup
WD_DestroyDeviceManager(handle);
```

### CMake Integration

```cmake
find_package(WinDevices REQUIRED)
target_link_libraries(your_target PRIVATE WinDevices::WinDevicesAPI)
```

### .NET API

```csharp
using WinDevices.Net;

using var manager = new DeviceManager();

// Enumerate USB devices
manager.EnumerateUsbDevices();

// Get all devices
var devices = manager.GetAllDevices();
foreach (var device in devices)
{
    Console.WriteLine($"{device.Product} (VID={device.VendorId:X4}, PID={device.ProductId:X4})");
}

// Enumerate specific device classes
manager.EnumerateKeyboards();
manager.EnumerateDiskDrives();
manager.EnumerateUsbMassStorage();
```

### .NET Project Reference

```cmd
dotnet add package WinDevicesNet
```

```xml
<PackageReference Include="WinDevicesNet" Version="0.1.1" />
```

The package carries the native `WinDevices.dll` under
`runtimes/win-x64/native/`, so a .NET consumer needs no machine-wide
installation. `install.cmd` remains the path for native C/C++ consumers that
use `find_package(WinDevices)`.

## Build Scripts

### build-and-test.cmd

Full build, test, and optional installation script.

```
Usage: build-and-test.cmd [debug|release] [options]

Options:
  --clean       Clean before building
  --no-test     Skip running tests
  --no-dotnet   Skip .NET build and tests
  --coverage    Run code coverage after tests
  --e2e         Run E2E tests (requires USB devices)
  --install     Install libraries to CMake install prefix
  --help        Show help message
```

### install.cmd

Simplified installation script.

```
Usage: install.cmd [options]

Options:
  --prefix PATH     Installation directory (default: C:\Program Files\WinDevices)
  --config TYPE     Build configuration: Debug or Release (default: Debug)
  --build-only      Build without installing
  --clean           Clean build directory before building
  --no-dotnet       Skip .NET library build and installation
  --help            Show help message
```

## Project Structure

```
WinDevicesLib/
├── include/WinDevices/     # Public C/C++ headers
├── src/WinDevices/         # C++ implementation
│   ├── api/                # C API implementation
│   └── core/               # Core library classes
├── tests/
│   ├── unit/               # Unit tests (GoogleTest)
│   └── e2e/                # End-to-end tests
├── dotnet/
│   ├── WinDevicesNet/      # .NET wrapper library
│   ├── WinDevicesNet.Tests/# .NET unit tests
│   └── TestConsole/        # .NET test application
├── build-and-test.cmd      # Build and test script
├── install.cmd             # Installation script
└── CMakeLists.txt          # CMake configuration
```

## Installed Files

After installation, the following files are available:

```
<install_prefix>/
├── bin/
│   └── WinDevices.dll      # Runtime library
├── lib/
│   ├── WinDevices.lib      # Import library
│   └── cmake/WinDevices/   # CMake configuration
├── include/WinDevices/     # Header files
└── dotnet/
    ├── WinDevicesNet.dll   # .NET wrapper
    ├── WinDevicesNet.xml   # XML documentation
    └── WinDevices.dll      # Native DLL for .NET
```

## API Reference

### C API Functions

| Function | Description |
|----------|-------------|
| `WD_CreateDeviceManager` | Create a new device manager instance |
| `WD_DestroyDeviceManager` | Destroy device manager and free resources |
| `WD_EnumerateUsbDevices` | Enumerate all USB devices |
| `WD_EnumerateAllDevices` | Enumerate all devices (USB and non-USB) |
| `WD_EnumerateByDeviceClass` | Enumerate devices by setup class GUID |
| `WD_EnumerateUsbMassStorage` | Enumerate USB mass storage devices only |
| `WD_GetDeviceCount` | Get number of enumerated devices |
| `WD_GetDeviceInfo` | Get device information by index |
| `WD_ClearDevices` | Clear enumerated device list |
| `WD_GetVersion` | Get API version information |
| `WD_GetErrorMessage` | Get error message for result code |

### Common Device Class GUIDs

| Class | GUID | Description |
|-------|------|-------------|
| USB | `{36FC9E60-C465-11CF-8056-444553540000}` | USB controllers and devices |
| DiskDrive | `{4D36E967-E325-11CE-BFC1-08002BE10318}` | Disk drives |
| Keyboard | `{4D36E96B-E325-11CE-BFC1-08002BE10318}` | Keyboards |
| Mouse | `{4D36E96F-E325-11CE-BFC1-08002BE10318}` | Mouse devices |
| Net | `{4D36E972-E325-11CE-BFC1-08002BE10318}` | Network adapters |
| Media | `{4D36E96C-E325-11CE-BFC1-08002BE10318}` | Media devices |
| Image | `{6BDD1FC6-810F-11D0-BEC7-08002BE2092F}` | Imaging devices |
| Bluetooth | `{E0CBF06C-CD8B-4647-BB8A-263B43F0F974}` | Bluetooth devices |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Contact

For bug reports or feature requests, please use the [GitHub Issues](https://github.com/TorinKS/WinDevicesLib/issues) page.
