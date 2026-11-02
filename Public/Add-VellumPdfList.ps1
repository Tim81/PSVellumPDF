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

        [ValidateRange(0, 1000)]
        [double]$Indent,

        [ValidateSet('Courier', 'CourierBold', 'CourierBoldOblique', 'CourierOblique',
            'Helvetica', 'HelveticaBold', 'HelveticaBoldOblique', 'HelveticaOblique',
            'Symbol', 'TimesBold', 'TimesBoldItalic', 'TimesItalic', 'TimesRoman', 'ZapfDingbats')]
        [string]$Font,

        [ValidateRange(1, 1000)]
        [double]$FontSize,

        # An embedded TrueType font from Register-VellumPdfFont (takes precedence
        # over -Font); needed for Unicode text and PDF/A documents.
        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        # Text colour for every item: R,G,B in 0..1, '#rrggbb', or a colour name.
        [object]$Color,

        [ValidateRange(0, 1000)]
        [double]$Leading,

        # BCP 47 language tag applied to every item (tagged documents only).
        [ValidateNotNullOrEmpty()]
        [string]$Language,

        [ValidateRange(0, 10000)]
        [double]$MarginTop,

        [ValidateRange(0, 10000)]
        [double]$MarginBottom
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfList'
            if ($FontHandle) {
                Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfList'
            }

            # VellumPdf.Layout renders exactly one nesting level (ListItem.Children
            # is read, a child's own Children never are). Refuse deeper input rather
            # than lose text silently; this also bounds cyclic hashtables, which
            # would otherwise recurse into an uncatchable StackOverflow.
            $maxDepth = 1

            # Gather every label (recursing into nested children) for the encoding
            # warning, which scans for characters the base-14 fonts cannot render.
            $collectText = {
                param($spec, $depth = 0)
                if ($depth -gt $maxDepth) {
                    throw ("Add-VellumPdfList: nested -Item exceeds the maximum depth of $maxDepth child level " +
                        '(VellumPdf.Layout draws one nesting level only; flatten the list or split it, ' +
                        'and check for cyclic input).')
                }
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
            Write-VellumPdfEncodingWarning -Text @(foreach ($spec in $Item) { & $collectText $spec }) `
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
            $listColor = if ($PSBoundParameters.ContainsKey('Color')) { ConvertTo-VellumColor $Color }
            $base = @{
                Font       = if ($Font) { $Font } else { $default.Font }
                FontSize   = if ($PSBoundParameters.ContainsKey('FontSize')) { $FontSize } else { $default.FontSize }
                FontHandle = $FontHandle
                Color      = $listColor
                Leading    = if ($PSBoundParameters.ContainsKey('Leading')) { $Leading }
            }
            $listWantsStyle = [bool]$Font -or $PSBoundParameters.ContainsKey('FontSize') -or $FontHandle `
                -or $listColor -or $PSBoundParameters.ContainsKey('Leading')

            $fontNames = [Enum]::GetNames([VellumPdf.Fonts.Standard14])

            # Builds the TextStyle for one item: the list-level values overlaid with
            # the item's own Font/FontSize/FontHandle/Color/Leading keys.
            $styleFor = {
                param($spec)
                $over = @('Font', 'FontSize', 'FontHandle', 'Color', 'Leading') | Where-Object {
                    $spec -is [System.Collections.IDictionary] -and $null -ne $spec[$_]
                }
                if (-not $listWantsStyle -and -not $over) { return $null }

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
                    if ($null -eq $size -or $size -lt 1 -or $size -gt 1000) {
                        throw "Add-VellumPdfList: item FontSize must be between 1 and 1000; got '$($spec['FontSize'])'."
                    }
                }
                $args2 = @{ FontSize = $size }
                if ($handle) { $args2['FontHandle'] = $handle } else { $args2['Font'] = $itemFont }
                $colorValue = $base.Color
                if ($spec -is [System.Collections.IDictionary] -and $spec['Color']) { $colorValue = ConvertTo-VellumColor $spec['Color'] }
                if ($colorValue) { $args2['Color'] = $colorValue }
                $lead = $base.Leading
                if ($spec -is [System.Collections.IDictionary] -and $null -ne $spec['Leading']) {
                    $lead = $spec['Leading'] -as [double]
                    if ($null -eq $lead -or $lead -lt 0 -or $lead -gt 1000) {
                        throw "Add-VellumPdfList: item Leading must be between 0 and 1000; got '$($spec['Leading'])'."
                    }
                }
                if ($null -ne $lead) { $args2['Leading'] = $lead }
                New-VellumTextStyle @args2
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
            foreach ($spec in $Item) {
                [void]$list.Add((& $buildItem $spec))
            }

            Set-VellumPdfElementMargin -Element $list -Top $MarginTop -Bottom $MarginBottom `
                -BoundParameters $PSBoundParameters -Document $Document -DeferBottom

            [void]$Document.Add($list)
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
