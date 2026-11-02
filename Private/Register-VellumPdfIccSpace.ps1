function Register-VellumPdfIccSpace {
    <#
    .SYNOPSIS
        Embeds an ICC profile once per page and returns its colour-space resource name.
    .DESCRIPTION
        Shared by the drawing cmdlets. The profile is read from disk, its component count
        is checked, and the colour space is registered on the page. Later calls for the
        same page and profile reuse the registered space (cached on the document as
        PSVellumIccSpaces).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [VellumPdf.Document.PdfDocument]$Document,
        [Parameter(Mandatory)] [int]$Page,
        [Parameter(Mandatory)] [string]$IccProfilePath,
        [Parameter(Mandatory)] [string]$CommandName
    )
    $iccPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($IccProfilePath)
    if (-not [System.IO.File]::Exists($iccPath)) { throw (New-VellumPdfErrorRecord FileNotFound "${CommandName}: ICC profile not found: '$iccPath'.") }
    $iccBytes = [System.IO.File]::ReadAllBytes($iccPath)
    $count = Get-VellumPdfIccComponentCount -Bytes $iccBytes -CommandName $CommandName
    $cacheProp = $Document.PSObject.Properties['PSVellumIccSpaces']
    if (-not $cacheProp) {
        $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumIccSpaces', @{}))
        $cacheProp = $Document.PSObject.Properties['PSVellumIccSpaces']
    }
    $cacheKey = "$Page|$iccPath"
    if (-not $cacheProp.Value.ContainsKey($cacheKey)) {
        $cacheProp.Value[$cacheKey] = $Document.RegisterIccBasedColorSpace($Document.Pages[$Page - 1], $iccBytes, $count, "VICC$($cacheProp.Value.Count + 1)")
    }
    [pscustomobject]@{ Name = $cacheProp.Value[$cacheKey]; Count = $count }
}
