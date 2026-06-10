function Add-VellumPdfParagraph {
    <#
    .SYNOPSIS
        Adds a paragraph of text to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(Paragraph). When no -Font/-FontSize/-Alignment override
        is supplied the document's default font (set by New-VellumPdfDocument) is
        used. The document flows through the pipeline for chaining.

        Use the 'Text' parameter set for a single-style paragraph.  Use the 'Runs'
        parameter set with the output of New-VellumPdfTextRun to compose a
        mixed-style paragraph (multiple fonts, colours, or hyperlinks in one
        paragraph).
    .EXAMPLE
        $doc | Add-VellumPdfParagraph -Text 'The quick brown fox.' -Alignment Justify
    .EXAMPLE
        $doc | Add-VellumPdfParagraph -Text 'Red heading.' -Color 1,0,0
    .EXAMPLE
        $run1 = New-VellumPdfTextRun -Text 'Normal '
        $run2 = New-VellumPdfTextRun -Text 'Bold' -Font HelveticaBold
        $doc | Add-VellumPdfParagraph -Run $run1, $run2
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        # --- Text parameter set ---
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Text')]
        [string]$Text,

        [Parameter(ParameterSetName = 'Text')]
        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font,

        [Parameter(ParameterSetName = 'Text')]
        [ValidateRange(1, 1000)]
        [double]$FontSize,

        [Parameter(ParameterSetName = 'Text')]
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [Parameter(ParameterSetName = 'Text')]
        [ValidateCount(3, 3)]
        [ValidateRange(0.0, 1.0)]
        [double[]]$Color,

        [Parameter(ParameterSetName = 'Text')]
        [string]$LinkUri,

        # --- Runs parameter set ---
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Runs')]
        [VellumPdf.Layout.Elements.TextRun[]]$Run,

        # --- Shared ---
        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Left'
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Runs') {
            $paragraph = [VellumPdf.Layout.Elements.Paragraph]::new(
                [System.Collections.Generic.List[VellumPdf.Layout.Elements.TextRun]]$Run)
            $paragraph.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
            [void]$Document.Add($paragraph)
            return $Document
        }

        # --- Text parameter set ---
        $wantsColor = $PSBoundParameters.ContainsKey('Color')
        $wantsLink  = $PSBoundParameters.ContainsKey('LinkUri') -and ($LinkUri -ne '')
        $wantsFont  = [bool]$Font -or $PSBoundParameters.ContainsKey('FontSize') -or $FontHandle
        $wantsStyle = $wantsFont -or $wantsColor -or $wantsLink

        if (-not $wantsStyle -and $Alignment -eq 'Left') {
            # No overrides at all: use the document's default font.
            [void]$Document.Add($Text, $null)
            return $Document
        }

        # A $null style makes the paragraph render with the document's default
        # font, so alignment-only paragraphs do not silently switch typeface.
        $style = if ($FontHandle) {
            $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { 11 }
            $sp = @{ FontHandle = $FontHandle; FontSize = $effSize }
            if ($wantsColor) { $sp['Color'] = $Color }
            if ($wantsLink)  { $sp['LinkUri'] = $LinkUri }
            New-VellumTextStyle @sp
        } elseif ($wantsFont) {
            $effFont = if ($Font) { $Font } else { 'Helvetica' }
            $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { 11 }
            $sp = @{ Font = $effFont; FontSize = $effSize }
            if ($wantsColor) { $sp['Color'] = $Color }
            if ($wantsLink)  { $sp['LinkUri'] = $LinkUri }
            New-VellumTextStyle @sp
        } elseif ($wantsColor -or $wantsLink) {
            # Color/LinkUri only, no font overrides - build a style without font info.
            $sp = @{}
            if ($wantsColor) { $sp['Color'] = $Color }
            if ($wantsLink)  { $sp['LinkUri'] = $LinkUri }
            New-VellumTextStyle @sp
        } else {
            $null
        }

        $paragraph = [VellumPdf.Layout.Elements.Paragraph]::new($Text, $style)
        $paragraph.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
        [void]$Document.Add($paragraph)
        $Document
    }
}
