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

        -Align Justify stretches every line except the last line of a paragraph to the full
        width by widening the gaps between words. A justified line is drawn word by word, each
        word followed by an invisible space, so extracted text keeps its spaces.

        With -MaxHeight the box stops after the lines that fit and warns about the rest. Use
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
        [ValidateRange(1, 1000000)]
        [double]$Width,

        [ValidateRange(1, 1000)]
        [double]$FontSize = 12,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font = 'Helvetica',

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [object]$Color,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Align = 'Left',

        [ValidateRange(0.1, 10000)]
        [double]$Leading,

        [ValidateRange(0.1, 1000000)]
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
            Assert-VellumPdfCoordinate $X 'X' 'Add-VellumPdfTextBox'; Assert-VellumPdfCoordinate $Y 'Y' 'Add-VellumPdfTextBox'; Assert-VellumPdfCoordinate $Width 'Width' 'Add-VellumPdfTextBox'
            $bound = $PSBoundParameters
            if (-not $bound.ContainsKey('Leading')) { $Leading = 1.2 * $FontSize }

            $resolved = Get-VellumPdfPageFont -Document $Document -FontHandle $FontHandle -Font $Font -CommandName 'Add-VellumPdfTextBox'
            if (-not $resolved.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None) {
                Write-VellumPdfEncodingWarning -Text $Text -CommandName 'Add-VellumPdfTextBox'
            }
            $measure = if ($resolved.Handle) {
                { param($s) $resolved.Handle.MeasureString($s, $FontSize) }
            }
            else {
                { param($s) $resolved.Resource.MeasureString($s, $FontSize) }
            }

            # Greedy line breaking. Each line remembers whether it ends its paragraph (not justified then).
            $lines = [System.Collections.Generic.List[object]]::new()
            foreach ($paragraph in ($Text -split '\r?\n')) {
                $words = @($paragraph -split '\s+' | Where-Object { $_ -ne '' })
                if ($words.Count -eq 0) { $lines.Add([pscustomobject]@{ Words = @(); Last = $true }); continue }
                $current = [System.Collections.Generic.List[string]]::new()
                foreach ($word in $words) {
                    $pieces = @($word)
                    if ((& $measure $word) -gt $Width) {
                        # Wider than the column: split at character boundaries.
                        $pieces = [System.Collections.Generic.List[string]]::new()
                        $chunk = ''
                        foreach ($ch in [System.Text.Rune[]]($word.EnumerateRunes() | ForEach-Object { $_ })) {
                            $next = $chunk + $ch.ToString()
                            if ($chunk -ne '' -and (& $measure $next) -gt $Width) { $pieces.Add($chunk); $chunk = $ch.ToString() }
                            else { $chunk = $next }
                        }
                        if ($chunk -ne '') { $pieces.Add($chunk) }
                    }
                    foreach ($piece in $pieces) {
                        $candidate = if ($current.Count) { ($current -join ' ') + ' ' + $piece } else { $piece }
                        if ($current.Count -and (& $measure $candidate) -gt $Width) {
                            $lines.Add([pscustomobject]@{ Words = $current.ToArray(); Last = $false })
                            $current = [System.Collections.Generic.List[string]]::new()
                        }
                        $current.Add($piece)
                    }
                }
                $lines.Add([pscustomobject]@{ Words = $current.ToArray(); Last = $true })
            }

            $allowed = $lines.Count
            if ($bound.ContainsKey('MaxHeight')) {
                $allowed = [Math]::Max(1, [int][Math]::Floor($MaxHeight / $Leading))
                if ($lines.Count -gt $allowed) {
                    Write-Warning "Add-VellumPdfTextBox: the text needs $($lines.Count) lines but -MaxHeight $MaxHeight fits $allowed; the rest was dropped."
                    $lines.RemoveRange($allowed, $lines.Count - $allowed)
                }
            }
            $height = $lines.Count * $Leading

            $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfTextBox'
            $pdfPage = $Document.Pages[$Page - 1]
            if (-not $Document.Tagged -and ($bound.ContainsKey('Role') -or $bound.ContainsKey('Language'))) {
                Write-Verbose 'Add-VellumPdfTextBox: -Role/-Language only matter in a tagged document (New-VellumPdfPageDocument -Tagged).'
            }

            [void]$canvas.SaveState()
            try {
                if ($bound.ContainsKey('Color')) {
                    $c = ConvertTo-VellumColor $Color
                    [void]$canvas.SetFillColorRgb($c[0], $c[1], $c[2])
                }
                if ($resolved.Handle) { $Document.RegisterEmbeddedFontUsage($pdfPage, $resolved.Handle) }
                $show = {
                    param([string]$s, [double]$x, [double]$y, $alignment)
                    if ($resolved.Handle) {
                        [void][PSVellumPDF.Interop.CanvasHelpers]::ShowEmbeddedText($canvas, $resolved.Handle, $s, $FontSize, $x, $y, $alignment)
                    }
                    else { [void]$canvas.ShowTextAligned($s, $x, $y, $alignment) }
                }
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType $Role -Language $Language -Draw {
                    $row = 0
                    foreach ($line in $lines) {
                        $baseline = $Y - $FontSize - $row * $Leading
                        $row++
                        if ($line.Words.Count -eq 0) { continue }
                        [void]$canvas.BeginText()
                        if ($resolved.Handle) { [void]$canvas.SetFontByName($resolved.Handle.ResourceName, $FontSize) }
                        else { [void]$canvas.SetFont($resolved.Resource, $FontSize) }
                        $textLine = $line.Words -join ' '
                        if ($Align -eq 'Justify' -and -not $line.Last -and $line.Words.Count -gt 1) {
                            $wordsWidth = 0.0
                            foreach ($w in $line.Words) { $wordsWidth += (& $measure $w) }
                            $gap = ($Width - $wordsWidth) / ($line.Words.Count - 1)
                            $cursor = $X
                            for ($n = 0; $n -lt $line.Words.Count; $n++) {
                                $w = $line.Words[$n]
                                # Every word but the last carries its trailing space in the same run: the space is
                                # invisible (the next word sits further right), but text extraction then finds it.
                                $shown = if ($n -lt $line.Words.Count - 1) { $w + ' ' } else { $w }
                                & $show $shown $cursor $baseline ([VellumPdf.Canvas.TextAlignment]::Left)
                                $cursor += (& $measure $w) + $gap
                            }
                        }
                        elseif ($Align -eq 'Center') { & $show $textLine ($X + $Width / 2) $baseline ([VellumPdf.Canvas.TextAlignment]::Center) }
                        elseif ($Align -eq 'Right') { & $show $textLine ($X + $Width) $baseline ([VellumPdf.Canvas.TextAlignment]::Right) }
                        else { & $show $textLine $X $baseline ([VellumPdf.Canvas.TextAlignment]::Left) }
                        [void]$canvas.EndText()
                    }
                }
            }
            finally { [void]$canvas.RestoreState() }

            if ($PassThru) {
                [pscustomobject]@{ Document = $Document; LineCount = $lines.Count; Height = $height; Bottom = $Y - $height }
            }
            else { $Document }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
