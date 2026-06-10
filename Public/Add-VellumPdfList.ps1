function Add-VellumPdfList {
    <#
    .SYNOPSIS
        Adds an ordered or unordered list to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(ListElement). Builds a ListElement from an array of
        string items and an optional list style (Unordered, OrderedDecimal,
        OrderedAlpha, OrderedRoman). An optional -Indent adjusts the left indent
        for the list. An optional -Font/-FontSize override applies a TextStyle to
        every item; when omitted the document default font is used.

        -MarginTop and -MarginBottom apply spacing above and below the list
        without affecting the left/right margins already set on the element.

        The document flows through the pipeline for chaining with other
        Add-VellumPdf* functions.
    .EXAMPLE
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Apples','Bananas','Cherries' |
            Save-VellumPdfDocument -Path ./fruit.pdf
    .EXAMPLE
        $doc | Add-VellumPdfList -Item 'First','Second','Third' `
               -Style OrderedDecimal -Indent 20 -Font Helvetica -FontSize 11
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory)]
        [string[]]$Item,

        [ValidateSet('Unordered', 'OrderedDecimal', 'OrderedAlpha', 'OrderedRoman')]
        [string]$Style = 'Unordered',

        [ValidateRange(0, 1000)]
        [double]$Indent,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font,

        [ValidateRange(1, 1000)]
        [double]$FontSize,

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom
    )

    process {
        $listStyle = [VellumPdf.Layout.Elements.ListStyle]::$Style

        # Build an empty typed list to satisfy the IEnumerable<ListItem> ctor param.
        $emptyItems = [System.Collections.Generic.List[VellumPdf.Layout.Elements.ListItem]]::new()
        $list = [VellumPdf.Layout.Elements.ListElement]::new($listStyle, $emptyItems)

        # Apply indent when supplied.
        if ($PSBoundParameters.ContainsKey('Indent')) {
            $list.Indent = $Indent
        }

        # Build a TextStyle only when font or size overrides were requested.
        # Gaps are filled from the document defaults: a style without a font
        # renders in the library-global Helvetica, not the document default.
        $wantsStyle = [bool]$Font -or $PSBoundParameters.ContainsKey('FontSize')
        $textStyle = $null
        if ($wantsStyle) {
            $default = Resolve-VellumPdfDefault -Document $Document
            $effFont = if ($Font) { $Font } else { $default.Font }
            $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { $default.FontSize }
            $textStyle = New-VellumTextStyle -Font $effFont -FontSize $effSize
        }

        # Add each item; pass $null style to let each item use DefaultStyle.
        foreach ($text in $Item) {
            [void]$list.Add($text, $textStyle)
        }

        Set-VellumPdfElementMargin -Element $list -Top $MarginTop -Bottom $MarginBottom `
            -BoundParameters $PSBoundParameters

        [void]$Document.Add($list)
        $Document
    }
}
