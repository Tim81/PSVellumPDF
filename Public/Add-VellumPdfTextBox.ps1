function Add-VellumPdfTextBox {
    <#
    .SYNOPSIS
        Places wrapped, optionally justified text in a column on a page of a page-based document.
    .DESCRIPTION
        Breaks -Text into lines that fit -Width (measured with the real font metrics) and
        draws them one under the other. A line break in -Text (`n) starts a new paragraph, a
        blank line leaves an empty line, and a word wider than the column is broken at
        character boundaries. -X is the left edge and -Y the top of the box in points from the
        page's bottom-left; the first baseline sits one -FontSize below -Y and the lines follow
        at -Leading (default 1.2 times the font size).

        A tab is expanded to four spaces before measuring; as in any wrapped text, runs of spaces
        and tabs separate words and are drawn as one space.

        -Align Justify stretches every line except the last line of a paragraph to the full
        width by widening the gaps between words. A justified line is drawn word by word, each
        word followed by an invisible space, so extracted text keeps its spaces.

        Without -MaxHeight, a box that would reach below the bottom of the page is an error (boxes are
        not split across pages). With -MaxHeight the box stops after the lines that fit and warns about the rest. Use
        -PassThru to get the number of lines and the height used (to place the next box); the
        object also carries the document.

        In a tagged page document the whole box is one structure element (-Role, default P).
        Use a base-14 font by name (-Font) or an embedded TrueType font (-FontHandle from
        Register-VellumPdfFont) for Unicode text. In a PDF/A document base-14 text is embedded
        automatically with a metric-compatible Liberation font.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Text
        The text to wrap.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER X
        Left edge of the column in points.
    .PARAMETER Y
        Top of the box in points from the bottom of the page.
    .PARAMETER Width
        Column width in points.
    .PARAMETER FontSize
        Size in points (default 12).
    .PARAMETER Font
        A base-14 font name (default Helvetica).
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont. Overrides -Font.
    .PARAMETER Color
        Text colour: RGB triple in 0..1, hex or name. Default black.
    .PARAMETER Align
        Left (default), Center, Right or Justify.
    .PARAMETER Leading
        Distance between baselines in points. Default 1.2 times -FontSize.
    .PARAMETER MaxHeight
        Maximum height of the box in points; lines beyond it are dropped with a warning.
    .PARAMETER Role
        In a tagged document: the structure role of the box - P (default), H1..H6, Span or Caption.
    .PARAMETER Language
        BCP 47 language tag of this text, written on its structure element (tagged documents).
    .PARAMETER PassThru
        Return an object with Document, LineCount, Height and Bottom (the y of the box's lower
        edge) instead of the document.
    .EXAMPLE
        $doc | Add-VellumPdfTextBox $text -X 72 -Y 700 -Width 220 -Align Justify
    .EXAMPLE
        $box = $doc | Add-VellumPdfTextBox $intro -X 72 -Y 700 -Width 300 -PassThru
        $box.Document | Add-VellumPdfTextBox $more -X 72 -Y ($box.Bottom - 12) -Width 300
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining), or with -PassThru a summary object.
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument], [pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,

        [Parameter(Mandatory)]
        [ValidateRange(1.0, 1000000.0)]
        [double]$Width,

        [ValidateRange(1.0, 1000.0)]
        [double]$FontSize = 12,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font = 'Helvetica',

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [object]$Color,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Align = 'Left',

        [ValidateRange(0.1, 10000.0)]
        [double]$Leading,

        [ValidateRange(0.1, 1000000.0)]
        [double]$MaxHeight,

        [ValidateSet('P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'Span', 'Caption')]
        [string]$Role = 'P',

        [ValidateNotNullOrEmpty()]
        [string]$Language,

        [switch]$PassThru
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfTextBox'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $(if ($PSBoundParameters.ContainsKey('Page')) { $PSBoundParameters['Page'] } else { 1 }) -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfTextBox'
            Assert-VellumPdfLanguageTag -Value $Language -CommandName 'Add-VellumPdfTextBox'
            Assert-VellumPdfValidText -Text $Text -CommandName 'Add-VellumPdfTextBox'
            $Text = Expand-VellumPdfTab -Text $Text
            $structType = Resolve-VellumPdfValidSetValue -Command $PSCmdlet.MyInvocation.MyCommand -Parameter 'Role' -Value $Role
            if (-not $FontHandle) { Assert-VellumPdfMeasurableFont -Font $Font -CommandName 'Add-VellumPdfTextBox' -Reason 'it wraps text' }
            Assert-VellumPdfCoordinate $X 'X' 'Add-VellumPdfTextBox'; Assert-VellumPdfCoordinate $Y 'Y' 'Add-VellumPdfTextBox'; Assert-VellumPdfCoordinate $Width 'Width' 'Add-VellumPdfTextBox'
            $bound = $PSBoundParameters
            if (-not $bound.ContainsKey('Leading')) { $Leading = 1.2 * $FontSize }

            $resolved = Get-VellumPdfPageFont -Document $Document -FontHandle $FontHandle -Font $Font -CommandName 'Add-VellumPdfTextBox'
            Write-VellumPdfMissingGlyphWarning -Handle $resolved.Handle -Text $Text -CommandName 'Add-VellumPdfTextBox'
            if (-not $resolved.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None) {
                Write-VellumPdfEncodingWarning -Text $Text -CommandName 'Add-VellumPdfTextBox'
            }
            $lines = [System.Collections.Generic.List[object]]::new()
            $lines.AddRange([object[]](Split-VellumPdfTextLine -Text $Text -Width $Width -Resolved $resolved -FontSize $FontSize))

            $allowed = $lines.Count
            $hadWords = [bool]($lines | Where-Object { $_.Words.Count -gt 0 })
            if ($bound.ContainsKey('MaxHeight')) {
                $allowed = [int][Math]::Floor($MaxHeight / $Leading + 1e-9)
                if ($lines.Count -gt $allowed) {
                    Write-Warning "Add-VellumPdfTextBox: the text needs $($lines.Count) lines but -MaxHeight $MaxHeight fits $allowed; the rest was dropped."
                    $lines.RemoveRange($allowed, $lines.Count - $allowed)
                }
            }
            $height = $lines.Count * $Leading

            # Without -MaxHeight the whole text is drawn, so it must fit above the bottom of the page
            # (the same rule Add-VellumPdfPageTable and Add-VellumPdfPageList apply).
            if (-not $bound.ContainsKey('MaxHeight') -and $hadWords) {
                $pageBottom = (Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfTextBox').MediaBox.LlY
                if ($Y - $height -lt $pageBottom) {
                    throw ("Add-VellumPdfTextBox: the text is $([math]::Round($height, 1)) pt tall ($($lines.Count) lines) but only " +
                        "$([math]::Round($Y - $pageBottom, 1)) pt are left below -Y on page $Page. Shorten the text, widen the box or use -MaxHeight to cut it off.")
                }
            }

            # A box without any word draws nothing: an empty tagged paragraph or heading is not valid structure.
            if (-not ($lines | Where-Object { $_.Words.Count -gt 0 })) {
                if ($hadWords) {
                    # The -MaxHeight limit dropped every line that had words; there is nothing left to draw.
                    if ($PassThru) { return [pscustomobject]@{ Document = $Document; LineCount = $lines.Count; Height = $height; Bottom = $Y - $height } }
                    return $Document
                }
                if ($Document.Tagged -and $structType -match '^H[1-6]$') {
                    throw "Add-VellumPdfTextBox: -Text has no words, so a $structType heading would be empty. Give it text or leave the box out."
                }
                Write-Verbose 'Add-VellumPdfTextBox: -Text has no words; nothing was drawn.'
                if ($PassThru) { return [pscustomobject]@{ Document = $Document; LineCount = $lines.Count; Height = $height; Bottom = $Y - $height } }
                return $Document
            }

            $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfTextBox'
            $pdfPage = $Document.Pages[$Page - 1]
            if (-not $Document.Tagged -and ($bound.ContainsKey('Role') -or $bound.ContainsKey('Language'))) {
                Write-Verbose 'Add-VellumPdfTextBox: -Role/-Language only matter in a tagged document (New-VellumPdfPageDocument -Tagged).'
            }

            [void]$canvas.SaveState()
            try {
                if ($bound.ContainsKey('Color')) {
                    $c = ConvertTo-VellumColor $Color -Document $Document -CommandName 'Add-VellumPdfTextBox'
                    [void]$canvas.SetFillColorRgb($c[0], $c[1], $c[2])
                }
                if ($resolved.Handle) { $Document.RegisterEmbeddedFontUsage($pdfPage, $resolved.Handle) }
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType $structType -Language $Language -Draw {
                    Write-VellumPdfTextLine -Canvas $canvas -Resolved $resolved -FontSize $FontSize -Lines $lines.ToArray() -X $X -Top $Y -Width $Width -Leading $Leading -Align $Align
                }
            }
            finally { [void]$canvas.RestoreState() }

            if ($PassThru) {
                [pscustomobject]@{ Document = $Document; LineCount = $lines.Count; Height = $height; Bottom = $Y - $height }
            }
            else { $Document }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Add-VellumPdfTextBox'))
        }
    }
}
