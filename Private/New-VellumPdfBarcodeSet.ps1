function New-VellumPdfBarcodeSet {
    <#
    .SYNOPSIS
        Validates barcode options and builds the VellumPdf.Barcodes symbol(s).
    .DESCRIPTION
        Shared by Add-VellumPdfBarcode (flow layout) and Add-VellumPdfPageBarcode
        (page canvas). -Parameters is the caller's $PSBoundParameters, using the
        parameter names of Add-VellumPdfBarcode. Layout-specific concerns - margins,
        the page-width check, adding to a document - stay with the callers. Error
        messages start with 'Add-VellumPdfBarcode:'; callers re-prefix them.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Builds new in-memory barcode objects; performs no external/system state change.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable]$Parameters,
        [Parameter(Mandatory)] [bool]$IsPdfA,
        [Parameter(Mandatory)] [string]$ParameterSetName
    )

    # Unpack the caller's parameters into variables (unbound ones are $null) so the
    # validation below reads exactly like it did inside the cmdlet.
    foreach ($n in @('Type', 'Content', 'Bytes', 'SplitInto', 'FileId', 'ModuleSize', 'TargetWidth', 'Foreground', 'Background', 'NoQuietZone', 'Alignment', 'AltText', 'Decorative', 'BarHeight', 'ShowText', 'TextSize', 'TextFont', 'Caption', 'FontHandle', 'ErrorCorrection', 'QrVersion', 'QrMask', 'TextEncoding', 'QrGs1', 'Gs1', 'Shape', 'AztecFormat', 'AztecErrorCorrectionPercent', 'Columns', 'Rows', 'Compact', 'ErrorCorrectionLevel', 'PreferredAspectRatio', 'RowHeight', 'MacroFileName', 'MacroSender', 'MacroAddressee', 'MacroTimestamp', 'MacroFileSize', 'MacroChecksum', 'CheckDigit', 'FullAscii', 'WideNarrowRatio', 'AddOn', 'BearerBars', 'MarginTop', 'MarginBottom', 'MarginLeft', 'MarginRight')) { Set-Variable -Name $n -Value $null }
    $Alignment = 'Left'   # the only parameter with a default; $PSBoundParameters omits defaults
    foreach ($k in $Parameters.Keys) { Set-Variable -Name $k -Value $Parameters[$k] }
    $bound = $Parameters
    $isPdfA = $IsPdfA

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
            PreferredAspectRatio        = @('Pdf417')
            RowHeight                   = @('Pdf417')
            MacroFileName               = @('Pdf417')
            MacroSender                 = @('Pdf417')
            MacroAddressee              = @('Pdf417')
            MacroTimestamp              = @('Pdf417')
            MacroFileSize               = @('Pdf417')
            MacroChecksum               = @('Pdf417')
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
        $macroKeys = 'MacroFileName', 'MacroSender', 'MacroAddressee', 'MacroTimestamp', 'MacroFileSize', 'MacroChecksum'
        if (-not $bound.ContainsKey('SplitInto') -and ($macroKeys | Where-Object { $bound.ContainsKey($_) })) {
            throw 'Add-VellumPdfBarcode: the -Macro* options describe a Macro PDF417 set and need -SplitInto.'
        }
        if ($bound.ContainsKey('ModuleSize') -and $bound.ContainsKey('TargetWidth')) {
            throw 'Add-VellumPdfBarcode: -ModuleSize and -TargetWidth cannot be combined; choose one.'
        }
        if ($Decorative -and $AltText) {
            throw 'Add-VellumPdfBarcode: -AltText and -Decorative cannot be combined.'
        }
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
                    elseif ($ParameterSetName -eq 'Bytes') { $barcodes.Add([VellumPdf.Barcodes.QrCode]::new($Bytes)) }
                    else { $barcodes.Add([VellumPdf.Barcodes.QrCode]::new($Content)) }
                }
                'MicroQrCode' { $barcodes.Add([VellumPdf.Barcodes.MicroQrCode]::new($Content)) }
                'DataMatrix'  { $barcodes.Add([VellumPdf.Barcodes.DataMatrixBarcode]::new($Content)) }
                'Aztec'       { $barcodes.Add([VellumPdf.Barcodes.AztecCode]::new($Content)) }
                'Pdf417' {
                    if ($bound.ContainsKey('SplitInto')) {
                        $id = if ($bound.ContainsKey('FileId')) { $FileId } else { Get-Random -Minimum 0 -Maximum 900 }
                        $macro = [VellumPdf.Barcodes.MacroPdf417Options]::new()
                        if ($bound.ContainsKey('MacroFileName')) { $macro.FileName = $MacroFileName }
                        if ($bound.ContainsKey('MacroSender')) { $macro.Sender = $MacroSender }
                        if ($bound.ContainsKey('MacroAddressee')) { $macro.Addressee = $MacroAddressee }
                        if ($bound.ContainsKey('MacroTimestamp')) { $macro.Timestamp = $MacroTimestamp }
                        if ($bound.ContainsKey('MacroFileSize')) { $macro.FileSize = $MacroFileSize }
                        if ($bound.ContainsKey('MacroChecksum')) { $macro.Checksum = $MacroChecksum }
                        foreach ($b in [VellumPdf.Barcodes.Pdf417Barcode]::MacroSet($Content, $SplitInto, $id, $macro)) { $barcodes.Add($b) }
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
                    if ($bound.ContainsKey('PreferredAspectRatio')) { $barcode.PreferredAspectRatio = $PreferredAspectRatio }
                    if ($bound.ContainsKey('RowHeight')) { $barcode.RowHeight = $RowHeight }
                }
                if ($Type -eq 'Code39') {
                    if ($CheckDigit) { $barcode.CheckDigit = $true }
                    if ($FullAscii) { $barcode.FullAscii = $true }
                }
                if (($Type -in 'Code39', 'Itf14') -and $bound.ContainsKey('WideNarrowRatio')) { $barcode.WideNarrowRatio = $WideNarrowRatio }
                if ($isEan -and $bound.ContainsKey('AddOn')) { $barcode.AddOn = $AddOn }
                if ($Type -eq 'Itf14' -and $bound.ContainsKey('BearerBars')) { $barcode.BearerBars = [VellumPdf.Barcodes.ItfBearerBarStyle]::$BearerBars }


                # Fail now, at the call site, for content or options the symbology cannot encode.
                [void]$barcode.Measure()
            }
        }
        catch {
            if ($_.Exception.Message -like 'Add-VellumPdfBarcode:*') { throw }
            $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
            throw "Add-VellumPdfBarcode: cannot create the $Type symbol: $inner"
        }
        $barcodes.ToArray()
}
