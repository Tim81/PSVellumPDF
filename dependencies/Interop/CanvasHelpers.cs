// PSVellumPDF.Interop: thin C# shims for VellumPdf members that PowerShell's
// method binder cannot call directly (ReadOnlySpan<T> parameters).
using VellumPdf.Canvas;

namespace PSVellumPDF.Interop;

/// <summary>
/// Array-taking wrappers around <see cref="PdfCanvas"/> operators whose
/// parameters are <c>ReadOnlySpan&lt;T&gt;</c>. PowerShell cannot convert an
/// array to a span, so scripts call these instead.
/// </summary>
public static class CanvasHelpers
{
    /// <summary>Sets the dash pattern (on/off lengths in points) and phase.</summary>
    public static PdfCanvas SetLineDash(PdfCanvas canvas, double[] pattern, double phase = 0)
    {
        ArgumentNullException.ThrowIfNull(canvas);
        ArgumentNullException.ThrowIfNull(pattern);
        return canvas.SetLineDash(pattern, phase);
    }

    /// <summary>Sets the non-stroking colour from raw components (1 = gray, 3 = RGB, 4 = CMYK, or per the active colour space).</summary>
    public static PdfCanvas SetFillColor(PdfCanvas canvas, double[] components)
    {
        ArgumentNullException.ThrowIfNull(canvas);
        ArgumentNullException.ThrowIfNull(components);
        return canvas.SetFillColor(components);
    }

    /// <summary>Sets the stroking colour from raw components.</summary>
    public static PdfCanvas SetStrokeColor(PdfCanvas canvas, double[] components)
    {
        ArgumentNullException.ThrowIfNull(canvas);
        ArgumentNullException.ThrowIfNull(components);
        return canvas.SetStrokeColor(components);
    }

    /// <summary>Shows embedded-font glyph ids at the current text position.</summary>
    public static PdfCanvas ShowGlyphs(PdfCanvas canvas, ushort[] glyphIds)
    {
        ArgumentNullException.ThrowIfNull(canvas);
        ArgumentNullException.ThrowIfNull(glyphIds);
        return canvas.ShowGlyphs(glyphIds);
    }
}
