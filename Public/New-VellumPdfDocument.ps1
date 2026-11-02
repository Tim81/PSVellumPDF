function New-VellumPdfDocument {
    <#
    .SYNOPSIS
        Creates a new VellumPdf layout document.
    .DESCRIPTION
        Returns a live VellumPdf.Layout.Document. Pipe it through the Add-VellumPdf*
        functions and finish with Save-VellumPdfDocument, which disposes it.

        The document is IDisposable. If you do not call Save-VellumPdfDocument,
        dispose it yourself with $doc.Dispose().

        Page margins can be set uniformly with -Margin, or per-side with
        -MarginTop, -MarginRight, -MarginBottom, -MarginLeft.  When any per-side
        parameter is supplied, the uniform -Margin value (if given) is used as
        the baseline for the unspecified sides; otherwise the library defaults
        are kept for unspecified sides.

        -UseObjectStreams enables PDF cross-reference object streams, which
        reduces file size for documents with many objects.
    .PARAMETER Conformance
        The conformance level for the document. Use PdfA2b, PdfA2u, or PdfA2a to
        produce an ISO 19005-2 compliant archive file, or PdfUA1 for ISO 14289-1
        (PDF/UA-1) accessibility; None (default) produces a standard PDF without
        conformance requirements. PDF/UA-1 forces a tagged document. To pass the
        preflight (Test-VellumPdfConformance, or Save-VellumPdfDocument -Validate)
        also set -Language, give the document a title with Set-VellumPdfDocumentInfo
        -Title, and give images, charts and barcodes alternate text. Both levels
        require embedded fonts: a conformant document therefore draws every base-14
        font name it uses (the document default, -Font on paragraphs, headings,
        tables, lists, text runs, headers and footers) in the metric-compatible
        Liberation font (Helvetica -> Liberation Sans, Times -> Serif, Courier ->
        Mono, with bold and italic variants), embedded once per document; layout is
        unchanged. Symbol and ZapfDingbats have no substitute: use -FontHandle
        (Register-VellumPdfFont) for those and for text outside Windows-1252. Text
        in embedded fonts is not extracted by Get-VellumPdfText (its reader decodes
        simple fonts only). A document without -Conformance keeps the plain base-14
        fonts. Hyperlinks (-LinkUri) are not tagged by
        VellumPdf, so a PDF/UA document containing them is not fully conformant.
        Note that PDF/A forbids encryption, so PDF/A is incompatible with
        Protect-VellumPdfDocument; PDF/UA-1 may be encrypted if Extract is kept.
    .PARAMETER PageWidthMm
        Custom page width in millimetres (1..5080), used together with
        -PageHeightMm instead of -PageSize. For a landscape page make the width
        the larger value.
    .PARAMETER PageHeightMm
        Custom page height in millimetres (1..5080); see -PageWidthMm.
    .PARAMETER PageSize
        The paper size for every page in the document. Accepts standard ISO and
        US names (A0-A6, Ledger, Legal, Letter). Defaults to A4.
    .PARAMETER DefaultFont
        The base-14 font name stored as the document-wide default. Content
        cmdlets that receive no explicit -Font fill the gap from this value
        rather than from the library-global Helvetica. Defaults to Helvetica.
    .PARAMETER DefaultFontSize
        The font size in points stored as the document-wide default. Content
        cmdlets that receive no explicit -FontSize fill the gap from this value.
        Must be between 1 and 1000. Defaults to 11.
    .PARAMETER Tagged
        When specified, marks the document as a tagged PDF (sets Document.Tagged
        to $true). Tagged PDFs are required for full PDF/A accessibility
        conformance and enable assistive-technology support.
    .PARAMETER Language
        A BCP 47 language tag written as the PDF /Lang entry (e.g. 'en-US').
        Relevant for tagged PDF and PDF/A accessibility. Requires VellumPdf 1.1+.
    .PARAMETER Margin
        Uniform page margin in points applied to all four sides. When any
        per-side parameter (-MarginTop, -MarginRight, -MarginBottom, -MarginLeft)
        is also supplied, this value becomes the baseline for the unspecified
        sides rather than overriding them.
    .PARAMETER MarginTop
        Top page margin in points. When supplied, overrides the -Margin baseline
        (or the library default) for the top side only.
    .PARAMETER MarginRight
        Right page margin in points. When supplied, overrides the -Margin
        baseline (or the library default) for the right side only.
    .PARAMETER MarginBottom
        Bottom page margin in points. When supplied, overrides the -Margin
        baseline (or the library default) for the bottom side only.
    .PARAMETER MarginLeft
        Left page margin in points. When supplied, overrides the -Margin
        baseline (or the library default) for the left side only.
    .PARAMETER Culture
        The culture used to turn non-string values into text: table cells, list items and pie-chart
        percentage labels (dates, numbers, and numbers read from strings). A culture name ('de-DE') or a
        [cultureinfo] (-Culture (Get-Culture) matches the console); an unknown name is an error. Default:
        the invariant culture, so the output is the same on every machine. Each of Add-VellumPdfTable,
        Add-VellumPdfList, Add-VellumPdfPieChart (and the page-document counterparts) has its own -Culture
        that overrides this default for one call. It is deliberately not derived from -Language: a language
        tag says nothing about how dates and numbers look.
    .PARAMETER InputCulture
        A culture name or [cultureinfo] used to READ numbers that are given as strings in table cells and
        list items (the document default; the table and list cmdlets have a per-call -InputCulture). With it,
        a string that consists only of a number is parsed strictly with that culture's decimal and grouping
        separators ('de-DE': '1.234,5' is 1234.5, '1.5' is not a number). Without it (the default) the
        separators are detected from the text. See Add-VellumPdfTable for the detection rules.
    .PARAMETER UseObjectStreams
        When specified, enables PDF cross-reference object streams in the output
        file. Object streams reduce file size for documents with many objects by
        compressing the cross-reference table.
    .EXAMPLE
        New-VellumPdfDocument -Conformance PdfA2b |
            Add-VellumPdfHeading -Text 'Report' |
            Add-VellumPdfParagraph -Text 'Body text.' |
            Save-VellumPdfDocument -Path ./report.pdf
    .EXAMPLE
        New-VellumPdfDocument -Margin 30
    .EXAMPLE
        New-VellumPdfDocument -Margin 30 -MarginLeft 50
    .OUTPUTS
        VellumPdf.Layout.Document
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Returns a new in-memory document object; performs no external/system state change.')]
    [CmdletBinding(DefaultParameterSetName = 'NamedPage')]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [ValidateSet('None', 'PdfA2b', 'PdfA2u', 'PdfA2a', 'PdfUA1')]
        [string]$Conformance = 'None',

        [Parameter(ParameterSetName = 'NamedPage')]
        [ValidateSet('A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'Ledger', 'Legal', 'Letter')]
        [string]$PageSize = 'A4',

        # Custom page size in millimetres (max 5080 mm = 14400 pt, the PDF default
        # user-space limit). Use instead of -PageSize; swap the two for landscape.
        [Parameter(Mandatory, ParameterSetName = 'CustomPage')]
        [ValidateRange(1.0, 5080.0)]
        [double]$PageWidthMm,

        [Parameter(Mandatory, ParameterSetName = 'CustomPage')]
        [ValidateRange(1.0, 5080.0)]
        [double]$PageHeightMm,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$DefaultFont = 'Helvetica',

        [ValidateRange(1.0, 1000.0)]
        [double]$DefaultFontSize = 11,

        [switch]$Tagged,

        # BCP 47 language tag written as the PDF /Lang entry (e.g. 'en-US').
        # Relevant for tagged PDF and PDF/A accessibility. Requires VellumPdf 1.1+.
        [string]$Language,

        [ValidateRange(0.0, 10000.0)]
        [double]$Margin,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginTop,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginRight,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginBottom,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginLeft,

        [switch]$UseObjectStreams,

        # Culture for turning values into text (tables, lists, pie labels); a name or a [cultureinfo]. Default: invariant.
        [object]$Culture,

        # Culture used to read numbers given as strings. Default: detect the separators from the text.
        [object]$InputCulture
    )

    try {
        # Resolved first: an unknown culture name must fail before a document exists.
        $documentCulture = if ($PSBoundParameters.ContainsKey('Culture')) { ConvertTo-VellumPdfCulture -Value $Culture -CommandName 'New-VellumPdfDocument' } else { [cultureinfo]::InvariantCulture }
        $documentInputCulture = if ($PSBoundParameters.ContainsKey('InputCulture') -and $null -ne $InputCulture) { ConvertTo-VellumPdfCulture -Value $InputCulture -CommandName 'New-VellumPdfDocument' -ParameterName 'InputCulture' }
        $doc = [VellumPdf.Layout.Document]::new()
        $doc.Conformance = [VellumPdf.Document.PdfConformance]::$Conformance
        $doc.PageSize = if ($PSCmdlet.ParameterSetName -eq 'CustomPage') {
            [VellumPdf.Document.PageSize]::Mm($PageWidthMm, $PageHeightMm)
        } else {
            [VellumPdf.Document.PageSize]::$PageSize
        }
        if ($Tagged) { $doc.Tagged = $true }
        Assert-VellumPdfLanguageTag -Value $Language -CommandName 'New-VellumPdfDocument'
            if ($Language) { $doc.Language = $Language }
        if ($UseObjectStreams) { $doc.UseObjectStreams = $true }

        $style = New-VellumTextStyle -Font $DefaultFont -FontSize $DefaultFontSize -Document $doc -CommandName 'New-VellumPdfDocument'
        [void]$doc.SetDefaultFont($style)

        # VellumPdf has no getter for the default style, and a TextStyle without a
        # font falls back to the library-global Helvetica rather than this default.
        # Stash what we applied so other cmdlets can fill style gaps correctly
        # (read back via Resolve-VellumPdfDefault).
        $doc.PSObject.Properties.Add([psnoteproperty]::new(
            'PSVellumDefault', @{ Font = $DefaultFont; FontSize = $DefaultFontSize }))

        $doc.PSObject.Properties.Add([psnoteproperty]::new('PSVellumCulture', $documentCulture))
        $doc.PSObject.Properties.Add([psnoteproperty]::new('PSVellumInputCulture', $documentInputCulture))

        $hasUniform = $PSBoundParameters.ContainsKey('Margin')
        $hasPerSide = $PSBoundParameters.ContainsKey('MarginTop') -or
                      $PSBoundParameters.ContainsKey('MarginRight') -or
                      $PSBoundParameters.ContainsKey('MarginBottom') -or
                      $PSBoundParameters.ContainsKey('MarginLeft')

        if ($hasPerSide) {
            # Start from -Margin uniform value if given, else from current document margins.
            $baseTop    = if ($hasUniform) { $Margin } else { $doc.Margins.Top }
            $baseRight  = if ($hasUniform) { $Margin } else { $doc.Margins.Right }
            $baseBottom = if ($hasUniform) { $Margin } else { $doc.Margins.Bottom }
            $baseLeft   = if ($hasUniform) { $Margin } else { $doc.Margins.Left }

            $top    = if ($PSBoundParameters.ContainsKey('MarginTop'))    { $MarginTop }    else { $baseTop }
            $right  = if ($PSBoundParameters.ContainsKey('MarginRight'))  { $MarginRight }  else { $baseRight }
            $bottom = if ($PSBoundParameters.ContainsKey('MarginBottom')) { $MarginBottom } else { $baseBottom }
            $left   = if ($PSBoundParameters.ContainsKey('MarginLeft'))   { $MarginLeft }   else { $baseLeft }

            $doc.Margins = [VellumPdf.Layout.Core.EdgeInsets]::new($top, $right, $bottom, $left)
        } elseif ($hasUniform) {
            $doc.Margins = [VellumPdf.Layout.Core.EdgeInsets]::new($Margin)
        }

        return $doc
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'New-VellumPdfDocument'))
    }
}
