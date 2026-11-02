function Add-VellumPdfText {
    <#
    .SYNOPSIS
        Places a line of text at x/y on a page of a page-based document.
    .DESCRIPTION
        Draws one line (no wrapping) with its baseline starting at (-X, -Y), in
        points from the page's bottom-left. -Align Center/Right positions the text
        about x instead. Use a base-14 font by name (-Font), or an embedded
        TrueType font (-FontHandle from Register-VellumPdfFont) for Unicode text.

        In a PDF/A document base-14 text is embedded automatically with a
        metric-compatible Liberation font (VellumPdf.Fonts.Standard14), as PDF/A
        forbids non-embedded fonts. For several lines of wrapped text use the
        flow-layout document (New-VellumPdfDocument).
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Text
        The text. A single line; line breaks are not supported.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER X
        Left edge (or centre/right edge with -Align) in points.
    .PARAMETER Y
        Baseline in points from the bottom of the page.
    .PARAMETER FontSize
        Size in points (default 12).
    .PARAMETER Font
        A base-14 font name (default Helvetica).
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont. Overrides -Font.
    .PARAMETER Color
        Text colour: RGB triple in 0..1, hex or name. Default black.
    .PARAMETER Align
        Left (default), Center or Right, about -X.
    .EXAMPLE
        $doc | Add-VellumPdfText 'Invoice 2026-001' -X 72 -Y 760 -FontSize 18 -Font HelveticaBold
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [string]$Text,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,

        [ValidateRange(1, 1000)]
        [double]$FontSize = 12,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font = 'Helvetica',

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [object]$Color,

        [ValidateSet('Left', 'Center', 'Right')]
        [string]$Align = 'Left'
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfText'
        if (-not [double]::IsFinite($X) -or -not [double]::IsFinite($Y)) { throw 'Add-VellumPdfText: -X and -Y must be finite.' }
        if ($Text -match '[\r\n]') { throw 'Add-VellumPdfText: -Text must be a single line; use New-VellumPdfDocument for wrapped text.' }

        $resolved = Get-VellumPdfPageFont -Document $Document -FontHandle $FontHandle -Font $Font -CommandName 'Add-VellumPdfText'
        if (-not $resolved.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None) {
            Write-VellumPdfEncodingWarning -Text $Text -CommandName 'Add-VellumPdfText'
        }
        $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfText'
        $alignment = [VellumPdf.Canvas.TextAlignment]::$Align

        [void]$canvas.SaveState()
        try {
            if ($PSBoundParameters.ContainsKey('Color')) {
                $c = ConvertTo-VellumColor $Color
                [void]$canvas.SetFillColorRgb($c[0], $c[1], $c[2])
            }
            [void]$canvas.BeginText()
            if ($resolved.Handle) {
                $Document.RegisterEmbeddedFontUsage($Document.Pages[$Page - 1], $resolved.Handle)
                [void]$canvas.SetFontByName($resolved.Handle.ResourceName, $FontSize)
                [void][PSVellumPDF.Interop.CanvasHelpers]::ShowEmbeddedText($canvas, $resolved.Handle, $Text, $FontSize, $X, $Y, $alignment)
            }
            else {
                [void]$canvas.SetFont($resolved.Resource, $FontSize)
                [void]$canvas.ShowTextAligned($Text, $X, $Y, $alignment)
            }
            [void]$canvas.EndText()
        }
        finally { [void]$canvas.RestoreState() }
        $Document
    }
}
