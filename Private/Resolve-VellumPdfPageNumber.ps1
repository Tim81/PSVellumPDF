function Resolve-VellumPdfPageNumber {
    <#
    .SYNOPSIS
        Returns the page a page-document cmdlet should draw on, honouring an enclosing scope.
    .DESCRIPTION
        Use-VellumPdfClip (and the other scope cmdlets) push their page onto a stack kept on the
        document. A drawing cmdlet inside the scope that was not given -Page draws on that page, so
        "Use-VellumPdfClip -Page 2 { ... Add-VellumPdfShape ... }" clips what the block draws on
        page 2 instead of silently drawing on page 1. An explicit -Page that differs from the scope
        page is respected, with a warning, because the scope's clip or transform does not reach it.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] $Document,
        [Parameter(Mandatory)] [int]$Page,
        [Parameter(Mandatory)] [bool]$Bound,
        [Parameter(Mandatory)] [string]$CommandName
    )
    $stack = $Document.PSObject.Properties['PSVellumScopePages']
    if (-not $stack -or $stack.Value.Count -eq 0) { return $Page }
    $scopePage = $stack.Value[$stack.Value.Count - 1]
    if (-not $Bound) { return $scopePage }
    if ($Page -ne $scopePage) {
        Write-Warning "${CommandName}: -Page $Page differs from the enclosing scope's page $scopePage, so the scope (clip or transform) does not apply to this drawing."
    }
    $Page
}
