function Add-VellumPdfBarcode {
    <#
    .SYNOPSIS
        Adds a barcode or 2-D symbol (QR, Data Matrix, Aztec, PDF417, Code 128, ...) as vector graphics.
    .DESCRIPTION
        Uses VellumPdf.Barcodes through Layout's custom-element hook
        (Document.Add(IRenderer)). Supported -Type values: QrCode, MicroQrCode,
        DataMatrix, Aztec, Pdf417, Code128, Code39, Ean13, Ean8, UpcA, UpcE, Itf14.

        The symbol is validated when it is added (content that cannot be encoded
        fails here, not when the document is saved). Size it with -ModuleSize (the
        width of one module in points) or -TargetWidth (the whole symbol's width),
        never both. In a tagged document a symbol is a Figure whose alternate text
        is -AltText or, by default, the symbology and content; use -Decorative when
        the encoded data is already available as nearby text.

        Options that belong to one symbology (for example -ErrorCorrection or
        -BearerBars) are rejected with a clear error when used with another type.

        PDF/A: the human-readable line under a 1-D barcode uses a base-14 font,
        which PDF/A forbids because it is not embedded. In a PDF/A document the
        line is therefore off by default and -ShowText is refused; use -Caption
        (with -FontHandle) to print the text in your embedded font instead.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline.
    .PARAMETER Type
        The symbology.
    .PARAMETER Content
        The text to encode. EAN/UPC/ITF-14 take digits only (the check digit is
        computed or verified; see the VellumPdf.Barcodes documentation).
    .PARAMETER Bytes
        Binary content to encode (QrCode only).
    .PARAMETER SplitInto
        QrCode: split the content over this many Structured Append symbols. Pdf417:
        split into this many Macro PDF417 segments. Each symbol is added in turn.
    .PARAMETER FileId
        Pdf417 with -SplitInto: the 0..899 identifier shared by the segments
        (default: random).
    .PARAMETER ModuleSize
        Width of one module in points. Exclusive with -TargetWidth.
    .PARAMETER TargetWidth
        Total width of the symbol in points. Exclusive with -ModuleSize.
    .PARAMETER Foreground
        Colour of the dark modules/bars (default black): R,G,B in 0..1, hex or name.
    .PARAMETER Background
        Fill colour behind the symbol (default none).
    .PARAMETER NoQuietZone
        Omit the blank quiet zone around the symbol. Scanners usually need it.
    .PARAMETER Alignment
        Left (default), Center or Right.
    .PARAMETER AltText
        Alternate text in a tagged document. Default: symbology and content.
    .PARAMETER Decorative
        Mark the symbol as an artifact (not read by screen readers).
    .PARAMETER BarHeight
        1-D symbols: the bar height in points (default 40).
    .PARAMETER ShowText
        1-D symbols: print the human-readable text under the bars (default on, off
        in PDF/A documents). Use -ShowText:$false to switch it off.
    .PARAMETER TextSize
        1-D symbols: size of the human-readable text (default: from -BarHeight).
    .PARAMETER TextFont
        1-D symbols: base-14 font of the human-readable text (default Helvetica).
    .PARAMETER Caption
        Text printed centred below the symbol in the document font. Use with
        -FontHandle in PDF/A documents.
    .PARAMETER FontHandle
        Embedded font for -Caption.
    .PARAMETER ErrorCorrection
        QrCode (L, M, Q, H; default M) and MicroQrCode (L, M, Q; default L).
    .PARAMETER QrVersion
        QrCode (1..40) and MicroQrCode (1..4): force a symbol version.
    .PARAMETER QrMask
        QrCode: force mask pattern 0..7.
    .PARAMETER TextEncoding
        QrCode: Auto (default), Latin1, Utf8 or Utf8Eci.
    .PARAMETER QrGs1
        QrCode: None (default), ElementString or DigitalLink (GS1 content).
    .PARAMETER Gs1
        Code128 (GS1-128) and DataMatrix (GS1 Data Matrix): treat -Content as GS1 element strings.
    .PARAMETER Shape
        DataMatrix: Automatic (default), Square or Rectangular.
    .PARAMETER AztecFormat
        Aztec: Automatic (default), Compact or FullRange.
    .PARAMETER AztecErrorCorrectionPercent
        Aztec: minimum error-correction percentage (default 23).
    .PARAMETER Columns
        Pdf417: number of data columns.
    .PARAMETER Rows
        Pdf417: number of rows.
    .PARAMETER Compact
        Pdf417: compact (truncated) variant.
    .PARAMETER ErrorCorrectionLevel
        Pdf417: security level 0..8 (default: chosen from the data size).
    .PARAMETER PreferredAspectRatio
        Pdf417: target width-to-height ratio used to choose the number of columns (default 3).
    .PARAMETER RowHeight
        Pdf417: height of one row in modules (default 3).
    .PARAMETER MacroFileName
        Pdf417 with -SplitInto: the file name recorded in every Macro PDF417 segment.
    .PARAMETER MacroSender
        Pdf417 with -SplitInto: sender recorded in the segments.
    .PARAMETER MacroAddressee
        Pdf417 with -SplitInto: addressee recorded in the segments.
    .PARAMETER MacroTimestamp
        Pdf417 with -SplitInto: timestamp recorded in the segments.
    .PARAMETER MacroFileSize
        Pdf417 with -SplitInto: total file size in bytes recorded in the segments.
    .PARAMETER MacroChecksum
        Pdf417 with -SplitInto: 16-bit checksum of the whole file recorded in the segments.
    .PARAMETER CheckDigit
        Code39: append a modulo-43 check character.
    .PARAMETER FullAscii
        Code39: encode the full ASCII set using two-character sequences.
    .PARAMETER WideNarrowRatio
        Code39 and Itf14: the wide/narrow bar ratio (default 2.5).
    .PARAMETER AddOn
        Ean13/UpcA/...: a 2- or 5-digit add-on symbol.
    .PARAMETER BearerBars
        Itf14: Frame (default), Horizontal or None.
    .PARAMETER MarginTop
        Extra spacing in points above the symbol.
    .PARAMETER MarginBottom
        Extra spacing in points below the symbol.
    .PARAMETER MarginLeft
        Extra spacing in points to the left of the symbol.
    .PARAMETER MarginRight
        Extra spacing in points to the right of the symbol.
    .EXAMPLE
        $doc | Add-VellumPdfBarcode -Type QrCode -Content 'https://example.com' -TargetWidth 90 -AltText 'Link to example.com'
    .EXAMPLE
        $doc | Add-VellumPdfBarcode -Type Ean13 -Content '5901234123457' -BarHeight 50 -Alignment Center
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('QrCode', 'MicroQrCode', 'DataMatrix', 'Aztec', 'Pdf417', 'Code128', 'Code39',
            'Ean13', 'Ean8', 'UpcA', 'UpcE', 'Itf14')]
        [string]$Type,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Text')]
        [string]$Content,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$Bytes,

        [ValidateRange(2, 16)]
        [int]$SplitInto,

        [ValidateRange(0, 899)]
        [int]$FileId,

        [ValidateRange(0.01, 1000)]
        [double]$ModuleSize,

        [ValidateRange(1, 100000)]
        [double]$TargetWidth,

        [object]$Foreground,
        [object]$Background,
        [switch]$NoQuietZone,

        [ValidateSet('Left', 'Center', 'Right')]
        [string]$Alignment = 'Left',

        [string]$AltText,
        [switch]$Decorative,

        [ValidateRange(1, 10000)]
        [double]$BarHeight,

        [bool]$ShowText,

        [ValidateRange(0, 1000)]
        [double]$TextSize,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$TextFont,

        [string]$Caption,
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [ValidateSet('L', 'M', 'Q', 'H')]
        [string]$ErrorCorrection,

        [ValidateRange(1, 40)]
        [int]$QrVersion,

        [ValidateRange(0, 7)]
        [int]$QrMask,

        [ValidateSet('Auto', 'Latin1', 'Utf8', 'Utf8Eci')]
        [string]$TextEncoding,

        [ValidateSet('None', 'ElementString', 'DigitalLink')]
        [string]$QrGs1,

        [switch]$Gs1,

        [ValidateSet('Automatic', 'Square', 'Rectangular')]
        [string]$Shape,

        [ValidateSet('Automatic', 'Compact', 'FullRange')]
        [string]$AztecFormat,

        [ValidateRange(0, 100)]
        [int]$AztecErrorCorrectionPercent,

        [ValidateRange(1, 30)]
        [int]$Columns,

        [ValidateRange(3, 90)]
        [int]$Rows,

        [switch]$Compact,

        [ValidateRange(0, 8)]
        [int]$ErrorCorrectionLevel,

        [ValidateRange(0.5, 20)]
        [double]$PreferredAspectRatio,

        [ValidateRange(1, 20)]
        [double]$RowHeight,

        [string]$MacroFileName,
        [string]$MacroSender,
        [string]$MacroAddressee,
        [System.DateTimeOffset]$MacroTimestamp,
        [ValidateRange(0, [long]::MaxValue)]
        [long]$MacroFileSize,
        [ValidateRange(0, 65535)]
        [int]$MacroChecksum,

        [switch]$CheckDigit,
        [switch]$FullAscii,

        [ValidateRange(2, 3)]
        [double]$WideNarrowRatio,

        [string]$AddOn,

        [ValidateSet('Frame', 'Horizontal', 'None')]
        [string]$BearerBars,

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom,

        [ValidateRange(0, 10000)]
        [double]$MarginLeft,

        [ValidateRange(0, 10000)]
        [double]$MarginRight
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfBarcode'
            $bound = $PSBoundParameters
            $isPdfA = $Document.Conformance -in @(
                [VellumPdf.Document.PdfConformance]::PdfA2b,
                [VellumPdf.Document.PdfConformance]::PdfA2u,
                [VellumPdf.Document.PdfConformance]::PdfA2a)

            # Option validation and symbol construction are shared with Add-VellumPdfPageBarcode.
            $barcodes = @(New-VellumPdfBarcodeSet -Parameters $PSBoundParameters -IsPdfA $isPdfA -ParameterSetName $PSCmdlet.ParameterSetName)

            if ($FontHandle) {
                Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfBarcode'
            }
            if ($FontHandle -and -not $Caption) {
                throw 'Add-VellumPdfBarcode: -FontHandle is only used for -Caption; add -Caption or drop -FontHandle.'
            }

            $contentWidth = $Document.PageSize.Width - $Document.Margins.Left - $Document.Margins.Right
            foreach ($barcode in $barcodes) {
                # Top/bottom go through the shared helper (which also adds any space the
                # previous element's -MarginBottom deferred); left/right are set directly.
                Set-VellumPdfElementMargin -Element $barcode -Top $MarginTop -Bottom $MarginBottom `
                    -BoundParameters $PSBoundParameters -Document $Document
                if ($bound.ContainsKey('MarginLeft') -or $bound.ContainsKey('MarginRight')) {
                    $edges = $barcode.Margins
                    $barcode.Margins = [VellumPdf.Layout.Core.EdgeInsets]::new($edges.Top,
                        $(if ($bound.ContainsKey('MarginRight')) { $MarginRight } else { $edges.Right }),
                        $edges.Bottom,
                        $(if ($bound.ContainsKey('MarginLeft')) { $MarginLeft } else { $edges.Left }))
                }

                $size = $barcode.Measure()
                if ($size.Width -gt $contentWidth) {
                    throw ("Add-VellumPdfBarcode: the symbol is $([math]::Round($size.Width, 1))pt wide but the page content area " +
                        "is only $([math]::Round($contentWidth, 1))pt. Reduce -ModuleSize/-TargetWidth or the margins.")
                }
            }

            # --- add to the document ----------------------------------------------------
            foreach ($barcode in $barcodes) {
                [void][VellumPdf.Barcodes.DocumentBarcodeExtensions]::Add($Document, $barcode)
            }

            if ($Caption) {
                $captionArgs = @{ Document = $Document; Text = $Caption; Alignment = $Alignment }
                if ($FontHandle) { $captionArgs['FontHandle'] = $FontHandle }
                [void](Add-VellumPdfParagraph @captionArgs)
            }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
