function Write-VellumPdfUntaggedWarning {
    <#
    .SYNOPSIS
        Warns once per document that annotations cannot be tagged.
    .DESCRIPTION
        VellumPdf.Kernel has no way to attach a link or form-field annotation to the
        structure tree, so a tagged page document that contains one is not fully
        PDF/UA-conformant. Emitted at most once per document and thing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [VellumPdf.Document.PdfDocument]$Document,
        [Parameter(Mandatory)] [string]$CommandName,
        [Parameter(Mandatory)] [string]$What
    )
    if (-not $Document.Tagged) { return }
    $key = "PSVellumUntaggedWarned_$($What -replace '\W', '')"
    if ($Document.PSObject.Properties[$key]) { return }
    $Document.PSObject.Properties.Add([psnoteproperty]::new($key, $true))
    Write-Warning ("${CommandName}: $What cannot be tagged by VellumPdf, so this tagged document is not fully " +
        'PDF/UA-conformant. Use it only where that is acceptable.')
}
