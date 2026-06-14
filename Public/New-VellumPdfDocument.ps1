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
        The PDF conformance level for the document. Use PdfA2b, PdfA2u, or
        PdfA2a to produce an ISO 19005-2 compliant archive file; use PdfUA1 to
        produce an ISO 14289-1 (PDF/UA) accessibility-conformant document; None
        (default) produces a standard PDF without conformance requirements. Note
        that PDF/A and PDF/UA both forbid encryption, so these conformance levels
        are incompatible with Protect-VellumPdfDocument. Like PDF/A, PDF/UA
        requires embedded fonts (Register-VellumPdfFont / -FontHandle) and a
        tagged document (-Tagged) to fully validate.
    .PARAMETER PageSize
        The paper size for every page in the document. Accepts standard ISO and
        US names (A0-A6, Ledger, Legal, Letter). Defaults to A4. Mutually
        exclusive with -PageWidthMm / -PageHeightMm.
    .PARAMETER PageWidthMm
        Custom page width in millimetres. Must be supplied together with
        -PageHeightMm. Mutually exclusive with -PageSize. Valid range: 1 to
        5080 mm. The 5080 mm ceiling is 14400 points (200 inches), the maximum
        page dimension in PDF default user space (ISO 32000-1 Annex C); larger
        pages would need a UserUnit scale that this engine does not emit, and
        would not render in many viewers.
    .PARAMETER PageHeightMm
        Custom page height in millimetres. Must be supplied together with
        -PageWidthMm. Mutually exclusive with -PageSize. Valid range: 1 to
        5080 mm (see -PageWidthMm for the rationale).
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
        # PDF/UA accessibility document (requires embedded font and -Tagged).
        $fh = New-VellumPdfDocument -Conformance PdfUA1 -Tagged -Language 'en-US' |
            Register-VellumPdfFont -Path ./fonts/DejaVuSans.ttf
        $fh.Document |
            Add-VellumPdfHeading -Text 'Accessible Report' -FontHandle $fh -Level 1 |
            Save-VellumPdfDocument -Path ./accessible.pdf
    .EXAMPLE
        # Custom page size 148 x 210 mm (A5 portrait).
        New-VellumPdfDocument -PageWidthMm 148 -PageHeightMm 210 |
            Add-VellumPdfParagraph -Text 'A5 custom size.' |
            Save-VellumPdfDocument -Path ./a5-custom.pdf
    .EXAMPLE
        New-VellumPdfDocument -Margin 30
    .EXAMPLE
        New-VellumPdfDocument -Margin 30 -MarginLeft 50
    .OUTPUTS
        VellumPdf.Layout.Document
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Returns a new in-memory document object; performs no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [ValidateSet('None', 'PdfA2b', 'PdfA2u', 'PdfA2a', 'PdfUA1')]
        [string]$Conformance = 'None',

        [ValidateSet('A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'Ledger', 'Legal', 'Letter')]
        [string]$PageSize = 'A4',

        [ValidateRange(1, 5080)]
        [double]$PageWidthMm,

        [ValidateRange(1, 5080)]
        [double]$PageHeightMm,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$DefaultFont = 'Helvetica',

        [ValidateRange(1, 1000)]
        [double]$DefaultFontSize = 11,

        [switch]$Tagged,

        # BCP 47 language tag written as the PDF /Lang entry (e.g. 'en-US').
        # Relevant for tagged PDF and PDF/A accessibility. Requires VellumPdf 1.1+.
        [string]$Language,

        [ValidateRange(0, 10000)]
        [double]$Margin,

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginRight,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom,

        [ValidateRange(0, 10000)]
        [double]$MarginLeft,

        [switch]$UseObjectStreams
    )

    $hasWidthMm  = $PSBoundParameters.ContainsKey('PageWidthMm')
    $hasHeightMm = $PSBoundParameters.ContainsKey('PageHeightMm')
    $hasPageSize = $PSBoundParameters.ContainsKey('PageSize')

    if ($hasWidthMm -ne $hasHeightMm) {
        throw 'New-VellumPdfDocument: -PageWidthMm and -PageHeightMm must be supplied together.'
    }
    if (($hasWidthMm -or $hasHeightMm) -and $hasPageSize) {
        throw 'New-VellumPdfDocument: -PageWidthMm/-PageHeightMm and -PageSize are mutually exclusive.'
    }

    $doc = [VellumPdf.Layout.Document]::new()
    $doc.Conformance = [VellumPdf.Document.PdfConformance]::$Conformance
    if ($hasWidthMm) {
        $doc.PageSize = [VellumPdf.Document.PageSize]::Mm($PageWidthMm, $PageHeightMm)
    } else {
        $doc.PageSize = [VellumPdf.Document.PageSize]::$PageSize
    }
    if ($Tagged) { $doc.Tagged = $true }
    if ($Language) { $doc.Language = $Language }
    if ($UseObjectStreams) { $doc.UseObjectStreams = $true }

    $style = New-VellumTextStyle -Font $DefaultFont -FontSize $DefaultFontSize
    [void]$doc.SetDefaultFont($style)

    # VellumPdf has no getter for the default style, and a TextStyle without a
    # font falls back to the library-global Helvetica rather than this default.
    # Stash what we applied so other cmdlets can fill style gaps correctly
    # (read back via Resolve-VellumPdfDefault).
    $doc.PSObject.Properties.Add([psnoteproperty]::new(
        'PSVellumDefault', @{ Font = $DefaultFont; FontSize = $DefaultFontSize }))

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
