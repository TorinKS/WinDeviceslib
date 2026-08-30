# WinDevicesNet - .NET Wrapper for WinDevices

A modern .NET 8.0 wrapper for the WinDevices USB enumeration library. This library provides a clean, type-safe C# API for enumerating and querying USB devices on Windows.

## Features

- **Simple API**: Clean, idiomatic C# interface
- **Type-safe**: Strongly-typed device information with nullable reference types
- **Exception-based**: Proper error handling with custom exceptions
- **LINQ-friendly**: Query devices with standard LINQ operators
- **IDisposable**: Proper resource management following .NET best practices
- **Well-tested**: Comprehensive unit and integration tests
- **Thread-safe**: Safe to use with multiple DeviceManager instances

## Installation

```cmd
dotnet add package WinDevicesNet
```

That is the whole story. The package ships the native `WinDevices.dll` under
`runtimes/win-x64/native/`, so the .NET SDK records it in your `deps.json` and
the runtime loads it from your build output. You do **not** need to install
anything machine-wide, add a `HintPath`, or copy the native library yourself.

Target `net8.0-windows` or later. The library wraps the Windows Setup and
Device Management APIs and only runs on Windows x64.

```xml
<ItemGroup>
  <PackageReference Include="WinDevicesNet" Version="0.1.1" />
</ItemGroup>
```

### Installing the native library machine-wide

`install.cmd` copies the native library, headers, import library, and CMake
package config to `C:\Program Files\WinDevices`. This is for **native C/C++
consumers** using `find_package(WinDevices)`. .NET projects do not need it.

```cmd
install.cmd --config Release
```

### Manual Build

```cmd
cd dotnet\WinDevicesNet
dotnet build -c Release
```

The compiled library will be in `bin/Release/net8.0-windows/WinDevicesNet.dll`

## Usage

### Quick Start

```csharp
using WinDevices.Net;

// Create device manager (use using for automatic cleanup)
using var manager = new DeviceManager();

// Enumerate USB devices
manager.EnumerateUsbDevices();

// Print all devices
foreach (var device in manager.GetAllDevices())
{
    Console.WriteLine(device); // Uses ToString() for smart formatting
}
```

### Basic Enumeration

```csharp
using WinDevices.Net;

using var manager = new DeviceManager();
manager.EnumerateUsbDevices();

var devices = manager.GetAllDevices();

foreach (var device in devices)
{
    Console.WriteLine($"{device.Manufacturer} {device.Product}");
    Console.WriteLine($"Serial Number: {device.SerialNumber}");
    Console.WriteLine($"VID: 0x{device.VendorId:X4}, PID: 0x{device.ProductId:X4}");
    Console.WriteLine();
}
```

### Finding Specific Devices

```csharp
// Find by serial number
var device = manager.FindDeviceBySerialNumber("ABC123456");

// Find by predicate
var massStorageDevices = manager.FindDevices(d => d.DeviceClass == 0x08);

// Using LINQ
var logitechDevices = manager.GetAllDevices()
    .Where(d => d.VendorId == 0x046D)
    .ToList();
```

### Enumerate by Device Class

```csharp
using var manager = new DeviceManager();

// Enumerate keyboards only
manager.EnumerateKeyboards();

// Or enumerate disk drives
manager.EnumerateDiskDrives();

// Or USB mass storage devices
manager.EnumerateUsbMassStorage();

foreach (var device in manager.GetAllDevices())
{
    Console.WriteLine($"{device.Product} (VID={device.VendorId:X4}, PID={device.ProductId:X4})");
}
```

### Error Handling

```csharp
try
{
    using var manager = new DeviceManager();
    manager.EnumerateUsbDevices();

    var device = manager.GetDeviceInfo(0);
    Console.WriteLine($"First device: {device}");
}
catch (WinDevicesException ex) when (ex.ErrorCode == WinDevicesErrorCode.InvalidHandle)
{
    Console.WriteLine("Invalid device manager handle");
}
catch (WinDevicesException ex) when (ex.ErrorCode == WinDevicesErrorCode.InvalidIndex)
{
    Console.WriteLine("Device index out of range");
}
catch (WinDevicesException ex)
{
    Console.WriteLine($"Device enumeration error {ex.ErrorCode}: {ex.Message}");
}
```

## API Reference

### DeviceManager Class

Main class for USB device enumeration and management.

#### Constructor
- `DeviceManager()` - Creates a new device manager instance

#### Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `EnumerateUsbDevices()` | Enumerate all USB devices | void |
| `EnumerateAllDevices()` | Enumerate all devices (USB and non-USB) | void |
| `EnumerateByDeviceClass(Guid classGuid)` | Enumerate devices by setup class GUID | void |
| `EnumerateKeyboards()` | Enumerate keyboard devices | void |
| `EnumerateDiskDrives()` | Enumerate disk drive devices | void |
| `EnumerateUsbMassStorage()` | Enumerate USB mass storage devices only | void |
| `GetDeviceCount()` | Get count of enumerated devices | int |
| `GetDeviceInfo(int index)` | Get device information by zero-based index | DeviceInfo |
| `GetAllDevices()` | Get all enumerated devices as a list | List&lt;DeviceInfo&gt; |
| `FindDevices(Func<DeviceInfo, bool> predicate)` | Find devices matching predicate | List&lt;DeviceInfo&gt; |
| `FindDeviceBySerialNumber(string serialNumber)` | Find first device with matching serial number | DeviceInfo? |
| `ClearDevices()` | Clear the list of enumerated devices | void |
| `Dispose()` | Release native resources | void |

#### Static Methods
- `GetVersion()` - Returns API version string (e.g., "1.0.0")

### DeviceInfo Class

Immutable class containing USB device information.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `Manufacturer` | string? | Device manufacturer name |
| `Product` | string? | Product name |
| `SerialNumber` | string? | Serial number |
| `Description` | string? | Device description |
| `DeviceId` | string? | Windows device ID |
| `FriendlyName` | string? | Windows friendly name |
| `DevicePath` | string? | Device path for direct access |
| `VendorId` | uint | USB Vendor ID (VID) |
| `ProductId` | uint | USB Product ID (PID) |
| `DeviceClass` | uint | USB device class code |
| `DeviceSubClass` | uint | USB device subclass code |
| `DeviceProtocol` | uint | USB device protocol code |
| `IsConnected` | bool | Whether device is currently connected |
| `IsUsbDevice` | bool | Whether this is a USB device |

### WinDevicesException Class

Custom exception for device enumeration errors.

#### Properties
- `ErrorCode` - The `WinDevicesErrorCode` enum value
- `Message` - Human-readable error message

#### Error Codes

| Code | Value | Description |
|------|-------|-------------|
| `Success` | 0 | Operation succeeded |
| `InvalidHandle` | -1 | Invalid device manager handle |
| `OutOfMemory` | -2 | Memory allocation failed |
| `NotImplemented` | -3 | Feature not implemented |
| `InvalidParameter` | -4 | Invalid parameter provided |
| `InvalidIndex` | -5 | Device index out of range |
| `DeviceNotFound` | -6 | Device not found |
| `Unknown` | -999 | Unknown error |

## Common Device Class GUIDs

| Class | GUID | Description |
|-------|------|-------------|
| USB | `{36FC9E60-C465-11CF-8056-444553540000}` | USB controllers and devices |
| DiskDrive | `{4D36E967-E325-11CE-BFC1-08002BE10318}` | Disk drives |
| Keyboard | `{4D36E96B-E325-11CE-BFC1-08002BE10318}` | Keyboards |
| Mouse | `{4D36E96F-E325-11CE-BFC1-08002BE10318}` | Mouse devices |
| Net | `{4D36E972-E325-11CE-BFC1-08002BE10318}` | Network adapters |
| Bluetooth | `{E0CBF06C-CD8B-4647-BB8A-263B43F0F974}` | Bluetooth devices |

## USB Device Classes

Common USB device class codes:

| Class | Code | Description |
|-------|------|-------------|
| Audio | 0x01 | Audio devices (speakers, microphones) |
| CDC | 0x02 | Communications devices |
| HID | 0x03 | Human Interface Devices (keyboards, mice) |
| Mass Storage | 0x08 | USB flash drives, external HDDs |
| Hub | 0x09 | USB hubs |
| Video | 0x0E | Video devices (webcams) |
| Wireless | 0xE0 | Wireless controllers (Bluetooth) |

## Best Practices

### Resource Management

Always use `using` statements:

```csharp
// Good - Automatic cleanup
using var manager = new DeviceManager();
manager.EnumerateUsbDevices();
```

### Error Handling

Catch specific error codes when appropriate:

```csharp
try
{
    var device = manager.GetDeviceInfo(index);
}
catch (WinDevicesException ex) when (ex.ErrorCode == WinDevicesErrorCode.InvalidIndex)
{
    return null;
}
```

### Performance

Enumerate once, query multiple times:

```csharp
// Good - Single enumeration
manager.EnumerateUsbDevices();
var allDevices = manager.GetAllDevices();
var storage = allDevices.Where(d => d.DeviceClass == 0x08);
var hid = allDevices.Where(d => d.DeviceClass == 0x03);
```

## Troubleshooting

### DllNotFoundException

**Problem**: `System.DllNotFoundException: Unable to load DLL 'WinDevices.dll'`

**Solutions**:
1. Ensure `WinDevices.dll` is installed (run `install.cmd`)
2. Check that the DLL is in `C:\Program Files\WinDevices\dotnet\`
3. Install [Visual C++ Redistributable 2022](https://aka.ms/vs/17/release/vc_redist.x64.exe)

### No Devices Found

**Problem**: `GetDeviceCount()` returns 0 after enumeration

**Solutions**:
1. Run application as Administrator (required for some USB operations)
2. Ensure USB devices are actually connected
3. Check Windows Device Manager for driver issues

### Access Denied

**Problem**: Enumeration fails with access errors

**Solutions**:
1. Run as Administrator
2. Check Windows permissions for USB device access

## Requirements

- **.NET 8.0 or later**
- **Windows 10/11**
- **Visual C++ Redistributable 2022**

## Testing

```cmd
cd dotnet\WinDevicesNet.Tests
dotnet test
```

The test suite includes unit tests, integration tests, and error handling tests.

## Related Documentation

- [Quick Start Guide](QUICKSTART.md)
- [Code Examples](EXAMPLES.md)
- [Main Project README](../../README.md)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](../../LICENSE) file for details.

## Support

For bug reports or feature requests, please use the [GitHub Issues](https://github.com/TorinKS/WinDevicesLib/issues) page.
