function Get-VellumPdfPage {
    <#
    .SYNOPSIS
        Returns the PdfPage for a 1-based page number of a page-based document.
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfPage])]
    param(
        [Parameter(Mandatory)] [VellumPdf.Document.PdfDocument]$Document,
        [Parameter(Mandatory)] [int]$Page,
        [Parameter(Mandatory)] [string]$CommandName
    )
    if ($Document.Pages.Count -eq 0) {
        throw "${CommandName}: the document has no pages yet. Add one with Add-VellumPdfPage."
    }
    if ($Page -lt 1 -or $Page -gt $Document.Pages.Count) {
        throw "${CommandName}: -Page $Page is out of range; the document has $($Document.Pages.Count) page(s)."
    }
    $Document.Pages[$Page - 1]
}
