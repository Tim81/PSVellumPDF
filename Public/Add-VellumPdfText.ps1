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
        forbids non-embedded fonts. A tab is drawn as four spaces (a tab has no glyph in a PDF font).
        For several lines of wrapped text use the
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
        Extra space after every character, in points; negative tightens. Alignment accounts for it: the space after the
        last character is not counted, so right-aligned text ends exactly at -X and centred text is
        centred on its visible glyphs.
    .PARAMETER WordSpacing
        Extra space after every space character, in points.
    .PARAMETER Rise
        Baseline shift in points: positive for superscript, negative for subscript.
    .PARAMETER HorizontalScale
        Horizontal scaling in percent (100 is normal, 50 half width).
    .PARAMETER Rotation
        Rotates the text about its anchor point (-X, -Y), in degrees counter-clockwise. Alignment is
        applied along the rotated baseline.
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

        [ValidateRange(1.0, 1000.0)]
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
        [ValidateRange(-100.0, 100.0)]
        [double]$CharSpacing,

        # Extra space after every space character, in points.
        [ValidateRange(-100.0, 100.0)]
        [double]$WordSpacing,

        # Baseline shift in points: positive raises (superscript), negative lowers.
        [ValidateRange(-1000.0, 1000.0)]
        [double]$Rise,

        # Horizontal scaling in percent (100 = normal).
        [ValidateRange(1.0, 1000.0)]
        [double]$HorizontalScale,

        # Rotation about the anchor (X, Y) in degrees, counter-clockwise.
        [double]$Rotation,

        # Structure role in a tagged document: P (default), H1-H6, Span or Caption.
        [ValidateSet('P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'Span', 'Caption')]
        [string]$Role = 'P',

        # BCP 47 language of this text, for a tagged document.
        [ValidateNotNullOrEmpty()]
        [string]$Language
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfText'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $(if ($PSBoundParameters.ContainsKey('Page')) { $PSBoundParameters['Page'] } else { 1 }) -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfText'
            Assert-VellumPdfLanguageTag -Value $Language -CommandName 'Add-VellumPdfText'
            Assert-VellumPdfValidText -Text $Text -CommandName 'Add-VellumPdfText'
            $Text = Expand-VellumPdfTab -Text $Text
            $structType = Resolve-VellumPdfValidSetValue -Command $PSCmdlet.MyInvocation.MyCommand -Parameter 'Role' -Value $Role
            Assert-VellumPdfCoordinate $X 'X' 'Add-VellumPdfText'; Assert-VellumPdfCoordinate $Y 'Y' 'Add-VellumPdfText'
            if ($Text -match '[\r\n]') { throw 'Add-VellumPdfText: -Text must be a single line; use New-VellumPdfDocument for wrapped text.' }

            $resolved = Get-VellumPdfPageFont -Document $Document -FontHandle $FontHandle -Font $Font -CommandName 'Add-VellumPdfText'
            Write-VellumPdfMissingGlyphWarning -Handle $resolved.Handle -Text $Text -CommandName 'Add-VellumPdfText'
            if (-not $FontHandle -and ($Align -ne 'Left' -or $PSBoundParameters.ContainsKey('CharSpacing') -or $PSBoundParameters.ContainsKey('WordSpacing') -or $PSBoundParameters.ContainsKey('HorizontalScale'))) {
                Assert-VellumPdfMeasurableFont -Font $Font -CommandName 'Add-VellumPdfText' -Reason 'it aligns or spaces the text'
            }
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
            $rotated = $bound.ContainsKey('Rotation') -and $Rotation -ne 0
            if ($bound.ContainsKey('Rotation') -and -not [double]::IsFinite($Rotation)) { throw 'Add-VellumPdfText: -Rotation must be a finite number of degrees.' }
            $anchorX = $X; $anchorY = $Y
            # Rotated text is drawn at the origin of a rotated, moved coordinate system.
            $drawX = if ($rotated) { 0.0 } else { $X }
            $drawY = if ($rotated) { 0.0 } else { $Y }
            $hasSpacing = $bound.ContainsKey('CharSpacing') -or $bound.ContainsKey('WordSpacing') -or $bound.ContainsKey('HorizontalScale')
            $startX = $drawX
            $showAlignment = [VellumPdf.Canvas.TextAlignment]::$Align
            $tc = if ($bound.ContainsKey('CharSpacing')) { $CharSpacing } else { 0.0 }
            $tw = if ($bound.ContainsKey('WordSpacing')) { $WordSpacing } else { 0.0 }
            $th = if ($bound.ContainsKey('HorizontalScale')) { $HorizontalScale } else { 100.0 }
            if ($hasSpacing -and $Align -ne 'Left') {
                $width = Measure-VellumPdfTextWidth -Resolved $resolved -Text $Text -FontSize $FontSize -CharSpacing $tc -WordSpacing $tw -HorizontalScale $th -VisibleExtent
                $startX = if ($Align -eq 'Center') { $drawX - $width / 2 } else { $drawX - $width }
                $showAlignment = [VellumPdf.Canvas.TextAlignment]::Left
            }
            # Word spacing (Tw) only applies to the single-byte space code. An embedded font is drawn with
            # two-byte glyph ids, so viewers ignore it; place the words one by one instead.
            $placeWords = [bool]($resolved.Handle -and $bound.ContainsKey('WordSpacing'))

            [void]$canvas.SaveState()
            try {
                if ($rotated) {
                    $radians = $Rotation * [math]::PI / 180
                    $cos = [math]::Round([math]::Cos($radians), 8) + 0.0
                    $sin = [math]::Round([math]::Sin($radians), 8) + 0.0
                    [void]$canvas.Concat($cos, $sin, (0.0 - $sin), $cos, $anchorX, $anchorY)
                }
                if ($bound.ContainsKey('Color')) {
                    $c = ConvertTo-VellumColor $Color
                    [void]$canvas.SetFillColorRgb($c[0], $c[1], $c[2])
                }
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType $structType -Language $Language -Draw {
                    [void]$canvas.BeginText()
                    try {
                    if ($bound.ContainsKey('CharSpacing')) { [void]$canvas.SetCharSpacing($CharSpacing) }
                    if ($bound.ContainsKey('WordSpacing') -and -not $placeWords) { [void]$canvas.SetWordSpacing($WordSpacing) }
                    if ($bound.ContainsKey('Rise')) { [void]$canvas.SetTextRise($Rise) }
                    if ($bound.ContainsKey('HorizontalScale')) { [void]$canvas.SetHorizScaling($HorizontalScale) }
                    if ($resolved.Handle) {
                        $Document.RegisterEmbeddedFontUsage($pdfPage, $resolved.Handle)
                        [void]$canvas.SetFontByName($resolved.Handle.ResourceName, $FontSize)
                        if ($placeWords) {
                            # Each word keeps its trailing space glyph, so extracted text still has its spaces.
                            $cursor = $startX
                            foreach ($m in [regex]::Matches($Text, '[^ ]*(?: |$)')) {
                                $piece = $m.Value
                                if ($piece.Length -eq 0) { continue }
                                [void][PSVellumPDF.Interop.CanvasHelpers]::ShowEmbeddedText($canvas, $resolved.Handle, $piece, $FontSize, $cursor, $drawY, [VellumPdf.Canvas.TextAlignment]::Left)
                                $trailing = if ($piece.EndsWith(' ')) { $tw } else { 0.0 }
                                $cursor += Measure-VellumPdfTextWidth -Resolved $resolved -Text $piece -FontSize $FontSize -CharSpacing $tc -WordSpacing $trailing -HorizontalScale $th
                            }
                        }
                        else {
                            [void][PSVellumPDF.Interop.CanvasHelpers]::ShowEmbeddedText($canvas, $resolved.Handle, $Text, $FontSize, $startX, $drawY, $showAlignment)
                        }
                    }
                    else {
                        [void]$canvas.SetFont($resolved.Resource, $FontSize)
                        [void]$canvas.ShowTextAligned($Text, $startX, $drawY, $showAlignment)
                    }
                    }
                    finally { [void]$canvas.EndText() }
                }
            }
            finally { [void]$canvas.RestoreState() }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
