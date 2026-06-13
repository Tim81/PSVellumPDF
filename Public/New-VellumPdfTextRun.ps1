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
    .PARAMETER Text
        The string content of this text run. Mandatory and positional (position 0).
    .PARAMETER Font
        A base-14 font name applied to this run only. When omitted the run
        inherits the document default font. Mutually exclusive with -FontHandle.
    .PARAMETER FontSize
        Font size in points for this run, between 1 and 1000. When omitted the
        run inherits the document default size.
    .PARAMETER FontHandle
        An EmbeddedFontHandle returned by Register-VellumPdfFont for the same
        document. When supplied, the run uses the embedded TrueType font instead
        of a base-14 font, and the base-14 encoding warning is suppressed.
        Handles are document-scoped; passing a handle from a different document
        is rejected by the content cmdlet.
    .PARAMETER Color
        Text colour as three doubles representing Red, Green, and Blue channels,
        each in the 0.0..1.0 range (e.g. 1,0,0 for pure red). Exactly three
        values must be supplied.
    .PARAMETER LinkUri
        Makes this run a clickable external hyperlink in the rendered PDF. Only
        http, https, and mailto URLs are allowed; any other scheme - and
        relative or scheme-relative URIs - is rejected. A whitespace-only value
        is treated as no link.
    .PARAMETER Leading
        Extra vertical line spacing in points added below each line of this run.
        When omitted the document-level leading applies.
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

    if (-not $FontHandle) {
        Write-VellumPdfEncodingWarning -Text $Text -CommandName 'New-VellumPdfTextRun'
    }

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
