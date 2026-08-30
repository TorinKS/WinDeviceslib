# WinDevicesNet - Quick Start Guide

Get started with WinDevicesNet in 5 minutes.

## Installation

### Option 1: Using install.cmd (Recommended)

```cmd
# From WinDevicesLib root directory
install.cmd

# Or for release build
install.cmd --config Release
```

This installs to `C:\Program Files\WinDevices`.

### Option 2: Using build-and-test.cmd

```cmd
# Build and install
build-and-test.cmd release --install
```

### Add Reference to Your Project

```cmd
dotnet add package WinDevicesNet
```

which adds:

```xml
<ItemGroup>
  <PackageReference Include="WinDevicesNet" Version="0.1.1" />
</ItemGroup>
```

The native `WinDevices.dll` travels inside the package, so nothing has to be
installed on the machine and no `HintPath` is needed.

## Your First Program

Create a new console application:

```csharp
using WinDevices.Net;

// Create and enumerate devices
using var manager = new DeviceManager();
manager.EnumerateUsbDevices();

// Display all devices
Console.WriteLine($"Found {manager.GetDeviceCount()} USB devices:\n");
foreach (var device in manager.GetAllDevices())
{
    Console.WriteLine(device);
}
```

Run your program to see all USB devices.

## Common Tasks

### Find a specific device

```csharp
using var manager = new DeviceManager();
manager.EnumerateUsbDevices();

// By serial number
var device = manager.FindDeviceBySerialNumber("ABC123456");
if (device != null)
{
    Console.WriteLine($"Found: {device.Product}");
}

// By vendor ID (e.g., Microsoft = 0x045E)
var devices = manager.FindDevices(d => d.VendorId == 0x045E);
Console.WriteLine($"Found {devices.Count} Microsoft devices");
```

### Get detailed information

```csharp
using var manager = new DeviceManager();
manager.EnumerateUsbDevices();

foreach (var device in manager.GetAllDevices())
{
    Console.WriteLine($"Manufacturer: {device.Manufacturer}");
    Console.WriteLine($"Product:      {device.Product}");
    Console.WriteLine($"Serial:       {device.SerialNumber}");
    Console.WriteLine($"VID:PID:      {device.VendorId:X4}:{device.ProductId:X4}");
    Console.WriteLine();
}
```

### Filter by device class

```csharp
using var manager = new DeviceManager();
manager.EnumerateUsbDevices();

// Find all mass storage devices (USB drives)
var drives = manager.FindDevices(d => d.DeviceClass == 0x08);

// Find all keyboards/mice (HID devices)
var hid = manager.FindDevices(d => d.DeviceClass == 0x03);

Console.WriteLine($"Storage: {drives.Count}, HID: {hid.Count}");
```

### Enumerate specific device types

```csharp
using var manager = new DeviceManager();

// Enumerate only keyboards
manager.EnumerateKeyboards();
Console.WriteLine($"Found {manager.GetDeviceCount()} keyboard(s)");

// Clear and enumerate disk drives
manager.ClearDevices();
manager.EnumerateDiskDrives();
Console.WriteLine($"Found {manager.GetDeviceCount()} disk drive(s)");

// Enumerate USB mass storage only
manager.ClearDevices();
manager.EnumerateUsbMassStorage();
Console.WriteLine($"Found {manager.GetDeviceCount()} USB mass storage device(s)");
```

### Handle errors

```csharp
try
{
    using var manager = new DeviceManager();
    manager.EnumerateUsbDevices();

    var device = manager.GetDeviceInfo(0);
    Console.WriteLine(device);
}
catch (WinDevicesException ex)
{
    Console.WriteLine($"Error: {ex.Message}");
    Console.WriteLine($"Error code: {ex.ErrorCode}");
}
```

## Device Class Reference

Quick reference for common USB device classes:

| Class | Code | Examples |
|-------|------|----------|
| HID | 0x03 | Keyboards, mice, game controllers |
| Mass Storage | 0x08 | USB drives, external HDDs |
| Video | 0x0E | Webcams, video capture devices |
| Wireless | 0xE0 | Bluetooth adapters |
| Miscellaneous | 0xEF | Multi-function devices |

## Next Steps

- Read the full [README](README.md) for detailed API documentation
- Check out [EXAMPLES.md](EXAMPLES.md) for real-world scenarios
- Review the test projects for more usage patterns

## Troubleshooting

**"Cannot find WinDevices.dll"**
- Run `install.cmd` from the WinDevicesLib root directory
- Check that `C:\Program Files\WinDevices\dotnet\` contains `WinDevices.dll`
- Install Visual C++ Redistributable 2022

**"No devices found"**
- Run as Administrator (some USB operations require elevated privileges)
- Check that USB devices are actually connected
- Try `EnumerateAllDevices()` instead of `EnumerateUsbDevices()`

**"Access denied"**
- Run your application as Administrator
- Some protected devices require specific permissions

## Minimal Working Example

Save this as `Program.cs`:

```csharp
using WinDevices.Net;

Console.WriteLine("WinDevicesNet - Quick Start\n");

try
{
    using var manager = new DeviceManager();
    Console.WriteLine($"API Version: {DeviceManager.GetVersion()}\n");

    manager.EnumerateUsbDevices();
    var count = manager.GetDeviceCount();

    Console.WriteLine($"Found {count} USB device(s):\n");

    for (int i = 0; i < count; i++)
    {
        var device = manager.GetDeviceInfo(i);
        Console.WriteLine($"{i + 1}. {device}");
    }
}
catch (Exception ex)
{
    Console.WriteLine($"Error: {ex.Message}");
}

Console.WriteLine("\nPress any key to exit...");
Console.ReadKey();
```

Create a `.csproj` file:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="WinDevicesNet" Version="0.1.1" />
  </ItemGroup>
</Project>
```

Run with `dotnet run`.

## Support

- Full documentation: [README.md](README.md)
- Code examples: [EXAMPLES.md](EXAMPLES.md)
- Main project: [WinDevicesLib README](../../README.md)
- Issues: [GitHub Issues](https://github.com/TorinKS/WinDevicesLib/issues)
