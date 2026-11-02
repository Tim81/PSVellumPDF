function Pop-VellumPdfScopePage {
    <#
    .SYNOPSIS
        Ends the innermost scope started with Push-VellumPdfScopePage.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Changes an in-memory note property only.')]
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Document)
    $prop = $Document.PSObject.Properties['PSVellumScopePages']
    if ($prop -and $prop.Value.Count -gt 0) { $prop.Value.RemoveAt($prop.Value.Count - 1) }
}
