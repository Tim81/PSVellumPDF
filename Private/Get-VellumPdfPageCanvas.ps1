function Get-VellumPdfPageCanvas {
    <#
    .SYNOPSIS
        Returns the one PdfCanvas of a page, creating it on first use.
    .DESCRIPTION
        PdfCanvas.Finish() replaces the page's content, so a page must have exactly
        one canvas for all drawing cmdlets to accumulate. Canvases are cached on the
        document (PSVellumCanvases) and finished by Complete-VellumPdfPageDocument
        when the document is saved.
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Canvas.PdfCanvas])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Canvas is a singular noun (the PDF drawing surface); the rule mistakes the trailing s.')]
    param(
        [Parameter(Mandatory)] [VellumPdf.Document.PdfDocument]$Document,
        [Parameter(Mandatory)] [int]$Page,
        [Parameter(Mandatory)] [string]$CommandName
    )
    $pdfPage = Get-VellumPdfPage -Document $Document -Page $Page -CommandName $CommandName
    $prop = $Document.PSObject.Properties['PSVellumCanvases']
    if (-not $prop) {
        $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumCanvases', [System.Collections.Generic.Dictionary[object, object]]::new()))
        $prop = $Document.PSObject.Properties['PSVellumCanvases']
    }
    $canvases = $prop.Value
    if (-not $canvases.ContainsKey($pdfPage)) {
        $canvases[$pdfPage] = [VellumPdf.Canvas.PdfCanvas]::new($pdfPage)
    }
    $canvases[$pdfPage]
}
