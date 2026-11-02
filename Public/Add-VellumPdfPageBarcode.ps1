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
        -TargetWidth. In a tagged page document the symbol is a Figure with -AltText
        (default: the symbology and content), or an artifact with -Decorative.

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
    .PARAMETER PreferredAspectRatio
        Pdf417: target width-to-height ratio used to choose the number of columns (default 3).
    .PARAMETER RowHeight
        Pdf417: height of one row in modules (default 3).
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
    .PARAMETER AltText
        Alternate text in a tagged document. Default: the symbology and its content.
    .PARAMETER Decorative
        Mark the symbol as an artifact in a tagged document.
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
        [ValidateRange(0.5, 20)] [double]$PreferredAspectRatio,
        [ValidateRange(1, 20)] [double]$RowHeight,
        [switch]$CheckDigit,
        [switch]$FullAscii,
        [ValidateRange(2, 3)] [double]$WideNarrowRatio,
        [string]$AddOn,
        [ValidateSet('Frame', 'Horizontal', 'None')] [string]$BearerBars,
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) }, ErrorMessage = '-AltText must not be empty or whitespace.')] [string]$AltText,
        [switch]$Decorative
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPageBarcode'
            Assert-VellumPdfCoordinate $X 'X' 'Add-VellumPdfPageBarcode'; Assert-VellumPdfCoordinate $Y 'Y' 'Add-VellumPdfPageBarcode'
            # Validates -Page up front (the canvas lookup below would do so too, but after building the symbol).
            [void](Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageBarcode')
            $isPdfA = (Get-VellumPdfConformanceNeeds -Document $Document).NeedsEmbeddedFonts

            try {
                $barcode = New-VellumPdfBarcodeSet -Parameters $PSBoundParameters -IsPdfA $isPdfA -ParameterSetName $PSCmdlet.ParameterSetName |
                    Select-Object -First 1
            }
            catch {
                throw ($_.Exception.Message -replace '^Add-VellumPdfBarcode:', 'Add-VellumPdfPageBarcode:')
            }

            $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageBarcode'
            $fontResource = if ($barcode -is [VellumPdf.Barcodes.Barcode1D] -and $barcode.ShowText) { $Document.UseFont($barcode.TextFont) }
            if ($Decorative -and $AltText) { throw 'Add-VellumPdfPageBarcode: -AltText and -Decorative cannot be combined.' }
            $kind = if ($Decorative) { 'Artifact' } else { 'Structure' }
            # Tagged documents: a data-bearing symbol is a Figure; default alternate text names the symbology.
            $alt = if ($AltText) { $AltText } elseif ($Content) { "$Type barcode: $Content" } else { "$Type barcode" }
            [void]$canvas.SaveState()
            try {
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $Document.Pages[$Page - 1] -Kind $kind -StructType Figure -AltText $alt -Draw {
                    [void][VellumPdf.Barcodes.BarcodeCanvasExtensions]::DrawBarcode($canvas, $barcode, $X, $Y, $fontResource)
                }
            }
            finally { [void]$canvas.RestoreState() }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
