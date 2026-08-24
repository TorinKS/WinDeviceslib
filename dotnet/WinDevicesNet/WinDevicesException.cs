using System;
using System.Runtime.InteropServices;
using WinDevices.Net.Interop;

namespace WinDevices.Net;

/// <summary>
/// Error codes returned by WinDevices operations
/// </summary>
public enum WinDevicesErrorCode
{
    /// <summary>
    /// Operation succeeded
    /// </summary>
    Success = 0,
    
    /// <summary>
    /// Invalid device manager handle
    /// </summary>
    InvalidHandle = -1,
    
    /// <summary>
    /// Out of memory
    /// </summary>
    OutOfMemory = -2,
    
    /// <summary>
    /// No devices found
    /// </summary>
    NoDevices = -3,
    
    /// <summary>
    /// Device enumeration failed
    /// </summary>
    EnumFailed = -4,
    
    /// <summary>
    /// Invalid device index
    /// </summary>
    InvalidIndex = -5,
    
    /// <summary>
    /// Null pointer argument
    /// </summary>
    NullPointer = -6,
    
    /// <summary>
    /// Unknown error
    /// </summary>
    Unknown = -99
}

/// <summary>
/// Exception thrown by WinDevices operations
/// </summary>
public class WinDevicesException : Exception
{
    /// <summary>
    /// Gets the error code associated with this exception
    /// </summary>
    public WinDevicesErrorCode ErrorCode { get; }

    internal WinDevicesException(NativeMethods.WdResult errorCode, string message)
        : base(message)
    {
        ErrorCode = (WinDevicesErrorCode)errorCode;
    }

    internal WinDevicesException(NativeMethods.WdResult errorCode, string message, Exception innerException)
        : base(message, innerException)
    {
        ErrorCode = (WinDevicesErrorCode)errorCode;
    }

    internal static void ThrowIfError(NativeMethods.WdResult result)
    {
        if (result == NativeMethods.WdResult.Success)
            return;

        var message = GetErrorMessage(result);
        throw new WinDevicesException(result, message);
    }

    private static string GetErrorMessage(NativeMethods.WdResult errorCode)
    {
        try
        {
            var ptr = NativeMethods.WD_GetErrorMessage(errorCode);
            if (ptr != IntPtr.Zero)
            {
                var msg = System.Runtime.InteropServices.Marshal.PtrToStringUTF8(ptr);
                if (!string.IsNullOrEmpty(msg))
                    return msg;
            }
        }
        catch
        {
            // Fallback to default message
        }

        return errorCode switch
        {
            NativeMethods.WdResult.InvalidHandle => "Invalid device manager handle",
            NativeMethods.WdResult.OutOfMemory => "Out of memory",
            NativeMethods.WdResult.NoDevices => "No devices found",
            NativeMethods.WdResult.EnumFailed => "Device enumeration failed",
            NativeMethods.WdResult.InvalidIndex => "Invalid device index",
            NativeMethods.WdResult.NullPointer => "Null pointer argument",
            _ => $"Unknown error (code: {errorCode})"
        };
    }
}
