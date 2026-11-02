function Add-VellumPdfPageTable {
    <#
    .SYNOPSIS
        Draws a table at x/y on a page of a page-based document, tagged as a real table in accessible PDFs.
    .DESCRIPTION
        The page-document counterpart of Add-VellumPdfTable: a grid whose cell text wraps inside its
        column, with column and row spans, backgrounds and borders. Because a page document has no
        flow, you give the position (-X and -Y, the top-left corner in points from the page's
        bottom-left) and the column widths yourself, and the table must fit on the page: one that is
        too tall is an error rather than being split.

        Rows are arrays of cells. A cell is text, or a hashtable with Text and optionally ColSpan,
        RowSpan, Alignment (Left, Center, Right, Justify), Background (colour) and Color (text colour):

            -Row @(
                @('Widget', '2', '10.00'),
                @(@{ Text = 'Shipping'; ColSpan = 2 }, '5.00')
            )

        A single row is written @(,@('a','b')). -Header takes one row of cells (-Header 'Item','Qty')
        or several (an array of arrays).

        In a tagged page document (PDF/UA-1, PDF/A-2a, -Tagged) the table is a Table element with TR rows
        and TH/TD cells: header cells carry Scope Column (with -RowHeader, the first cell of every body
        row is a TH with Scope Row), and ColSpan and RowSpan are written on the cells. The grid lines and
        backgrounds are artifacts. In an untagged document it is only drawing.

        Header text uses the bold variant of -Font (Helvetica, Times and Courier), or -HeaderFont.
        Use a base-14 font by name (-Font) or an embedded TrueType font (-FontHandle from
        Register-VellumPdfFont); PDF/A and PDF/UA documents embed base-14 text automatically.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Row
        The body rows: an array of rows, each an array of cells.
    .PARAMETER Header
        The header row (an array of cells) or rows (an array of arrays).
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER X
        Left edge of the table in points.
    .PARAMETER Y
        Top edge of the table in points from the bottom of the page.
    .PARAMETER Width
        Total table width; the columns share it equally. Give this or -ColumnWidth.
    .PARAMETER ColumnWidth
        One width per grid column, in points. Give this or -Width.
    .PARAMETER ColumnAlignment
        Left, Center, Right or Justify per grid column. A cell's own Alignment wins.
    .PARAMETER FontSize
        Size in points (default 10).
    .PARAMETER Font
        A base-14 font name (default Helvetica).
    .PARAMETER HeaderFont
        A base-14 font for header cells (default: the bold variant of -Font).
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont. Overrides -Font and -HeaderFont.
    .PARAMETER Color
        Text colour: RGB triple in 0..1, hex or name. Default black.
    .PARAMETER Leading
        Distance between baselines in points. Default 1.2 times -FontSize.
    .PARAMETER Padding
        Space between a cell's border and its text, in points (default 4).
    .PARAMETER BorderWidth
        Grid line width in points (default 0.5); 0 draws no lines.
    .PARAMETER BorderColor
        Grid line colour (default black).
    .PARAMETER HeaderBackground
        Background colour of the header rows.
    .PARAMETER AlternateRowBackground
        Background colour of every second body row.
    .PARAMETER RowHeader
        Make the first cell of every body row a row header (TH, Scope Row).
    .PARAMETER Language
        BCP 47 language tag of the table text, written on the Table element.
    .PARAMETER PassThru
        Return an object with Document, Height, Bottom (the y of the table's lower edge), Rows and
        Columns instead of the document.
    .EXAMPLE
        $doc | Add-VellumPdfPageTable -X 72 -Y 700 -Width 450 -Header 'Item', 'Qty', 'Price' `
            -ColumnAlignment Left, Right, Right -HeaderBackground '#e8f0fe' -Row @(
                @('Widget', '2', '10.00'),
                @('Gadget', '1', '24.50'),
                @(@{ Text = 'Total'; ColSpan = 2 }, '44.50'))
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining), or with -PassThru a summary object.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Width')]
    [OutputType([VellumPdf.Document.PdfDocument], [pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$Row,

        [object[]]$Header,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,

        [Parameter(Mandatory, ParameterSetName = 'Width')]
        [ValidateRange(1.0, 1000000.0)]
        [double]$Width,

        [Parameter(Mandatory, ParameterSetName = 'ColumnWidth')]
        [ValidateRange(0.5, 1000000.0)]
        [double[]]$ColumnWidth,

        [ValidateSet('Left', 'Center', 'Right', 'Justify')]
        [string[]]$ColumnAlignment,

        [ValidateRange(1.0, 1000.0)]
        [double]$FontSize = 10,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font = 'Helvetica',

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$HeaderFont,

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [object]$Color,

        [ValidateRange(0.1, 10000.0)]
        [double]$Leading,

        [ValidateRange(0.0, 1000.0)]
        [double]$Padding = 4,

        [ValidateRange(0.0, 100.0)]
        [double]$BorderWidth = 0.5,

        [object]$BorderColor,
        [object]$HeaderBackground,
        [object]$AlternateRowBackground,

        [switch]$RowHeader,

        [ValidateNotNullOrEmpty()]
        [string]$Language,

        [switch]$PassThru
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPageTable'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $(if ($PSBoundParameters.ContainsKey('Page')) { $PSBoundParameters['Page'] } else { 1 }) -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfPageTable'
            [void](Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageTable')
            Assert-VellumPdfLanguageTag -Value $Language -CommandName 'Add-VellumPdfPageTable'
            if (-not $FontHandle) {
                Assert-VellumPdfMeasurableFont -Font $Font -CommandName 'Add-VellumPdfPageTable' -Reason 'it wraps cell text'
                if ($HeaderFont) { Assert-VellumPdfMeasurableFont -Font $HeaderFont -CommandName 'Add-VellumPdfPageTable' -Reason 'it wraps cell text' }
            }
            Assert-VellumPdfCoordinate $X 'X' 'Add-VellumPdfPageTable'
            Assert-VellumPdfCoordinate $Y 'Y' 'Add-VellumPdfPageTable'
            $bound = $PSBoundParameters
            if (-not $bound.ContainsKey('Leading')) { $Leading = 1.2 * $FontSize }

            # --- cells: normalise rows, place them on the grid -------------------------------------------
            # -Header is one row of cells (strings, maps, numbers) or several rows (an array of arrays).
            $headerRows = @()
            if ($bound.ContainsKey('Header')) {
                $headerList = @($Header)
                $oneRow = $headerList.Count -gt 0 -and ($headerList[0] -is [string] -or $headerList[0] -is [System.Collections.IDictionary] -or $headerList[0] -is [ValueType])
                if ($oneRow) { $headerRows = @(, $headerList) } else { $headerRows = $headerList }
            }
            $bodyRows = @($Row)
            $cellOf = {
                param($spec)
                $isMap = $spec -is [System.Collections.IDictionary]
                if (-not $isMap -and $spec -isnot [string] -and $spec -isnot [ValueType] -and $null -ne $spec) {
                    throw ("Add-VellumPdfPageTable: a cell must be text or a hashtable with a Text key, not $($spec.GetType().Name). " +
                        'Rows are arrays of cells; a single row is written -Row @(,@(''a'', ''b'')) and records are not supported (use Add-VellumPdfTable for objects).')
                }
                if ($isMap -and -not $spec.Contains('Text')) { throw 'Add-VellumPdfPageTable: a cell hashtable needs a Text key (rows are arrays of cells, not records).' }
                $text = if ($isMap) { [string](Get-VellumPdfPropertyValue -InputObject $spec -Name 'Text') } else { [string]$spec }
                Assert-VellumPdfValidText -Text $text -CommandName 'Add-VellumPdfPageTable'
                $span = {
                    param($key)
                    $v = if ($isMap) { Get-VellumPdfPropertyValue -InputObject $spec -Name $key }
                    if ($null -eq $v) { 1 }
                    else {
                        $d = $v -as [double]
                        if ($null -eq $d -or $d -ne [Math]::Floor($d) -or $d -lt 1 -or $d -gt 1000) { throw "Add-VellumPdfPageTable: cell $key must be a whole number from 1 to 1000; got '$v'." }
                        [int]$d
                    }
                }
                $align = if ($isMap) { Get-VellumPdfPropertyValue -InputObject $spec -Name 'Alignment' }
                if ($align -and [string]$align -notin 'Left', 'Center', 'Right', 'Justify') { throw "Add-VellumPdfPageTable: cell Alignment '$align' is invalid; use Left, Center, Right or Justify." }
                [pscustomobject]@{
                    Text = $text; ColSpan = (& $span 'ColSpan'); RowSpan = (& $span 'RowSpan'); Align = [string]$align
                    # Colours are resolved here, before anything is drawn, so a bad value cannot leave half a table behind.
                    Background = $(if ($isMap -and $null -ne (Get-VellumPdfPropertyValue -InputObject $spec -Name 'Background')) { ConvertTo-VellumColor (Get-VellumPdfPropertyValue -InputObject $spec -Name 'Background') })
                    Color = $(if ($isMap -and $null -ne (Get-VellumPdfPropertyValue -InputObject $spec -Name 'Color')) { ConvertTo-VellumColor (Get-VellumPdfPropertyValue -InputObject $spec -Name 'Color') })
                    Row = 0; Col = 0; IsHeader = $false; Scope = $null; Lines = $null; Height = 0.0
                }
            }
            $cells = [System.Collections.Generic.List[object]]::new()
            $taken = @{}
            $rowIndex = 0
            $rowKinds = [System.Collections.Generic.List[string]]::new()
            foreach ($kind in 'Header', 'Body') {
                # Plain assignments: an if-expression would unroll a one-row array into its cells.
                if ($kind -eq 'Header') { $source = $headerRows } else { $source = $bodyRows }
                $bodyIndex = 0
                foreach ($specRow in $source) {
                    $column = 0
                    foreach ($spec in @($specRow)) {
                        while ($taken.ContainsKey("$rowIndex,$column")) { $column++ }
                        $cell = & $cellOf $spec
                        $cell.Row = $rowIndex; $cell.Col = $column
                        $isRowHeader = $RowHeader -and $column -eq 0 -and $kind -eq 'Body'
                        $cell.IsHeader = ($kind -eq 'Header') -or $isRowHeader
                        $cell.Scope = if ($kind -eq 'Header') { 'Column' } elseif ($isRowHeader) { 'Row' }
                        for ($dr = 0; $dr -lt $cell.RowSpan; $dr++) { for ($dc = 0; $dc -lt $cell.ColSpan; $dc++) { $taken["$($rowIndex + $dr),$($column + $dc)"] = $true } }
                        $column += $cell.ColSpan
                        $cells.Add($cell)
                    }
                    $rowKinds.Add($(if ($kind -eq 'Header') { 'Header' } elseif ($bodyIndex % 2 -eq 1) { 'Alternate' } else { 'Body' }))
                    $rowIndex++
                    $bodyIndex++
                }
            }
            $rowCount = $rowIndex
            if ($cells.Count -eq 0) { throw 'Add-VellumPdfPageTable: the table has no cells.' }
            $columnCount = ($cells | ForEach-Object { $_.Col + $_.ColSpan } | Measure-Object -Maximum).Maximum
            $lastRowUsed = ($cells | ForEach-Object { $_.Row + $_.RowSpan } | Measure-Object -Maximum).Maximum
            if ($lastRowUsed -gt $rowCount) { throw "Add-VellumPdfPageTable: a RowSpan runs past the last row (the table has $rowCount row(s))." }

            # A row that does not fill every grid column makes a table PDF/UA validators reject (7.2-41/42/43).
            $irregular = @(0..($rowCount - 1) | Where-Object {
                    $r = $_
                    @(0..($columnCount - 1) | Where-Object { $taken.ContainsKey("$r,$_") }).Count -ne $columnCount
                })
            if ($irregular.Count -gt 0) {
                Write-Warning ("Add-VellumPdfPageTable: row(s) $((@($irregular | ForEach-Object { $_ + 1 })) -join ', ') do not fill all $columnCount grid columns " +
                    '(cells, ColSpan and RowSpan do not add up); a tagged table like this fails PDF/UA validation.')
            }
            $cellsByRow = @{}
            foreach ($cell in $cells) {
                if (-not $cellsByRow.ContainsKey($cell.Row)) { $cellsByRow[$cell.Row] = [System.Collections.Generic.List[object]]::new() }
                $cellsByRow[$cell.Row].Add($cell)
            }

            if ($PSCmdlet.ParameterSetName -eq 'ColumnWidth') {
                if ($ColumnWidth.Count -ne $columnCount) { throw "Add-VellumPdfPageTable: -ColumnWidth has $($ColumnWidth.Count) value(s) but the table has $columnCount column(s)." }
                $widths = $ColumnWidth
            }
            else { $widths = [double[]]@(1..$columnCount | ForEach-Object { $Width / $columnCount }) }
            foreach ($w in $widths) { Assert-VellumPdfCoordinate $w 'ColumnWidth' 'Add-VellumPdfPageTable' }
            $tableWidth = ($widths | Measure-Object -Sum).Sum
            Assert-VellumPdfCoordinate $tableWidth 'Width' 'Add-VellumPdfPageTable'

            # --- fonts, wrapping, row heights --------------------------------------------------------------
            $body = Get-VellumPdfPageFont -Document $Document -FontHandle $FontHandle -Font $Font -CommandName 'Add-VellumPdfPageTable'
            $headerName = if ($HeaderFont) { $HeaderFont } else { @{ Helvetica = 'HelveticaBold'; TimesRoman = 'TimesBold'; Courier = 'CourierBold' }[$Font] ?? $Font }
            $head = if ($FontHandle) { $body } else { Get-VellumPdfPageFont -Document $Document -Font $headerName -CommandName 'Add-VellumPdfPageTable' }
            $allText = @($cells | ForEach-Object { $_.Text })
            Write-VellumPdfMissingGlyphWarning -Handle $body.Handle -Text $allText -CommandName 'Add-VellumPdfPageTable'
            if (-not $body.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None) {
                Write-VellumPdfEncodingWarning -Text $allText -CommandName 'Add-VellumPdfPageTable'
            }
            $rowHeights = [double[]]::new($rowCount)
            for ($r = 0; $r -lt $rowCount; $r++) { $rowHeights[$r] = $Leading + 2 * $Padding }
            foreach ($cell in $cells) {
                $span = 0.0
                for ($c = $cell.Col; $c -lt $cell.Col + $cell.ColSpan; $c++) { $span += $widths[$c] }
                $cellResolved = if ($cell.IsHeader -and $cell.Scope -eq 'Column') { $head } else { $body }
                $inner = [Math]::Max(1.0, $span - 2 * $Padding)
                $cell.Lines = Split-VellumPdfTextLine -Text $cell.Text -Width $inner -Resolved $cellResolved -FontSize $FontSize
                $cell.Height = $cell.Lines.Count * $Leading + 2 * $Padding
                if ($cell.RowSpan -eq 1 -and $cell.Height -gt $rowHeights[$cell.Row]) { $rowHeights[$cell.Row] = $cell.Height }
            }
            foreach ($cell in ($cells | Where-Object { $_.RowSpan -gt 1 })) {
                $have = 0.0
                for ($r = $cell.Row; $r -lt $cell.Row + $cell.RowSpan; $r++) { $have += $rowHeights[$r] }
                if ($cell.Height -gt $have) { $rowHeights[$cell.Row + $cell.RowSpan - 1] += $cell.Height - $have }
            }
            $tableHeight = ($rowHeights | Measure-Object -Sum).Sum
            $pdfPage = $Document.Pages[$Page - 1]
            if ($Y - $tableHeight -lt $pdfPage.MediaBox.LlY) {
                throw ("Add-VellumPdfPageTable: the table is $([math]::Round($tableHeight, 1)) pt tall but only " +
                    "$([math]::Round($Y - $pdfPage.MediaBox.LlY, 1)) pt are left below -Y on page $Page. Page tables are not split across pages.")
            }
            $rowTop = [double[]]::new($rowCount + 1)
            $rowTop[0] = $Y
            for ($r = 0; $r -lt $rowCount; $r++) { $rowTop[$r + 1] = $rowTop[$r] - $rowHeights[$r] }
            $colLeft = [double[]]::new($columnCount + 1)
            $colLeft[0] = $X
            for ($c = 0; $c -lt $columnCount; $c++) { $colLeft[$c + 1] = $colLeft[$c] + $widths[$c] }

            # --- drawing -------------------------------------------------------------------------------------
            $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageTable'
            if ($body.Handle) { $Document.RegisterEmbeddedFontUsage($pdfPage, $body.Handle) }
            if ($head.Handle -and $head.Handle -ne $body.Handle) { $Document.RegisterEmbeddedFontUsage($pdfPage, $head.Handle) }
            # Colour operators are written only for colours that were asked for: a default RGB operator would
            # fail PDF/A with a CMYK output intent.
            $textRgb = if ($bound.ContainsKey('Color')) { ConvertTo-VellumColor $Color }
            $borderRgb = if ($bound.ContainsKey('BorderColor')) { ConvertTo-VellumColor $BorderColor }
            $headerBg = if ($bound.ContainsKey('HeaderBackground')) { ConvertTo-VellumColor $HeaderBackground }
            $altBg = if ($bound.ContainsKey('AlternateRowBackground')) { ConvertTo-VellumColor $AlternateRowBackground }

            [void]$canvas.SaveState()
            try {
                # Backgrounds and grid lines are decoration: artifacts in a tagged document.
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Artifact -Draw {
                    for ($r = 0; $r -lt $rowCount; $r++) {
                        $fill = if ($rowKinds[$r] -eq 'Header') { $headerBg } elseif ($rowKinds[$r] -eq 'Alternate') { $altBg }
                        if ($fill) {
                            [void]$canvas.SaveState().SetFillColorRgb($fill[0], $fill[1], $fill[2]).Rectangle($X, $rowTop[$r + 1], $tableWidth, $rowHeights[$r]).Fill().RestoreState()
                        }
                    }
                    foreach ($cell in $cells) {
                        if ($null -eq $cell.Background) { continue }
                        $bg = $cell.Background
                        $bottom = $rowTop[$cell.Row + $cell.RowSpan]
                        [void]$canvas.SaveState().SetFillColorRgb($bg[0], $bg[1], $bg[2]).Rectangle($colLeft[$cell.Col], $bottom, $colLeft[$cell.Col + $cell.ColSpan] - $colLeft[$cell.Col], $rowTop[$cell.Row] - $bottom).Fill().RestoreState()
                    }
                    if ($BorderWidth -gt 0) {
                        [void]$canvas.SaveState().SetLineWidth($BorderWidth)
                        if ($borderRgb) { [void]$canvas.SetStrokeColorRgb($borderRgb[0], $borderRgb[1], $borderRgb[2]) }
                        foreach ($cell in $cells) {
                            $bottom = $rowTop[$cell.Row + $cell.RowSpan]
                            [void]$canvas.Rectangle($colLeft[$cell.Col], $bottom, $colLeft[$cell.Col + $cell.ColSpan] - $colLeft[$cell.Col], $rowTop[$cell.Row] - $bottom).Stroke()
                        }
                        [void]$canvas.RestoreState()
                    }
                }

                # Text: Table > TR > TH/TD in a tagged document.
                $table = $null
                if ($Document.Tagged) {
                    $table = [VellumPdf.Document.PdfStructElem]::new('Table')
                    if ($Language) { $table.Language = $Language }
                    Push-VellumPdfStructParent -Document $Document -Element $table
                }
                try {
                    for ($r = 0; $r -lt $rowCount; $r++) {
                        $tableRow = $null
                        if ($Document.Tagged) {
                            $tableRow = [VellumPdf.Document.PdfStructElem]::new('TR')
                            [void]$table.AddChild($tableRow)
                            Push-VellumPdfStructParent -Document $Document -Element $tableRow
                        }
                        try {
                            foreach ($cell in @($cellsByRow[$r])) {
                                $structType = if ($cell.IsHeader) { 'TH' } else { 'TD' }
                                $configure = {
                                    param($element)
                                    if ($cell.Scope) { $element.TableHeaderScope = $cell.Scope }
                                    if ($cell.RowSpan -gt 1) { $element.TableRowSpan = $cell.RowSpan }
                                    if ($cell.ColSpan -gt 1) { $element.TableColSpan = $cell.ColSpan }
                                }.GetNewClosure()
                                $cellResolved = if ($cell.IsHeader -and $cell.Scope -eq 'Column') { $head } else { $body }
                                $alignment = if ($cell.Align) { $cell.Align } elseif ($ColumnAlignment -and $cell.Col -lt $ColumnAlignment.Count) { $ColumnAlignment[$cell.Col] } else { 'Left' }
                                $rgb = if ($null -ne $cell.Color) { $cell.Color } else { $textRgb }
                                $cellLeft = $colLeft[$cell.Col] + $Padding
                                $cellWidth = $colLeft[$cell.Col + $cell.ColSpan] - $colLeft[$cell.Col] - 2 * $Padding
                                $cellTop = $rowTop[$cell.Row] - $Padding
                                $cellLines = $cell.Lines
                                $cellFont = $cellResolved
                                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType $structType -Configure $configure -Draw {
                                    [void]$canvas.SaveState()
                                    try {
                                        if ($rgb) { [void]$canvas.SetFillColorRgb($rgb[0], $rgb[1], $rgb[2]) }
                                        $hasText = [bool]($cellLines | Where-Object { $_.Words.Count -gt 0 })
                                        if ($hasText) {
                                            Write-VellumPdfTextLine -Canvas $canvas -Resolved $cellFont -FontSize $FontSize -Lines $cellLines -X $cellLeft -Top $cellTop -Width $cellWidth -Leading $Leading -Align $alignment
                                        }
                                    }
                                    finally { [void]$canvas.RestoreState() }
                                }
                            }
                        }
                        finally { if ($Document.Tagged) { Pop-VellumPdfStructParent -Document $Document } }
                    }
                }
                finally {
                    # Even a table that failed half way is registered: the cells already drawn own MCIDs.
                    if ($Document.Tagged) { Pop-VellumPdfStructParent -Document $Document; Add-VellumPdfStructElement -Document $Document -Element $table }
                }
            }
            finally { [void]$canvas.RestoreState() }

            if ($PassThru) {
                [pscustomobject]@{ Document = $Document; Height = $tableHeight; Bottom = $Y - $tableHeight; Rows = $rowCount; Columns = $columnCount }
            }
            else { $Document }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
