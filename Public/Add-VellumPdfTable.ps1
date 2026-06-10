function Add-VellumPdfTable {
    <#
    .SYNOPSIS
        Adds a table to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(TableElement). Builds a TableElement from a jagged array
        of row data, an optional header row, optional column widths, border styling,
        and a default cell text style. The document flows through the pipeline for
        chaining with other Add-VellumPdf* functions.

        Each inner array in -Row represents one data row; each element is converted
        to a string with ToString() and added as a cell. The optional -Header array
        produces a header row via AddHeaderRow().

        The -BorderColor and -HeaderBackground parameters accept a three-element
        array of [double] values in the 0..1 range (R, G, B).

        NOTE: -Row is a jagged array (array of rows). For a SINGLE row use the
        unary comma operator so PowerShell does not flatten the outer array:
        -Row @(,@('Cell1','Cell2')). A flat array like -Row @('a','b') is
        treated as two one-cell rows.
    .EXAMPLE
        $headers = @('Name', 'Score', 'Grade')
        $rows = @(
            @('Alice', '95', 'A'),
            @('Bob',   '82', 'B')
        )
        New-VellumPdfDocument |
            Add-VellumPdfTable -Header $headers -Row $rows -BorderWidth 0.5 |
            Save-VellumPdfDocument -Path ./report.pdf
    .EXAMPLE
        $doc | Add-VellumPdfTable -Row @(@('Cell1','Cell2')) `
               -ColumnWidth @(100, 200) -Font Helvetica -FontSize 10 -Alignment Center
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [string[]]$Header,

        [Parameter(Mandatory)]
        [object[][]]$Row,

        [double[]]$ColumnWidth,

        [ValidateRange(0, 100)]
        [double]$BorderWidth,

        [ValidateCount(3, 3)]
        [ValidateRange(0.0, 1.0)]
        [double[]]$BorderColor,

        [ValidateCount(3, 3)]
        [ValidateRange(0.0, 1.0)]
        [double[]]$HeaderBackground,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font,

        [ValidateRange(1, 1000)]
        [double]$FontSize,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Left'
    )

    process {
        $table = [VellumPdf.Layout.Elements.Table.TableElement]::new()

        # Apply default cell style when font or size is requested.
        $wantsStyle = [bool]$Font -or $PSBoundParameters.ContainsKey('FontSize')
        if ($wantsStyle) {
            $effFont = if ($Font) { $Font } else { 'Helvetica' }
            $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { 11 }
            $table.DefaultCellStyle = New-VellumTextStyle -Font $effFont -FontSize $effSize
        }

        # Apply border width.
        if ($PSBoundParameters.ContainsKey('BorderWidth')) {
            $table.BorderWidth = $BorderWidth
        }

        # Apply border color.
        if ($BorderColor) {
            $table.BorderColor = [VellumPdf.Layout.Core.ColorRgb]::new(
                $BorderColor[0], $BorderColor[1], $BorderColor[2])
        }

        # Apply column widths.
        if ($ColumnWidth) {
            [void]$table.SetColumnWidths($ColumnWidth)
        }

        # Add optional header row.
        if ($Header) {
            $headerRow = $table.AddHeaderRow()
            if ($HeaderBackground) {
                $headerRow.Background = [VellumPdf.Layout.Core.ColorRgb]::new(
                    $HeaderBackground[0], $HeaderBackground[1], $HeaderBackground[2])
            }
            foreach ($text in $Header) {
                $cell = [VellumPdf.Layout.Elements.Table.Cell]::new([string]$text)
                $cell.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
                [void]$headerRow.AddCell($cell)
            }
        }

        # Add data rows.
        foreach ($dataRow in $Row) {
            $tableRow = $table.AddRow($false)
            foreach ($value in $dataRow) {
                $cell = [VellumPdf.Layout.Elements.Table.Cell]::new([string]$value)
                $cell.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
                [void]$tableRow.AddCell($cell)
            }
        }

        [void]$Document.Add($table)
        $Document
    }
}
