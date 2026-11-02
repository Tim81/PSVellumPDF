function Get-VellumPdfConformanceNeeds {
    <#
    .SYNOPSIS
        Describes what a document's conformance level demands from the content the module draws.
    .DESCRIPTION
        One place for the rules several cmdlets apply:
          IsPdfA             PDF/A-2b/2u/2a: no CMYK without a CMYK output intent
          NeedsEmbeddedFonts PDF/A and PDF/UA-1 both forbid non-embedded fonts, so text drawn
                             with a base-14 font (including barcode captions) must be embedded
                             or left out
          Tagged             the document writes a structure tree
        Works for both document kinds.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Document)

    $level = $Document.Conformance
    $pdfA = $level -in @(
        [VellumPdf.Document.PdfConformance]::PdfA2b,
        [VellumPdf.Document.PdfConformance]::PdfA2u,
        [VellumPdf.Document.PdfConformance]::PdfA2a)
    [pscustomobject]@{
        IsPdfA             = $pdfA
        NeedsEmbeddedFonts = $pdfA -or $level -eq [VellumPdf.Document.PdfConformance]::PdfUA1
        Tagged             = [bool]$Document.Tagged
    }
}
