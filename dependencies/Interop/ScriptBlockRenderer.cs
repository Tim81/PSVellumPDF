using System.Management.Automation;
using System.Management.Automation.Runspaces;
using VellumPdf.Document;
using VellumPdf.Layout.Core;

namespace PSVellumPDF.Interop;

/// <summary>A drawing rectangle in PDF user space (origin bottom-left, points).</summary>
public sealed record PdfBox(double X, double Y, double Width, double Height);

/// <summary>
/// An <see cref="IRenderer"/> that reserves a fixed-height block in the flow and
/// draws it by invoking a PowerShell script block with
/// <c>($canvas, $box, $ctx)</c>.
/// </summary>
/// <remarks>
/// The script block must run on the thread that owns a PowerShell runspace, so
/// this renderer works with the synchronous <c>Document.Save</c> and
/// <c>SigningExtensions.Sign</c> only. <c>SaveAsync</c> and <c>SignAsync</c> run
/// layout on a thread-pool thread, where <see cref="Draw"/> throws a clear error.
/// </remarks>
public sealed class ScriptBlockRenderer : IRenderer
{
    private readonly double _height;
    private readonly ScriptBlock _script;
    private readonly string? _altText;
    private readonly bool _decorative;
    private LayoutBox _occupied;

    public ScriptBlockRenderer(double height, ScriptBlock script, string? altText = null, bool decorative = false)
    {
        if (!double.IsFinite(height) || height <= 0)
            throw new ArgumentOutOfRangeException(nameof(height), height, "Height must be a positive, finite number of points.");
        ArgumentNullException.ThrowIfNull(script);
        _height = height;
        _script = script;
        _altText = altText;
        _decorative = decorative;
    }

    public LayoutResult Layout(LayoutContext ctx)
    {
        if (_height > ctx.Area.Height) return LayoutResult.Nothing();
        _occupied = ctx.Area.WithHeight(_height);
        return LayoutResult.Full(_occupied);
    }

    public void Draw(DrawContext ctx)
    {
        if (Runspace.DefaultRunspace is null)
            throw new InvalidOperationException(
                "A drawing script block can only run during a synchronous save on the PowerShell pipeline thread. " +
                "Do not use SaveAsync/SignAsync (or an external async signer) with Add-VellumPdfDrawing.");

        var (x, y, w, h) = ctx.ToPdfRect(_occupied);
        var canvas = ctx.Canvas;

        var mcid = -1;
        if (ctx.Tagged)
        {
            if (_decorative) canvas.BeginArtifactMarkedContent();
            else mcid = canvas.BeginMarkedContent("Figure");
        }

        canvas.SaveState();
        try
        {
            _script.Invoke(canvas, new PdfBox(x, y, w, h), ctx);
        }
        catch (RuntimeException e) when (e.InnerException is null)
        {
            throw new InvalidOperationException("The drawing script block failed: " + e.Message, e);
        }
        finally
        {
            canvas.RestoreState();
        }

        if (ctx.Tagged)
        {
            canvas.EndMarkedContent();
            if (mcid >= 0)
                ctx.RegisterStructElem(new PdfStructElem("Figure")
                {
                    Mcid = mcid,
                    // PDF/UA-1 clause 7.3-1 rejects a Figure whose /Alt is empty.
                    AltText = string.IsNullOrWhiteSpace(_altText) ? "Drawing" : _altText,
                });
        }
    }
}
