function Add-VellumPdfElement {
    <#
    .SYNOPSIS
        Adds a custom layout element (any VellumPdf IRenderer) to a document.
    .DESCRIPTION
        Wraps Document.Add(IRenderer): the extension point behind barcodes and
        charts. Use it with a renderer you compiled yourself (Add-Type) or got from
        another VellumPdf package. The renderer's Layout(LayoutContext) is called
        during the save - possibly several times - to measure and split it across
        pages, and Draw(DrawContext) to paint it, so exceptions from either surface
        from Save-VellumPdfDocument. An element may use at most 50,000 page
        continuations. Space left by a previous element's -MarginBottom is inserted
        before the element as an invisible spacer.

        Write the renderer in C# (Add-Type): PowerShell classes cannot run on the
        thread-pool threads an asynchronous save uses. For quick drawing from a
        script block use Add-VellumPdfDrawing instead.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline.
    .PARAMETER Renderer
        The renderer to add.
    .EXAMPLE
        $doc | Add-VellumPdfElement -Renderer ([VellumPdf.Barcodes.BarcodeRenderer]::new($qr))
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory)]
        [VellumPdf.Layout.Core.IRenderer]$Renderer
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfElement'
            # A custom renderer has no margins of its own: put the space a previous element's
            # -MarginBottom deferred in front of it as an invisible spacer.
            $pending = $Document.PSObject.Properties['PSVellumPendingSpace']
            if ($pending -and $pending.Value) {
                [void]$Document.Add([PSVellumPDF.Interop.SpacerRenderer]::new([double]$pending.Value))
                $pending.Value = 0.0
            }
            [void]$Document.Add($Renderer)
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
