// PSVellumPDF.Interop: scans a PDF content stream for q/Q (save/restore graphics state) balance.
using System.Text;

namespace PSVellumPDF.Interop;

/// <summary>
/// Counts q and Q operators in a content stream while skipping everything that could contain the
/// letters q or Q without being an operator: literal strings, hex strings, comments, names and
/// inline image data.
/// </summary>
public static class ContentStreamBalance
{
    /// <summary>Result of a scan: the lowest depth reached and the depth at the end.</summary>
    public readonly record struct Result(int MinDepth, int FinalDepth);

    /// <summary>Scans <paramref name="content"/> and returns the lowest and final q/Q depth.</summary>
    public static Result Scan(byte[] content)
    {
        ArgumentNullException.ThrowIfNull(content);
        var depth = 0;
        var min = 0;
        var i = 0;
        var n = content.Length;
        while (i < n)
        {
            var b = content[i];
            if (IsWhite(b)) { i++; continue; }
            switch ((char)b)
            {
                case '%':
                    while (i < n && content[i] != '\n' && content[i] != '\r') i++;
                    continue;
                case '(':
                    i = SkipLiteralString(content, i);
                    continue;
                case '<':
                    if (i + 1 < n && content[i + 1] == '<') { i += 2; continue; }
                    while (i < n && content[i] != '>') i++;
                    i++;
                    continue;
                case '>':
                case '[':
                case ']':
                case '{':
                case '}':
                case ')':
                    i++;
                    continue;
                case '/':
                    i++;
                    while (i < n && !IsWhite(content[i]) && !IsDelimiter(content[i])) i++;
                    continue;
            }

            var start = i;
            while (i < n && !IsWhite(content[i]) && !IsDelimiter(content[i])) i++;
            var length = i - start;
            if (length == 1 && content[start] == (byte)'q') depth++;
            else if (length == 1 && content[start] == (byte)'Q') { depth--; if (depth < min) min = depth; }
            else if (length == 2 && content[start] == (byte)'B' && content[start + 1] == (byte)'I')
                i = SkipInlineImage(content, i);
        }

        return new Result(min, depth);
    }

    private static bool IsWhite(byte b) => b is 0 or 9 or 10 or 12 or 13 or 32;

    private static bool IsDelimiter(byte b) => b is (byte)'(' or (byte)')' or (byte)'<' or (byte)'>'
        or (byte)'[' or (byte)']' or (byte)'{' or (byte)'}' or (byte)'/' or (byte)'%';

    private static int SkipLiteralString(byte[] c, int i)
    {
        var level = 0;
        while (i < c.Length)
        {
            var b = c[i++];
            if (b == '\\') { i++; continue; }
            if (b == '(') level++;
            else if (b == ')' && --level == 0) break;
        }

        return i;
    }

    // After "BI": key/value pairs, then "ID", a single white byte, binary data, then "EI" delimited by white space.
    private static int SkipInlineImage(byte[] c, int i)
    {
        var n = c.Length;
        while (i + 1 < n)
        {
            if (c[i] == 'I' && c[i + 1] == 'D' && (i == 0 || IsWhite(c[i - 1])) && (i + 2 >= n || IsWhite(c[i + 2])))
            {
                i += 3;
                break;
            }

            i++;
        }

        while (i + 1 < n)
        {
            if (c[i] == 'E' && c[i + 1] == 'I' && IsWhite(c[i - 1]) && (i + 2 >= n || IsWhite(c[i + 2])))
                return i + 2;
            i++;
        }

        return n;
    }
}
