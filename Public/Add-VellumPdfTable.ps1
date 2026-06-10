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

        -MarginTop and -MarginBottom apply spacing above and below the table
        without affecting the left/right margins already set on the element.

        Objects from Import-Csv (PSCustomObject) are rejected with a hint;
        convert them to value arrays first:
            $rows = Import-Csv data.csv |
                ForEach-Object { [object[]]($_.PSObject.Properties.Value) }
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
        [string]$Alignment = 'Left',

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom
    )

    process {
        # Objects from Import-Csv / Select-Object bind as one PSCustomObject per
        # row, which would stringify into a single mangled cell. Fail fast with
        # a conversion hint instead of producing a silently wrong table.
        foreach ($r in $Row) {
            foreach ($v in $r) {
                if ($v -is [System.Management.Automation.PSCustomObject]) {
                    throw ('Add-VellumPdfTable: -Row received a PSCustomObject (e.g. from Import-Csv). ' +
                        'Convert rows to value arrays first: ' +
                        '$rows = $data | ForEach-Object { [object[]]($_.PSObject.Properties.Value) }')
                }
            }
        }

        $cellText = @($Header) + @($Row | ForEach-Object { $_ | ForEach-Object { [string]$_ } })
        Write-VellumPdfEncodingWarning -Text $cellText -CommandName 'Add-VellumPdfTable'

        $table = [VellumPdf.Layout.Elements.Table.TableElement]::new()

        # Apply default cell style when font or size is requested. Gaps are
        # filled from the document defaults: a style without a font renders in
        # the library-global Helvetica, not the document default.
        $wantsStyle = [bool]$Font -or $PSBoundParameters.ContainsKey('FontSize')
        if ($wantsStyle) {
            $default = Resolve-VellumPdfDefault -Document $Document
            $effFont = if ($Font) { $Font } else { $default.Font }
            $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { $default.FontSize }
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

        Set-VellumPdfElementMargin -Element $table -Top $MarginTop -Bottom $MarginBottom `
            -BoundParameters $PSBoundParameters

        [void]$Document.Add($table)
        $Document
    }
}
