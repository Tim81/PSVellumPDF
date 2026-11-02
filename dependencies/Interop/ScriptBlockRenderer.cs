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
    private readonly double _marginTop;
    private readonly double _marginBottom;
    private LayoutBox _occupied;

    public ScriptBlockRenderer(double height, ScriptBlock script, string? altText = null, bool decorative = false,
        double marginTop = 0, double marginBottom = 0)
    {
        if (!double.IsFinite(height) || height <= 0)
            throw new ArgumentOutOfRangeException(nameof(height), height, "Height must be a positive, finite number of points.");
        if (!double.IsFinite(marginTop) || marginTop < 0)
            throw new ArgumentOutOfRangeException(nameof(marginTop), marginTop, "Margins must be finite and not negative.");
        if (!double.IsFinite(marginBottom) || marginBottom < 0)
            throw new ArgumentOutOfRangeException(nameof(marginBottom), marginBottom, "Margins must be finite and not negative.");
        ArgumentNullException.ThrowIfNull(script);
        _marginTop = marginTop;
        _marginBottom = marginBottom;
        _height = height;
        _script = script;
        _altText = altText;
        _decorative = decorative;
    }

    public LayoutResult Layout(LayoutContext ctx)
    {
        var total = _marginTop + _height + _marginBottom;
        if (total > ctx.Area.Height) return LayoutResult.Nothing();
        _occupied = ctx.Area.WithHeight(total);
        return LayoutResult.Full(_occupied);
    }

    public void Draw(DrawContext ctx)
    {
        if (Runspace.DefaultRunspace is null)
            throw new InvalidOperationException(
                "A drawing script block can only run during a synchronous save on the PowerShell pipeline thread. " +
                "Do not use SaveAsync/SignAsync (or an external async signer) with Add-VellumPdfDrawing.");

        // Margins are reserved space; the script draws inside what is left.
        var (x, y, w, h) = ctx.ToPdfRect(_occupied.Deflate(new EdgeInsets(_marginTop, 0, _marginBottom, 0)));
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
