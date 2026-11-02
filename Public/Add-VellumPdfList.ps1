function Add-VellumPdfList {
    <#
    .SYNOPSIS
        Adds an ordered or unordered list to a VellumPdf document.
    .DESCRIPTION
        Wraps Document.Add(ListElement). Builds a ListElement from an array of
        string items and an optional list style (Unordered, OrderedDecimal,
        OrderedAlpha, OrderedRoman). An optional -Indent adjusts the left indent
        for the list. An optional -Font/-FontSize override applies a TextStyle to
        every item; when omitted the document default font is used.

        -MarginTop and -MarginBottom apply spacing above and below the list
        without affecting the left/right margins already set on the element.

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

        The document flows through the pipeline for chaining with other
        Add-VellumPdf* functions.
    .PARAMETER Document
        The live VellumPdf document flowing through the pipeline. The same
        instance is returned after the list is added, enabling chaining.
    .PARAMETER Item
        The list items. Each element is either a string (a leaf item) or a
        hashtable describing a nested item:
            @{ Text = 'Parent'; Children = @('Child A', @{ Text = 'Child B' }) }
        One level of children is supported: VellumPdf.Layout draws a child's own
        children nowhere (a grandchild's text would silently vanish), so deeper
        nesting is refused with an error. Flatten deeper trees or add separate
        lists. An item hashtable may also set Font, FontSize, FontHandle, Color,
        Leading and Language for that item alone. A nested item in an Unordered list is marked with U+25E6, which
        the base-14 fonts cannot encode (it shows as '?'). Empty strings are
        permitted. Mandatory.
    .PARAMETER Style
        The list marker style. Unordered uses bullet points; OrderedDecimal,
        OrderedAlpha, and OrderedRoman use numbered, alphabetic, and Roman
        numeral markers respectively. Defaults to Unordered.
    .PARAMETER FontHandle
        An embedded TrueType font from Register-VellumPdfFont, applied to every
        item (takes precedence over -Font). Needed for text outside Windows-1252
        and for PDF/A documents. An item may override it with its own FontHandle key.
    .PARAMETER Color
        Text colour for every item: an R,G,B triple in 0..1, a hex string
        ('#3366cc'), or a colour name.
    .PARAMETER Leading
        Line height in points for every item; 0 (the default) means 1.2 x the font size.
    .PARAMETER Language
        A BCP 47 language tag written for every item (e.g. 'fr'); only used in tagged
        documents. An item hashtable may carry its own Language key.
    .PARAMETER Indent
        Left indent for the list in points, between 0 and 1000. When omitted
        the VellumPdf library default indent is used.
    .PARAMETER Font
        A base-14 font name applied to every list item. When omitted the
        document default font is used.
    .PARAMETER FontSize
        Font size in points for list items, between 1 and 1000. When omitted
        the document default size is used.
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
    .PARAMETER MarginTop
        Extra spacing in points above the list element. Does not affect the
        left/right page margins.
    .PARAMETER MarginBottom
        Extra spacing in points below the list element. Does not affect the
        left/right page margins.
    .EXAMPLE
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 'Apples','Bananas','Cherries' |
            Save-VellumPdfDocument -Path ./fruit.pdf
    .EXAMPLE
        $doc | Add-VellumPdfList -Item 'First','Second','Third' `
               -Style OrderedDecimal -Indent 20 -Font Helvetica -FontSize 11
    .EXAMPLE
        # Nested list
        $doc | Add-VellumPdfList -Item @(
            'Fruit',
            @{ Text = 'Vegetables'; Children = @('Carrot', 'Potato') }
        )
    .EXAMPLE
        # Numbers and dates with a culture and a format
        New-VellumPdfDocument |
            Add-VellumPdfList -Item 1234.5, '1.444,5', 99 -Format 'N2' -Culture de-DE |
            Save-VellumPdfDocument -Path ./amounts.pdf
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Layout.Document]$Document,

        # Each element is a string (a leaf item) or a hashtable describing a
        # nested item: @{ Text = 'Parent'; Children = @('child', @{ Text = ... }) }.
        [Parameter(Mandatory)]
        [object[]]$Item,

        [ValidateSet('Unordered', 'OrderedDecimal', 'OrderedAlpha', 'OrderedRoman')]
        [string]$Style = 'Unordered',

        [ValidateRange(0.0, 1000.0)]
        [double]$Indent,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font,

        [ValidateRange(1.0, 1000.0)]
        [double]$FontSize,

        # An embedded TrueType font from Register-VellumPdfFont (takes precedence
        # over -Font); needed for Unicode text and PDF/A documents.
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        # Text colour for every item: R,G,B in 0..1, '#rrggbb', or a colour name.
        [object]$Color,

        [ValidateRange(0.0, 1000.0)]
        [double]$Leading,

        # BCP 47 language tag applied to every item (tagged documents only).
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

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginTop,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginBottom
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfList'
            Assert-VellumPdfLanguageTag -Value $Language -CommandName 'Add-VellumPdfList'
            $cultures = Resolve-VellumPdfCulture -Document $Document -Culture $Culture -CultureBound:$PSBoundParameters.ContainsKey('Culture') `
                -InputCulture $InputCulture -InputCultureBound:$PSBoundParameters.ContainsKey('InputCulture') -CommandName 'Add-VellumPdfList'
            if ($FontHandle) {
                Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfList'
            }

            # VellumPdf.Layout renders exactly one nesting level (ListItem.Children
            # is read, a child's own Children never are). Refuse deeper input rather
            # than lose text silently; this also bounds cyclic hashtables, which
            # would otherwise recurse into an uncatchable StackOverflow.
            $maxDepth = 1

            $depthError = {
                "Add-VellumPdfList: nested -Item exceeds the maximum depth of $maxDepth child level " +
                    '(VellumPdf.Layout draws one nesting level only; flatten the list or split it, ' +
                    'and check for cyclic input).'
            }

            # Values become text: number detection, -Format / an item's Format key, and the culture. Every item and child
            # of the call is evidence for the others about the decimal mark. The tree is rebuilt (hashtables copied, the
            # caller's input is not changed) with the converted text.
            $slotList = [System.Collections.Generic.List[object]]::new()
            $prepare = {
                param($spec, $depth, $label)
                if ($depth -gt $maxDepth) { throw (& $depthError) }
                $isMap = $spec -is [System.Collections.IDictionary]
                if ($isMap -and -not $spec.Contains('Text')) {
                    throw "Add-VellumPdfList: a nested-item hashtable must include a 'Text' key."
                }
                $itemFormat = if ($isMap -and $null -ne $spec['Format']) { [string]$spec['Format'] } else { $Format }
                $itemParse = -not ($isMap -and $null -ne $spec['Parse'] -and -not [bool]$spec['Parse'])
                $slot = New-VellumPdfTextSlot -Value $(if ($isMap) { $spec['Text'] } else { $spec }) -Format $itemFormat -Parse $itemParse -Group 0 -What $label
                $slotList.Add($slot)
                $childNodes = [System.Collections.Generic.List[object]]::new()
                if ($isMap -and $spec['Children']) {
                    $k = 0
                    foreach ($child in @($spec['Children'])) { $k++; $childNodes.Add((& $prepare $child ($depth + 1) "child $k of $label")) }
                }
                [pscustomobject]@{ Spec = $spec; Slot = $slot; Children = $childNodes }
            }
            $nodes = [System.Collections.Generic.List[object]]::new()
            $n = 0
            foreach ($spec in $Item) { $n++; $nodes.Add((& $prepare $spec 0 "item $n")) }
            Convert-VellumPdfSlotText -Slot $slotList.ToArray() -Culture $cultures.Culture -InputCulture $cultures.InputCulture `
                -NoNumberParsing:$NoNumberParsing -CommandName 'Add-VellumPdfList'
            $rebuild = {
                param($node)
                if ($node.Spec -isnot [System.Collections.IDictionary]) { return $node.Slot.Text }
                $copy = @{}
                foreach ($key in $node.Spec.Keys) { $copy[$key] = $node.Spec[$key] }
                $copy['Text'] = $node.Slot.Text
                if ($node.Children.Count -gt 0) { $copy['Children'] = @(foreach ($childNode in $node.Children) { & $rebuild $childNode }) }
                $copy
            }
            $convertedItem = @(foreach ($node in $nodes) { & $rebuild $node })

            # Gather every label (recursing into nested children) for the encoding
            # warning, which scans for characters the base-14 fonts cannot render.
            $collectAllText = {
                param($spec, $depth = 0)
                if ($depth -gt $maxDepth) { throw (& $depthError) }
                if ($spec -is [System.Collections.IDictionary]) {
                    if ($spec.Contains('Text')) { [string]$spec['Text'] }
                    if ($spec['Children']) { foreach ($c in @($spec['Children'])) { & $collectAllText $c ($depth + 1) } }
                }
                else { [string]$spec }
            }
            $collectText = {
                param($spec, $depth = 0)
                if ($depth -gt $maxDepth) { throw (& $depthError) }
                if ($spec -is [System.Collections.IDictionary]) {
                    if (-not $spec.Contains('Text')) {
                        throw "Add-VellumPdfList: a nested-item hashtable must include a 'Text' key."
                    }
                    if (-not $FontHandle -and -not $spec['FontHandle']) { [string]$spec['Text'] }
                    if ($spec['Children']) { foreach ($c in @($spec['Children'])) { & $collectText $c ($depth + 1) } }
                }
                elseif (-not $FontHandle) {
                    [string]$spec
                }
            }
            if ($FontHandle) {
                $itemTexts = @(foreach ($spec in $convertedItem) { & $collectAllText $spec })
                Write-VellumPdfMissingGlyphWarning -Handle $FontHandle -Text $itemTexts -CommandName 'Add-VellumPdfList'
            }
            Write-VellumPdfEncodingWarning -Text @(foreach ($spec in $convertedItem) { & $collectText $spec }) `
                -CommandName 'Add-VellumPdfList'
            $listStyle = [VellumPdf.Layout.Elements.ListStyle]::$Style

            # Build an empty typed list to satisfy the IEnumerable<ListItem> ctor param.
            $emptyItems = [System.Collections.Generic.List[VellumPdf.Layout.Elements.ListItem]]::new()
            $list = [VellumPdf.Layout.Elements.ListElement]::new($listStyle, $emptyItems)

            # Apply indent when supplied.
            if ($PSBoundParameters.ContainsKey('Indent')) {
                $list.Indent = $Indent
            }

            # List-level style values. Gaps are filled from the document defaults: a
            # style without a font renders in the library-global Helvetica, not the
            # document default. A $null style lets an item fall back to the engine's
            # list default.
            $default = Resolve-VellumPdfDefault -Document $Document
            $listColor = if ($PSBoundParameters.ContainsKey('Color')) { ConvertTo-VellumColor $Color -Document $Document -CommandName 'Add-VellumPdfList' }
            $base = @{
                Font       = if ($Font) { $Font } else { $default.Font }
                FontSize   = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { $default.FontSize }
                FontHandle = $FontHandle
                Color      = $listColor
                Leading    = if ($PSBoundParameters.ContainsKey('Leading')) { $Leading }
            }
            $fontNames = [Enum]::GetNames([VellumPdf.Fonts.Standard14])

            # Builds the TextStyle for one item: the list-level values overlaid with
            # the item's own Font/FontSize/FontHandle/Color/Leading keys.
            $styleFor = {
                param($spec)
                # Always an explicit style: a TextStyle without a font would draw in the library-global
                # Helvetica instead of the document's default font.
                $handle = $FontHandle
                if ($spec -is [System.Collections.IDictionary] -and $spec['FontHandle']) {
                    if ($spec['FontHandle'] -isnot [VellumPdf.Fonts.EmbeddedFontHandle]) {
                        throw 'Add-VellumPdfList: item FontHandle must be an EmbeddedFontHandle from Register-VellumPdfFont.'
                    }
                    Assert-VellumPdfFontHandle -FontHandle $spec['FontHandle'] -Document $Document -CommandName 'Add-VellumPdfList'
                    $handle = $spec['FontHandle']
                }
                $itemFont = $base.Font
                if ($spec -is [System.Collections.IDictionary] -and $spec['Font']) {
                    if ([string]$spec['Font'] -notin $fontNames) {
                        throw "Add-VellumPdfList: item Font '$($spec['Font'])' is not a base-14 font name."
                    }
                    $itemFont = [string]$spec['Font']
                    if (-not $spec['FontHandle']) { $handle = $null }   # an explicit base-14 Font on the item wins over the list handle
                }
                $size = $base.FontSize
                if ($spec -is [System.Collections.IDictionary] -and $null -ne $spec['FontSize']) {
                    $size = $spec['FontSize'] -as [double]
                    if ($null -eq $size -or -not [double]::IsFinite($size) -or $size -lt 1 -or $size -gt 1000) {
                        throw "Add-VellumPdfList: item FontSize must be between 1 and 1000; got '$($spec['FontSize'])'."
                    }
                }
                $args2 = @{ FontSize = $size }
                if ($handle) { $args2['FontHandle'] = $handle } else { $args2['Font'] = $itemFont }
                $colorValue = $base.Color
                if ($spec -is [System.Collections.IDictionary] -and $spec['Color']) { $colorValue = ConvertTo-VellumColor $spec['Color'] -Document $Document -CommandName 'Add-VellumPdfList' }
                if ($colorValue) { $args2['Color'] = $colorValue }
                $lead = $base.Leading
                if ($spec -is [System.Collections.IDictionary] -and $null -ne $spec['Leading']) {
                    $lead = $spec['Leading'] -as [double]
                    if ($null -eq $lead -or -not [double]::IsFinite($lead) -or $lead -lt 0 -or $lead -gt 1000) {
                        throw "Add-VellumPdfList: item Leading must be between 0 and 1000; got '$($spec['Leading'])'."
                    }
                }
                if ($null -ne $lead) { $args2['Leading'] = $lead }
                New-VellumTextStyle @args2 -Document $Document -CommandName 'Add-VellumPdfList'
            }

            # Build each item (recursing into Children via ListItem.AddChild).
            $buildItem = {
                param($spec)
                $text = if ($spec -is [System.Collections.IDictionary]) { [string]$spec['Text'] } else { [string]$spec }
                $li = [VellumPdf.Layout.Elements.ListItem]::new($text, (& $styleFor $spec))
                $lang = if ($spec -is [System.Collections.IDictionary] -and $spec['Language']) { [string]$spec['Language'] }
                        elseif ($Language) { $Language }
                if ($lang) { $li.Language = $lang }
                if ($spec -is [System.Collections.IDictionary] -and $spec['Children']) {
                    foreach ($child in @($spec['Children'])) {
                        [void]$li.AddChild((& $buildItem $child))
                    }
                }
                $li
            }
            foreach ($spec in $convertedItem) {
                [void]$list.Add((& $buildItem $spec))
            }

            Set-VellumPdfElementMargin -Element $list -Top $MarginTop -Bottom $MarginBottom `
                -BoundParameters $PSBoundParameters -Document $Document -DeferBottom

            [void]$Document.Add($list)
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Add-VellumPdfList'))
        }
    }
}
