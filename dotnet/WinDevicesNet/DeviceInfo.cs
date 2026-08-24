using System;

namespace WinDevices.Net;

/// <summary>
/// Represents information about a USB device
/// </summary>
public sealed class DeviceInfo
{
    /// <summary>
    /// Gets the device manufacturer name
    /// </summary>
    public string Manufacturer { get; init; } = string.Empty;

    /// <summary>
    /// Gets the product name
    /// </summary>
    public string Product { get; init; } = string.Empty;

    /// <summary>
    /// Gets the device serial number
    /// </summary>
    public string SerialNumber { get; init; } = string.Empty;

    /// <summary>
    /// Gets the device description
    /// </summary>
    public string Description { get; init; } = string.Empty;

    /// <summary>
    /// Gets the device ID
    /// </summary>
    public string DeviceId { get; init; } = string.Empty;

    /// <summary>
    /// Gets the friendly name
    /// </summary>
    public string FriendlyName { get; init; } = string.Empty;

    /// <summary>
    /// Gets the device path
    /// </summary>
    public string DevicePath { get; init; } = string.Empty;

    /// <summary>
    /// Gets the vendor ID (0x0000 if not available)
    /// </summary>
    public uint VendorId { get; init; }

    /// <summary>
    /// Gets the product ID (0x0000 if not available)
    /// </summary>
    public uint ProductId { get; init; }

    /// <summary>
    /// Gets the USB device class code
    /// </summary>
    public uint DeviceClass { get; init; }

    /// <summary>
    /// Gets the USB interface class code (0xFF if not available)
    /// </summary>
    public uint InterfaceClass { get; init; }

    /// <summary>
    /// Gets the USB device subclass code
    /// </summary>
    public uint DeviceSubClass { get; init; }

    /// <summary>
    /// Gets the USB device protocol code
    /// </summary>
    public uint DeviceProtocol { get; init; }

    /// <summary>
    /// Gets a value indicating whether the device is currently connected
    /// </summary>
    public bool IsConnected { get; init; }

    /// <summary>
    /// Gets a value indicating whether this is a USB device
    /// </summary>
    public bool IsUsbDevice { get; init; }

    /// <summary>
    /// Gets the Windows Device Setup Class GUID
    /// </summary>
    public Guid DeviceClassGuid { get; init; }

    /// <summary>
    /// Gets the friendly name of the device class
    /// </summary>
    public string DeviceClassName { get; init; } = string.Empty;

    /// <summary>
    /// Gets the USB-IF registered vendor name (from VID lookup)
    /// </summary>
    public string VendorName { get; init; } = string.Empty;

    /// <summary>
    /// Gets the USB-IF registered product name (from VID/PID lookup)
    /// </summary>
    public string ProductName { get; init; } = string.Empty;

    /// <summary>
    /// Gets the human-readable USB Interface Class name (e.g., "Mass Storage")
    /// </summary>
    public string InterfaceClassName { get; init; } = string.Empty;

    /// <summary>
    /// Returns a string representation of the device
    /// </summary>
    public override string ToString()
    {
        if (!string.IsNullOrEmpty(Product) && !string.IsNullOrEmpty(Manufacturer))
            return $"{Manufacturer} {Product} (SN: {SerialNumber ?? "N/A"})";
        
        if (!string.IsNullOrEmpty(Product))
            return $"{Product} (SN: {SerialNumber ?? "N/A"})";
        
        if (!string.IsNullOrEmpty(SerialNumber))
            return $"Device (SN: {SerialNumber})";
        
        return $"Device (Class: 0x{DeviceClass:X2})";
    }

    internal static DeviceInfo FromNative(Interop.NativeMethods.WdDeviceInfo native)
    {
        var deviceClassGuid = native.DeviceClassGuid.ToGuid();

        return new DeviceInfo
        {
            Manufacturer = Interop.Utf8Buffer.ToStringZ(native.Manufacturer),
            Product = Interop.Utf8Buffer.ToStringZ(native.Product),
            SerialNumber = Interop.Utf8Buffer.ToStringZ(native.SerialNumber),
            Description = Interop.Utf8Buffer.ToStringZ(native.Description),
            DeviceId = Interop.Utf8Buffer.ToStringZ(native.DeviceId),
            FriendlyName = Interop.Utf8Buffer.ToStringZ(native.FriendlyName),
            DevicePath = Interop.Utf8Buffer.ToStringZ(native.DevicePath),
            VendorId = native.VendorId,
            ProductId = native.ProductId,
            DeviceClass = native.DeviceClass,
            InterfaceClass = native.InterfaceClass,
            DeviceSubClass = native.DeviceSubClass,
            DeviceProtocol = native.DeviceProtocol,
            IsConnected = native.IsConnected != 0,
            IsUsbDevice = native.IsUsbDevice != 0,
            DeviceClassGuid = deviceClassGuid,
            DeviceClassName = DeviceClassGuids.GetClassName(deviceClassGuid),
            VendorName = Interop.Utf8Buffer.ToStringZ(native.VendorName),
            ProductName = Interop.Utf8Buffer.ToStringZ(native.ProductName),
            InterfaceClassName = Interop.Utf8Buffer.ToStringZ(native.InterfaceClassName)
        };
    }
}
