// PSVellumPDF.Interop: scans a PDF content stream for the balance of q/Q (graphics state), BT/ET (text objects)
// and BMC/BDC/EMC (marked content).
using System.Text;

namespace PSVellumPDF.Interop;

/// <summary>
/// Counts the paired operators q/Q, BT/ET and BMC|BDC/EMC in a content stream while skipping everything
/// that could contain their letters without being an operator: literal strings, hex strings, comments,
/// names and inline image data.
/// </summary>
public static class ContentStreamBalance
{
    /// <summary>
    /// Result of a scan. MinDepth and FinalDepth are the lowest and final q/Q depth; the Text and Marked
    /// pairs are the same for BT/ET and for BMC|BDC / EMC.
    /// </summary>
    public readonly record struct Result(
        int MinDepth, int FinalDepth,
        int TextMinDepth = 0, int TextFinalDepth = 0,
        int MarkedMinDepth = 0, int MarkedFinalDepth = 0)
    {
        /// <summary>True when q/Q, BT/ET and BMC|BDC/EMC are all balanced and never close more than was opened.</summary>
        public bool IsBalanced => Describe().Length == 0;

        /// <summary>Names every unbalanced operator pair, for example "BT/ET (final depth 1)"; empty when balanced.</summary>
        public string Describe()
        {
            var parts = new List<string>();
            Add(parts, "q/Q", MinDepth, FinalDepth);
            Add(parts, "BT/ET", TextMinDepth, TextFinalDepth);
            Add(parts, "BMC|BDC/EMC", MarkedMinDepth, MarkedFinalDepth);
            return string.Join("; ", parts);
        }

        private static void Add(List<string> parts, string pair, int min, int final)
        {
            if (min < 0 || final != 0)
                parts.Add($"{pair} (lowest depth {min}, final depth {final})");
        }
    }

    /// <summary>Scans <paramref name="content"/> and returns the lowest and final depth of each operator pair.</summary>
    public static Result Scan(byte[] content)
    {
        ArgumentNullException.ThrowIfNull(content);
        var depth = 0;
        var min = 0;
        var text = 0;
        var textMin = 0;
        var marked = 0;
        var markedMin = 0;
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
            else if (length == 2 && content[start] == (byte)'B' && content[start + 1] == (byte)'T') text++;
            else if (length == 2 && content[start] == (byte)'E' && content[start + 1] == (byte)'T') { text--; if (text < textMin) textMin = text; }
            else if (length == 3 && content[start] == (byte)'B' && content[start + 1] == (byte)'M' && content[start + 2] == (byte)'C') marked++;
            else if (length == 3 && content[start] == (byte)'B' && content[start + 1] == (byte)'D' && content[start + 2] == (byte)'C') marked++;
            else if (length == 3 && content[start] == (byte)'E' && content[start + 1] == (byte)'M' && content[start + 2] == (byte)'C') { marked--; if (marked < markedMin) markedMin = marked; }
        }

        return new Result(min, depth, textMin, text, markedMin, marked);
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
