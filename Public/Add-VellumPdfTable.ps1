function Add-VellumPdfTable {
    <#
    .SYNOPSIS
        Adds a table to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(TableElement). Builds a TableElement from row data, an
        optional header row, optional column widths, border and row styling, and a
        default cell text style. The document flows through the pipeline for
        chaining with other Add-VellumPdf* functions.

        -Row accepts two shapes (the first row decides which):
          - Records: PSCustomObject rows straight from Import-Csv or Select-Object,
            or one hashtable per row. Columns are the property/key names and a
            header is derived from them when -Header is omitted.
          - Cell arrays: one array per row. Each element is a scalar (added as
            text) or a rich-cell hashtable for that one cell:
              @{ Text = 'Total'; ColSpan = 2; Alignment = 'Right';
                 Background = '#eeeeee'; Font = 'HelveticaBold'; FontSize = 11;
                 Color = 'navy' }
            Text is required; the rest are optional.

        Colour parameters (-BorderColor, -HeaderBackground, -AlternateRowBackground,
        and a cell's Background/Color) accept an R,G,B triple in 0..1, a hex string
        ('#3366cc'/'#36c'), or a colour name.

        NOTE: with cell-array rows, a SINGLE row needs the unary comma operator so
        PowerShell does not flatten the outer array: -Row @(,@('Cell1','Cell2')).
        A flat array like -Row @('a','b') is treated as two one-cell rows. Records
        do not need this.

        -MarginTop and -MarginBottom apply spacing above and below the table
        without affecting the left/right margins already set on the element.

        Import-Csv example:
            Import-Csv data.csv | ForEach-Object { $rows += $_ }
            Add-VellumPdfTable -Row (Import-Csv data.csv)
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the table is added, enabling chaining.
    .PARAMETER Header
        An optional string array of column header labels. When supplied, a
        styled header row is prepended to the table via AddHeaderRow(). The
        count of header cells determines the expected column count for
        -ColumnWidth mismatch warnings.
    .PARAMETER Row
        The table rows. Either PSCustomObject/hashtable records (columns are the
        property/key names; header derived when -Header is omitted), or one array
        per row whose elements are scalars or rich-cell hashtables (see the
        description). For a single cell-array row, use the unary comma operator to
        prevent PowerShell from flattening the outer array: -Row @(,@('a','b')).
    .PARAMETER ColumnWidth
        Column widths in points, each between 0.01 and 100000. The count should
        match the number of columns determined by the -Header or first -Row; a
        mismatch emits a warning and extra widths are ignored.
    .PARAMETER BorderWidth
        Border line width in points applied to all cell borders, between 0 and
        100. When omitted the VellumPdf library default is used.
    .PARAMETER BorderColor
        Border line colour: an R,G,B triple in 0..1, a hex string ('#3366cc'),
        or a colour name. When omitted the library default border colour is used.
    .PARAMETER HeaderBackground
        Background fill colour for the header row (R,G,B triple, hex, or name).
        Applied only when a header is present (supplied via -Header or derived
        from record columns).
    .PARAMETER AlternateRowBackground
        Background fill colour applied to every second data row (zebra striping):
        an R,G,B triple in 0..1, a hex string, or a colour name.
    .PARAMETER ColumnAlignment
        Per-column horizontal alignment by column index (Left/Center/Right/
        Justify), overriding -Alignment for those columns. A cell's own
        Alignment key still wins over this.
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
        [object[]]$Row,

        [ValidateRange(0.01, 100000)]
        [double[]]$ColumnWidth,

        [ValidateRange(0, 100)]
        [double]$BorderWidth,

        # RGB triple (0..1), hex ('#3366cc'/'#36c'), or a colour name.
        [object]$BorderColor,

        # Background for the header row. RGB triple, hex, or a colour name.
        [object]$HeaderBackground,

        # Background applied to every second data row (zebra striping). RGB
        # triple, hex, or a colour name.
        [object]$AlternateRowBackground,

        # Per-column horizontal alignment, by column index, overriding
        # -Alignment for that column. Shorter than the column count leaves the
        # remaining columns on -Alignment.
        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string[]]$ColumnAlignment,

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

        # Two row shapes are accepted:
        #   - records: PSCustomObject (e.g. from Import-Csv) or a hashtable per
        #     row. Columns are the property/key names; values are read by name.
        #   - cell arrays: an array per row, each element a scalar or a rich-cell
        #     hashtable (@{ Text=...; ColSpan=...; Background=...; Alignment=... }).
        # The first row decides the mode.
        $recordMode = $Row.Count -gt 0 -and (
            ($Row[0] -is [System.Management.Automation.PSCustomObject]) -or
            ($Row[0] -is [System.Collections.IDictionary]))

        # Resolve a single cell value to a spec hashtable carrying at least Text.
        $toSpec = {
            param($value)
            if ($value -is [System.Collections.IDictionary]) {
                if (-not $value.Contains('Text')) {
                    throw "Add-VellumPdfTable: a rich-cell hashtable must include a 'Text' key."
                }
                return $value
            }
            return @{ Text = [string]$value }
        }

        # Build the rows as arrays of cell specs, and the effective header labels.
        $headerLabels = $Header
        $specRows = [System.Collections.Generic.List[object]]::new()
        if ($recordMode) {
            $columns = if ($Row[0] -is [System.Collections.IDictionary]) {
                @($Row[0].Keys)
            }
            else {
                @($Row[0].PSObject.Properties.Name)
            }
            if (-not $headerLabels) { $headerLabels = [string[]]$columns }
            foreach ($rec in $Row) {
                $cells = foreach ($col in $columns) {
                    $cellValue = if ($rec -is [System.Collections.IDictionary]) { $rec[$col] } else { $rec.$col }
                    & $toSpec $cellValue
                }
                $specRows.Add(@($cells))
            }
        }
        else {
            foreach ($r in $Row) {
                $cells = foreach ($v in @($r)) { & $toSpec $v }
                $specRows.Add(@($cells))
            }
        }

        # Encoding warning over every header label and cell's text.
        $cellText = @($headerLabels) + @($specRows | ForEach-Object { $_ | ForEach-Object { [string]$_['Text'] } })
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

        # Resolve flexible colours once (RGB triple / hex / name -> ColorRgb).
        $toRgb = {
            param($value)
            $c = ConvertTo-VellumColor $value
            [VellumPdf.Layout.Core.ColorRgb]::new($c[0], $c[1], $c[2])
        }
        if ($PSBoundParameters.ContainsKey('BorderColor')) { $table.BorderColor = & $toRgb $BorderColor }
        $headerBg = if ($PSBoundParameters.ContainsKey('HeaderBackground')) { & $toRgb $HeaderBackground }
        $altBg    = if ($PSBoundParameters.ContainsKey('AlternateRowBackground')) { & $toRgb $AlternateRowBackground }

        # Builds a styled Cell from a spec hashtable at a column index.
        $buildCell = {
            param($spec, $colIndex)
            $cell = [VellumPdf.Layout.Elements.Table.Cell]::new([string]$spec['Text'])
            $align = if ($spec['Alignment']) { [string]$spec['Alignment'] }
                elseif ($ColumnAlignment -and $colIndex -lt $ColumnAlignment.Count) { $ColumnAlignment[$colIndex] }
                else { $Alignment }
            $cell.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$align
            if ($spec['ColSpan']) { $cell.ColSpan = [int]$spec['ColSpan'] }
            if ($spec['RowSpan']) { $cell.RowSpan = [int]$spec['RowSpan'] }
            if ($spec['Background']) { $cell.Background = & $toRgb $spec['Background'] }
            if ($spec['Font'] -or $spec['FontSize'] -or $spec['Color']) {
                $cellStyle = @{}
                if ($spec['Font'])     { $cellStyle['Font']     = [string]$spec['Font'] }
                if ($spec['FontSize']) { $cellStyle['FontSize'] = [double]$spec['FontSize'] }
                if ($spec['Color'])    { $cellStyle['Color']    = ConvertTo-VellumColor $spec['Color'] }
                $cell.Style = New-VellumTextStyle @cellStyle
            }
            $cell
        }

        # Apply column widths.
        if ($ColumnWidth) {
            $columnCount = if ($headerLabels) { $headerLabels.Count } elseif ($specRows.Count) { $specRows[0].Count } else { 0 }
            if ($ColumnWidth.Count -ne $columnCount) {
                Write-Warning ("Add-VellumPdfTable: -ColumnWidth has $($ColumnWidth.Count) value(s) " +
                    "but the table has $columnCount column(s); extra widths are ignored and " +
                    'missing ones fall back to the library default.')
            }
            [void]$table.SetColumnWidths($ColumnWidth)
        }

        # Add optional header row.
        if ($headerLabels) {
            $headerRow = $table.AddHeaderRow()
            if ($headerBg) { $headerRow.Background = $headerBg }
            $hi = 0
            foreach ($text in $headerLabels) {
                [void]$headerRow.AddCell((& $buildCell @{ Text = [string]$text } $hi))
                $hi++
            }
        }

        # Add data rows, applying zebra striping to every second row.
        $rowIndex = 0
        foreach ($specRow in $specRows) {
            $tableRow = $table.AddRow($false)
            if ($altBg -and ($rowIndex % 2 -eq 1)) { $tableRow.Background = $altBg }
            $colIndex = 0
            foreach ($spec in $specRow) {
                [void]$tableRow.AddCell((& $buildCell $spec $colIndex))
                $colIndex++
            }
            $rowIndex++
        }

        Set-VellumPdfElementMargin -Element $table -Top $MarginTop -Bottom $MarginBottom `
            -BoundParameters $PSBoundParameters

        [void]$Document.Add($table)
        $Document
    }
}
