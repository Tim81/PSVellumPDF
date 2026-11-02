function Add-VellumPdfPageList {
    <#
    .SYNOPSIS
        Draws a bulleted or numbered list at x/y on a page of a page-based document, tagged as a real list.
    .DESCRIPTION
        The page-document counterpart of Add-VellumPdfList: each item is a marker (a bullet, or 1. 2. 3.
        with -Numbered) followed by text that wraps inside -Width and hangs under itself. -X is the left
        edge and -Y the top of the list in points from the page's bottom-left. A list that does not fit
        above the bottom of the page is an error.

        An item is text, or a hashtable with Text and optionally Children (one more level of items):

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
        [ValidateNotNullOrEmpty()]
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
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $Page -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfPageList'
            Assert-VellumPdfLanguageTag -Value $Language -CommandName 'Add-VellumPdfPageList'
            Assert-VellumPdfCoordinate $X 'X' 'Add-VellumPdfPageList'
            Assert-VellumPdfCoordinate $Y 'Y' 'Add-VellumPdfPageList'
            Assert-VellumPdfCoordinate $Width 'Width' 'Add-VellumPdfPageList'
            $bound = $PSBoundParameters
            if (-not $bound.ContainsKey('Leading')) { $Leading = 1.2 * $FontSize }
            if (-not $bound.ContainsKey('Indent')) { $Indent = 1.8 * $FontSize }
            if ($Width -le 2 * $Indent + 1) { throw "Add-VellumPdfPageList: -Width $Width is too narrow for a marker column of $Indent pt and one nested level." }

            # --- items ------------------------------------------------------------------------------------
            $entries = foreach ($spec in $Item) {
                $isMap = $spec -is [System.Collections.IDictionary]
                $text = if ($isMap) { [string](Get-VellumPdfPropertyValue -InputObject $spec -Name 'Text') } else { [string]$spec }
                $children = @(if ($isMap) { Get-VellumPdfPropertyValue -InputObject $spec -Name 'Children' })
                $childEntries = @(foreach ($child in $children) {
                        if ($child -is [System.Collections.IDictionary] -and $child['Children']) {
                            throw 'Add-VellumPdfPageList: the list has one nesting level; an item of Children cannot have Children of its own.'
                        }
                        $childText = if ($child -is [System.Collections.IDictionary]) { [string](Get-VellumPdfPropertyValue -InputObject $child -Name 'Text') } else { [string]$child }
                        [pscustomobject]@{ Text = $childText; Children = @(); Lines = $null }
                    })
                [pscustomobject]@{ Text = $text; Children = $childEntries; Lines = $null }
            }
            $entries = @($entries)

            $resolved = Get-VellumPdfPageFont -Document $Document -FontHandle $FontHandle -Font $Font -CommandName 'Add-VellumPdfPageList'
            $allText = @($entries | ForEach-Object { $_.Text; $_.Children | ForEach-Object { $_.Text } })
            Write-VellumPdfMissingGlyphWarning -Handle $resolved.Handle -Text $allText -CommandName 'Add-VellumPdfPageList'
            if (-not $resolved.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None) {
                Write-VellumPdfEncodingWarning -Text $allText -CommandName 'Add-VellumPdfPageList'
            }
            $bullet = $Marker
            if ($resolved.Handle -and $resolved.Handle.GetGlyphId(([System.Text.Rune]::GetRuneAt($bullet, 0)).Value) -eq 0) { $bullet = '-' }
            $childBullet = if ($bullet -eq '-') { '-' } else { [string][char]0x2013 }
            if (-not $resolved.Handle -and $Document.Conformance -eq [VellumPdf.Document.PdfConformance]::None -and -not $bound.ContainsKey('Marker')) { $childBullet = '-' }

            $markerFor = {
                param($index, $level)
                if ($Numbered) { if ($level -eq 0) { "$($index + 1)." } else { "$([char](97 + ($index % 26)))." } }
                elseif ($level -eq 0) { $bullet }
                else { $childBullet }
            }

            # --- measure -----------------------------------------------------------------------------------
            $placed = [System.Collections.Generic.List[object]]::new()
            $layout = @{ Cursor = $Y }
            $place = {
                param($entry, $index, $level)
                $left = $X + $level * $Indent
                $bodyWidth = $Width - ($level + 1) * $Indent
                $entry.Lines = Split-VellumPdfTextLine -Text $entry.Text -Width $bodyWidth -Resolved $resolved -FontSize $FontSize
                $textHeight = $entry.Lines.Count * $Leading
                $placed.Add([pscustomobject]@{
                        Entry = $entry; Level = $level; Index = $index; Left = $left; BodyLeft = $left + $Indent; BodyWidth = $bodyWidth
                        Top = $layout.Cursor; TextHeight = $textHeight
                    })
                $layout.Cursor -= $textHeight + $ItemSpacing
            }
            for ($i = 0; $i -lt $entries.Count; $i++) {
                & $place $entries[$i] $i 0
                for ($j = 0; $j -lt $entries[$i].Children.Count; $j++) { & $place $entries[$i].Children[$j] $j 1 }
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
            $rgb = if ($bound.ContainsKey('Color')) { ConvertTo-VellumColor $Color } else { 0, 0, 0 }
            $tagged = $Document.Tagged
            $oneLine = { param($text) , @([pscustomobject]@{ Words = [string[]]@($text); Last = $true }) }

            [void]$canvas.SaveState()
            try {
                $listGroup = $null
                if ($tagged) {
                    $listGroup = [VellumPdf.Document.PdfStructElem]::new('L')
                    if ($Language) { $listGroup.Language = $Language }
                    Push-VellumPdfStructParent -Document $Document -Element $listGroup
                }
                try {
                    $topItem = $null     # the LI group of the current top-level item
                    $nested = $null      # the nested L group of the current item, when it has children
                    foreach ($p in $placed) {
                        $marker = & $markerFor $p.Index $p.Level
                        $markerLines = & $oneLine $marker
                        $drawLines = {
                            param($lines, $left, $width)
                            [void]$canvas.SaveState().SetFillColorRgb($rgb[0], $rgb[1], $rgb[2])
                            Write-VellumPdfTextLine -Canvas $canvas -Resolved $resolved -FontSize $FontSize -Lines $lines -X $left -Top $p.Top -Width $width -Leading $Leading -Align Left
                            [void]$canvas.RestoreState()
                        }
                        if ($tagged) {
                            if ($p.Level -eq 0) {
                                if ($topItem) { Pop-VellumPdfStructParent -Document $Document; if ($nested) { Pop-VellumPdfStructParent -Document $Document } }
                                $topItem = [VellumPdf.Document.PdfStructElem]::new('LI')
                                Add-VellumPdfStructElement -Document $Document -Element $topItem
                                Push-VellumPdfStructParent -Document $Document -Element $topItem
                                $nested = $null
                                $hasChildren = $p.Entry.Children.Count -gt 0
                                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType Lbl -Draw { & $drawLines $markerLines $p.Left $Indent }
                                if ($hasChildren) {
                                    # LBody holds the item's text and the nested list, so it is a group with a P leaf.
                                    $body = [VellumPdf.Document.PdfStructElem]::new('LBody')
                                    Add-VellumPdfStructElement -Document $Document -Element $body
                                    Push-VellumPdfStructParent -Document $Document -Element $body
                                    Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType P -Draw { & $drawLines $p.Entry.Lines $p.BodyLeft $p.BodyWidth }
                                    $nested = [VellumPdf.Document.PdfStructElem]::new('L')
                                    [void]$body.AddChild($nested)
                                    Pop-VellumPdfStructParent -Document $Document
                                    Push-VellumPdfStructParent -Document $Document -Element $nested
                                }
                                else {
                                    Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType LBody -Draw { & $drawLines $p.Entry.Lines $p.BodyLeft $p.BodyWidth }
                                }
                            }
                            else {
                                # A child item: LI > Lbl + LBody inside the nested L.
                                $childItem = [VellumPdf.Document.PdfStructElem]::new('LI')
                                Add-VellumPdfStructElement -Document $Document -Element $childItem
                                Push-VellumPdfStructParent -Document $Document -Element $childItem
                                try {
                                    Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType Lbl -Draw { & $drawLines $markerLines $p.Left $Indent }
                                    Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Structure -StructType LBody -Draw { & $drawLines $p.Entry.Lines $p.BodyLeft $p.BodyWidth }
                                }
                                finally { Pop-VellumPdfStructParent -Document $Document }
                            }
                        }
                        else {
                            & $drawLines $markerLines $p.Left $Indent
                            & $drawLines $p.Entry.Lines $p.BodyLeft $p.BodyWidth
                        }
                    }
                    if ($tagged -and $topItem) {
                        # Close the open top-level item (and its nested list, when it had one).
                        if ($nested) { Pop-VellumPdfStructParent -Document $Document }
                        Pop-VellumPdfStructParent -Document $Document
                    }
                }
                finally { if ($tagged) { Pop-VellumPdfStructParent -Document $Document } }
                if ($tagged) { Add-VellumPdfStructElement -Document $Document -Element $listGroup }
            }
            finally { [void]$canvas.RestoreState() }

            if ($PassThru) {
                [pscustomobject]@{ Document = $Document; Height = $height; Bottom = $bottom; ItemCount = $placed.Count }
            }
            else { $Document }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
