function Add-VellumPdfPageList {
    <#
    .SYNOPSIS
        Draws a bulleted or numbered list at x/y on a page of a page-based document, tagged as a real list.
    .DESCRIPTION
        The page-document counterpart of Add-VellumPdfList: each item is a marker (a bullet, or 1. 2. 3.
        with -Numbered) followed by text that wraps inside -Width and hangs under itself. -X is the left
        edge and -Y the top of the list in points from the page's bottom-left. A list that does not fit
        above the bottom of the page is an error.

        An item is text, or a hashtable (or object) with Text and optionally Children (one more level of
        items). An item without Text is an error; a missing or $null Children means no children:

            -Item 'First', @{ Text = 'Second'; Children = 'Second A', 'Second B' }, 'Third'

        In a tagged page document (PDF/UA-1, PDF/A-2a, -Tagged) the list is an L element with LI items,
        each holding a Lbl (the marker) and an LBody (the text, plus the nested L of an item that has
        children). In an untagged document it is only drawing.

        Items become text with a culture and an optional format. A string item is drawn as given unless it
        consists only of a number; any other value (a number, a date, ...) is converted with -Culture (the
        document's -Culture, invariant unless set) and -Format (a .NET format string such as 'N2' or
        'yyyy-MM-dd'); an item hashtable may carry its own Format key, and Parse = $false to draw its string
        as given.

        Numbers in strings are always recognised (switch it off with -NoNumberParsing): a string item that is
        only a number is read as [decimal], keeping its decimals, and then drawn like any other number, so
        with the invariant default '1.444,50' becomes 1444.50, '1,976.08' becomes 1976.08 and '55433.34'
        stays 55433.34. The separators are detected from the text:
          1. With both '.' and ',' the LAST one is the decimal mark (1.444,50 and 1,976.08).
          2. A separator that appears more than once is grouping (1.234.567).
          3. A separator that appears once is a decimal mark (55433.34, 66443,85), except that exactly three
             digits after it with at most three digits before it is ambiguous (1,234 and 1.234; with more
             than three digits before it, as in 12345,678, it is a decimal mark).
          4. Grouping must be regular: 1-3 digits, then groups of exactly 3 (1.2.3 and 10.0.0.1 stay text).
          5. Not a number, so left as is: a leading zero in a multi-digit integer part (007, 01234), spaces,
             currency symbols, '%', exponents, an empty string.
          6. An ambiguous number takes the convention of the other items of the same call; without such
             evidence it is left unchanged and ONE warning per call names the values.
        -InputCulture switches detection off: every string is read strictly with that culture's separators.

        Use a base-14 font by name (-Font) or an embedded TrueType font (-FontHandle from
        Register-VellumPdfFont); PDF/A and PDF/UA documents embed base-14 text automatically.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Item
        The items: text, or hashtables with Text and Children.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER X
        Left edge of the list in points.
    .PARAMETER Y
        Top of the list in points from the bottom of the page.
    .PARAMETER Width
        Total width of the list including the marker column.
    .PARAMETER Numbered
        Number the items 1. 2. 3. instead of using a bullet; children are numbered a. b. c.
    .PARAMETER Marker
        The bullet character (default a bullet; a hyphen when the font has no bullet glyph).
    .PARAMETER FontSize
        Size in points (default 11).
    .PARAMETER Font
        A base-14 font name (default Helvetica).
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont. Overrides -Font.
    .PARAMETER Color
        Text colour: RGB triple in 0..1, hex or name. Default black.
    .PARAMETER Leading
        Distance between baselines in points. Default 1.2 times -FontSize.
    .PARAMETER ItemSpacing
        Extra space after every item, in points (default 3).
    .PARAMETER Indent
        Width of the marker column in points (default 1.8 times -FontSize). Children are indented by one more.
    .PARAMETER Language
        BCP 47 language tag of the list text, written on the L element.
    .PARAMETER Format
        A .NET format string for items that are not text ('N2', 'yyyy-MM-dd'), applied with -Culture; also to
        numbers read from strings. An item's own Format key wins. A format the value's type rejects is an
        error naming the item.
    .PARAMETER Culture
        The culture used to turn numbers and dates into text: a name ('de-DE') or a [cultureinfo]
        (-Culture (Get-Culture) matches the console). Default: the document's -Culture, which is the
        invariant culture unless New-VellumPdfDocument/New-VellumPdfPageDocument set one. An unknown name is
        an error.
    .PARAMETER InputCulture
        Read number strings strictly with this culture (name or [cultureinfo]) instead of detecting the
        separators. Default: the document's -InputCulture, else detection. Pass $null to switch the
        document's -InputCulture off for this call.
    .PARAMETER NoNumberParsing
        Draw every string exactly as given instead of reading numbers from it. A single item can do the same
        with the key Parse = $false.
    .PARAMETER PassThru
        Return an object with Document, Height, Bottom (the y of the list's lower edge) and ItemCount
        instead of the document.
    .EXAMPLE
        $doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 300 -Item 'Read the brief', 'Draft the plan', 'Review with the team'
    .EXAMPLE
        $doc | Add-VellumPdfPageList -X 72 -Y 600 -Width 300 -Numbered -Item 'Prepare', @{ Text = 'Run'; Children = 'Dry run', 'Real run' }, 'Report'
    .EXAMPLE
        $doc | Add-VellumPdfPageList -X 72 -Y 500 -Width 300 -Item 1234.5, '1.444,5', 99 -Format 'N2' -Culture de-DE
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining), or with -PassThru a summary object.
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument], [pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [ValidateCount(1, 100000)]
        [AllowEmptyString()]
        [object[]]$Item,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,

        [Parameter(Mandatory)]
        [ValidateRange(1.0, 1000000.0)]
        [double]$Width,

        [switch]$Numbered,

        [ValidateNotNullOrEmpty()]
        [string]$Marker = [string][char]0x2022,

        [ValidateRange(1.0, 1000.0)]
        [double]$FontSize = 11,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font = 'Helvetica',

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [object]$Color,

        [ValidateRange(0.1, 10000.0)]
        [double]$Leading,

        [ValidateRange(0.0, 1000.0)]
        [double]$ItemSpacing = 3,

        [ValidateRange(1.0, 1000.0)]
        [double]$Indent,

        [ValidateNotNullOrEmpty()]
        [string]$Language,

        # .NET format string for items that are not text ('N2', 'yyyy-MM-dd'); an item hashtable may carry its own Format key.
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Format,

        # Culture used to turn dates and numbers into text; a name or a [cultureinfo].
        # Default: the document's -Culture (invariant unless set).
        [object]$Culture,

        # Culture used to read numbers given as strings (strict, no detection); $null switches the
        # document's -InputCulture off for this call. Default: the document's -InputCulture, else detection.
        [AllowNull()]
        [object]$InputCulture,

        # Draw strings exactly as given instead of reading numbers from them.
        [switch]$NoNumberParsing,

        [switch]$PassThru
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPageList'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $(if ($PSBoundParameters.ContainsKey('Page')) { $PSBoundParameters['Page'] } else { 1 }) -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfPageList'
            [void](Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageList')
            Assert-VellumPdfLanguageTag -Value $Language -CommandName 'Add-VellumPdfPageList'
            $cultures = Resolve-VellumPdfCulture -Document $Document -Culture $Culture -CultureBound:$PSBoundParameters.ContainsKey('Culture') `
                -InputCulture $InputCulture -InputCultureBound:$PSBoundParameters.ContainsKey('InputCulture') -CommandName 'Add-VellumPdfPageList'
            if (-not $FontHandle) { Assert-VellumPdfMeasurableFont -Font $Font -CommandName 'Add-VellumPdfPageList' -Reason 'it wraps item text' }
            Assert-VellumPdfCoordinate $X 'X' 'Add-VellumPdfPageList'
            Assert-VellumPdfCoordinate $Y 'Y' 'Add-VellumPdfPageList'
            Assert-VellumPdfCoordinate $Width 'Width' 'Add-VellumPdfPageList'
            $bound = $PSBoundParameters
            if (-not $bound.ContainsKey('Leading')) { $Leading = 1.2 * $FontSize }
            $markerIndent = if ($bound.ContainsKey('Indent')) { $Indent } else { 1.8 * $FontSize }

            # --- items ------------------------------------------------------------------------------------
            # An item is text, or a hashtable / object with Text and optionally Children.
            $isRecord = { param($x) $x -is [System.Collections.IDictionary] -or $x -is [pscustomobject] }
            # The raw value plus the item's own Format / Parse keys: it becomes text (number detection, format,
            # culture) below, once all items are known, because they are evidence for each other.
            $textOf = {
                param($x, $what)
                if (& $isRecord $x) {
                    $t = Get-VellumPdfPropertyValue -InputObject $x -Name 'Text'
                    if ($null -eq $t) { throw "Add-VellumPdfPageList: $what has no Text; give text or a hashtable with a Text key (an empty string draws a marker only)." }
                    $itemFormat = Get-VellumPdfPropertyValue -InputObject $x -Name 'Format'
                    $itemParse = Get-VellumPdfPropertyValue -InputObject $x -Name 'Parse'
                    [pscustomobject]@{ Value = $t; Format = $(if ($null -ne $itemFormat) { [string]$itemFormat } else { $Format }); Parse = ($null -eq $itemParse -or [bool]$itemParse) }
                }
                else { [pscustomobject]@{ Value = $x; Format = $Format; Parse = $true } }
            }
            $entries = foreach ($spec in $Item) {
                if ($null -eq $spec) { throw 'Add-VellumPdfPageList: an item is $null; give text or a hashtable with Text (an empty string draws a marker only).' }
                $text = & $textOf $spec 'an item'
                $children = @()
                if (& $isRecord $spec) {
                    $rawChildren = Get-VellumPdfPropertyValue -InputObject $spec -Name 'Children'
                    if ($null -ne $rawChildren) { $children = @($rawChildren) }
                }
                $childEntries = @(foreach ($child in $children) {
                        if ($null -eq $child) { throw 'Add-VellumPdfPageList: a child item is $null; give text or a hashtable with Text.' }
                        if ((& $isRecord $child) -and @(Get-VellumPdfPropertyValue -InputObject $child -Name 'Children').Where({ $null -ne $_ }).Count -gt 0) {
                            throw 'Add-VellumPdfPageList: the list has one nesting level; an item of Children cannot have Children of its own.'
                        }
                        [pscustomobject]@{ Source = (& $textOf $child 'a child item'); Text = ''; Children = @(); Lines = $null }
                    })
                [pscustomobject]@{ Source = $text; Text = ''; Children = $childEntries; Lines = $null }
            }
            $entries = @($entries)
            $slotList = [System.Collections.Generic.List[object]]::new()
            $slotOwners = [System.Collections.Generic.List[object]]::new()
            $itemNumber = 0
            foreach ($entry in $entries) {
                $itemNumber++
                $slotList.Add((New-VellumPdfTextSlot -Value $entry.Source.Value -Format $entry.Source.Format -Parse $entry.Source.Parse -Group 0 -What "item $itemNumber"))
                $slotOwners.Add($entry)
                $childNumber = 0
                foreach ($childEntry in $entry.Children) {
                    $childNumber++
                    $slotList.Add((New-VellumPdfTextSlot -Value $childEntry.Source.Value -Format $childEntry.Source.Format -Parse $childEntry.Source.Parse -Group 0 -What "child $childNumber of item $itemNumber"))
                    $slotOwners.Add($childEntry)
                }
            }
            Convert-VellumPdfSlotText -Slot $slotList.ToArray() -Culture $cultures.Culture -InputCulture $cultures.InputCulture `
                -NoNumberParsing:$NoNumberParsing -CommandName 'Add-VellumPdfPageList'
            for ($si = 0; $si -lt $slotOwners.Count; $si++) { $slotOwners[$si].Text = $slotList[$si].Text }

            $resolved = Get-VellumPdfPageFont -Document $Document -FontHandle $FontHandle -Font $Font -CommandName 'Add-VellumPdfPageList'
            $allText = @($entries | ForEach-Object { $_.Text; $_.Children | ForEach-Object { $_.Text } })
            Assert-VellumPdfValidText -Text $allText -CommandName 'Add-VellumPdfPageList'
            Write-VellumPdfMissingGlyphWarning -Handle $resolved.Handle -Text $allText -CommandName 'Add-VellumPdfPageList'
            if (-not $resolved.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None) {
                Write-VellumPdfEncodingWarning -Text $allText -CommandName 'Add-VellumPdfPageList'
            }
            $bullet = $Marker
            if ($resolved.Handle -and $resolved.Handle.GetGlyphId(([System.Text.Rune]::GetRuneAt($bullet, 0)).Value) -eq 0) { $bullet = '-' }
            $childBullet = if ($bullet -eq '-') { '-' } else { [string][char]0x2013 }
            if (-not $resolved.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None -and -not $bound.ContainsKey('Marker')) { $childBullet = '-' }

            # a. b. ... z. aa. ab. ...
            $letters = {
                param([int]$n)
                $label = ''
                do { $label = [string][char](97 + ($n % 26)) + $label; $n = [Math]::Floor($n / 26) - 1 } while ($n -ge 0)
                $label
            }
            $markerFor = {
                param($index, $level)
                if ($Numbered) { if ($level -eq 0) { "$($index + 1)." } else { "$(& $letters $index)." } }
                elseif ($level -eq 0) { $bullet }
                else { $childBullet }
            }

            # The marker column grows with the widest marker (numbers of 100 and above, long letter labels).
            if (-not $bound.ContainsKey('Indent')) {
                $widest = 0.0
                for ($i = 0; $i -lt $entries.Count; $i++) {
                    $widest = [Math]::Max($widest, (Measure-VellumPdfTextWidth -Resolved $resolved -Text (& $markerFor $i 0) -FontSize $FontSize))
                    for ($j = 0; $j -lt $entries[$i].Children.Count; $j++) {
                        $widest = [Math]::Max($widest, (Measure-VellumPdfTextWidth -Resolved $resolved -Text (& $markerFor $j 1) -FontSize $FontSize))
                    }
                }
                $markerIndent = [Math]::Max($markerIndent, $widest + 0.5 * $FontSize)
            }
            if ($Width -le 2 * $markerIndent + 1) { throw "Add-VellumPdfPageList: -Width $Width is too narrow for a marker column of $([math]::Round($markerIndent, 1)) pt and one nested level." }

            # --- measure -----------------------------------------------------------------------------------
            # Every entry becomes a placed record; children are kept with their parent for drawing.
            $layout = @{ Cursor = $Y }
            $place = {
                param($entry, $index, $level)
                $left = $X + $level * $markerIndent
                $bodyWidth = $Width - ($level + 1) * $markerIndent
                $entry.Lines = Split-VellumPdfTextLine -Text $entry.Text -Width $bodyWidth -Resolved $resolved -FontSize $FontSize
                $textHeight = $entry.Lines.Count * $Leading
                $record = [pscustomobject]@{
                    Entry = $entry; Level = $level; Index = $index; Left = $left; BodyLeft = $left + $markerIndent; BodyWidth = $bodyWidth
                    Top = $layout.Cursor; TextHeight = $textHeight; Children = [System.Collections.Generic.List[object]]::new()
                }
                $layout.Cursor -= $textHeight + $ItemSpacing
                $record
            }
            $placed = [System.Collections.Generic.List[object]]::new()
            $itemCount = 0
            for ($i = 0; $i -lt $entries.Count; $i++) {
                $top = & $place $entries[$i] $i 0
                $itemCount++
                for ($j = 0; $j -lt $entries[$i].Children.Count; $j++) { $top.Children.Add((& $place $entries[$i].Children[$j] $j 1)); $itemCount++ }
                $placed.Add($top)
            }
            $bottom = $layout.Cursor + $ItemSpacing
            $height = $Y - $bottom
            $pdfPage = $Document.Pages[$Page - 1]
            if ($bottom -lt $pdfPage.MediaBox.LlY) {
                throw ("Add-VellumPdfPageList: the list is $([math]::Round($height, 1)) pt tall but only " +
                    "$([math]::Round($Y - $pdfPage.MediaBox.LlY, 1)) pt are left below -Y on page $Page.")
            }

            # --- draw ---------------------------------------------------------------------------------------
            $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageList'
            if ($resolved.Handle) { $Document.RegisterEmbeddedFontUsage($pdfPage, $resolved.Handle) }
            # A colour operator is written only for a colour that was asked for (DeviceRGB would fail PDF/A with a CMYK intent).
            $rgb = if ($bound.ContainsKey('Color')) { ConvertTo-VellumColor $Color -Document $Document -CommandName 'Add-VellumPdfPageList' }
            $tagged = $Document.Tagged
            $oneLine = { param($text) , @([pscustomobject]@{ Words = [string[]]@($text); Last = $true }) }
            $drawLines = {
                param($lines, $left, $width, $top)
                [void]$canvas.SaveState()
                try {
                    if ($rgb) { [void]$canvas.SetFillColorRgb($rgb[0], $rgb[1], $rgb[2]) }
                    Write-VellumPdfTextLine -Canvas $canvas -Resolved $resolved -FontSize $FontSize -Lines $lines -X $left -Top $top -Width $width -Leading $Leading -Align Left
                }
                finally { [void]$canvas.RestoreState() }
            }
            # Draws one entry as LI > Lbl + LBody (or only marker and text when the document is untagged).
            $drawItem = {
                param($record, $bodyIsGroup)
                $markerText = & $markerFor $record.Index $record.Level
                $markerLines = & $oneLine $markerText
                if (-not $tagged) {
                    & $drawLines $markerLines $record.Left $markerIndent $record.Top
                    & $drawLines $record.Entry.Lines $record.BodyLeft $record.BodyWidth $record.Top
                    return
                }
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType Lbl -Draw { & $drawLines $markerLines $record.Left $markerIndent $record.Top }
                if ($bodyIsGroup) {
                    Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType P -Draw { & $drawLines $record.Entry.Lines $record.BodyLeft $record.BodyWidth $record.Top }
                }
                else {
                    Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType LBody -Draw { & $drawLines $record.Entry.Lines $record.BodyLeft $record.BodyWidth $record.Top }
                }
            }

            [void]$canvas.SaveState()
            try {
                $listGroup = $null
                if ($tagged) {
                    $listGroup = [VellumPdf.Document.PdfStructElem]::new('L')
                    if ($Language) { $listGroup.Language = $Language }
                    Push-VellumPdfStructParent -Document $Document -Element $listGroup
                }
                try {
                    foreach ($record in $placed) {
                        $listItem = $null
                        if ($tagged) {
                            $listItem = [VellumPdf.Document.PdfStructElem]::new('LI')
                            Add-VellumPdfStructElement -Document $Document -Element $listItem
                            Push-VellumPdfStructParent -Document $Document -Element $listItem
                        }
                        try {
                            if ($record.Children.Count -eq 0) { & $drawItem $record $false }
                            else {
                                # With children, LBody is a group: the item's text paragraph and the nested list.
                                $itemBody = $null
                                $nestedList = $null
                                if ($tagged) {
                                    $itemBody = [VellumPdf.Document.PdfStructElem]::new('LBody')
                                    $nestedList = [VellumPdf.Document.PdfStructElem]::new('L')
                                    $markerLines = & $oneLine (& $markerFor $record.Index 0)
                                    Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType Lbl -Draw { & $drawLines $markerLines $record.Left $markerIndent $record.Top }
                                    Add-VellumPdfStructElement -Document $Document -Element $itemBody
                                    Push-VellumPdfStructParent -Document $Document -Element $itemBody
                                }
                                try {
                                    if ($tagged) {
                                        Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType P -Draw { & $drawLines $record.Entry.Lines $record.BodyLeft $record.BodyWidth $record.Top }
                                        [void]$itemBody.AddChild($nestedList)
                                        Push-VellumPdfStructParent -Document $Document -Element $nestedList
                                    }
                                    else { & $drawItem $record $false }
                                    try {
                                        foreach ($child in $record.Children) {
                                            $childItem = $null
                                            if ($tagged) {
                                                $childItem = [VellumPdf.Document.PdfStructElem]::new('LI')
                                                Add-VellumPdfStructElement -Document $Document -Element $childItem
                                                Push-VellumPdfStructParent -Document $Document -Element $childItem
                                            }
                                            try { & $drawItem $child $false }
                                            finally { if ($tagged) { Pop-VellumPdfStructParent -Document $Document } }
                                        }
                                    }
                                    finally { if ($tagged) { Pop-VellumPdfStructParent -Document $Document } }
                                }
                                finally { if ($tagged) { Pop-VellumPdfStructParent -Document $Document } }
                            }
                        }
                        finally { if ($tagged) { Pop-VellumPdfStructParent -Document $Document } }
                    }
                }
                finally {
                    if ($tagged) { Pop-VellumPdfStructParent -Document $Document; Add-VellumPdfStructElement -Document $Document -Element $listGroup }
                }
            }
            finally { [void]$canvas.RestoreState() }

            if ($PassThru) {
                [pscustomobject]@{ Document = $Document; Height = $height; Bottom = $bottom; ItemCount = $itemCount }
            }
            else { $Document }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Add-VellumPdfPageList'))
        }
    }
}
