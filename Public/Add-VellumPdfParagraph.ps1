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
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the paragraph is added, enabling chaining.
    .PARAMETER Text
        The string content of the paragraph. Used in the 'Text' parameter set
        for a single-style paragraph. Mandatory and positional (position 0).
    .PARAMETER Font
        A base-14 font name for the paragraph text. When omitted the document
        default font is used. Valid only in the 'Text' parameter set.
    .PARAMETER FontSize
        Font size in points for the paragraph, between 1 and 1000. When omitted
        the document default size is used. Valid only in the 'Text' parameter set.
    .PARAMETER FontHandle
        An EmbeddedFontHandle returned by Register-VellumPdfFont for this
        document. When supplied the paragraph uses the embedded TrueType font and
        the base-14 encoding warning is suppressed. Handles from a different
        document are rejected. Valid only in the 'Text' parameter set.
    .PARAMETER Color
        Text colour, given as an R,G,B triple in 0..1 (e.g. 1,0,0 for red), a hex
        string ('#3366cc' or '#36c'), or a colour name. Valid only in the 'Text'
        parameter set.
    .PARAMETER LinkUri
        Makes the entire paragraph a clickable external hyperlink. Only http,
        https, and mailto URLs are allowed; any other scheme - and relative or
        scheme-relative URIs - is rejected so a generated document cannot carry
        an active or local-resource link. A whitespace-only value is treated as
        no link. Valid only in the 'Text' parameter set.
    .PARAMETER Leading
        Extra vertical line spacing in points added below each line. When omitted
        the document-level leading applies. Valid only in the 'Text' parameter set.
    .PARAMETER Run
        An array of TextRun objects produced by New-VellumPdfTextRun that
        compose a mixed-style paragraph. Used in the 'Runs' parameter set.
        Mandatory and positional (position 0).
    .PARAMETER Language
        A BCP 47 language tag (e.g. 'fr') written for this paragraph; only used in
        tagged documents. VellumPdf does not validate the tag.
    .PARAMETER Alignment
        Horizontal alignment of the paragraph text. Accepts Left, Center, Right,
        or Justify. Defaults to Left. Applies to both parameter sets.
    .PARAMETER MarginTop
        Extra spacing in points above the paragraph element. Does not affect the
        left/right page margins. Applies to both parameter sets.
    .PARAMETER MarginBottom
        Extra spacing in points below the paragraph element. Does not affect the
        left/right page margins. Applies to both parameter sets.
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
        [ValidateRange(1.0, 1000.0)]
        [double]$FontSize,

        [Parameter(ParameterSetName = 'Text')]
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        # RGB triple (0..1), a hex string ('#3366cc'/'#36c'), or a colour name.
        [Parameter(ParameterSetName = 'Text')]
        [object]$Color,

        [Parameter(ParameterSetName = 'Text')]
        [string]$LinkUri,

        [Parameter(ParameterSetName = 'Text')]
        [ValidateRange(0.0, 1000.0)]
        [double]$Leading,

        # --- Runs parameter set ---
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Runs')]
        [VellumPdf.Layout.Elements.TextRun[]]$Run,

        # --- Shared ---
        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Left',

        # BCP 47 language tag for this paragraph (tagged documents only).
        [ValidateNotNullOrEmpty()]
        [string]$Language,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginTop,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginBottom
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfParagraph'
            Assert-VellumPdfLanguageTag -Value $Language -CommandName 'Add-VellumPdfParagraph'
            if ($FontHandle) {
                Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfParagraph'
                Write-VellumPdfMissingGlyphWarning -Handle $FontHandle -Text $Text -CommandName 'Add-VellumPdfParagraph'
            }

            if ($PSCmdlet.ParameterSetName -eq 'Runs') {
                if ($Run | Where-Object { $_.Style.LinkUri }) {
                    Write-VellumPdfLinkConformanceWarning -Document $Document -CommandName 'Add-VellumPdfParagraph'
                }
                # A run built by New-VellumPdfTextRun without its own font or size takes the document default
                # (otherwise the engine would draw it in Helvetica 12).
                $default = Resolve-VellumPdfDefault -Document $Document
                $filled = [System.Collections.Generic.List[VellumPdf.Layout.Elements.TextRun]]::new()
                $needsEmbedded = (Get-VellumPdfConformanceRequirement -Document $Document).NeedsEmbeddedFonts
                foreach ($r in $Run) {
                    $stamp = $r.PSObject.Properties['PSVellumRunBound']
                    if ($stamp -and ((-not ($stamp.Value -contains 'Font' -or $stamp.Value -contains 'FontHandle')) -or $stamp.Value -notcontains 'FontSize')) {
                        $merged = [VellumPdf.Layout.Core.TextStyle]::new()
                        # TextStyle.Font and FontRef replace each other: set exactly one of them.
                        if ($stamp.Value -contains 'FontHandle') { $merged.FontRef = $r.Style.FontRef }
                        elseif ($stamp.Value -contains 'Font') { $merged.Font = $r.Style.Font }
                        $merged.FontSize = $r.Style.FontSize
                        $merged.Leading = $r.Style.Leading
                        $merged.Color = $r.Style.Color
                        if ($r.Style.LinkUri) { $merged.LinkUri = $r.Style.LinkUri }   # assigning $null would store '' and write an empty link
                        if (-not ($stamp.Value -contains 'Font' -or $stamp.Value -contains 'FontHandle')) {
                            $merged.Font = [VellumPdf.Fonts.Standard14]::($default.Font)
                        }
                        if ($stamp.Value -notcontains 'FontSize') { $merged.FontSize = $default.FontSize }
                        $r = [VellumPdf.Layout.Elements.TextRun]::new($r.Text, $merged)
                    }
                    # A conformant document cannot use a base-14 font (a bare style draws Helvetica): swap in the
                    # embedded Liberation substitute on a copy, so the caller's run stays reusable elsewhere.
                    if ($needsEmbedded -and -not $r.Style.FontRef.IsEmbedded) {
                        $handle = Get-VellumPdfEmbeddedStandard14 -Document $Document -Font ([string]$r.Style.Font) -CommandName 'Add-VellumPdfParagraph'
                        $copy = [VellumPdf.Layout.Core.TextStyle]::new()
                        $copy.FontRef = [VellumPdf.Layout.Core.FontReference]::new($handle)
                        $copy.FontSize = $r.Style.FontSize
                        $copy.Leading = $r.Style.Leading
                        $copy.Color = $r.Style.Color
                        if ($r.Style.LinkUri) { $copy.LinkUri = $r.Style.LinkUri }
                        $r = [VellumPdf.Layout.Elements.TextRun]::new($r.Text, $copy)
                    }
                    $filled.Add($r)
                }
                $paragraph = [VellumPdf.Layout.Elements.Paragraph]::new($filled)
                $paragraph.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
                if ($Language) { $paragraph.Language = $Language }
                Set-VellumPdfElementMargin -Element $paragraph -Top $MarginTop -Bottom $MarginBottom `
                    -BoundParameters $PSBoundParameters -Document $Document -DeferBottom
                [void]$Document.Add($paragraph)
                return $Document
            }

            # --- Text parameter set ---
            if ($PSBoundParameters.ContainsKey('LinkUri') -and $LinkUri) {
                Write-VellumPdfLinkConformanceWarning -Document $Document -CommandName 'Add-VellumPdfParagraph'
            }
            if (-not $FontHandle) {
                Write-VellumPdfEncodingWarning -Text $Text -CommandName 'Add-VellumPdfParagraph'
            }
            $wantsColor   = $PSBoundParameters.ContainsKey('Color')
            if ($wantsColor) { $Color = ConvertTo-VellumColor $Color -Document $Document -CommandName 'Add-VellumPdfParagraph' }
            $wantsLink    = $PSBoundParameters.ContainsKey('LinkUri') -and ($LinkUri -ne '')
            $wantsLeading = $PSBoundParameters.ContainsKey('Leading')
            $wantsFont    = [bool]$Font -or $PSBoundParameters.ContainsKey('FontSize') -or $FontHandle
            $wantsStyle   = $wantsFont -or $wantsColor -or $wantsLink -or $wantsLeading

            if (-not $wantsStyle -and $Alignment -eq 'Left' -and -not $Language `
                    -and -not $PSBoundParameters.ContainsKey('MarginTop') `
                    -and -not $PSBoundParameters.ContainsKey('MarginBottom') `
                    -and -not $Document.PSObject.Properties['PSVellumPendingSpace']?.Value) {
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
                $style = New-VellumTextStyle @sp -Document $Document -CommandName 'Add-VellumPdfParagraph'
            } else {
                $effFont = if ($Font) { $Font } else { $default.Font }
                $sp = @{ Font = $effFont; FontSize = $effSize }
                if ($wantsColor)   { $sp['Color']   = $Color }
                if ($wantsLink)    { $sp['LinkUri'] = $LinkUri }
                if ($wantsLeading) { $sp['Leading'] = $Leading }
                $style = New-VellumTextStyle @sp -Document $Document -CommandName 'Add-VellumPdfParagraph'
            }

            $paragraph = [VellumPdf.Layout.Elements.Paragraph]::new($Text, $style)
            $paragraph.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
            if ($Language) { $paragraph.Language = $Language }
            Set-VellumPdfElementMargin -Element $paragraph -Top $MarginTop -Bottom $MarginBottom `
                -BoundParameters $PSBoundParameters -Document $Document -DeferBottom
            [void]$Document.Add($paragraph)
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Add-VellumPdfParagraph'))
        }
    }
}
