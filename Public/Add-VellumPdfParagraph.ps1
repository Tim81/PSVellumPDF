function Add-VellumPdfParagraph {
    <#
    .SYNOPSIS
        Adds a paragraph of text to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(Paragraph). When no -Font/-FontSize/-Alignment override
        is supplied the document's default font (set by New-VellumPdfDocument) is
        used. The document flows through the pipeline for chaining.
    .EXAMPLE
        $doc | Add-VellumPdfParagraph -Text 'The quick brown fox.' -Alignment Justify
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0)]
        [string]$Text,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font,

        [ValidateRange(1, 1000)]
        [double]$FontSize,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Left',

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle
    )

    process {
        $wantsStyle = [bool]$Font -or $PSBoundParameters.ContainsKey('FontSize') -or $Alignment -ne 'Left' -or $FontHandle
        if (-not $wantsStyle) {
            # No overrides: use the document's default font.
            [void]$Document.Add($Text, $null)
            return $Document
        }

        # Building an explicit Paragraph requires a concrete style; fill any gaps
        # with the base-14 default so text always has a usable font and size.
        $style = if ($FontHandle) {
            $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { 11 }
            New-VellumTextStyle -FontHandle $FontHandle -FontSize $effSize
        } else {
            $effFont = if ($Font) { $Font } else { 'Helvetica' }
            $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { 11 }
            New-VellumTextStyle -Font $effFont -FontSize $effSize
        }

        $paragraph = [VellumPdf.Layout.Elements.Paragraph]::new($Text, $style)
        $paragraph.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
        [void]$Document.Add($paragraph)
        $Document
    }
}
