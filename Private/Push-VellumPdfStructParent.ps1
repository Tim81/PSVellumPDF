function Push-VellumPdfStructParent {
    <#
    .SYNOPSIS
        Makes a structure element the parent of everything tagged next (until Pop-VellumPdfStructParent).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Changes an in-memory note property only.')]
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Document, [Parameter(Mandatory)] [VellumPdf.Document.PdfStructElem]$Element)
    $prop = $Document.PSObject.Properties['PSVellumStructParents']
    if (-not $prop) {
        $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumStructParents', [System.Collections.Generic.List[VellumPdf.Document.PdfStructElem]]::new()))
        $prop = $Document.PSObject.Properties['PSVellumStructParents']
    }
    $prop.Value.Add($Element)
}
