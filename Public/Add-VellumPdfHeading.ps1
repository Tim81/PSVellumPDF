function Add-VellumPdfHeading {
    <#
    .SYNOPSIS
        Adds a heading to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(Heading). The document flows through the pipeline so
        Add-VellumPdf* calls can be chained. Headings with a BookmarkTitle (or any
        heading in a tagged document) become PDF outline/bookmark entries.
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

        [string]$BookmarkTitle
    )

    process {
        $style = New-VellumTextStyle -Font $Font -FontSize $FontSize
        $heading = [VellumPdf.Layout.Elements.Heading]::new($Text, $style)
        $heading.Level = $Level
        $heading.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
        if ($BookmarkTitle) { $heading.BookmarkTitle = $BookmarkTitle }

        [void]$Document.Add($heading)
        $Document
    }
}
