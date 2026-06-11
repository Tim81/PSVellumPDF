function Add-VellumPdfHeading {
    <#
    .SYNOPSIS
        Adds a heading to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(Heading). The document flows through the pipeline so
        Add-VellumPdf* calls can be chained. Headings with a BookmarkTitle (or any
        heading in a tagged document) become PDF outline/bookmark entries.

        -MarginTop and -MarginBottom apply spacing above and below the heading
        without affecting the left/right margins already set on the element.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the heading is added, enabling chaining.
    .PARAMETER Text
        The string content of the heading. Mandatory and positional (position 0).
    .PARAMETER Level
        The heading level from 1 (top-level) to 6 (lowest). Controls the PDF
        outline depth and the H1-H6 structure tag in tagged documents. Defaults
        to 1.
    .PARAMETER Font
        A base-14 font name for the heading. Defaults to HelveticaBold. Ignored
        when -FontHandle is supplied.
    .PARAMETER FontSize
        Font size in points for the heading, between 1 and 1000. Defaults to 16.
    .PARAMETER Alignment
        Horizontal alignment of the heading text. Accepts Left, Center, Right,
        or Justify. Defaults to Left.
    .PARAMETER BookmarkTitle
        When supplied, adds a named PDF outline (bookmark) entry for this
        heading. In tagged documents all headings automatically produce outline
        entries; this parameter overrides the bookmark label for non-tagged docs.
    .PARAMETER FontHandle
        An EmbeddedFontHandle returned by Register-VellumPdfFont for this
        document. When supplied the heading uses the embedded TrueType font and
        the base-14 encoding warning is suppressed. Handles from a different
        document are rejected.
    .PARAMETER MarginTop
        Extra spacing in points above the heading element. Does not affect the
        left/right page margins.
    .PARAMETER MarginBottom
        Extra spacing in points below the heading element. Does not affect the
        left/right page margins.
    .EXAMPLE
        $doc | Add-VellumPdfHeading -Text 'Chapter 1' -Level 1 -FontSize 18
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

        [ValidateRange(1, 6)]
        [int]$Level = 1,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font = 'HelveticaBold',

        [ValidateRange(1, 1000)]
        [double]$FontSize = 16,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Left',

        [string]$BookmarkTitle,

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfHeading'
        if ($FontHandle) {
            Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfHeading'
        }
        if (-not $FontHandle) {
            Write-VellumPdfEncodingWarning -Text $Text -CommandName 'Add-VellumPdfHeading'
        }
        $styleParams = if ($FontHandle) {
            @{ FontHandle = $FontHandle; FontSize = $FontSize }
        } else {
            @{ Font = $Font; FontSize = $FontSize }
        }
        $style = New-VellumTextStyle @styleParams
        $heading = [VellumPdf.Layout.Elements.Heading]::new($Text, $style)
        $heading.Level = $Level
        $heading.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
        if ($BookmarkTitle) { $heading.BookmarkTitle = $BookmarkTitle }

        Set-VellumPdfElementMargin -Element $heading -Top $MarginTop -Bottom $MarginBottom `
            -BoundParameters $PSBoundParameters

        [void]$Document.Add($heading)
        $Document
    }
}
