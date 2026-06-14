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
                 FontHandle = $handle; Color = 'navy';
                 Padding = @(4, 8, 4, 8); Language = 'en-US' }
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
        An optional array of column header labels. Each element is either a
        plain string or a rich-cell hashtable (the same keys accepted by data
        cells: Text, Background, Alignment, Font, FontHandle, FontSize, Color,
        Padding, Language, ColSpan). When supplied, a styled header row is
        prepended to the table via AddHeaderRow(). The count of header cells
        determines the expected column count for -ColumnWidth mismatch warnings.
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
        cells. Mutually exclusive with -FontHandle. When omitted the document
        default font is used.
    .PARAMETER FontSize
        Font size in points for all data cells, between 1 and 1000. When
        omitted the document default size is used.
    .PARAMETER FontHandle
        An EmbeddedFontHandle returned by Register-VellumPdfFont for this
        document. When supplied the table uses the embedded TrueType font as its
        default cell style, enabling Unicode text and PDF/A conformance. Handles
        from a different document are rejected. Mutually exclusive with -Font.
    .PARAMETER Alignment
        Horizontal text alignment for all cells (header and data). Accepts
        Left, Center, Right, or Justify. Defaults to Left.
    .PARAMETER CellPadding
        Default padding applied to every cell in the table, as either a single
        uniform value (in points) or a four-element array in the order
        top, right, bottom, left. Each value must be a non-negative number. A
        cell's own Padding key overrides this per-cell.
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
    .EXAMPLE
        # Embedded font table with rich header cells and per-cell padding.
        $handle = Register-VellumPdfFont -Document $doc -Path ./fonts/DejaVuSans.ttf
        $richHeaders = @(
            @{ Text = 'Name';  Background = '#336699'; Color = 'white'; FontHandle = $handle },
            @{ Text = 'Score'; Background = '#336699'; Color = 'white'; FontHandle = $handle }
        )
        $rows = @(
            @('Alice', '95'),
            @('Bob',   '82')
        )
        New-VellumPdfDocument |
            Add-VellumPdfTable -Header $richHeaders -Row $rows `
                -FontHandle $handle -CellPadding @(4, 8, 4, 8) |
            Save-VellumPdfDocument -Path ./report.pdf
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        [object[]]$Header,

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

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string]$Alignment = 'Left',

        # Default cell padding: a single uniform value or four values in the
        # order top, right, bottom, left. Each must be a non-negative number.
        [double[]]$CellPadding,

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfTable'

        # -Font and -FontHandle are mutually exclusive.
        if ($Font -and $FontHandle) {
            throw 'Add-VellumPdfTable: -Font and -FontHandle are mutually exclusive; supply only one.'
        }

        if ($FontHandle) {
            Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfTable'
        }

        # Validate -CellPadding element count: must be 1 (uniform) or 4 (top/right/bottom/left).
        if ($PSBoundParameters.ContainsKey('CellPadding')) {
            if ($CellPadding.Count -ne 1 -and $CellPadding.Count -ne 4) {
                throw ("Add-VellumPdfTable: -CellPadding must have 1 value (uniform) or 4 values " +
                    "(top, right, bottom, left); got $($CellPadding.Count).")
            }
            foreach ($pv in $CellPadding) {
                if ($pv -lt 0) {
                    throw "Add-VellumPdfTable: -CellPadding values must be non-negative; got '$pv'."
                }
            }
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

        # Build the rows as arrays of cell specs, and the effective header labels.
        $headerSpecs = $null
        if ($Header) {
            $headerSpecs = @(foreach ($h in $Header) { & $toSpec $h })
        }
        $specRows = [System.Collections.Generic.List[object]]::new()
        if ($recordMode) {
            $columns = if ($Row[0] -is [System.Collections.IDictionary]) {
                @($Row[0].Keys)
            }
            else {
                @($Row[0].PSObject.Properties.Name)
            }
            if (-not $headerSpecs) {
                $headerSpecs = @(foreach ($col in $columns) { @{ Text = [string]$col } })
            }
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
        $headerTexts = if ($headerSpecs) { @($headerSpecs | ForEach-Object { [string]$_['Text'] }) } else { @() }
        $cellText = $headerTexts + @($specRows | ForEach-Object { $_ | ForEach-Object { [string]$_['Text'] } })
        Write-VellumPdfEncodingWarning -Text $cellText -CommandName 'Add-VellumPdfTable'

        $table = [VellumPdf.Layout.Elements.Table.TableElement]::new()

        # Effective table font/size: the -Font/-FontHandle/-FontSize overrides,
        # else the document defaults. A TextStyle without a font renders in the
        # library-global Helvetica, so these fill the gap for the default cell
        # style AND for rich cells that set only Colour (see $buildCell).
        $default = Resolve-VellumPdfDefault -Document $Document
        $effFont = if ($Font) { $Font } else { $default.Font }
        $effSize = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { $default.FontSize }
        if ($FontHandle) {
            $table.DefaultCellStyle = New-VellumTextStyle -FontHandle $FontHandle -FontSize $effSize
        } elseif ([bool]$Font -or $PSBoundParameters.ContainsKey('FontSize')) {
            $table.DefaultCellStyle = New-VellumTextStyle -Font $effFont -FontSize $effSize
        }

        # Build the table-level default EdgeInsets for -CellPadding, if supplied.
        $tableCellPadding = $null
        if ($PSBoundParameters.ContainsKey('CellPadding')) {
            if ($CellPadding.Count -eq 1) {
                $tableCellPadding = [VellumPdf.Layout.Core.EdgeInsets]::new($CellPadding[0])
            } else {
                $tableCellPadding = [VellumPdf.Layout.Core.EdgeInsets]::new(
                    $CellPadding[0], $CellPadding[1], $CellPadding[2], $CellPadding[3])
            }
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
            $c = ConvertTo-VellumColor $value
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
                    $span = $spec[$spanKey] -as [int]
                    if ($null -eq $span -or $span -lt 1) {
                        throw "Add-VellumPdfTable: rich-cell $spanKey must be a positive integer; got '$($spec[$spanKey])'."
                    }
                    $cell.$spanKey = $span
                }
            }

            if ($spec['Background']) { $cell.Background = & $toRgb $spec['Background'] }

            # Validate and apply cell-level Padding.
            if ($null -ne $spec['Padding']) {
                $padArr = @($spec['Padding'])
                if ($padArr.Count -ne 1 -and $padArr.Count -ne 4) {
                    throw ("Add-VellumPdfTable: rich-cell Padding must have 1 value (uniform) or 4 values " +
                        "(top, right, bottom, left); got $($padArr.Count).")
                }
                foreach ($pv in $padArr) {
                    $pn = $pv -as [double]
                    if ($null -eq $pn -or $pn -lt 0) {
                        throw "Add-VellumPdfTable: rich-cell Padding values must be non-negative numbers; got '$pv'."
                    }
                }
                $cell.Padding = if ($padArr.Count -eq 1) {
                    [VellumPdf.Layout.Core.EdgeInsets]::new([double]$padArr[0])
                } else {
                    [VellumPdf.Layout.Core.EdgeInsets]::new(
                        [double]$padArr[0], [double]$padArr[1], [double]$padArr[2], [double]$padArr[3])
                }
            } elseif ($null -ne $tableCellPadding) {
                # Apply table-level default padding when the cell has none of its own.
                $cell.Padding = $tableCellPadding
            }

            # Apply cell-level Language (BCP-47 tag, e.g. 'en-US').
            if ($spec['Language']) {
                $cell.Language = [string]$spec['Language']
            }

            # Determine which font source the cell needs. Priority:
            #   1. Cell's own FontHandle key.
            #   2. Cell's own Font key (base-14).
            #   3. Neither: fall through to the gap-fill logic below.
            $cellFontHandle = $spec['FontHandle']
            $cellFont       = $spec['Font']

            if ($cellFontHandle -or $cellFont -or $null -ne $spec['FontSize'] -or $spec['Color']) {
                # Validate cell FontHandle ownership.
                if ($cellFontHandle) {
                    Assert-VellumPdfFontHandle -FontHandle $cellFontHandle -Document $Document `
                        -CommandName 'Add-VellumPdfTable'
                }

                # Validate cell Font name.
                if ($cellFont -and [string]$cellFont -notin $fontNames) {
                    throw ("Add-VellumPdfTable: rich-cell Font '$($spec['Font'])' is not a base-14 font name. " +
                        "Valid names: $($fontNames -join ', ').")
                }

                # Validate FontSize.
                if ($null -ne $spec['FontSize']) {
                    $size = $spec['FontSize'] -as [double]
                    if ($null -eq $size -or $size -lt 1 -or $size -gt 1000) {
                        throw "Add-VellumPdfTable: rich-cell FontSize must be between 1 and 1000; got '$($spec['FontSize'])'."
                    }
                }

                $cellStyleParams = @{ FontSize = if ($null -ne $spec['FontSize']) { [double]$spec['FontSize'] } else { $effSize } }

                if ($cellFontHandle) {
                    # Cell has its own embedded handle; use it.
                    $cellStyleParams['FontHandle'] = $cellFontHandle
                } elseif ($cellFont) {
                    # Cell has an explicit base-14 font.
                    $cellStyleParams['Font'] = [string]$cellFont
                } elseif ($FontHandle) {
                    # Table has an embedded handle and the cell does not override the
                    # font; inherit the handle so a Colour-only or FontSize-only cell
                    # in an embedded-font table keeps the embedded font instead of
                    # falling back to the library-global Helvetica.
                    $cellStyleParams['FontHandle'] = $FontHandle
                } else {
                    # Fill from the table's effective base-14 font default.
                    $cellStyleParams['Font'] = $effFont
                }

                if ($spec['Color']) { $cellStyleParams['Color'] = ConvertTo-VellumColor $spec['Color'] }
                $cell.Style = New-VellumTextStyle @cellStyleParams
            }
            $cell
        }

        # Apply column widths.
        if ($ColumnWidth) {
            $columnCount = if ($headerSpecs) { $headerSpecs.Count } elseif ($specRows.Count) { $specRows[0].Count } else { 0 }
            if ($ColumnWidth.Count -ne $columnCount) {
                Write-Warning ("Add-VellumPdfTable: -ColumnWidth has $($ColumnWidth.Count) value(s) " +
                    "but the table has $columnCount column(s); extra widths are ignored and " +
                    'missing ones fall back to the library default.')
            }
            [void]$table.SetColumnWidths($ColumnWidth)
        }

        # Add optional header row. Each element of $headerSpecs is already a
        # spec hashtable (plain strings were converted by $toSpec above), so the
        # same $buildCell path used for data cells applies here.
        if ($headerSpecs) {
            $headerRow = $table.AddHeaderRow()
            if ($headerBg) { $headerRow.Background = $headerBg }
            $hi = 0
            foreach ($spec in $headerSpecs) {
                [void]$headerRow.AddCell((& $buildCell $spec $hi))
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
