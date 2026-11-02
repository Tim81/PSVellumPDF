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
    .PARAMETER PassThru
        Return an object with Document, Height, Bottom (the y of the list's lower edge) and ItemCount
        instead of the document.
    .EXAMPLE
        $doc | Add-VellumPdfPageList -X 72 -Y 700 -Width 300 -Item 'Read the brief', 'Draft the plan', 'Review with the team'
    .EXAMPLE
        $doc | Add-VellumPdfPageList -X 72 -Y 600 -Width 300 -Numbered -Item 'Prepare', @{ Text = 'Run'; Children = 'Dry run', 'Real run' }, 'Report'
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

        [switch]$PassThru
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPageList'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $(if ($PSBoundParameters.ContainsKey('Page')) { $PSBoundParameters['Page'] } else { 1 }) -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfPageList'
            [void](Get-VellumPdfPage -Document $Document -Page $Page -CommandName 'Add-VellumPdfPageList')
            Assert-VellumPdfLanguageTag -Value $Language -CommandName 'Add-VellumPdfPageList'
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
            $textOf = {
                param($x, $what)
                if (& $isRecord $x) {
                    $t = Get-VellumPdfPropertyValue -InputObject $x -Name 'Text'
                    if ($null -eq $t) { throw "Add-VellumPdfPageList: $what has no Text; give text or a hashtable with a Text key (an empty string draws a marker only)." }
                    [string]$t
                }
                else { [string]$x }
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
                        [pscustomobject]@{ Text = (& $textOf $child 'a child item'); Children = @(); Lines = $null }
                    })
                [pscustomobject]@{ Text = $text; Children = $childEntries; Lines = $null }
            }
            $entries = @($entries)

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
            $rgb = if ($bound.ContainsKey('Color')) { ConvertTo-VellumColor $Color }
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
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
