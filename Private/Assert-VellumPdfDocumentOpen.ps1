function Assert-VellumPdfDocumentOpen {
    <#
    .SYNOPSIS
        Throws a clear error when a cmdlet receives an already-disposed document.
    .DESCRIPTION
        Save-VellumPdfDocument stamps the document with a PSVellumDisposed note
        property after disposing it. VellumPdf itself does not guard Add() on a
        disposed document (content is silently buffered and only a later Save
        fails), so without this check stale-document bugs surface far from
        their cause.
    #>
    [CmdletBinding()]
    param(
        # A flow-layout document (New-VellumPdfDocument) or a page-based Kernel
        # document (New-VellumPdfPageDocument).
        [Parameter(Mandatory)]
        [object]$Document,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    if ($Document -isnot [VellumPdf.Layout.Document] -and $Document -isnot [VellumPdf.Document.PdfDocument]) {
        throw ("${CommandName}: -Document must come from New-VellumPdfDocument or New-VellumPdfPageDocument; " +
            "got $(if ($null -eq $Document) { 'null' } else { $Document.GetType().FullName }).")
    }
    if ($Document.PSObject.Properties['PSVellumDisposed']) {
        throw ("${CommandName}: this document was already saved and disposed by " +
            'Save-VellumPdfDocument. Create a new document with New-VellumPdfDocument, ' +
            'or pass -KeepOpen to Save-VellumPdfDocument to keep working with it.')
    }
}
