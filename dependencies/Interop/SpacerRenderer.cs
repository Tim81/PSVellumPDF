using VellumPdf.Layout.Core;

namespace PSVellumPDF.Interop;

/// <summary>
/// An invisible flow element that reserves vertical space. Used to carry a previous
/// element's bottom margin in front of an element that has no margins of its own,
/// such as a custom <see cref="IRenderer"/>.
/// </summary>
public sealed class SpacerRenderer : IRenderer
{
    private readonly double _height;

    public SpacerRenderer(double height)
    {
        if (!double.IsFinite(height) || height < 0)
            throw new ArgumentOutOfRangeException(nameof(height), height, "Height must be finite and not negative.");
        _height = height;
    }

    public LayoutResult Layout(LayoutContext ctx)
    {
        // At the very top of a page nothing precedes the space, so it is dropped rather
        // than pushed to a new page; elsewhere a space that does not fit is dropped too.
        return _height > ctx.Area.Height
            ? LayoutResult.Full(ctx.Area.WithHeight(0))
            : LayoutResult.Full(ctx.Area.WithHeight(_height));
    }

    public void Draw(DrawContext ctx)
    {
        // Nothing to paint.
    }
}
