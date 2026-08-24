using System.Runtime.InteropServices;
using System.Text;
using FluentAssertions;
using WinDevices.Net.Interop;
using Xunit;

namespace WinDevicesNet.Tests;

/// <summary>
/// Regression tests for the UTF-8 string boundary between the native C API and .NET.
///
/// The native library writes every WD_DEVICE_INFO char[] field as UTF-8. The managed
/// struct previously declared those fields as CharSet.Ansi/ByValTStr, so the CLR decoded
/// them with the system ANSI codepage and mangled every non-ASCII character
/// (github.com/TorinKS/WinDeviceslib issue #1).
/// </summary>
public class Utf8MarshalingTests
{
    private static byte[] Buffer(string text, int size)
    {
        var buffer = new byte[size];
        Encoding.UTF8.GetBytes(text).CopyTo(buffer, 0);
        return buffer;
    }

    [Theory]
    [InlineData("Billboard-Gerät")]      // the exact product string from issue #1
    [InlineData("Größe")]
    [InlineData("Müller Präzision GmbH")]
    [InlineData("Ünïcödé")]
    public void ToStringZ_WithNonAsciiText_RoundTripsExactly(string original)
    {
        var decoded = Utf8Buffer.ToStringZ(Buffer(original, 256));

        decoded.Should().Be(original);
    }

    [Fact]
    public void ToStringZ_DoesNotProduceAnsiMojibake()
    {
        // What the old CharSet.Ansi marshalling produced on a Western-European codepage.
        var utf8 = Encoding.UTF8.GetBytes("Billboard-Gerät");
        var mojibake = Encoding.Latin1.GetString(utf8);
        mojibake.Should().Be("Billboard-GerÃ¤t", "this is the corruption reported in issue #1");

        Utf8Buffer.ToStringZ(Buffer("Billboard-Gerät", 256))
            .Should().Be("Billboard-Gerät").And.NotBe(mojibake);
    }

    [Fact]
    public void ToStringZ_StopsAtNulAndIgnoresTrailingBytes()
    {
        var buffer = Buffer("Gerät", 32);
        buffer[Encoding.UTF8.GetByteCount("Gerät") + 3] = 0x41; // stale byte past the terminator

        Utf8Buffer.ToStringZ(buffer).Should().Be("Gerät");
    }

    [Fact]
    public void ToStringZ_WithoutNulTerminator_DecodesWholeBuffer()
    {
        Utf8Buffer.ToStringZ(Encoding.UTF8.GetBytes("Gerät")).Should().Be("Gerät");
    }

    [Theory]
    [InlineData(null)]
    [InlineData(new byte[0])]
    [InlineData(new byte[] { 0, 0, 0, 0 })]
    public void ToStringZ_WithEmptyInput_ReturnsEmptyString(byte[]? buffer)
    {
        Utf8Buffer.ToStringZ(buffer).Should().BeEmpty();
    }

    [Fact]
    public void ToStringZ_WithMalformedUtf8_DoesNotThrow()
    {
        // A lone continuation byte - must degrade to U+FFFD rather than fail enumeration.
        var act = () => Utf8Buffer.ToStringZ(new byte[] { 0xC3, 0x00 });

        act.Should().NotThrow();
    }

    /// <summary>
    /// Guards the claim that swapping ByValTStr for byte buffers kept the struct
    /// binary-compatible with the native WD_DEVICE_INFO.
    /// </summary>
    [Fact]
    public void WdDeviceInfo_LayoutMatchesNativeStruct()
    {
        Marshal.SizeOf<NativeMethods.WdDeviceInfo>().Should().Be(2672);

        Offset("Manufacturer").Should().Be(0);
        Offset("Product").Should().Be(256);
        Offset("SerialNumber").Should().Be(512);
        Offset("Description").Should().Be(768);
        Offset("DeviceId").Should().Be(1024);
        Offset("FriendlyName").Should().Be(1536);
        Offset("DevicePath").Should().Be(1792);
        Offset("VendorId").Should().Be(2304);
        Offset("DeviceClassGuid").Should().Be(2336);
        Offset("VendorName").Should().Be(2352);
        Offset("ProductName").Should().Be(2480);
        Offset("InterfaceClassName").Should().Be(2608);

        static int Offset(string field) =>
            Marshal.OffsetOf<NativeMethods.WdDeviceInfo>(field).ToInt32();
    }
}
