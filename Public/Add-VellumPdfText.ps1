function Add-VellumPdfText {
    <#
    .SYNOPSIS
        Places a line of text at x/y on a page of a page-based document.
    .DESCRIPTION
        Draws one line (no wrapping) with its baseline starting at (-X, -Y), in
        points from the page's bottom-left. -Align Center/Right positions the text
        about x instead. Use a base-14 font by name (-Font), or an embedded
        TrueType font (-FontHandle from Register-VellumPdfFont) for Unicode text.

        In a PDF/A document base-14 text is embedded automatically with a
        metric-compatible Liberation font (VellumPdf.Fonts.Standard14), as PDF/A
        forbids non-embedded fonts. For several lines of wrapped text use the
        flow-layout document (New-VellumPdfDocument).
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Text
        The text. A single line; line breaks are not supported.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER X
        Left edge (or centre/right edge with -Align) in points.
    .PARAMETER Y
        Baseline in points from the bottom of the page.
    .PARAMETER FontSize
        Size in points (default 12).
    .PARAMETER Font
        A base-14 font name (default Helvetica).
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont. Overrides -Font.
    .PARAMETER Color
        Text colour: RGB triple in 0..1, hex or name. Default black.
    .PARAMETER Align
        Left (default), Center or Right, about -X.
    .PARAMETER CharSpacing
        Extra space after every character, in points; negative tightens. Alignment accounts for it.
    .PARAMETER WordSpacing
        Extra space after every space character, in points.
    .PARAMETER Rise
        Baseline shift in points: positive for superscript, negative for subscript.
    .PARAMETER HorizontalScale
        Horizontal scaling in percent (100 is normal, 50 half width).
    .PARAMETER Role
        In a tagged document (New-VellumPdfPageDocument -Tagged, PdfA2a or PdfUA1): the
        structure role of this text - P (default), H1..H6, Span or Caption.
    .PARAMETER Language
        BCP 47 language tag of this text, written on its structure element (tagged documents).
    .EXAMPLE
        $doc | Add-VellumPdfText 'Invoice 2026-001' -X 72 -Y 760 -FontSize 18 -Font HelveticaBold
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [string]$Text,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,

        [ValidateRange(1, 1000)]
        [double]$FontSize = 12,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font = 'Helvetica',

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [object]$Color,

        [ValidateSet('Left', 'Center', 'Right')]
        [string]$Align = 'Left',

        # Extra space after every character, in points (negative tightens).
        [ValidateRange(-100, 100)]
        [double]$CharSpacing,

        # Extra space after every space character, in points.
        [ValidateRange(-100, 100)]
        [double]$WordSpacing,

        # Baseline shift in points: positive raises (superscript), negative lowers.
        [ValidateRange(-1000, 1000)]
        [double]$Rise,

        # Horizontal scaling in percent (100 = normal).
        [ValidateRange(1, 1000)]
        [double]$HorizontalScale,

        # Structure role in a tagged document: P (default), H1-H6, Span or Caption.
        [ValidateSet('P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'Span', 'Caption')]
        [string]$Role = 'P',

        # BCP 47 language of this text, for a tagged document.
        [ValidateNotNullOrEmpty()]
        [string]$Language
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfText'
        if (-not [double]::IsFinite($X) -or -not [double]::IsFinite($Y)) { throw 'Add-VellumPdfText: -X and -Y must be finite.' }
        if ($Text -match '[\r\n]') { throw 'Add-VellumPdfText: -Text must be a single line; use New-VellumPdfDocument for wrapped text.' }

        $resolved = Get-VellumPdfPageFont -Document $Document -FontHandle $FontHandle -Font $Font -CommandName 'Add-VellumPdfText'
        if (-not $resolved.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None) {
            Write-VellumPdfEncodingWarning -Text $Text -CommandName 'Add-VellumPdfText'
        }
        $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfText'
        $pdfPage = $Document.Pages[$Page - 1]
        $bound = $PSBoundParameters
        if (-not $Document.Tagged -and ($bound.ContainsKey('Role') -or $bound.ContainsKey('Language'))) {
            Write-Verbose 'Add-VellumPdfText: -Role/-Language only matter in a tagged document (New-VellumPdfPageDocument -Tagged).'
        }

        # Alignment shifts the start by the text's width. The engine measures without
        # character/word spacing and scaling, so when those are set the width is computed
        # here and the text is placed left-aligned at the adjusted x.
        $hasSpacing = $bound.ContainsKey('CharSpacing') -or $bound.ContainsKey('WordSpacing') -or $bound.ContainsKey('HorizontalScale')
        $startX = $X
        $showAlignment = [VellumPdf.Canvas.TextAlignment]::$Align
        if ($hasSpacing -and $Align -ne 'Left') {
            $base = if ($resolved.Handle) { $resolved.Handle.MeasureString($Text, $FontSize) } else { $resolved.Resource.MeasureString($Text, $FontSize) }
            $spaces = ($Text.ToCharArray() | Where-Object { $_ -eq ' ' } | Measure-Object).Count
            $width = ($base + $CharSpacing * $Text.Length + $WordSpacing * $spaces) * $(if ($bound.ContainsKey('HorizontalScale')) { $HorizontalScale / 100 } else { 1 })
            $startX = if ($Align -eq 'Center') { $X - $width / 2 } else { $X - $width }
            $showAlignment = [VellumPdf.Canvas.TextAlignment]::Left
        }

        [void]$canvas.SaveState()
        try {
            if ($bound.ContainsKey('Color')) {
                $c = ConvertTo-VellumColor $Color
                [void]$canvas.SetFillColorRgb($c[0], $c[1], $c[2])
            }
            Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType $Role -Language $Language -Draw {
                [void]$canvas.BeginText()
                if ($bound.ContainsKey('CharSpacing')) { [void]$canvas.SetCharSpacing($CharSpacing) }
                if ($bound.ContainsKey('WordSpacing')) { [void]$canvas.SetWordSpacing($WordSpacing) }
                if ($bound.ContainsKey('Rise')) { [void]$canvas.SetTextRise($Rise) }
                if ($bound.ContainsKey('HorizontalScale')) { [void]$canvas.SetHorizScaling($HorizontalScale) }
                if ($resolved.Handle) {
                    $Document.RegisterEmbeddedFontUsage($pdfPage, $resolved.Handle)
                    [void]$canvas.SetFontByName($resolved.Handle.ResourceName, $FontSize)
                    [void][PSVellumPDF.Interop.CanvasHelpers]::ShowEmbeddedText($canvas, $resolved.Handle, $Text, $FontSize, $startX, $Y, $showAlignment)
                }
                else {
                    [void]$canvas.SetFont($resolved.Resource, $FontSize)
                    [void]$canvas.ShowTextAligned($Text, $startX, $Y, $showAlignment)
                }
                [void]$canvas.EndText()
            }
        }
        finally { [void]$canvas.RestoreState() }
        $Document
    }
}
