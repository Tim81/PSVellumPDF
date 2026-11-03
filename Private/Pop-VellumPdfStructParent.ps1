function Pop-VellumPdfStructParent {
    <#
    .SYNOPSIS
        Ends the innermost structure scope started with Push-VellumPdfStructParent.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Changes an in-memory note property only.')]
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Document)
    $prop = $Document.PSObject.Properties['PSVellumStructParents']
    if ($prop -and $prop.Value.Count -gt 0) { $prop.Value.RemoveAt($prop.Value.Count - 1) }
}
