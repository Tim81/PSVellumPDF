function Add-VellumPdfLineSeparator {
    <#
    .SYNOPSIS
        Adds a horizontal line separator to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(LineSeparator). Constructs a LineSeparator element with
        an optional line width, RGB colour, and top/bottom margins, then adds it to
        the document.

        -Color accepts a three-element array of [double] values in the 0.0..1.0
        range (R, G, B).

        -MarginTop and -MarginBottom apply spacing above and below the separator
        without affecting the left/right margins already set on the element.

        The document flows through the pipeline for chaining with other
        Add-VellumPdf* functions.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the separator is added, enabling chaining.
    .PARAMETER LineWidth
        Thickness of the horizontal rule in points, between 0.1 and 50. When
        omitted the VellumPdf library default line width is used.
    .PARAMETER Color
        Line colour, given as an R,G,B triple in 0..1 (e.g. 0,0,0 for black), a
        hex string ('#3366cc' or '#36c'), or a colour name. When omitted the
        library default colour is used.
    .PARAMETER MarginTop
        Extra spacing in points above the separator element. Does not affect
        the left/right page margins.
    .PARAMETER MarginBottom
        Extra spacing in points below the separator element. Does not affect
        the left/right page margins.
    .EXAMPLE
        New-VellumPdfDocument |
            Add-VellumPdfParagraph -Text 'Above the line.' |
            Add-VellumPdfLineSeparator |
            Add-VellumPdfParagraph -Text 'Below the line.' |
            Save-VellumPdfDocument -Path ./report.pdf
    .EXAMPLE
        $doc | Add-VellumPdfLineSeparator -LineWidth 2.0 -Color 0.2,0.4,0.8 `
               -MarginTop 10 -MarginBottom 10
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [ValidateRange(0.1, 50)]
        [double]$LineWidth,

        # RGB triple (0..1), a hex string ('#3366cc'/'#36c'), or a colour name.
        [object]$Color,

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfLineSeparator'

        $sep = [VellumPdf.Layout.Elements.LineSeparator]::new()

        if ($PSBoundParameters.ContainsKey('LineWidth')) {
            $sep.LineWidth = $LineWidth
        }

        if ($PSBoundParameters.ContainsKey('Color')) {
            $rgb = ConvertTo-VellumColor $Color
            $sep.Color = [VellumPdf.Layout.Core.ColorRgb]::new($rgb[0], $rgb[1], $rgb[2])
        }

        Set-VellumPdfElementMargin -Element $sep -Top $MarginTop -Bottom $MarginBottom `
            -BoundParameters $PSBoundParameters

        [void]$Document.Add($sep)
        $Document
    }
}
