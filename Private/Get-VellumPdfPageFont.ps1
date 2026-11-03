function Get-VellumPdfPageFont {
    <#
    .SYNOPSIS
        Resolves the font for page text: an embedded handle, a base-14 resource, or
        (in PDF/A documents) an automatically embedded substitute.
    .DESCRIPTION
        PDF/A forbids non-embedded fonts. For a conformant page document a base-14
        name is therefore mapped to the metric-compatible Liberation font shipped in
        VellumPdf.Fonts.Standard14 and embedded once per document. Returns an object
        with Handle (embedded) or Resource (base-14), exactly one non-null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [VellumPdf.Document.PdfDocument]$Document,
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,
        [string]$Font = 'Helvetica',
        [Parameter(Mandatory)] [string]$CommandName
    )

    if ($FontHandle) {
        Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName $CommandName
        return [pscustomobject]@{ Handle = $FontHandle; Resource = $null }
    }
    if ($Document.Conformance -ne [VellumPdf.Document.PdfConformance]::None) {
        $handle = Get-VellumPdfEmbeddedStandard14 -Document $Document -Font $Font -CommandName $CommandName
        return [pscustomobject]@{ Handle = $handle; Resource = $null }
    }
    [pscustomobject]@{ Handle = $null; Resource = $Document.UseFont([VellumPdf.Fonts.Standard14]::$Font) }
}
