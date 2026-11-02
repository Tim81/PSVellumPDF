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
            or one [ordered] dictionary per row. Columns are the property/key names,
            in the first row's order, and a header is derived from them when -Header
            is omitted. A plain @{} hashtable with more than one key is refused: it
            has no fixed key order, so the columns would come out shuffled. Write
            [ordered]@{ ... } or [pscustomobject]@{ ... } (a one-key hashtable is fine).
          - Cell arrays: one array per row. Each element is a scalar (added as
            text) or a rich-cell hashtable for that one cell:
              @{ Text = 'Total'; ColSpan = 2; Alignment = 'Right';
                 Background = '#eeeeee'; Font = 'HelveticaBold'; FontSize = 11;
                 Color = 'navy' }
            Text is required; the rest are optional. More keys: FontHandle (an
            embedded font for this cell), Leading, Padding (1, 2 or 4 numbers),
            and Language (BCP 47 tag, tagged documents only). A LinkUri key is
            refused because VellumPdf ignores hyperlinks in table cells.
          - The same keys work in -Header entries.

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
        Optional column header entries: strings, or rich-cell hashtables with the
        same keys as a data cell. For several header rows pass an array per row, e.g.
        -Header @('Region', @{ Text = 'Sales'; ColSpan = 2 }), @('', 'Q1', 'Q2'); the
        leading header rows repeat on every page. When supplied, a header row is prepended to the
        table via AddHeaderRow(). The count of header cells determines the
        expected column count for -ColumnWidth mismatch warnings.
    .PARAMETER Row
        The table rows. Either PSCustomObject/[ordered] records (columns are the
        property/key names; header derived when -Header is omitted), or one array
        per row whose elements are scalars or rich-cell hashtables (see the
        description). For a single cell-array row, use the unary comma operator to
        prevent PowerShell from flattening the outer array: -Row @(,@('a','b')).
        May be empty (or $null) when -Header is given: the result is a header-only
        table (drawn as ordinary rows, because the engine cannot lay out a table
        of header rows alone, so a tagged document does not mark them as header
        cells). An empty -Row without -Header is an error.
    .PARAMETER ColumnWidth
        Column widths in points, each between 0 and 100000. A width of 0 means
        "auto": the column shares the remaining space. The count should
        match the number of columns determined by the -Header or first -Row; a
        mismatch emits a warning and extra widths are ignored.
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont, used as the table's
        default cell font. Takes precedence over -Font. Needed for text outside
        Windows-1252 and for PDF/A documents. A cell may override it with its own
        FontHandle key.
    .PARAMETER CellPadding
        Default padding for every cell, in points: one number (all sides), two
        (top/bottom, left/right) or four (top, right, bottom, left). A cell's own
        Padding key wins. When omitted the engine default (4, 6, 4, 6) applies.
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

        # Header labels. Each entry is a string or a rich-cell hashtable (same
        # keys as a data cell), e.g. @{ Text = 'Total'; Alignment = 'Right' }.
        [object[]]$Header,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Row,

        [ValidateRange(0.0, 100000.0)]
        [double[]]$ColumnWidth,

        [ValidateRange(0.0, 100.0)]
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

        [ValidateRange(1.0, 1000.0)]
        [double]$FontSize,

        # An embedded TrueType font from Register-VellumPdfFont. Takes precedence
        # over -Font; required for Unicode text and for PDF/A documents.
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        # Default padding for every cell: one number (all sides), two (top/bottom,
        # left/right) or four (top, right, bottom, left), in points. A cell's own
        # Padding key wins. The engine default is 4,6,4,6.
        [object]$CellPadding,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Left',

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginTop,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginBottom
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfTable'
            if ($FontHandle) {
                Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfTable'
            }
            # An empty -Row is a header-only table; without a -Header there would be nothing to draw.
            if ($null -eq $Row) { $Row = @() }
            if ($Row.Count -eq 0 -and ($null -eq $Header -or $Header.Count -eq 0)) {
                throw 'Add-VellumPdfTable: -Row is empty and no -Header was given; supply at least one row, or a -Header for a header-only table.'
            }
            $tablePadding = if ($PSBoundParameters.ContainsKey('CellPadding')) {
                ConvertTo-VellumInsets -Value $CellPadding -What 'Add-VellumPdfTable: -CellPadding'
            }

            # Two row shapes are accepted:
            #   - records: PSCustomObject (e.g. from Import-Csv) or a hashtable per
            #     row. Columns are the property/key names; values are read by name.
            #   - cell arrays: an array per row, each element a scalar or a rich-cell
            #     hashtable (@{ Text=...; ColSpan=...; Background=...; Alignment=... }).
            # The first row decides the mode.
            $isRecord = {
                param($r)
                ($r -is [System.Management.Automation.PSCustomObject]) -or ($r -is [System.Collections.IDictionary])
            }
            $recordMode = $Row.Count -gt 0 -and (& $isRecord $Row[0])

            # All rows must be the same shape. Mixing records and cell-arrays would
            # otherwise render silently-wrong output (an object stringified into one
            # cell, or array cells read by property name as all-empty).
            for ($i = 1; $i -lt $Row.Count; $i++) {
                if ((& $isRecord $Row[$i]) -ne $recordMode) {
                    throw ('Add-VellumPdfTable: -Row mixes record rows (PSCustomObject/hashtable) and ' +
                        "cell-array rows; row $i does not match the shape of the first row. Use one shape " +
                        'for all rows.')
                }
            }

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

            # Build the rows as arrays of cell specs, and the effective header cells.
            $headerLabels = $Header
            $specRows = [System.Collections.Generic.List[object]]::new()
            if ($recordMode) {
                # A plain hashtable enumerates its keys in no fixed order, so the columns would come out shuffled.
                if ($Row[0] -is [hashtable] -and $Row[0].Count -gt 1) {
                    throw ('Add-VellumPdfTable: a plain @{} hashtable row has no fixed key order, so its columns would come ' +
                        'out in an arbitrary order. Write each row as [ordered]@{ ... } or [pscustomobject]@{ ... }, or pass ' +
                        'cell-array rows (one array per row) together with -Header.')
                }
                $columns = if ($Row[0] -is [System.Collections.IDictionary]) {
                    @($Row[0].Keys)
                }
                else {
                    @($Row[0].PSObject.Properties.Name)
                }
                if (-not $headerLabels) { $headerLabels = [string[]]$columns }
                foreach ($rec in $Row) {
                    $cells = foreach ($col in $columns) {
                        $cellValue = Get-VellumPdfPropertyValue -InputObject $rec -Name $col
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

            # -Header is one row of entries, or several rows when its entries are themselves arrays.
            $isHeaderRow = { param($e) $e -is [System.Collections.IEnumerable] -and $e -isnot [string] -and $e -isnot [System.Collections.IDictionary] }
            $headerRowSpecs = [System.Collections.Generic.List[object]]::new()
            if ($null -ne $headerLabels) {
                $nested = @(@($headerLabels) | Where-Object { & $isHeaderRow $_ }).Count
                if ($nested -gt 0 -and $nested -ne @($headerLabels).Count) {
                    throw 'Add-VellumPdfTable: -Header mixes plain entries and row arrays; give either one row of entries or several row arrays.'
                }
                if ($nested -gt 0) {
                    foreach ($hrow in $headerLabels) { $headerRowSpecs.Add(@(foreach ($h in @($hrow)) { & $toSpec $h })) }
                }
                else { $headerRowSpecs.Add(@(foreach ($h in @($headerLabels)) { & $toSpec $h })) }
            }
            $headerSpecs = if ($headerRowSpecs.Count) { @($headerRowSpecs | ForEach-Object { $_ }) } else { @() }   # every header cell, for text checks

            # Spans are read while the grid is laid out, before any cell is built: check them first.
            foreach ($spec in @($headerSpecs) + @($specRows | ForEach-Object { $_ })) {
                foreach ($spanKey in 'ColSpan', 'RowSpan') {
                    if ($null -eq $spec[$spanKey]) { continue }
                    $spanValue = $spec[$spanKey] -as [double]
                    if ($null -eq $spanValue -or -not [double]::IsFinite($spanValue) -or $spanValue -ne [Math]::Floor($spanValue) -or $spanValue -lt 1 -or $spanValue -gt 1000) {
                        throw "Add-VellumPdfTable: rich-cell $spanKey must be a whole number from 1 to 1000; got '$($spec[$spanKey])'."
                    }
                }
            }

            # Encoding warning over every header and data cell's text, skipping cells
            # that render in an embedded font (the table's, or the cell's own).
            $cellText = @(
                foreach ($spec in @($headerSpecs) + @($specRows | ForEach-Object { $_ })) {
                    if (-not $FontHandle -and -not $spec['FontHandle']) { [string]$spec['Text'] }
                }
            )
            Write-VellumPdfEncodingWarning -Text $cellText -CommandName 'Add-VellumPdfTable'

            $table = [VellumPdf.Layout.Elements.Table.TableElement]::new()

            # Effective table font/size: the -Font/-FontSize overrides, else the
            # document defaults. A TextStyle without a font renders in the
            # library-global Helvetica, so these fill the gap for the default cell
            # style AND for rich cells that set only Colour (see $buildCell).
            $default = Resolve-VellumPdfDefault -Document $Document
            $effFont = if ($Font) { $Font } else { $default.Font }
            $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { $default.FontSize }
            if ($FontHandle) {
                $table.DefaultCellStyle = New-VellumTextStyle -FontHandle $FontHandle -FontSize $effSize -Document $Document -CommandName 'Add-VellumPdfTable'
            }
            else {
                $table.DefaultCellStyle = New-VellumTextStyle -Font $effFont -FontSize $effSize -Document $Document -CommandName 'Add-VellumPdfTable'
            }

            # The base-14 font names a rich cell's Font key may use (same set as the
            # -Font parameter's ValidateSet, which does not reach per-cell hashtables).
            $fontNames = @('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
                'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
                'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')

            # Apply border width.
            if ($PSBoundParameters.ContainsKey('BorderWidth')) {
                $table.BorderWidth = $BorderWidth
            }

            # Resolve flexible colours once (RGB triple / hex / name -> ColorRgb).
            $toRgb = {
                param($value)
                $c = ConvertTo-VellumColor $value -Document $Document -CommandName 'Add-VellumPdfTable'
                [VellumPdf.Layout.Core.ColorRgb]::new($c[0], $c[1], $c[2])
            }
            if ($PSBoundParameters.ContainsKey('BorderColor')) { $table.BorderColor = & $toRgb $BorderColor }
            $headerBg = if ($PSBoundParameters.ContainsKey('HeaderBackground')) { & $toRgb $HeaderBackground }
            $altBg    = if ($PSBoundParameters.ContainsKey('AlternateRowBackground')) { & $toRgb $AlternateRowBackground }

            # Builds a styled Cell from a spec hashtable at a column index. Rich-cell
            # values are validated here because the -Font/-FontSize/-Alignment
            # parameter guards do not reach per-cell hashtables.
            $buildCell = {
                param($spec, $colIndex)
                $cell = [VellumPdf.Layout.Elements.Table.Cell]::new([string]$spec['Text'])

                $align = if ($spec['Alignment']) { [string]$spec['Alignment'] }
                    elseif ($ColumnAlignment -and $colIndex -lt $ColumnAlignment.Count) { $ColumnAlignment[$colIndex] }
                    else { $Alignment }
                if ($align -notin @('Left', 'Center', 'Right', 'Justify')) {
                    throw "Add-VellumPdfTable: rich-cell Alignment '$align' is invalid; use Left, Center, Right, or Justify."
                }
                $cell.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$align

                foreach ($spanKey in 'ColSpan', 'RowSpan') {
                    if ($null -ne $spec[$spanKey]) {
                        $cell.$spanKey = [int]$spec[$spanKey]   # validated up front
                    }
                }

                if ($spec['Background']) { $cell.Background = & $toRgb $spec['Background'] }

                if ($spec['LinkUri']) {
                    throw ('Add-VellumPdfTable: a table cell cannot carry a LinkUri - VellumPdf ignores hyperlinks ' +
                        'inside table cells. Put the link in a paragraph with -LinkUri instead.')
                }

                $cellHandle = $spec['FontHandle']
                if ($cellHandle) {
                    if ($cellHandle -isnot [VellumPdf.Fonts.EmbeddedFontHandle]) {
                        throw 'Add-VellumPdfTable: rich-cell FontHandle must be an EmbeddedFontHandle from Register-VellumPdfFont.'
                    }
                    Assert-VellumPdfFontHandle -FontHandle $cellHandle -Document $Document -CommandName 'Add-VellumPdfTable'
                }
                $effHandle = if ($cellHandle) { $cellHandle } else { $FontHandle }
                Write-VellumPdfMissingGlyphWarning -Handle $effHandle -Text ([string]$spec['Text']) -CommandName 'Add-VellumPdfTable'

                if ($null -ne $spec['Leading']) {
                    $lead = $spec['Leading'] -as [double]
                    if ($null -eq $lead -or -not [double]::IsFinite($lead) -or $lead -lt 0 -or $lead -gt 1000) {
                        throw "Add-VellumPdfTable: rich-cell Leading must be between 0 and 1000; got '$($spec['Leading'])'."
                    }
                }

                if ($spec['Font'] -or $null -ne $spec['FontSize'] -or $spec['Color'] -or $cellHandle -or $null -ne $spec['Leading']) {
                    if ($spec['Font'] -and [string]$spec['Font'] -notin $fontNames) {
                        throw ("Add-VellumPdfTable: rich-cell Font '$($spec['Font'])' is not a base-14 font name. " +
                            "Valid names: $($fontNames -join ', ').")
                    }
                    if ($null -ne $spec['FontSize']) {
                        $size = $spec['FontSize'] -as [double]
                        if ($null -eq $size -or -not [double]::IsFinite($size) -or $size -lt 1 -or $size -gt 1000) {
                            throw "Add-VellumPdfTable: rich-cell FontSize must be between 1 and 1000; got '$($spec['FontSize'])'."
                        }
                    }
                    # Fill the font/size gap from the table's effective default so a
                    # Colour-only cell keeps the table font (base-14 or embedded)
                    # instead of falling back to the library-global Helvetica.
                    $cellStyle = @{
                        FontSize = if ($null -ne $spec['FontSize']) { [double]$spec['FontSize'] } else { $effSize }
                    }
                    if ($effHandle -and -not $spec['Font']) { $cellStyle['FontHandle'] = $effHandle }
                    else { $cellStyle['Font'] = if ($spec['Font']) { [string]$spec['Font'] } else { $effFont } }
                    if ($spec['Color']) { $cellStyle['Color'] = ConvertTo-VellumColor $spec['Color'] -Document $Document -CommandName 'Add-VellumPdfTable' }
                    if ($null -ne $spec['Leading']) { $cellStyle['Leading'] = [double]$spec['Leading'] }
                    $cell.Style = New-VellumTextStyle @cellStyle -Document $Document -CommandName 'Add-VellumPdfTable'
                }

                if ($null -ne $spec['Padding']) {
                    $cell.Padding = ConvertTo-VellumInsets -Value $spec['Padding'] -What 'Add-VellumPdfTable: rich-cell Padding'
                }
                elseif ($tablePadding) {
                    $cell.Padding = $tablePadding
                }
                if ($spec['Language']) { Assert-VellumPdfLanguageTag -Value ([string]$spec['Language']) -CommandName 'Add-VellumPdfTable' -Name 'Language (cell)'; $cell.Language = [string]$spec['Language'] }
                $cell
            }

            # Apply column widths.
            # Spans: a cell advances the grid column by its ColSpan, and a RowSpan reserves its columns
            # in the rows below, so -ColumnAlignment and the -ColumnWidth count follow the grid, not the cell count.
            $spanOf = {
                param($cellSpec, $key)
                if ($cellSpec -is [System.Collections.IDictionary] -and $null -ne $cellSpec[$key]) { [Math]::Max(1, [int]$cellSpec[$key]) } else { 1 }
            }
            $gridTaken = @{}
            $gridState = @{ Row = 0 }
            $placeRow = {
                param($rowSpecs)
                $column = 0
                $placed = foreach ($cellSpec in $rowSpecs) {
                    while ($gridTaken.ContainsKey("$($gridState.Row),$column")) { $column++ }
                    $column
                    $colSpan = & $spanOf $cellSpec 'ColSpan'
                    $rowSpan = & $spanOf $cellSpec 'RowSpan'
                    for ($dr = 0; $dr -lt $rowSpan; $dr++) { for ($dc = 0; $dc -lt $colSpan; $dc++) { $gridTaken["$($gridState.Row + $dr),$($column + $dc)"] = $true } }
                    $column += $colSpan
                }
                $gridState.Row++
                , @($placed)
            }
            if ($ColumnWidth) {
                $firstRow = if ($headerRowSpecs.Count) { $headerRowSpecs[0] } elseif ($specRows.Count) { $specRows[0] } else { @() }
                $columnCount = 0
                foreach ($cellSpec in $firstRow) { $columnCount += (& $spanOf $cellSpec 'ColSpan') }
                if ($ColumnWidth.Count -ne $columnCount) {
                    Write-Warning ("Add-VellumPdfTable: -ColumnWidth has $($ColumnWidth.Count) value(s) " +
                        "but the table has $columnCount column(s); extra widths are ignored and " +
                        'missing ones fall back to the library default.')
                }
                [void]$table.SetColumnWidths($ColumnWidth)
            }

            # Add optional header row.
            foreach ($specsOfRow in $headerRowSpecs) {
                # The engine cannot lay out a table made only of header rows, so a header-only table draws its
                # header as ordinary rows (same look and background, but not marked as header cells).
                $headerRow = if ($specRows.Count -eq 0) { $table.AddRow($false) } else { $table.AddHeaderRow() }
                if ($headerBg) { $headerRow.Background = $headerBg }
                $gridColumns = & $placeRow $specsOfRow
                $hi = 0
                foreach ($headerSpec in $specsOfRow) {
                    [void]$headerRow.AddCell((& $buildCell $headerSpec $gridColumns[$hi]))
                    $hi++
                }
            }

            # Add data rows, applying zebra striping to every second row.
            $rowIndex = 0
            foreach ($specRow in $specRows) {
                $tableRow = $table.AddRow($false)
                if ($altBg -and ($rowIndex % 2 -eq 1)) { $tableRow.Background = $altBg }
                $gridColumns = & $placeRow $specRow
                $colIndex = 0
                foreach ($spec in $specRow) {
                    [void]$tableRow.AddCell((& $buildCell $spec $gridColumns[$colIndex]))
                    $colIndex++
                }
                $rowIndex++
            }

            Set-VellumPdfElementMargin -Element $table -Top $MarginTop -Bottom $MarginBottom `
                -BoundParameters $PSBoundParameters -Document $Document -DeferBottom

            [void]$Document.Add($table)
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
