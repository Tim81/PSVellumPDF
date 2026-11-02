function Assert-VellumPdfDocumentOpen {
    <#
    .SYNOPSIS
        Throws a clear error when a cmdlet receives an already-disposed document.
    .DESCRIPTION
        Save-VellumPdfDocument stamps the document with a PSVellumDisposed note
        property after disposing it. VellumPdf itself does not guard Add() on a
        disposed document (content is silently buffered and only a later Save
        fails), so without this check stale-document bugs surface far from
        their cause. A page document saved with -KeepOpen is refused too (nothing drawn on it could be saved).
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
        throw (New-VellumPdfErrorRecord InvalidArgument ("${CommandName}: -Document must come from New-VellumPdfDocument or New-VellumPdfPageDocument; " +
            "got $(if ($null -eq $Document) { 'null' } else { $Document.GetType().FullName })."))
    }
    $factory = if ($Document -is [VellumPdf.Document.PdfDocument]) { 'New-VellumPdfPageDocument' } else { 'New-VellumPdfDocument' }
    if ($Document.PSObject.Properties['PSVellumDisposed']) {
        throw (New-VellumPdfErrorRecord InvalidArgument ("${CommandName}: this document was already saved and disposed by " +
            "Save-VellumPdfDocument. Create a new document with $factory. " +
            '(Save-VellumPdfDocument -KeepOpen keeps a saved document alive for inspection only; ' +
            'it can be neither drawn on nor saved again.)'))
    }
    # A page document saved with -KeepOpen is not disposed, but it is final: its canvases were finished and
    # written, a second save is refused and anything drawn now would be lost. (A layout document keeps
    # accepting elements; they are simply never saved.) Save-VellumPdfDocument reports this case itself.
    if ($Document -is [VellumPdf.Document.PdfDocument] -and $CommandName -ne 'Save-VellumPdfDocument' -and $Document.PSObject.Properties['PSVellumSaved']) {
        throw (New-VellumPdfErrorRecord InvalidArgument ("${CommandName}: this document was already saved (Save-VellumPdfDocument -KeepOpen), " +
            "so nothing more can be drawn on it and it cannot be saved again. Create a new document with $factory."))
    }
}
