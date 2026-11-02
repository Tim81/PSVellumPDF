// PSVellumPDF.Interop: wraps still-encoded image data extracted from a PDF into standalone files.
using System.Buffers.Binary;

namespace PSVellumPDF.Interop;

/// <summary>
/// Builds standalone files around image codestreams that a PDF stores without their container:
/// CCITT fax data becomes a single-strip TIFF and an embedded JBIG2 stream becomes a sequential
/// JBIG2 file (ITU-T T.88 annex D.4).
/// </summary>
public static class ImageContainers
{
    /// <summary>
    /// Wraps CCITT data in a TIFF, or returns null when TIFF cannot represent the parameters
    /// (K &lt; 0 with byte-aligned rows has no TIFF equivalent).
    /// </summary>
    /// <param name="width">Image width in pixels (the /Columns entry, or the image width).</param>
    /// <param name="height">Image height in pixels.</param>
    /// <param name="k">PDF /K: negative for Group 4, 0 for 1-D Group 3, positive for mixed 2-D Group 3.</param>
    /// <param name="blackIs1">PDF /BlackIs1, already combined with an inverting /Decode array.</param>
    /// <param name="byteAlign">PDF /EncodedByteAlign.</param>
    /// <param name="endOfLine">PDF /EndOfLine: whether the rows are separated by EOL codes.</param>
    /// <param name="data">The CCITT-encoded bytes.</param>
    /// <remarks>
    /// TIFF Compression 3 (Group 3 fax) requires an EOL code before every row, so Group 3 data without them
    /// cannot be written as such. The one exception is one-dimensional data with byte-aligned rows and no EOLs,
    /// which is TIFF Compression 2 (CCITT modified Huffman RLE). Other combinations return null.
    /// Dimensions above 100,000 pixels return null (no reader opens such a file).
    /// </remarks>
    public static byte[]? BuildCcittTiff(int width, int height, int k, bool blackIs1, bool byteAlign, bool endOfLine, byte[] data)
    {
        ArgumentNullException.ThrowIfNull(data);
        if (width <= 0 || height <= 0 || width > 100_000 || height > 100_000) return null;
        if (k < 0 && byteAlign) return null;
        var modifiedHuffman = k == 0 && byteAlign && !endOfLine;
        if (k >= 0 && !endOfLine && !modifiedHuffman) return null;

        var group4 = k < 0;
        // Photometric 1 (BlackIsZero) for BlackIs1 = true and 0 (WhiteIsZero) otherwise. Checked against
        // poppler's rendering of PDFs that embed CCITT TIFFs (pixel-identical): a PDF's /BlackIs1 describes
        // the filter output, which the TIFF decoder reads through the opposite photometric convention.
        var photometric = (ushort)(blackIs1 ? 1 : 0);
        var entries = new List<(ushort Tag, ushort Type, uint Value)>
        {
            (256, 4, (uint)width),
            (257, 4, (uint)height),
            (258, 3, 1),
            (259, 3, group4 ? 4u : modifiedHuffman ? 2u : 3u),
            (262, 3, photometric),
            (273, 4, 0),          // StripOffsets, patched below
            (277, 3, 1),
            (278, 4, (uint)height),
            (279, 4, (uint)data.Length),
        };
        if (!modifiedHuffman)
            entries.Add(((ushort)(292 + (group4 ? 1 : 0)), 4, group4 ? 0u : (uint)((k > 0 ? 1 : 0) | (byteAlign ? 4 : 0))));

        // Header (8) + IFD (2 + 12 * n + 4) + data.
        var ifdSize = 2 + 12 * entries.Count + 4;
        var dataOffset = 8 + ifdSize;
        var file = new byte[dataOffset + data.Length];
        file[0] = (byte)'I'; file[1] = (byte)'I';
        BinaryPrimitives.WriteUInt16LittleEndian(file.AsSpan(2), 42);
        BinaryPrimitives.WriteUInt32LittleEndian(file.AsSpan(4), 8);
        BinaryPrimitives.WriteUInt16LittleEndian(file.AsSpan(8), (ushort)entries.Count);
        var position = 10;
        foreach (var (tag, type, value) in entries)
        {
            BinaryPrimitives.WriteUInt16LittleEndian(file.AsSpan(position), tag);
            BinaryPrimitives.WriteUInt16LittleEndian(file.AsSpan(position + 2), type);
            BinaryPrimitives.WriteUInt32LittleEndian(file.AsSpan(position + 4), 1);
            var v = tag == 273 ? (uint)dataOffset : value;
            if (type == 3) BinaryPrimitives.WriteUInt16LittleEndian(file.AsSpan(position + 8), (ushort)v);
            else BinaryPrimitives.WriteUInt32LittleEndian(file.AsSpan(position + 8), v);
            position += 12;
        }

        // Next-IFD offset stays 0.
        data.CopyTo(file.AsSpan(dataOffset));
        return file;
    }

    /// <summary>
    /// Builds a sequential JBIG2 file from the embedded-form segments a PDF stores plus the optional
    /// /JBIG2Globals segments. Adds end-of-page and end-of-file segments when the stream lacks them.
    /// Returns null when the segment headers cannot be parsed.
    /// </summary>
    public static byte[]? BuildJbig2File(byte[] embedded, byte[]? globals)
    {
        ArgumentNullException.ThrowIfNull(embedded);
        var globalSegments = globals is { Length: > 0 } ? ParseSegments(globals) : new List<Segment>();
        var pageSegments = ParseSegments(embedded);
        if (globalSegments is null || pageSegments is null || pageSegments.Count == 0) return null;

        using var output = new MemoryStream();
        output.Write(new byte[] { 0x97, 0x4A, 0x42, 0x32, 0x0D, 0x0A, 0x1A, 0x0A });
        output.WriteByte(0x01); // sequential organisation, page count known
        var pageCount = new byte[4];
        BinaryPrimitives.WriteUInt32BigEndian(pageCount, 1);
        output.Write(pageCount);

        uint highest = 0;
        var hasEndOfPage = false;
        var hasEndOfFile = false;
        foreach (var segment in globalSegments.Concat(pageSegments))
        {
            output.Write(segment.Bytes);
            highest = Math.Max(highest, segment.Number);
            hasEndOfPage |= segment.Type == 49;
            hasEndOfFile |= segment.Type == 51;
        }

        if (!hasEndOfPage) WriteEmptySegment(output, ++highest, 49, 1);
        if (!hasEndOfFile) WriteEmptySegment(output, ++highest, 51, 0);
        return output.ToArray();
    }

    private readonly record struct Segment(uint Number, int Type, byte[] Bytes);

    private static void WriteEmptySegment(Stream output, uint number, int type, byte pageAssociation)
    {
        Span<byte> header = stackalloc byte[11];
        BinaryPrimitives.WriteUInt32BigEndian(header, number);
        header[4] = (byte)type;
        header[5] = 0;
        header[6] = pageAssociation;
        BinaryPrimitives.WriteUInt32BigEndian(header[7..], 0);
        output.Write(header);
    }

    // Walks segment headers (T.88 7.2): number, flags, referred-to segments, page association, data length.
    private static List<Segment>? ParseSegments(byte[] data)
    {
        var list = new List<Segment>();
        long i = 0;
        while (i < data.Length)
        {
            var start = (int)i;
            if (i + 6 > data.Length) return null;
            var number = BinaryPrimitives.ReadUInt32BigEndian(data.AsSpan((int)i));
            var flags = data[i + 4];
            var type = flags & 0x3F;
            var largePage = (flags & 0x40) != 0;
            i += 5;
            var countByte = data[i];
            long count = countByte >> 5;
            if (count == 7)
            {
                if (i + 4 > data.Length) return null;
                count = BinaryPrimitives.ReadUInt32BigEndian(data.AsSpan((int)i)) & 0x1FFFFFFF;
                i += 4 + (count + 8) / 8;
            }
            else
            {
                i += 1;
            }

            var referenceSize = number <= 256 ? 1 : number <= 65536 ? 2 : 4;
            i += count * referenceSize;
            i += largePage ? 4 : 1;
            if (i + 4 > data.Length) return null;
            var length = BinaryPrimitives.ReadUInt32BigEndian(data.AsSpan((int)i));
            i += 4;
            if (length == 0xFFFFFFFF) return null; // unknown length (immediate generic regions in streams) is not handled
            if (i + (long)length > data.Length) return null;
            i += length;
            list.Add(new Segment(number, type, data.AsSpan(start, (int)i - start).ToArray()));
        }

        return list;
    }
}
