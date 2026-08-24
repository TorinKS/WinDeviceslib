using System;
using System.Runtime.InteropServices;

namespace WinDevices.Net.Interop;

/// <summary>
/// P/Invoke declarations for the WinDevices C API
/// </summary>
internal static class NativeMethods
{
    private const string DllName = "WinDevices.dll";

    #region Error Codes

    internal enum WdResult
    {
        Success = 0,
        InvalidHandle = -1,
        OutOfMemory = -2,
        NoDevices = -3,
        EnumFailed = -4,
        InvalidIndex = -5,
        NullPointer = -6,
        Unknown = -99
    }

    #endregion

    #region Structures

    [StructLayout(LayoutKind.Sequential)]
    public struct WdGuid
    {
        public uint Data1;
        public ushort Data2;
        public ushort Data3;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public byte[] Data4;

        public WdGuid(Guid guid)
        {
            var bytes = guid.ToByteArray();
            Data1 = BitConverter.ToUInt32(bytes, 0);
            Data2 = BitConverter.ToUInt16(bytes, 4);
            Data3 = BitConverter.ToUInt16(bytes, 6);
            Data4 = new byte[8];
            Array.Copy(bytes, 8, Data4, 0, 8);
        }

        public Guid ToGuid()
        {
            var bytes = new byte[16];
            BitConverter.GetBytes(Data1).CopyTo(bytes, 0);
            BitConverter.GetBytes(Data2).CopyTo(bytes, 4);
            BitConverter.GetBytes(Data3).CopyTo(bytes, 6);
            Data4.CopyTo(bytes, 8);
            return new Guid(bytes);
        }
    }

    /// <summary>
    /// Mirrors the native WD_DEVICE_INFO struct.
    /// </summary>
    /// <remarks>
    /// The native char[] fields are UTF-8, not ANSI (see WinDevicesAPI.h). They are marshalled
    /// as raw byte buffers and decoded explicitly via <see cref="Utf8Buffer.ToStringZ"/>; using
    /// CharSet.Ansi with ByValTStr here would decode them in the system ANSI codepage and
    /// mangle every non-ASCII character. Field order and sizes must match the native struct
    /// exactly - byte buffers occupy the same space as the ByValTStr fields they replaced,
    /// so the layout is unchanged and remains binary-compatible.
    /// </remarks>
    [StructLayout(LayoutKind.Sequential)]
    public struct WdDeviceInfo
    {
        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256, ArraySubType = UnmanagedType.U1)]
        public byte[] Manufacturer;

        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256, ArraySubType = UnmanagedType.U1)]
        public byte[] Product;

        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256, ArraySubType = UnmanagedType.U1)]
        public byte[] SerialNumber;

        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256, ArraySubType = UnmanagedType.U1)]
        public byte[] Description;

        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 512, ArraySubType = UnmanagedType.U1)]
        public byte[] DeviceId;

        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256, ArraySubType = UnmanagedType.U1)]
        public byte[] FriendlyName;

        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 512, ArraySubType = UnmanagedType.U1)]
        public byte[] DevicePath;

        public uint VendorId;
        public uint ProductId;
        public uint DeviceClass;
        public uint InterfaceClass;
        public uint DeviceSubClass;
        public uint DeviceProtocol;

        [MarshalAs(UnmanagedType.I4)]
        public int IsConnected;

        [MarshalAs(UnmanagedType.I4)]
        public int IsUsbDevice;

        public WdGuid DeviceClassGuid;

        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 128, ArraySubType = UnmanagedType.U1)]
        public byte[] VendorName;

        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 128, ArraySubType = UnmanagedType.U1)]
        public byte[] ProductName;

        /// <summary>UTF-8 bytes, NUL-terminated. Decode with <see cref="Utf8Buffer.ToStringZ"/>.</summary>
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 64, ArraySubType = UnmanagedType.U1)]
        public byte[] InterfaceClassName;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WdVersionInfo
    {
        public int Major;
        public int Minor;
        public int Patch;
        /// <summary>const char* - UTF-8, decoded via Marshal.PtrToStringUTF8.</summary>
        public IntPtr BuildDate;
    }

    #endregion

    #region Device Manager Functions

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_CreateDeviceManager(out IntPtr handle);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_DestroyDeviceManager(IntPtr handle);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_EnumerateUsbDevices(IntPtr handle);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_EnumerateAllDevices(IntPtr handle);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_EnumerateByDeviceClass(IntPtr handle, ref WdGuid classGuid);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_EnumerateUsbMassStorage(IntPtr handle);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_GetDeviceCount(IntPtr handle, out int count);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_GetDeviceInfo(IntPtr handle, int index, out WdDeviceInfo info);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_ClearDevices(IntPtr handle);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern WdResult WD_GetVersion(out WdVersionInfo versionInfo);

    /// <summary>Returns a const char* to a static UTF-8 message; decode with Marshal.PtrToStringUTF8.</summary>
    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr WD_GetErrorMessage(WdResult errorCode);

    #endregion
}
