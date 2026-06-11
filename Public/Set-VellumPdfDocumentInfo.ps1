function Set-VellumPdfDocumentInfo {
    <#
    .SYNOPSIS
        Sets PDF document metadata (Info dictionary) on a VellumPdf document.
    .DESCRIPTION
        Writes one or more string properties on Document.Info. Only parameters
        that are explicitly supplied are set; omitted parameters leave the
        existing property values unchanged.

        Note: Title and Author are embedded in the XMP packet when writing
        PDF/A conformant documents and are required for PDF/A XMP metadata
        compliance.
    .EXAMPLE
        $doc | Set-VellumPdfDocumentInfo -Title 'Annual Report 2026' `
               -Author 'Acme Corp' -Subject 'Finance' -Keywords 'finance,annual'
    .EXAMPLE
        $doc | Set-VellumPdfDocumentInfo -Title 'Draft'
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory document object only; no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [string]$Title,
        [string]$Author,
        [string]$Subject,
        [string]$Keywords,
        [string]$Creator,
        [string]$Producer
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Set-VellumPdfDocumentInfo'
        if ($PSBoundParameters.ContainsKey('Title'))    { $Document.Info.Title    = $Title }
        if ($PSBoundParameters.ContainsKey('Author'))   { $Document.Info.Author   = $Author }
        if ($PSBoundParameters.ContainsKey('Subject'))  { $Document.Info.Subject  = $Subject }
        if ($PSBoundParameters.ContainsKey('Keywords')) { $Document.Info.Keywords = $Keywords }
        if ($PSBoundParameters.ContainsKey('Creator'))  { $Document.Info.Creator  = $Creator }
        if ($PSBoundParameters.ContainsKey('Producer')) { $Document.Info.Producer = $Producer }
        $Document
    }
}
