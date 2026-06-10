function New-VellumPdfDocument {
    <#
    .SYNOPSIS
        Creates a new VellumPdf layout document.
    .DESCRIPTION
        Returns a live VellumPdf.Layout.Document. Pipe it through the Add-VellumPdf*
        functions and finish with Save-VellumPdfDocument, which disposes it.

        The document is IDisposable. If you do not call Save-VellumPdfDocument,
        dispose it yourself with $doc.Dispose().

        Page margins can be set uniformly with -Margin, or per-side with
        -MarginTop, -MarginRight, -MarginBottom, -MarginLeft.  When any per-side
        parameter is supplied, the uniform -Margin value (if given) is used as
        the baseline for the unspecified sides; otherwise the library defaults
        are kept for unspecified sides.
    .EXAMPLE
        New-VellumPdfDocument -Conformance PdfA2b |
            Add-VellumPdfHeading -Text 'Report' |
            Add-VellumPdfParagraph -Text 'Body text.' |
            Save-VellumPdfDocument -Path ./report.pdf
    .EXAMPLE
        New-VellumPdfDocument -Margin 30
    .EXAMPLE
        New-VellumPdfDocument -Margin 30 -MarginLeft 50
    .OUTPUTS
        VellumPdf.Layout.Document
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Returns a new in-memory document object; performs no external/system state change.')]
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

        [switch]$Tagged,

        [ValidateRange(0, 10000)]
        [double]$Margin,

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginRight,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom,

        [ValidateRange(0, 10000)]
        [double]$MarginLeft
    )

    $doc = [VellumPdf.Layout.Document]::new()
    $doc.Conformance = [VellumPdf.Document.PdfConformance]::$Conformance
    $doc.PageSize = [VellumPdf.Document.PageSize]::$PageSize
    if ($Tagged) { $doc.Tagged = $true }

    $style = New-VellumTextStyle -Font $DefaultFont -FontSize $DefaultFontSize
    [void]$doc.SetDefaultFont($style)

    $hasUniform = $PSBoundParameters.ContainsKey('Margin')
    $hasPerSide = $PSBoundParameters.ContainsKey('MarginTop') -or
                  $PSBoundParameters.ContainsKey('MarginRight') -or
                  $PSBoundParameters.ContainsKey('MarginBottom') -or
                  $PSBoundParameters.ContainsKey('MarginLeft')

    if ($hasPerSide) {
        # Start from -Margin uniform value if given, else from current document margins.
        $baseTop    = if ($hasUniform) { $Margin } else { $doc.Margins.Top }
        $baseRight  = if ($hasUniform) { $Margin } else { $doc.Margins.Right }
        $baseBottom = if ($hasUniform) { $Margin } else { $doc.Margins.Bottom }
        $baseLeft   = if ($hasUniform) { $Margin } else { $doc.Margins.Left }

        $top    = if ($PSBoundParameters.ContainsKey('MarginTop'))    { $MarginTop }    else { $baseTop }
        $right  = if ($PSBoundParameters.ContainsKey('MarginRight'))  { $MarginRight }  else { $baseRight }
        $bottom = if ($PSBoundParameters.ContainsKey('MarginBottom')) { $MarginBottom } else { $baseBottom }
        $left   = if ($PSBoundParameters.ContainsKey('MarginLeft'))   { $MarginLeft }   else { $baseLeft }

        $doc.Margins = [VellumPdf.Layout.Core.EdgeInsets]::new($top, $right, $bottom, $left)
    } elseif ($hasUniform) {
        $doc.Margins = [VellumPdf.Layout.Core.EdgeInsets]::new($Margin)
    }

    return $doc
}
