function Invoke-VellumPdfCanvas {
    <#
    .SYNOPSIS
        Draws on a page of a page-based document with a script block that receives the canvas.
    .DESCRIPTION
        Gives full access to the VellumPdf PdfCanvas of one page - paths, colours
        (RGB, grey, CMYK), transparency, gradients, clipping, dashes, text, images -
        for anything the Add-VellumPdfShape/Text/... cmdlets do not cover. The script
        block receives:

          $canvas    the VellumPdf.Canvas.PdfCanvas of the page
          $page      the VellumPdf.Document.PdfPage
          $document  the VellumPdf.Document.PdfDocument

        All drawing on a page shares one canvas, so calls accumulate in order. The
        graphics state is saved before and restored after your script. Operators that
        take spans (dash patterns, raw colour components, glyph ids) cannot be called
        from PowerShell directly; use [PSVellumPDF.Interop.CanvasHelpers].
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER ScriptBlock
        The drawing code: param($canvas, $page, $document).
    .EXAMPLE
        $doc | Invoke-VellumPdfCanvas -Page 1 -ScriptBlock {
            param($canvas)
            $canvas.SetFillAlpha(0.4).SetFillColorRgb(0, 0, 1).Rectangle(100, 100, 200, 120).Fill() | Out-Null
        }
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Invoke-VellumPdfCanvas'
        $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Invoke-VellumPdfCanvas'
        $pdfPage = $Document.Pages[$Page - 1]
        [void]$canvas.SaveState()
        try { & $ScriptBlock $canvas $pdfPage $Document | Out-Null }
        finally { [void]$canvas.RestoreState() }
        $Document
    }
}
