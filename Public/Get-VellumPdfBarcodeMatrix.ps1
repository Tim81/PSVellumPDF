function Get-VellumPdfBarcodeMatrix {
    <#
    .SYNOPSIS
        Returns the module (black/white square) matrix of a 2-D barcode, without drawing it.
    .DESCRIPTION
        Encodes the content with the same validation and options as Add-VellumPdfBarcode and
        returns the symbol as data: its size and every row as text ('#' dark, '.' light).
        Use it to show a QR code in a console, to compare symbols in tests, or to render the
        symbol with another tool. Supported: QrCode, MicroQrCode, DataMatrix, Aztec, Pdf417.
        The matrix has no quiet zone.
    .PARAMETER Type
        QrCode, MicroQrCode, DataMatrix, Aztec or Pdf417.
    .PARAMETER Content
        The text to encode.
    .PARAMETER Bytes
        Binary content (QrCode only).
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
        DataMatrix: GS1 element strings.
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
    .EXAMPLE
        (Get-VellumPdfBarcodeMatrix QrCode 'hello').Rows
    .OUTPUTS
        PSVellumPDF.BarcodeMatrix (Type, Width, Height, Rows, and an IsDark(x, y) method)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    [OutputType('PSVellumPDF.BarcodeMatrix')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('QrCode', 'MicroQrCode', 'DataMatrix', 'Aztec', 'Pdf417')]
        [string]$Type,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Text')]
        [string]$Content,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$Bytes,

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
        [ValidateRange(0, 8)] [int]$ErrorCorrectionLevel
    )

    process {
        try {
            $barcode = New-VellumPdfBarcodeSet -Parameters $PSBoundParameters -IsPdfA $false -ParameterSetName $PSCmdlet.ParameterSetName |
                Select-Object -First 1
            $matrix = $barcode.GetMatrix()
        }
        catch {
            throw ($_.Exception.Message -replace '^Add-VellumPdfBarcode:', 'Get-VellumPdfBarcodeMatrix:')
        }
        $lines = [System.Collections.Generic.List[string]]::new()
        for ($y = 0; $y -lt $matrix.Height; $y++) {
            $row = [System.Text.StringBuilder]::new($matrix.Width)
            for ($x = 0; $x -lt $matrix.Width; $x++) { [void]$row.Append($(if ($matrix.IsDark($x, $y)) { '#' } else { '.' })) }
            $lines.Add($row.ToString())
        }
        $result = [pscustomobject]@{
            PSTypeName = 'PSVellumPDF.BarcodeMatrix'
            Type       = $Type
            Width      = $matrix.Width
            Height     = $matrix.Height
            Rows       = $lines.ToArray()
        }
        $result | Add-Member -MemberType ScriptMethod -Name IsDark -Value { param([int]$x, [int]$y) $this.Rows[$y][$x] -eq '#' }
        $result
    }
}
