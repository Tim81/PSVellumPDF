function Invoke-VellumPdfTagged {
    <#
    .SYNOPSIS
        Runs drawing code inside the marked-content sequence a tagged page document needs.
    .DESCRIPTION
        In a tagged page document (New-VellumPdfPageDocument -Tagged, or PdfA2a/PdfUA1)
        every piece of page content must be either part of the structure tree or an
        artifact. This helper brackets the drawing code accordingly:

          Artifact   decorative content: /Artifact BMC ... EMC, no structure element
          Structure  real content: /<StructType> <</MCID n>> BDC ... EMC plus a
                     PdfStructElem(StructType) carrying the MCID, page, language and
                     (for Figure) the alternate text

        In an untagged document the code just runs. The drawing code is a script block
        run in the caller's scope.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [VellumPdf.Document.PdfDocument]$Document,
        [Parameter(Mandatory)] [VellumPdf.Canvas.PdfCanvas]$Canvas,
        [Parameter(Mandatory)] [VellumPdf.Document.PdfPage]$PdfPage,
        [Parameter(Mandatory)] [ValidateSet('Artifact', 'Structure')] [string]$Kind,
        [string]$StructType,
        [string]$AltText,
        [string]$Language,
        [Parameter(Mandatory)] [scriptblock]$Draw
    )

    if (-not $Document.Tagged) { & $Draw; return }

    if ($Kind -eq 'Artifact') {
        [void]$Canvas.BeginArtifactMarkedContent()
        try { & $Draw }
        finally { [void]$Canvas.EndMarkedContent() }
        return
    }

    $mcid = $Canvas.BeginMarkedContent($StructType)
    try { & $Draw }
    finally { [void]$Canvas.EndMarkedContent() }
    $elem = [VellumPdf.Document.PdfStructElem]::new($StructType)
    $elem.Mcid = $mcid
    $elem.Page = $PdfPage
    if ($AltText) { $elem.AltText = $AltText }
    if ($Language) { $elem.Language = $Language }
    $Document.RegisterStructElem($elem)
}
