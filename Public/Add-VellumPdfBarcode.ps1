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
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfBarcode'
        $bound = $PSBoundParameters
        $is1D = $Type -in @('Code128', 'Code39', 'Ean13', 'Ean8', 'UpcA', 'UpcE', 'Itf14')
        $isEan = $Type -in @('Ean13', 'Ean8', 'UpcA', 'UpcE')

        # --- reject options that do not belong to this symbology -------------------
        $allowed = @{
            ErrorCorrection             = @('QrCode', 'MicroQrCode')
            QrVersion                   = @('QrCode', 'MicroQrCode')
            QrMask                      = @('QrCode')
            TextEncoding                = @('QrCode')
            QrGs1                       = @('QrCode')
            Gs1                         = @('Code128', 'DataMatrix')
            Shape                       = @('DataMatrix')
            AztecFormat                 = @('Aztec')
            AztecErrorCorrectionPercent = @('Aztec')
            Columns                     = @('Pdf417')
            Rows                        = @('Pdf417')
            Compact                     = @('Pdf417')
            ErrorCorrectionLevel        = @('Pdf417')
            CheckDigit                  = @('Code39')
            FullAscii                   = @('Code39')
            WideNarrowRatio             = @('Code39', 'Itf14')
            AddOn                       = @('Ean13', 'Ean8', 'UpcA', 'UpcE')
            BearerBars                  = @('Itf14')
            FileId                      = @('Pdf417')
        }
        foreach ($name in $allowed.Keys) {
            if ($bound.ContainsKey($name) -and $Type -notin $allowed[$name]) {
                throw ("Add-VellumPdfBarcode: -$name does not apply to -Type $Type (it applies to: " +
                    "$($allowed[$name] -join ', ')).")
            }
        }
        foreach ($name in 'BarHeight', 'ShowText', 'TextSize', 'TextFont') {
            if ($bound.ContainsKey($name) -and -not $is1D) {
                throw "Add-VellumPdfBarcode: -$name only applies to linear (1-D) barcodes, not -Type $Type."
            }
        }
        if ($bound.ContainsKey('Bytes') -and $Type -ne 'QrCode') {
            throw 'Add-VellumPdfBarcode: -Bytes is supported for -Type QrCode only; use -Content for other symbologies.'
        }
        if ($bound.ContainsKey('SplitInto') -and $Type -notin @('QrCode', 'Pdf417')) {
            throw 'Add-VellumPdfBarcode: -SplitInto applies to QrCode (Structured Append) and Pdf417 (Macro PDF417) only.'
        }
        if ($bound.ContainsKey('SplitInto') -and $bound.ContainsKey('Bytes')) {
            throw 'Add-VellumPdfBarcode: -SplitInto needs -Content text, not -Bytes.'
        }
        if ($bound.ContainsKey('ModuleSize') -and $bound.ContainsKey('TargetWidth')) {
            throw 'Add-VellumPdfBarcode: -ModuleSize and -TargetWidth cannot be combined; choose one.'
        }
        if ($Decorative -and $AltText) {
            throw 'Add-VellumPdfBarcode: -AltText and -Decorative cannot be combined.'
        }
        if ($FontHandle) {
            Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfBarcode'
        }
        if ($FontHandle -and -not $Caption) {
            throw 'Add-VellumPdfBarcode: -FontHandle is only used for -Caption; add -Caption or drop -FontHandle.'
        }

        # PDF/A forbids the non-embedded base-14 font used for the human-readable line.
        $isPdfA = $Document.Conformance -in @(
            [VellumPdf.Document.PdfConformance]::PdfA2b,
            [VellumPdf.Document.PdfConformance]::PdfA2u,
            [VellumPdf.Document.PdfConformance]::PdfA2a)
        $showTextValue = if ($bound.ContainsKey('ShowText')) { $ShowText } else { -not $isPdfA }
        if ($is1D -and $isPdfA -and $showTextValue) {
            throw ('Add-VellumPdfBarcode: the human-readable line of a linear barcode uses a non-embedded base-14 ' +
                'font, which PDF/A forbids. Leave -ShowText off and use -Caption with an embedded -FontHandle instead.')
        }
        if ($is1D -and $isPdfA -and $bound.ContainsKey('TextFont')) {
            throw 'Add-VellumPdfBarcode: -TextFont uses a base-14 font, which PDF/A forbids; use -Caption with -FontHandle.'
        }

        # --- build the symbol(s) ----------------------------------------------------
        $barcodes = [System.Collections.Generic.List[VellumPdf.Barcodes.Barcode]]::new()
        try {
            switch ($Type) {
                'QrCode' {
                    if ($bound.ContainsKey('SplitInto')) {
                        $ec = if ($bound.ContainsKey('ErrorCorrection')) { [VellumPdf.Barcodes.QrErrorCorrection]::$ErrorCorrection } else { [VellumPdf.Barcodes.QrErrorCorrection]::M }
                        $te = if ($bound.ContainsKey('TextEncoding')) { [VellumPdf.Barcodes.QrTextEncoding]::$TextEncoding } else { [VellumPdf.Barcodes.QrTextEncoding]::Auto }
                        foreach ($b in [VellumPdf.Barcodes.QrCode]::StructuredAppend($Content, $SplitInto, $ec, $te)) { $barcodes.Add($b) }
                    }
                    elseif ($PSCmdlet.ParameterSetName -eq 'Bytes') { $barcodes.Add([VellumPdf.Barcodes.QrCode]::new($Bytes)) }
                    else { $barcodes.Add([VellumPdf.Barcodes.QrCode]::new($Content)) }
                }
                'MicroQrCode' { $barcodes.Add([VellumPdf.Barcodes.MicroQrCode]::new($Content)) }
                'DataMatrix'  { $barcodes.Add([VellumPdf.Barcodes.DataMatrixBarcode]::new($Content)) }
                'Aztec'       { $barcodes.Add([VellumPdf.Barcodes.AztecCode]::new($Content)) }
                'Pdf417' {
                    if ($bound.ContainsKey('SplitInto')) {
                        $id = if ($bound.ContainsKey('FileId')) { $FileId } else { Get-Random -Minimum 0 -Maximum 900 }
                        foreach ($b in [VellumPdf.Barcodes.Pdf417Barcode]::MacroSet($Content, $SplitInto, $id)) { $barcodes.Add($b) }
                    }
                    else { $barcodes.Add([VellumPdf.Barcodes.Pdf417Barcode]::new($Content)) }
                }
                'Code128' { $barcodes.Add([VellumPdf.Barcodes.Code128Barcode]::new($Content)) }
                'Code39'  { $barcodes.Add([VellumPdf.Barcodes.Code39Barcode]::new($Content)) }
                'Itf14'   { $barcodes.Add([VellumPdf.Barcodes.Itf14Barcode]::new($Content)) }
                default   { $barcodes.Add([VellumPdf.Barcodes.EanBarcode]::new([VellumPdf.Barcodes.EanSymbology]::$Type, $Content)) }
            }

            $fg = if ($bound.ContainsKey('Foreground')) { ConvertTo-VellumColor $Foreground }
            $bg = if ($bound.ContainsKey('Background')) { ConvertTo-VellumColor $Background }
            foreach ($barcode in $barcodes) {
                if ($fg) { $barcode.Foreground = [VellumPdf.Layout.Core.ColorRgb]::new($fg[0], $fg[1], $fg[2]) }
                if ($bg) { $barcode.Background = [VellumPdf.Layout.Core.ColorRgb]::new($bg[0], $bg[1], $bg[2]) }
                if ($NoQuietZone) { $barcode.IncludeQuietZone = $false }
                $barcode.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
                if ($bound.ContainsKey('ModuleSize')) { $barcode.ModuleSize = $ModuleSize }
                if ($bound.ContainsKey('TargetWidth')) { $barcode.TargetWidth = $TargetWidth }
                if ($AltText) { $barcode.AltText = $AltText }
                if ($Decorative) { $barcode.Decorative = $true }

                if ($is1D) {
                    $barcode.ShowText = $showTextValue
                    if ($bound.ContainsKey('BarHeight')) { $barcode.BarHeight = $BarHeight }
                    if ($bound.ContainsKey('TextSize')) { $barcode.TextSize = $TextSize }
                    if ($bound.ContainsKey('TextFont')) { $barcode.TextFont = [VellumPdf.Fonts.Standard14]::$TextFont }
                }
                switch ($Type) {
                    { $_ -in 'QrCode', 'MicroQrCode' } {
                        if ($bound.ContainsKey('ErrorCorrection')) { $barcode.ErrorCorrection = [VellumPdf.Barcodes.QrErrorCorrection]::$ErrorCorrection }
                        if ($bound.ContainsKey('QrVersion')) { $barcode.Version = $QrVersion }
                    }
                }
                if ($Type -eq 'QrCode') {
                    if ($bound.ContainsKey('QrMask')) { $barcode.Mask = $QrMask }
                    if ($bound.ContainsKey('TextEncoding')) { $barcode.TextEncoding = [VellumPdf.Barcodes.QrTextEncoding]::$TextEncoding }
                    if ($bound.ContainsKey('QrGs1')) { $barcode.Gs1 = [VellumPdf.Barcodes.QrGs1Mode]::$QrGs1 }
                }
                if (($Type -in 'Code128', 'DataMatrix') -and $Gs1) { $barcode.Gs1 = $true }
                if ($Type -eq 'DataMatrix' -and $bound.ContainsKey('Shape')) { $barcode.Shape = [VellumPdf.Barcodes.DataMatrixShape]::$Shape }
                if ($Type -eq 'Aztec') {
                    if ($bound.ContainsKey('AztecFormat')) { $barcode.Format = [VellumPdf.Barcodes.AztecFormat]::$AztecFormat }
                    if ($bound.ContainsKey('AztecErrorCorrectionPercent')) { $barcode.ErrorCorrectionPercent = $AztecErrorCorrectionPercent }
                }
                if ($Type -eq 'Pdf417') {
                    if ($bound.ContainsKey('Columns')) { $barcode.Columns = $Columns }
                    if ($bound.ContainsKey('Rows')) { $barcode.Rows = $Rows }
                    if ($Compact) { $barcode.Compact = $true }
                    if ($bound.ContainsKey('ErrorCorrectionLevel')) { $barcode.ErrorCorrectionLevel = $ErrorCorrectionLevel }
                }
                if ($Type -eq 'Code39') {
                    if ($CheckDigit) { $barcode.CheckDigit = $true }
                    if ($FullAscii) { $barcode.FullAscii = $true }
                }
                if (($Type -in 'Code39', 'Itf14') -and $bound.ContainsKey('WideNarrowRatio')) { $barcode.WideNarrowRatio = $WideNarrowRatio }
                if ($isEan -and $bound.ContainsKey('AddOn')) { $barcode.AddOn = $AddOn }
                if ($Type -eq 'Itf14' -and $bound.ContainsKey('BearerBars')) { $barcode.BearerBars = [VellumPdf.Barcodes.ItfBearerBarStyle]::$BearerBars }

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

                # Fail now, at the call site, for content or options the symbology cannot encode.
                $size = $barcode.Measure()
                $contentWidth = $Document.PageSize.Width - $Document.Margins.Left - $Document.Margins.Right
                if ($size.Width -gt $contentWidth) {
                    throw ("Add-VellumPdfBarcode: the symbol is $([math]::Round($size.Width, 1))pt wide but the page content area " +
                        "is only $([math]::Round($contentWidth, 1))pt. Reduce -ModuleSize/-TargetWidth or the margins.")
                }
            }
        }
        catch {
            if ($_.Exception.Message -like 'Add-VellumPdfBarcode:*') { throw }
            $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
            throw "Add-VellumPdfBarcode: cannot create the $Type symbol: $inner"
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
}
