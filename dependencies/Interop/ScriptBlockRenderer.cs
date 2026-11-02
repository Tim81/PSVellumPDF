using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using VellumPdf.Canvas;
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
    private readonly List<PSVariable>? _variables;
    private LayoutBox _occupied;

    // PdfCanvas keeps its operators in a private MemoryStream. Reading what the script block appended lets
    // Draw check that it saved and restored the graphics state evenly (the public API exposes no depth).
    // When a future VellumPdf version renames the field the check is skipped rather than failing.
    private static readonly FieldInfo? OperatorStream =
        typeof(PdfCanvas).GetField("_ops", BindingFlags.Instance | BindingFlags.NonPublic);

    public ScriptBlockRenderer(double height, ScriptBlock script, string? altText = null, bool decorative = false,
        double marginTop = 0, double marginBottom = 0, IEnumerable<PSVariable>? variables = null)
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
        _variables = variables is null ? null : new List<PSVariable>(variables);
    }

    private static void CheckBalanced(MemoryStream? operators, long startOffset)
    {
        if (operators is null || !operators.TryGetBuffer(out var buffer) || buffer.Array is null) return;
        var length = operators.Length - startOffset;
        if (length <= 0) return;
        var written = buffer.Array.AsSpan(buffer.Offset + (int)startOffset, (int)length).ToArray();
        var balance = ContentStreamBalance.Scan(written);
        if (balance.MinDepth < 0 || balance.FinalDepth != 0)
            throw new InvalidOperationException(
                "Add-VellumPdfDrawing: the script block saved and restored the graphics state unevenly " +
                $"(lowest depth {balance.MinDepth}, final depth {balance.FinalDepth}). " +
                "Every SaveState needs a RestoreState inside the same block.");
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
        var operators = OperatorStream?.GetValue(canvas) as MemoryStream;
        var startOffset = operators?.Length ?? 0;
        try
        {
            // The captured variables (a loop variable, a function's locals) shadow whatever the caller's scope
            // holds by now; the block itself stays bound to its own session state ($script:, $global:, functions).
            if (_variables is { Count: > 0 })
                _script.InvokeWithContext(null, _variables, canvas, new PdfBox(x, y, w, h), ctx);
            else
                _script.Invoke(canvas, new PdfBox(x, y, w, h), ctx);
            CheckBalanced(operators, startOffset);
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
