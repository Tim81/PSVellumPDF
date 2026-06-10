function Register-VellumPdfFont {
    <#
    .SYNOPSIS
        Registers a TrueType font file with a VellumPdf document for embedding.
    .DESCRIPTION
        Loads a TrueType (.ttf) font file into the document and returns an
        EmbeddedFontHandle. Pass the returned handle to the -FontHandle parameter
        of Add-VellumPdfHeading or Add-VellumPdfParagraph to use the embedded font
        instead of a Standard14 base-14 font.

        NOTE: This cmdlet returns the EmbeddedFontHandle, NOT the document.
        TrueType font embedding is required for Unicode text and PDF/A conformance;
        the Standard14 base-14 fonts cannot be embedded.
    .EXAMPLE
        $doc = New-VellumPdfDocument -Conformance PdfA2b
        $handle = Register-VellumPdfFont -Document $doc -Path ./DejaVuSans.ttf
        $doc | Add-VellumPdfHeading -Text 'Unicode Heading' -FontHandle $handle |
               Add-VellumPdfParagraph -Text 'Body with embedded font.' -FontHandle $handle |
               Save-VellumPdfDocument -Path ./output.pdf
    .OUTPUTS
        VellumPdf.Fonts.EmbeddedFontHandle
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Fonts.EmbeddedFontHandle])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    process {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        if (-not [System.IO.File]::Exists($resolved)) {
            throw "Register-VellumPdfFont: font file not found: '$resolved'. Verify the path and try again."
        }

        $Document.LoadTrueTypeFont($resolved)
    }
}
