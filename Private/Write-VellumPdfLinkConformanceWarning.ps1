function Write-VellumPdfLinkConformanceWarning {
    <#
    .SYNOPSIS
        Warns that hyperlinks make a PDF/UA document non-conformant.
    .DESCRIPTION
        VellumPdf.Layout writes URI link annotations but does not tag them (no
        Link structure element), so a PDF/UA-1 document that contains one fails
        the preflight. Emits one warning per document.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory)]
        [string]$CommandName
    )

    if ($Document.Conformance -ne [VellumPdf.Document.PdfConformance]::PdfUA1) { return }
    if ($Document.PSObject.Properties['PSVellumLinkWarned']) { return }
    $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumLinkWarned', $true))
    Write-Warning ("${CommandName}: hyperlinks are not tagged by VellumPdf, so a PDF/UA-1 document " +
        'that contains them is not fully conformant. Remove the link or accept the PDF/UA preflight finding.')
}
