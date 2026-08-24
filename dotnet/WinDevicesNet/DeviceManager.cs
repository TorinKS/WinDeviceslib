using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using WinDevices.Net.Interop;

namespace WinDevices.Net;

/// <summary>
/// Manages USB device enumeration and provides device information
/// </summary>
public sealed class DeviceManager : IDisposable
{
    private IntPtr _handle;
    private bool _disposed;

    /// <summary>
    /// Initializes a new instance of the DeviceManager class
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if device manager creation fails</exception>
    public DeviceManager()
    {
        var result = NativeMethods.WD_CreateDeviceManager(out _handle);
        WinDevicesException.ThrowIfError(result);
    }

    /// <summary>
    /// Enumerates all USB devices
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateUsbDevices()
    {
        ThrowIfDisposed();
        var result = NativeMethods.WD_EnumerateUsbDevices(_handle);
        WinDevicesException.ThrowIfError(result);
    }

    /// <summary>
    /// Enumerates all devices (USB and non-USB)
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateAllDevices()
    {
        ThrowIfDisposed();
        var result = NativeMethods.WD_EnumerateAllDevices(_handle);
        WinDevicesException.ThrowIfError(result);
    }

    /// <summary>
    /// Enumerates devices by Windows Device Setup Class GUID
    /// </summary>
    /// <param name="deviceClassGuid">The device setup class GUID to enumerate</param>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateByDeviceClass(Guid deviceClassGuid)
    {
        ThrowIfDisposed();
        var wdGuid = new Interop.NativeMethods.WdGuid(deviceClassGuid);
        var result = NativeMethods.WD_EnumerateByDeviceClass(_handle, ref wdGuid);
        WinDevicesException.ThrowIfError(result);
    }

    /// <summary>
    /// Enumerates external USB mass storage devices only (USB flash drives, external hard drives)
    /// </summary>
    /// <remarks>
    /// This method filters USB devices to return only those with USB interface class 0x08 (Mass Storage).
    /// Useful for DLP solutions that need to monitor removable storage devices.
    /// </remarks>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateUsbMassStorage()
    {
        ThrowIfDisposed();
        var result = NativeMethods.WD_EnumerateUsbMassStorage(_handle);
        WinDevicesException.ThrowIfError(result);
    }

    /// <summary>
    /// Enumerates all media devices (sound, video, game controllers)
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateMediaDevices()
    {
        EnumerateByDeviceClass(DeviceClassGuids.Media);
    }

    /// <summary>
    /// Enumerates all modem devices
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateModems()
    {
        EnumerateByDeviceClass(DeviceClassGuids.Modem);
    }

    /// <summary>
    /// Enumerates all keyboard devices
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateKeyboards()
    {
        EnumerateByDeviceClass(DeviceClassGuids.Keyboard);
    }

    /// <summary>
    /// Enumerates all mouse devices
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateMice()
    {
        EnumerateByDeviceClass(DeviceClassGuids.Mouse);
    }

    /// <summary>
    /// Enumerates all disk drive devices
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateDiskDrives()
    {
        EnumerateByDeviceClass(DeviceClassGuids.DiskDrive);
    }

    /// <summary>
    /// Enumerates all network adapter devices
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateNetworkAdapters()
    {
        EnumerateByDeviceClass(DeviceClassGuids.Net);
    }

    /// <summary>
    /// Enumerates all Bluetooth devices
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateBluetoothDevices()
    {
        EnumerateByDeviceClass(DeviceClassGuids.Bluetooth);
    }

    /// <summary>
    /// Enumerates all image devices (cameras, scanners)
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if enumeration fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void EnumerateImageDevices()
    {
        EnumerateByDeviceClass(DeviceClassGuids.Image);
    }

    /// <summary>
    /// Gets the count of enumerated devices
    /// </summary>
    /// <returns>The number of enumerated devices</returns>
    /// <exception cref="WinDevicesException">Thrown if the operation fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public int GetDeviceCount()
    {
        ThrowIfDisposed();
        var result = NativeMethods.WD_GetDeviceCount(_handle, out int count);
        WinDevicesException.ThrowIfError(result);
        return count;
    }

    /// <summary>
    /// Gets device information by index
    /// </summary>
    /// <param name="index">Zero-based device index</param>
    /// <returns>Device information</returns>
    /// <exception cref="WinDevicesException">Thrown if the operation fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    /// <exception cref="ArgumentOutOfRangeException">Thrown if index is negative</exception>
    public DeviceInfo GetDeviceInfo(int index)
    {
        if (index < 0)
            throw new ArgumentOutOfRangeException(nameof(index), "Index must be non-negative");

        ThrowIfDisposed();
        var result = NativeMethods.WD_GetDeviceInfo(_handle, index, out var info);
        WinDevicesException.ThrowIfError(result);
        return DeviceInfo.FromNative(info);
    }

    /// <summary>
    /// Gets all enumerated devices
    /// </summary>
    /// <returns>A list of all enumerated devices</returns>
    /// <exception cref="WinDevicesException">Thrown if the operation fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public IReadOnlyList<DeviceInfo> GetAllDevices()
    {
        ThrowIfDisposed();
        int count = GetDeviceCount();
        var devices = new List<DeviceInfo>(count);

        for (int i = 0; i < count; i++)
        {
            devices.Add(GetDeviceInfo(i));
        }

        return devices;
    }

    /// <summary>
    /// Finds devices matching the specified predicate
    /// </summary>
    /// <param name="predicate">The predicate to match devices</param>
    /// <returns>A list of matching devices</returns>
    /// <exception cref="ArgumentNullException">Thrown if predicate is null</exception>
    /// <exception cref="WinDevicesException">Thrown if the operation fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public IReadOnlyList<DeviceInfo> FindDevices(Func<DeviceInfo, bool> predicate)
    {
        ArgumentNullException.ThrowIfNull(predicate);
        return GetAllDevices().Where(predicate).ToList();
    }

    /// <summary>
    /// Finds a device by serial number
    /// </summary>
    /// <param name="serialNumber">The serial number to search for</param>
    /// <returns>The device info if found, otherwise null</returns>
    /// <exception cref="ArgumentNullException">Thrown if serialNumber is null</exception>
    /// <exception cref="WinDevicesException">Thrown if the operation fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public DeviceInfo? FindDeviceBySerialNumber(string serialNumber)
    {
        ArgumentNullException.ThrowIfNull(serialNumber);
        return GetAllDevices().FirstOrDefault(d => 
            d.SerialNumber.Equals(serialNumber, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>
    /// Clears all enumerated devices
    /// </summary>
    /// <exception cref="WinDevicesException">Thrown if the operation fails</exception>
    /// <exception cref="ObjectDisposedException">Thrown if the manager has been disposed</exception>
    public void ClearDevices()
    {
        ThrowIfDisposed();
        var result = NativeMethods.WD_ClearDevices(_handle);
        WinDevicesException.ThrowIfError(result);
    }

    /// <summary>
    /// Gets the API version information
    /// </summary>
    /// <returns>Version information</returns>
    public static (int Major, int Minor, int Patch, string BuildDate) GetVersion()
    {
        var result = NativeMethods.WD_GetVersion(out var versionInfo);
        WinDevicesException.ThrowIfError(result);

        string buildDate = string.Empty;
        if (versionInfo.BuildDate != IntPtr.Zero)
        {
            buildDate = Marshal.PtrToStringUTF8(versionInfo.BuildDate) ?? string.Empty;
        }

        return (versionInfo.Major, versionInfo.Minor, versionInfo.Patch, buildDate);
    }

    private void ThrowIfDisposed()
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(DeviceManager));
    }

    /// <summary>
    /// Releases all resources used by the DeviceManager
    /// </summary>
    public void Dispose()
    {
        if (_disposed)
            return;

        if (_handle != IntPtr.Zero)
        {
            NativeMethods.WD_DestroyDeviceManager(_handle);
            _handle = IntPtr.Zero;
        }

        _disposed = true;
        GC.SuppressFinalize(this);
    }

    /// <summary>
    /// Finalizer
    /// </summary>
    ~DeviceManager()
    {
        Dispose();
    }
}
