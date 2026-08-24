using System;
using System.Text;

namespace WinDevices.Net.Interop;

/// <summary>
/// Helpers for decoding the fixed-size UTF-8 buffers used by the native WinDevices C API.
/// </summary>
/// <remarks>
/// Every <c>char[]</c> field in <c>WD_DEVICE_INFO</c> holds UTF-8 (see WinDevicesAPI.h),
/// not text in the system ANSI codepage. Decoding these buffers with the ANSI codepage
/// corrupts all non-ASCII characters, so they are marshalled as raw bytes and decoded here.
/// </remarks>
internal static class Utf8Buffer
{
    /// <summary>
    /// Decodes a NUL-terminated UTF-8 buffer into a string.
    /// </summary>
    /// <param name="buffer">Fixed-size buffer marshalled from native code; may be null.</param>
    /// <returns>
    /// The decoded text up to the first NUL, or <see cref="string.Empty"/> when the buffer is
    /// null or starts with a NUL. If no NUL is present the whole buffer is decoded.
    /// </returns>
    /// <remarks>
    /// Uses the replacement-character fallback rather than throwing, so a malformed buffer
    /// from a mismatched native build degrades gracefully instead of failing enumeration.
    /// </remarks>
    public static string ToStringZ(byte[]? buffer)
    {
        if (buffer is null || buffer.Length == 0)
            return string.Empty;

        int length = Array.IndexOf<byte>(buffer, 0);
        if (length < 0)
            length = buffer.Length;

        return length == 0 ? string.Empty : Encoding.UTF8.GetString(buffer, 0, length);
    }
}
