function Assert-VellumPdfFontHandle {
    <#
    .SYNOPSIS
        Rejects an EmbeddedFontHandle that belongs to a different document.
    .DESCRIPTION
        VellumPdf accepts a foreign font handle without complaint, but the
        resulting PDF references a font resource that does not exist in the
        document - the text silently fails to render in every viewer.
        Register-VellumPdfFont tags each handle with its owning document
        (PSVellumOwner); this helper enforces the pairing. Handles created by
        calling the .NET API directly carry no tag and are not checked.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [Parameter(Mandatory)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $owner = $FontHandle.PSObject.Properties['PSVellumOwner']
    if ($owner -and -not [object]::ReferenceEquals($owner.Value, $Document)) {
        throw ("${CommandName}: this -FontHandle was registered on a DIFFERENT document. " +
            'A font handle is only valid for the document it came from (using it elsewhere ' +
            'produces a PDF whose text cannot render). Call Register-VellumPdfFont on this ' +
            'document to get a valid handle.')
    }
}
