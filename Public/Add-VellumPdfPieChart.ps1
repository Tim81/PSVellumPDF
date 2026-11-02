function Add-VellumPdfPieChart {
    <#
    .SYNOPSIS
        Adds a pie chart to a VellumPdf document.
    .DESCRIPTION
        Wraps VellumPdf.Layout.Elements.PieChart / PieSlice and Document.Add. Give
        the slices explicitly with -Slice, or pipe any objects in and name the
        properties holding the value and the label:

            $doc | Add-VellumPdfPieChart -Slice @(
                @{ Value = 40; Label = 'North' },
                @{ Value = 25; Label = 'South'; Color = 'orange' })

            Get-Process | Group-Object Company |
                Add-VellumPdfPieChart -Document $doc -ValueProperty Count -LabelProperty Name

        A slice without a Color takes the next colour of a built-in palette
        designed to stay distinguishable for colour-blind readers. The engine
        never draws slice labels on the chart; pass -Legend to add a table
        (colour swatch, label, share) below it. In a tagged document the chart is
        a Figure whose alternate text is -AltText, or - when omitted - composed
        from the labels and percentages; use -Decorative when the same numbers
        are already in nearby text.
    .PARAMETER Document
        The live VellumPdf document. Pipe it in with -Slice; pass it by parameter
        when piping the data objects.
    .PARAMETER Slice
        The slices: hashtables with Value (required, finite, >= 0), and optional
        Color (RGB triple, hex or name) and Label, or VellumPdf PieSlice objects.
    .PARAMETER InputObject
        Data objects to chart (pipeline). Use with -ValueProperty.
    .PARAMETER ValueProperty
        The property of each input object holding the slice size.
    .PARAMETER LabelProperty
        The property used as the slice label. When omitted slices are unlabeled.
    .PARAMETER Diameter
        Chart diameter in points (default 200). Wider than the page content area is
        clamped by the engine, and warned about here.
    .PARAMETER StrokeColor
        Colour of the thin separator drawn between slices. Default: none.
    .PARAMETER StrokeWidth
        Separator width in points (default 0.5).
    .PARAMETER Alignment
        Left, Center (default) or Right.
    .PARAMETER StartAngle
        Where the first slice starts, in degrees counter-clockwise from 3 o'clock.
        Default 90 (12 o'clock).
    .PARAMETER CounterClockwise
        Draw the slices counter-clockwise (default clockwise).
    .PARAMETER AltText
        Alternate text for the chart in a tagged document. Default: composed from
        the slice labels and percentages.
    .PARAMETER Decorative
        Mark the chart as an artifact (not read by screen readers). Cannot be
        combined with -AltText.
    .PARAMETER Legend
        Add a table below the chart listing each slice: swatch, label, percentage.
    .PARAMETER FontHandle
        Embedded font for the -Legend table (needed for PDF/A and non-Windows-1252
        labels).
    .PARAMETER MarginTop
        Extra spacing in points above the chart.
    .PARAMETER MarginBottom
        Extra spacing in points below the chart.
    .EXAMPLE
        New-VellumPdfDocument -Tagged -Language en |
            Add-VellumPdfPieChart -Legend -Slice @(
                @{ Value = 60; Label = 'Hardware' }, @{ Value = 40; Label = 'Services' }) |
            Save-VellumPdfDocument -Path ./share.pdf
    .OUTPUTS
        VellumPdf.Layout.Document (the same instance, for chaining)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Slices')]
    [OutputType([VellumPdf.Layout.Document])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Slices')]
        [Parameter(Mandatory, ParameterSetName = 'Data')]
        [VellumPdf.Layout.Document]$Document,

        [Parameter(Mandatory, ParameterSetName = 'Slices')]
        [object[]]$Slice,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Data')]
        [object]$InputObject,

        [Parameter(Mandatory, ParameterSetName = 'Data')]
        [string]$ValueProperty,

        [Parameter(ParameterSetName = 'Data')]
        [string]$LabelProperty,

        [ValidateRange(1.0, 100000.0)]
        [double]$Diameter = 200,

        [object]$StrokeColor,

        [ValidateRange(0.0, 100.0)]
        [double]$StrokeWidth = 0.5,

        [ValidateSet('Left', 'Center', 'Right')]
        [string]$Alignment = 'Center',

        [ValidateRange(-360.0, 360.0)]
        [double]$StartAngle = 90,

        [switch]$CounterClockwise,

        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) }, ErrorMessage = '-AltText must not be empty or whitespace.')]

        [string]$AltText,

        [switch]$Decorative,

        [switch]$Legend,

        [VellumPdf.Fonts.EmbeddedFontHandle]$FontHandle,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginTop,

        [ValidateRange(0.0, 10000.0)]
        [double]$MarginBottom
    )

    begin {
        try {
            $collected = [System.Collections.Generic.List[object]]::new()
            $palette = Get-VellumPdfPalette
            # Inside the script block below $PSBoundParameters would be the block's own (empty) dictionary.
            $boundParameters = $PSBoundParameters

            # Builds and adds the chart (and legend) for a list of raw slice specs.
            $buildChart = {
                param([object[]]$Specs)

                Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPieChart'
                if ($FontHandle) {
                    Assert-VellumPdfFontHandle -FontHandle $FontHandle -Document $Document -CommandName 'Add-VellumPdfPieChart'
                }
                if ($Decorative -and $AltText) {
                    throw 'Add-VellumPdfPieChart: -AltText and -Decorative cannot be combined; a decorative chart has no alternate text.'
                }
                if (-not $Specs -or $Specs.Count -eq 0) {
                    throw 'Add-VellumPdfPieChart: at least one slice is required.'
                }

                # Normalise every spec to (Value, Color triple, Label), validating up
                # front: the engine only throws when the document is saved.
                $items = [System.Collections.Generic.List[object]]::new()
                $sum = 0.0
                $i = 0
                foreach ($spec in $Specs) {
                    if ($spec -is [VellumPdf.Layout.Elements.PieSlice]) {
                        $value = $spec.Value
                        $rgb = @($spec.Color.R, $spec.Color.G, $spec.Color.B)
                        $label = $spec.Label
                    }
                    elseif ($spec -is [System.Collections.IDictionary] -or $spec -is [System.Management.Automation.PSCustomObject]) {
                        $get = { param($k) Get-VellumPdfPropertyValue -InputObject $spec -Name $k }
                        $raw = & $get 'Value'
                        $value = if ($null -ne $raw) { $raw -as [double] }
                        if ($null -eq $value) { throw "Add-VellumPdfPieChart: slice $($i + 1) has no numeric Value (got '$raw')." }
                        $colorSpec = & $get 'Color'
                        $rgb = if ($null -ne $colorSpec) { ConvertTo-VellumColor $colorSpec } else { ConvertTo-VellumColor $palette[$i % $palette.Count] }
                        $label = & $get 'Label'
                    }
                    else {
                        throw "Add-VellumPdfPieChart: slice $($i + 1) must be a hashtable (Value/Color/Label) or a PieSlice; got $($spec.GetType().Name)."
                    }
                    if (-not [double]::IsFinite($value) -or $value -lt 0) {
                        throw "Add-VellumPdfPieChart: slice $($i + 1) Value must be a finite number >= 0; got $value."
                    }
                    $sum += $value
                    $items.Add([pscustomobject]@{ Value = [double]$value; Rgb = $rgb; Label = if ($null -ne $label) { [string]$label } })
                    $i++
                }
                if ($sum -le 0) { throw 'Add-VellumPdfPieChart: the slice values must add up to more than zero.' }

                $contentWidth = $Document.PageSize.Width - $Document.Margins.Left - $Document.Margins.Right
                if ($Diameter -gt $contentWidth) {
                    Write-Warning ("Add-VellumPdfPieChart: -Diameter $Diameter is wider than the $([math]::Round($contentWidth, 1))pt " +
                        'content area; the engine will draw a smaller chart.')
                }

                $slices = [System.Collections.Generic.List[VellumPdf.Layout.Elements.PieSlice]]::new()
                foreach ($item in $items) {
                    $color = [VellumPdf.Layout.Core.ColorRgb]::new($item.Rgb[0], $item.Rgb[1], $item.Rgb[2])
                    $slices.Add([VellumPdf.Layout.Elements.PieSlice]::new($item.Value, $color, $item.Label))
                }

                $chart = [VellumPdf.Layout.Elements.PieChart]::new()
                $chart.Slices = $slices
                $chart.Diameter = $Diameter
                $chart.StrokeWidth = $StrokeWidth
                if ($boundParameters.ContainsKey('StrokeColor')) {
                    $sc = ConvertTo-VellumColor $StrokeColor
                    $chart.StrokeColor = [VellumPdf.Layout.Core.ColorRgb]::new($sc[0], $sc[1], $sc[2])
                }
                $chart.Alignment = [VellumPdf.Layout.Core.HorizontalAlignment]::$Alignment
                # The engine measures the start angle in radians from +X (counter-clockwise).
                $chart.StartAngle = $StartAngle * [math]::PI / 180
                $chart.Clockwise = -not $CounterClockwise
                if ($AltText) { $chart.AltText = $AltText }
                if ($Decorative) { $chart.Decorative = $true }

                Set-VellumPdfElementMargin -Element $chart -Top $MarginTop -Bottom $MarginBottom `
                    -BoundParameters $boundParameters -Document $Document
                [void]$Document.Add($chart)

                if ($Legend) {
                    $rows = [System.Collections.Generic.List[object]]::new()
                    $n = 0
                    foreach ($item in $items) {
                        $hex = '#{0:X2}{1:X2}{2:X2}' -f [int][math]::Round($item.Rgb[0] * 255), [int][math]::Round($item.Rgb[1] * 255), [int][math]::Round($item.Rgb[2] * 255)
                        $name = if ($item.Label) { $item.Label } else { "Slice $($n + 1)" }
                        $share = '{0:P1}' -f ($item.Value / $sum)
                        $rows.Add(@(@{ Text = ' '; Background = $hex }, $name, @{ Text = $share; Alignment = 'Right' }))
                        $n++
                    }
                    $tableArgs = @{ Document = $Document; Row = $rows.ToArray(); ColumnWidth = @(18, 0, 60); BorderWidth = 0 }
                    if ($FontHandle) { $tableArgs['FontHandle'] = $FontHandle }
                    [void](Add-VellumPdfTable @tableArgs)
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    process {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Data') {
                foreach ($item in $InputObject) { $collected.Add($item) }
            }
            else {
                & $buildChart $Slice
                $Document
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    end {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Data') {
                $specs = foreach ($obj in $collected) {
                    $label = if ($LabelProperty) { Get-VellumPdfPropertyValue -InputObject $obj -Name $LabelProperty }
                    @{ Value = (Get-VellumPdfPropertyValue -InputObject $obj -Name $ValueProperty); Label = $label }
                }
                & $buildChart @($specs)
                $Document
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
