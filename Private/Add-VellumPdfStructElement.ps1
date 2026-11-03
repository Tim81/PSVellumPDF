function Add-VellumPdfStructElement {
    <#
    .SYNOPSIS
        Puts a structure element into the tree: under the current structure parent, or at the root.
    .DESCRIPTION
        Use-VellumPdfStructure and the table and list cmdlets build nested structure (Table, TR, TD ...)
        by making a group the current parent. Elements tagged while a parent is current become its
        children; otherwise they are registered at the document root, as before.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Changes an in-memory structure tree only.')]
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Document, [Parameter(Mandatory)] [VellumPdf.Document.PdfStructElem]$Element)
    $prop = $Document.PSObject.Properties['PSVellumStructParents']
    if ($prop -and $prop.Value.Count -gt 0) { [void]$prop.Value[$prop.Value.Count - 1].AddChild($Element) }
    else { $Document.RegisterStructElem($Element) }
}
