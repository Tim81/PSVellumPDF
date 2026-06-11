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

        -Leading (Text set only) sets the extra vertical spacing between lines,
        in points.

        -MarginTop and -MarginBottom apply spacing above and below the paragraph
        without affecting the left/right margins already set on the element.
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

        [Parameter(ParameterSetName = 'Text')]
        [ValidateRange(0, 1000)]
        [double]$Leading,

        # --- Runs parameter set ---
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Runs')]
        [VellumPdf.Layout.Elements.TextRun[]]$Run,

        # --- Shared ---
        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Left',

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfParagraph'
        if ($FontHandle) {
            Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfParagraph'
        }

        if ($PSCmdlet.ParameterSetName -eq 'Runs') {
            $paragraph = [VellumPdf.Layout.Elements.Paragraph]::new(
                [System.Collections.Generic.List[VellumPdf.Layout.Elements.TextRun]]$Run)
            $paragraph.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
            Set-VellumPdfElementMargin -Element $paragraph -Top $MarginTop -Bottom $MarginBottom `
                -BoundParameters $PSBoundParameters
            [void]$Document.Add($paragraph)
            return $Document
        }

        # --- Text parameter set ---
        if (-not $FontHandle) {
            Write-VellumPdfEncodingWarning -Text $Text -CommandName 'Add-VellumPdfParagraph'
        }
        $wantsColor   = $PSBoundParameters.ContainsKey('Color')
        $wantsLink    = $PSBoundParameters.ContainsKey('LinkUri') -and ($LinkUri -ne '')
        $wantsLeading = $PSBoundParameters.ContainsKey('Leading')
        $wantsFont    = [bool]$Font -or $PSBoundParameters.ContainsKey('FontSize') -or $FontHandle
        $wantsStyle   = $wantsFont -or $wantsColor -or $wantsLink -or $wantsLeading

        if (-not $wantsStyle -and $Alignment -eq 'Left' `
                -and -not $PSBoundParameters.ContainsKey('MarginTop') `
                -and -not $PSBoundParameters.ContainsKey('MarginBottom')) {
            # No overrides at all: use the document's default font.
            [void]$Document.Add($Text, $null)
            return $Document
        }

        # An explicit Paragraph needs a complete style: VellumPdf renders any
        # style without a font in the library-global Helvetica, NOT the document
        # default. Fill gaps from the stashed document defaults instead.
        $default = Resolve-VellumPdfDefault -Document $Document
        $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { $default.FontSize }
        if ($FontHandle) {
            $sp = @{ FontHandle = $FontHandle; FontSize = $effSize }
            if ($wantsColor)   { $sp['Color']   = $Color }
            if ($wantsLink)    { $sp['LinkUri'] = $LinkUri }
            if ($wantsLeading) { $sp['Leading'] = $Leading }
            $style = New-VellumTextStyle @sp
        } else {
            $effFont = if ($Font) { $Font } else { $default.Font }
            $sp = @{ Font = $effFont; FontSize = $effSize }
            if ($wantsColor)   { $sp['Color']   = $Color }
            if ($wantsLink)    { $sp['LinkUri'] = $LinkUri }
            if ($wantsLeading) { $sp['Leading'] = $Leading }
            $style = New-VellumTextStyle @sp
        }

        $paragraph = [VellumPdf.Layout.Elements.Paragraph]::new($Text, $style)
        $paragraph.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
        Set-VellumPdfElementMargin -Element $paragraph -Top $MarginTop -Bottom $MarginBottom `
            -BoundParameters $PSBoundParameters
        [void]$Document.Add($paragraph)
        $Document
    }
}
