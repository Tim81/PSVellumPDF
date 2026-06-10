function Resolve-VellumPdfDefault {
    <#
    .SYNOPSIS
        Returns the document's default font name and size.
    .DESCRIPTION
        New-VellumPdfDocument stashes the default font/size it applied via
        SetDefaultFont as an ETS note property (PSVellumDefault) on the document
        instance, because VellumPdf exposes no getter for the default style and
        a TextStyle without a font falls back to the library-global Helvetica,
        not the document default.

        This helper reads that stash so cmdlets that must build an explicit
        TextStyle (e.g. -FontSize only) can fill the gaps with the document's
        real defaults. Falls back to Helvetica/11 for documents created outside
        New-VellumPdfDocument.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [VellumPdf.Layout.Document]$Document
    )

    $stash = $Document.PSObject.Properties['PSVellumDefault']
    if ($stash -and $stash.Value -is [hashtable]) {
        return $stash.Value
    }
    return @{ Font = 'Helvetica'; FontSize = 11 }
}
