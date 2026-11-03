function Measure-VellumPdfText {
    <#
    .SYNOPSIS
        Measures the width of a line of text in a PDF font.
    .DESCRIPTION
        Returns how wide the text is in points when drawn in a base-14 font (-Font) or an embedded
        TrueType font (-FontHandle from Register-VellumPdfFont), using the same metrics the drawing
        cmdlets use for alignment and wrapping. Use it to size a box, to centre something by hand or
        to check that a label fits before placing it. -CharSpacing, -WordSpacing and
        -HorizontalScale are added the way Add-VellumPdfText applies them. The width is the PDF advance
        width: with -CharSpacing it includes the space after the last character (a viewer adds it there
        too), whereas Add-VellumPdfText aligns on the visible extent without it. A tab is measured as
        four spaces, which is how the drawing cmdlets draw it.

        The result also lists characters the font cannot show: UnencodableCharacters for a base-14 font
        (outside Windows-1252, drawn as a question mark) and MissingGlyphs for an embedded font (drawn
        as an empty box). The text must be a single line.
    .PARAMETER Text
        The text to measure. A single line; accepts pipeline input.
    .PARAMETER FontSize
        Size in points (default 12).
    .PARAMETER Font
        A base-14 font name (default Helvetica).
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont. Overrides -Font.
    .PARAMETER CharSpacing
        Extra space after every character, in points.
    .PARAMETER WordSpacing
        Extra space after every space character, in points.
    .PARAMETER HorizontalScale
        Horizontal scaling in percent (100 is normal).
    .EXAMPLE
        Measure-VellumPdfText 'Invoice 2026-001' -FontSize 18 -Font HelveticaBold | Select-Object -ExpandProperty Width
    .EXAMPLE
        $width = (Measure-VellumPdfText $label -FontSize 10).Width
        $doc | Add-VellumPdfText $label -X (300 - $width / 2) -Y 700 -FontSize 10
    .OUTPUTS
        PSVellumPDF.TextMeasurement with Text, Font, FontSize, Width, UnencodableCharacters and MissingGlyphs.
    #>
    [CmdletBinding()]
    [OutputType('PSVellumPDF.TextMeasurement')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,

        [ValidateRange(1.0, 1000.0)]
        [double]$FontSize = 12,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font = 'Helvetica',

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [ValidateRange(-100.0, 100.0)]
        [double]$CharSpacing = 0,

        [ValidateRange(-100.0, 100.0)]
        [double]$WordSpacing = 0,

        [ValidateRange(1.0, 1000.0)]
        [double]$HorizontalScale = 100
    )

    process {
        try {
            if ($Text -match '[\r\n]') { throw 'Measure-VellumPdfText: -Text must be a single line.' }
            Assert-VellumPdfValidText -Text $Text -CommandName 'Measure-VellumPdfText'
            $measured = Expand-VellumPdfTab -Text $Text
            if (-not $FontHandle) { Assert-VellumPdfMeasurableFont -Font $Font -CommandName 'Measure-VellumPdfText' -Reason 'it measures text' }
            $resolved = $null
            $unencodable = [System.Collections.Generic.List[string]]::new()
            $missing = [System.Collections.Generic.List[string]]::new()
            if ($FontHandle) {
                $resolved = [pscustomobject]@{ Handle = $FontHandle; Resource = $null }
                foreach ($rune in $measured.EnumerateRunes()) {
                    if ($FontHandle.GetGlyphId($rune.Value) -eq 0 -and -not $missing.Contains($rune.ToString())) { $missing.Add($rune.ToString()) }
                }
                $fontName = 'embedded'
            }
            else {
                $standard = [VellumPdf.Fonts.Standard14]::$Font
                $resource = [pscustomobject]@{}
                $resource | Add-Member -MemberType ScriptMethod -Name MeasureString -Value {
                    param([string]$s, [double]$size)
                    [VellumPdf.Fonts.Standard14Metrics]::MeasureString($standard, $s, $size)
                }.GetNewClosure()
                $resolved = [pscustomobject]@{ Handle = $null; Resource = $resource }
                for ($i = 0; $i -lt $measured.Length; $i++) {
                    $code = [int]$measured[$i]
                    if ($code -lt 0x80 -or (Test-VellumPdfWinAnsiChar -CodeUnit $code)) { continue }
                    $shown = if ([char]::IsHighSurrogate($measured[$i]) -and $i + 1 -lt $measured.Length) { $measured.Substring($i, 2) } else { [string]$measured[$i] }
                    if ($shown.Length -eq 2) { $i++ }
                    if (-not $unencodable.Contains($shown)) { $unencodable.Add($shown) }
                }
                $fontName = $Font
            }
            $width = Measure-VellumPdfTextWidth -Resolved $resolved -Text $measured -FontSize $FontSize -CharSpacing $CharSpacing -WordSpacing $WordSpacing -HorizontalScale $HorizontalScale
            [pscustomobject]@{
                PSTypeName             = 'PSVellumPDF.TextMeasurement'
                Text                   = $Text
                Font                   = $fontName
                FontSize               = $FontSize
                Width                  = [math]::Round($width, 4)
                UnencodableCharacters  = $unencodable.ToArray()
                MissingGlyphs          = $missing.ToArray()
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Measure-VellumPdfText'))
        }
    }
}
