function Add-VellumPdfPageBarcode {
    <#
    .SYNOPSIS
        Draws a barcode or 2-D symbol at x/y on a page of a page-based document.
    .DESCRIPTION
        The page-document counterpart of Add-VellumPdfBarcode, with the same
        symbologies and options (QrCode, MicroQrCode, DataMatrix, Aztec, Pdf417,
        Code128, Code39, Ean13, Ean8, UpcA, UpcE, Itf14) and the same validation:
        content that cannot be encoded fails here. The symbol's lower-left corner,
        including its quiet zone, is placed at (-X, -Y). Size it with -ModuleSize or
        -TargetWidth. The symbol carries no alternate text (untagged page content).

        In a PDF/A page document the human-readable line of a 1-D barcode is off by
        default and -ShowText is refused, because it would need a non-embedded font.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Type
        The symbology.
    .PARAMETER Content
        The text to encode.
    .PARAMETER Bytes
        Binary content (QrCode only).
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER X
        Lower-left x in points.
    .PARAMETER Y
        Lower-left y in points.
    .PARAMETER ModuleSize
        Width of one module in points. Exclusive with -TargetWidth.
    .PARAMETER TargetWidth
        Total symbol width in points. Exclusive with -ModuleSize.
    .PARAMETER Foreground
        Colour of dark modules/bars (default black).
    .PARAMETER Background
        Fill colour behind the symbol (default none).
    .PARAMETER NoQuietZone
        Omit the quiet zone.
    .PARAMETER BarHeight
        1-D symbols: bar height in points (default 40).
    .PARAMETER ShowText
        1-D symbols: print the human-readable text (default on; off in PDF/A).
    .PARAMETER TextSize
        1-D symbols: size of the human-readable text.
    .PARAMETER TextFont
        1-D symbols: base-14 font of the human-readable text.
    .PARAMETER ErrorCorrection
        QrCode (L, M, Q, H) and MicroQrCode (L, M, Q).
    .PARAMETER QrVersion
        QrCode (1..40) / MicroQrCode (1..4) version.
    .PARAMETER QrMask
        QrCode mask pattern 0..7.
    .PARAMETER TextEncoding
        QrCode: Auto, Latin1, Utf8 or Utf8Eci.
    .PARAMETER QrGs1
        QrCode: None, ElementString or DigitalLink.
    .PARAMETER Gs1
        Code128 / DataMatrix: GS1 element strings.
    .PARAMETER Shape
        DataMatrix: Automatic, Square or Rectangular.
    .PARAMETER AztecFormat
        Aztec: Automatic, Compact or FullRange.
    .PARAMETER AztecErrorCorrectionPercent
        Aztec: minimum error-correction percentage.
    .PARAMETER Columns
        Pdf417 data columns.
    .PARAMETER Rows
        Pdf417 rows.
    .PARAMETER Compact
        Pdf417 compact variant.
    .PARAMETER ErrorCorrectionLevel
        Pdf417 security level 0..8.
    .PARAMETER CheckDigit
        Code39 check character.
    .PARAMETER FullAscii
        Code39 full-ASCII mode.
    .PARAMETER WideNarrowRatio
        Code39/Itf14 wide:narrow ratio.
    .PARAMETER AddOn
        EAN/UPC add-on digits.
    .PARAMETER BearerBars
        Itf14: Frame, Horizontal or None.
    .EXAMPLE
        $doc | Add-VellumPdfPageBarcode QrCode 'https://example.com' -X 72 -Y 600 -TargetWidth 90
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('QrCode', 'MicroQrCode', 'DataMatrix', 'Aztec', 'Pdf417', 'Code128', 'Code39',
            'Ean13', 'Ean8', 'UpcA', 'UpcE', 'Itf14')]
        [string]$Type,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Text')]
        [string]$Content,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$Bytes,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,

        [ValidateRange(0.01, 1000)] [double]$ModuleSize,
        [ValidateRange(1, 100000)] [double]$TargetWidth,
        [object]$Foreground,
        [object]$Background,
        [switch]$NoQuietZone,
        [ValidateRange(1, 10000)] [double]$BarHeight,
        [bool]$ShowText,
        [ValidateRange(0, 1000)] [double]$TextSize,
        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$TextFont,
        [ValidateSet('L', 'M', 'Q', 'H')] [string]$ErrorCorrection,
        [ValidateRange(1, 40)] [int]$QrVersion,
        [ValidateRange(0, 7)] [int]$QrMask,
        [ValidateSet('Auto', 'Latin1', 'Utf8', 'Utf8Eci')] [string]$TextEncoding,
        [ValidateSet('None', 'ElementString', 'DigitalLink')] [string]$QrGs1,
        [switch]$Gs1,
        [ValidateSet('Automatic', 'Square', 'Rectangular')] [string]$Shape,
        [ValidateSet('Automatic', 'Compact', 'FullRange')] [string]$AztecFormat,
        [ValidateRange(0, 100)] [int]$AztecErrorCorrectionPercent,
        [ValidateRange(1, 30)] [int]$Columns,
        [ValidateRange(3, 90)] [int]$Rows,
        [switch]$Compact,
        [ValidateRange(0, 8)] [int]$ErrorCorrectionLevel,
        [switch]$CheckDigit,
        [switch]$FullAscii,
        [ValidateRange(2, 3)] [double]$WideNarrowRatio,
        [string]$AddOn,
        [ValidateSet('Frame', 'Horizontal', 'None')] [string]$BearerBars
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPageBarcode'
        if (-not [double]::IsFinite($X) -or -not [double]::IsFinite($Y)) { throw 'Add-VellumPdfPageBarcode: -X and -Y must be finite.' }
        $pdfPage = Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageBarcode'
        $isPdfA = $Document.Conformance -in @([VellumPdf.Document.PdfConformance]::PdfA2b, [VellumPdf.Document.PdfConformance]::PdfA2u,
            [VellumPdf.Document.PdfConformance]::PdfA2a)

        try {
            $barcode = New-VellumPdfBarcodeSet -Parameters $PSBoundParameters -IsPdfA $isPdfA -ParameterSetName $PSCmdlet.ParameterSetName |
                Select-Object -First 1
        }
        catch {
            throw ($_.Exception.Message -replace '^Add-VellumPdfBarcode:', 'Add-VellumPdfPageBarcode:')
        }

        $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageBarcode'
        $fontResource = if ($barcode -is [VellumPdf.Barcodes.Barcode1D] -and $barcode.ShowText) { $Document.UseFont($barcode.TextFont) }
        [void]$canvas.SaveState()
        try { [void][VellumPdf.Barcodes.BarcodeCanvasExtensions]::DrawBarcode($canvas, $barcode, $X, $Y, $fontResource) }
        finally { [void]$canvas.RestoreState() }
        $Document
    }
}
