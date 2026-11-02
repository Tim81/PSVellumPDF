function Push-VellumPdfScopePage {
    <#
    .SYNOPSIS
        Starts a scope on a page; end it with Pop-VellumPdfScopePage in a finally block.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Changes an in-memory note property only.')]
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Document, [Parameter(Mandatory)] [int]$Page)
    $prop = $Document.PSObject.Properties['PSVellumScopePages']
    if (-not $prop) {
        $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumScopePages', [System.Collections.Generic.List[int]]::new()))
        $prop = $Document.PSObject.Properties['PSVellumScopePages']
    }
    $prop.Value.Add($Page)
}
