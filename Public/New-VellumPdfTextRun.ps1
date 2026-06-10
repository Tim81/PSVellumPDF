function New-VellumPdfTextRun {
    <#
    .SYNOPSIS
        Creates a styled text run for use in a mixed-style paragraph.
    .DESCRIPTION
        Returns a VellumPdf.Layout.Elements.TextRun that can be passed to
        Add-VellumPdfParagraph via its -Run parameter.  Multiple runs compose
        into a single paragraph, each with its own font, size, colour, or
        hyperlink.

        Every run carries at least an empty TextStyle so that the VellumPdf
        renderer can fall back to the document's default font.  When no styling
        parameters are supplied the run inherits the document default.

        -Color accepts three doubles (R, G, B) in the 0.0..1.0 range.
        -LinkUri makes the run a clickable external hyperlink in the PDF.
        -Leading sets the extra vertical spacing between lines for this run, in
        points. When omitted the document-level leading is used.
    .EXAMPLE
        $run1 = New-VellumPdfTextRun -Text 'Normal text '
        $run2 = New-VellumPdfTextRun -Text 'Red text ' -Color 1,0,0
        $run3 = New-VellumPdfTextRun -Text 'Click me' -LinkUri 'https://example.com'
        $doc | Add-VellumPdfParagraph -Run $run1, $run2, $run3
    .OUTPUTS
        VellumPdf.Layout.Elements.TextRun
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Returns a new in-memory TextRun object; performs no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Elements.TextRun])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Text,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font,

        [ValidateRange(1, 1000)]
        [double]$FontSize,

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [ValidateCount(3, 3)]
        [ValidateRange(0.0, 1.0)]
        [double[]]$Color,

        [string]$LinkUri,

        [ValidateRange(0, 1000)]
        [double]$Leading
    )

    # Build a style forwarding only the parameters that were explicitly bound.
    # Always produce at least a bare TextStyle (never $null) because the
    # VellumPdf renderer requires a non-null style on every TextRun in a
    # runs-based paragraph.
    $styleParams = @{}
    if ($PSBoundParameters.ContainsKey('Font'))       { $styleParams['Font']       = $Font }
    if ($PSBoundParameters.ContainsKey('FontSize'))   { $styleParams['FontSize']   = $FontSize }
    if ($PSBoundParameters.ContainsKey('FontHandle')) { $styleParams['FontHandle'] = $FontHandle }
    if ($PSBoundParameters.ContainsKey('Color'))      { $styleParams['Color']      = $Color }
    if ($PSBoundParameters.ContainsKey('LinkUri'))    { $styleParams['LinkUri']    = $LinkUri }
    if ($PSBoundParameters.ContainsKey('Leading'))    { $styleParams['Leading']    = $Leading }

    $style = if ($styleParams.Count -gt 0) {
        New-VellumTextStyle @styleParams
    } else {
        $null
    }

    # Guarantee a non-null style: an empty TextStyle lets the renderer fall
    # back to the document's default font without any NullReferenceException.
    if ($null -eq $style) {
        $style = [VellumPdf.Layout.Core.TextStyle]::new()
    }

    [VellumPdf.Layout.Elements.TextRun]::new($Text, $style)
}
