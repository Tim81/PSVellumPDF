function New-VellumPdfDocument {
    <#
    .SYNOPSIS
        Creates a new VellumPdf layout document.
    .DESCRIPTION
        Returns a live VellumPdf.Layout.Document. Pipe it through the Add-VellumPdf*
        functions and finish with Save-VellumPdfDocument, which disposes it.

        The document is IDisposable. If you do not call Save-VellumPdfDocument,
        dispose it yourself with $doc.Dispose().
    .EXAMPLE
        New-VellumPdfDocument -Conformance PdfA2b |
            Add-VellumPdfHeading -Text 'Report' |
            Add-VellumPdfParagraph -Text 'Body text.' |
            Save-VellumPdfDocument -Path ./report.pdf
    .OUTPUTS
        VellumPdf.Layout.Document
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [ValidateSet('None', 'PdfA2b', 'PdfA2u', 'PdfA2a')]
        [string]$Conformance = 'None',

        [ValidateSet('A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'Ledger', 'Legal', 'Letter')]
        [string]$PageSize = 'A4',

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$DefaultFont = 'Helvetica',

        [ValidateRange(1, 1000)]
        [double]$DefaultFontSize = 11,

        [switch]$Tagged
    )

    $doc = [VellumPdf.Layout.Document]::new()
    $doc.Conformance = [VellumPdf.Document.PdfConformance]::$Conformance
    $doc.PageSize = [VellumPdf.Document.PageSize]::$PageSize
    if ($Tagged) { $doc.Tagged = $true }

    $style = New-VellumTextStyle -Font $DefaultFont -FontSize $DefaultFontSize
    [void]$doc.SetDefaultFont($style)

    return $doc
}
