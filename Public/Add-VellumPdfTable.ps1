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
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the table is added, enabling chaining.
    .PARAMETER Header
        An optional string array of column header labels. When supplied, a
        styled header row is prepended to the table via AddHeaderRow(). The
        count of header cells determines the expected column count for
        -ColumnWidth mismatch warnings.
    .PARAMETER Row
        A jagged array of data rows (array of arrays). Each inner array element
        is converted to a string via ToString() and added as a cell. PSCustomObject
        elements are rejected with a conversion hint. For a single data row, use
        the unary comma operator to prevent PowerShell from flattening the outer
        array: -Row @(,@('Cell1','Cell2')).
    .PARAMETER ColumnWidth
        Column widths in points, each between 0.01 and 100000. The count should
        match the number of columns determined by the -Header or first -Row; a
        mismatch emits a warning and extra widths are ignored.
    .PARAMETER BorderWidth
        Border line width in points applied to all cell borders, between 0 and
        100. When omitted the VellumPdf library default is used.
    .PARAMETER BorderColor
        Border line colour as three doubles representing Red, Green, and Blue
        channels, each in the 0.0..1.0 range. Exactly three values must be
        supplied. When omitted the library default border colour is used.
    .PARAMETER HeaderBackground
        Background fill colour for the header row as three doubles representing
        Red, Green, and Blue channels, each in the 0.0..1.0 range. Exactly
        three values must be supplied. Only applied when -Header is also
        supplied.
    .PARAMETER Font
        A base-14 font name applied as the default cell style for all data
        cells. When omitted the document default font is used.
    .PARAMETER FontSize
        Font size in points for all data cells, between 1 and 1000. When
        omitted the document default size is used.
    .PARAMETER Alignment
        Horizontal text alignment for all cells (header and data). Accepts
        Left, Center, Right, or Justify. Defaults to Left.
    .PARAMETER MarginTop
        Extra spacing in points above the table element. Does not affect the
        left/right page margins.
    .PARAMETER MarginBottom
        Extra spacing in points below the table element. Does not affect the
        left/right page margins.
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

        [ValidateRange(0.01, 100000)]
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
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfTable'

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
            $columnCount = if ($Header) { $Header.Count } else { $Row[0].Count }
            if ($ColumnWidth.Count -ne $columnCount) {
                Write-Warning ("Add-VellumPdfTable: -ColumnWidth has $($ColumnWidth.Count) value(s) " +
                    "but the table has $columnCount column(s); extra widths are ignored and " +
                    'missing ones fall back to the library default.')
            }
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
