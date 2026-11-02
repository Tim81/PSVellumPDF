function Set-VellumPdfHeader {
    <#
    .SYNOPSIS
        Sets a running header band on a VellumPdf document.
    .DESCRIPTION
        Wraps Document.SetHeader(template, style, alignment). The header band
        appears at the top of every page. The document flows through the pipeline
        for chaining.

        Template tokens:
          {page}  - replaced with the current page number (e.g. 2)
          {pages} - replaced with the total page count   (e.g. 9)

        Example template: 'Page {page} of {pages}'
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the header is configured, enabling chaining.
    .PARAMETER Template
        The header text template. Use {page} for the current page number and
        {pages} for the total page count (e.g. 'Page {page} of {pages}').
        Mandatory.
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont, used for the header
        text (takes precedence over -Font). Needed for text outside Windows-1252 and
        for PDF/A documents.
    .PARAMETER Color
        Text colour: an R,G,B triple in 0..1, a hex string ('#3366cc'), or a colour
        name. Honoured by VellumPdf 2.x.
    .PARAMETER Height
        The header band height in points. Defaults to the line height plus 4. A
        header wider than the page is truncated at a word boundary; Save-VellumPdfDocument
        warns when that happens. A link style is ignored in bands.
    .PARAMETER Font
        A base-14 font name for the header text. When omitted the document
        default font is used.
    .PARAMETER FontSize
        Font size in points for the header text, between 1 and 1000. When
        omitted the document default size is used.
    .PARAMETER Alignment
        Horizontal alignment of the header text. Accepts Left, Center, Right,
        or Justify. Defaults to Center.
    .EXAMPLE
        $doc | Set-VellumPdfHeader -Template 'Page {page} of {pages}'
    .EXAMPLE
        $doc | Set-VellumPdfHeader -Template 'Confidential - Page {page} of {pages}' `
               -Font Helvetica -FontSize 9 -Alignment Right
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Mutates an in-memory document object only; no external/system state change.')]
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory)]
        [string]$Template,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font,

        [ValidateRange(1, 1000)]
        [double]$FontSize,

        # An embedded TrueType font from Register-VellumPdfFont (takes precedence
        # over -Font); needed for Unicode text and PDF/A documents.
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        # Text colour: R,G,B in 0..1, '#rrggbb', or a colour name.
        [object]$Color,

        # Band height in points (default: line height + 4). Text wider than the
        # page is truncated at a word boundary and reported when saving.
        [ValidateRange(0.1, 10000)]
        [double]$Height,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Center'
    )

    process {
        try {
            Set-VellumPdfBand -Document $Document -Kind Header -Template $Template -Font $Font -FontSize $FontSize `
                -FontHandle $FontHandle -Color $Color -Height $Height -Alignment $Alignment `
                -BoundParameters $PSBoundParameters
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
