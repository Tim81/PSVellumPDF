function Add-VellumPdfPath {
    <#
    .SYNOPSIS
        Draws a free-form path (lines and Bezier curves) on a page of a page-based document.
    .DESCRIPTION
        Describe the outline with -Data, a small subset of SVG path syntax in PDF points
        (72 pt = 1 inch, origin at the page's bottom-left):

            M x y                        move to (starts a sub-path)
            L x y                        straight line to
            C x1 y1 x2 y2 x y            cubic Bezier curve to
            Z                            close the current sub-path

        Only upper-case absolute commands are accepted; numbers after a command may repeat
        (L 10 10 20 20 draws two lines). A path may hold several sub-paths, for example a
        ring made of an outer and an inner circle. Alternatively give a polyline or polygon
        as x,y pairs with -Point (add -Close for a polygon).

        -FillRule decides which areas count as inside when sub-paths overlap: NonZero
        (default) or EvenOdd, which cuts the inner sub-path out of the outer one. A path
        with neither a fill nor a stroke is stroked in black. The PDF operator for
        "fill even-odd and stroke" does not exist in the engine, so an EvenOdd path with both
        is painted as a fill followed by a stroke of the same outline; the result is the same.

        Colours, dashes, caps, joins and opacity work as in Add-VellumPdfShape, including
        -FillCmyk/-StrokeCmyk and ICC colours (-IccProfilePath with -FillIcc/-StrokeIcc).
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER Data
        Path data, e.g. 'M 100 100 L 200 100 L 150 180 Z'.
    .PARAMETER Point
        Polyline or polygon vertices as x,y pairs, e.g. (100,100),(200,100),(150,180).
    .PARAMETER Close
        Close the -Point outline into a polygon.
    .PARAMETER FillRule
        NonZero (default) or EvenOdd.
    .PARAMETER IccProfilePath
        An ICC profile that -FillIcc / -StrokeIcc colours are expressed in.
    .PARAMETER FillIcc
        Fill colour as components of the ICC profile (1, 3 or 4 values in 0..1).
    .PARAMETER StrokeIcc
        Outline colour as components of the ICC profile.
    .PARAMETER FillColor
        Fill colour (RGB triple, hex or name).
    .PARAMETER FillCmyk
        Fill colour as C,M,Y,K in 0..1.
    .PARAMETER StrokeColor
        Outline colour (RGB triple, hex or name).
    .PARAMETER StrokeCmyk
        Outline colour as C,M,Y,K in 0..1.
    .PARAMETER StrokeWidth
        Outline width in points (default 1).
    .PARAMETER Dash
        Dash pattern in points, e.g. 4,2.
    .PARAMETER LineCap
        Butt (default), Round or Square.
    .PARAMETER LineJoin
        Miter (default), Round or Bevel.
    .PARAMETER MiterLimit
        Longest miter, as a multiple of the line width, before a Miter join is bevelled.
    .PARAMETER Opacity
        Fill opacity 0..1.
    .PARAMETER StrokeOpacity
        Outline opacity 0..1.
    .PARAMETER AltText
        Alternate text. In a tagged page document the path is then a Figure with this text;
        without it the path is an artifact that assistive technology skips.
    .EXAMPLE
        $doc | Add-VellumPdfPath -Data 'M 100 100 L 200 100 L 150 180 Z' -FillColor '#f4b400' -StrokeColor black
    .EXAMPLE
        # A ring: two circles, the inner one cut out by the even-odd rule.
        $k = 0.5522847498
        $ring = 'M 250 400 C 250 {0} {1} 450 200 450 C {2} 450 150 {0} 150 400 C 150 {3} {2} 350 200 350 C {1} 350 250 {3} 250 400' -f 400+$k*50, 200+$k*50, 200-$k*50, 400-$k*50
        $doc | Add-VellumPdfPath -Data $ring -FillRule EvenOdd -FillColor navy
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Data')]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Data')]
        [ValidateNotNullOrEmpty()]
        [string]$Data,

        [Parameter(Mandatory, ParameterSetName = 'Point')]
        [ValidateNotNull()]
        [object[]]$Point,

        [Parameter(ParameterSetName = 'Point')]
        [switch]$Close,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [ValidateSet('NonZero', 'EvenOdd')]
        [string]$FillRule = 'NonZero',

        [string]$IccProfilePath,
        [ValidateRange(0, 1)] [double[]]$FillIcc,
        [ValidateRange(0, 1)] [double[]]$StrokeIcc,

        [object]$FillColor,
        [ValidateCount(4, 4)] [ValidateRange(0, 1)] [double[]]$FillCmyk,
        [object]$StrokeColor,
        [ValidateCount(4, 4)] [ValidateRange(0, 1)] [double[]]$StrokeCmyk,

        [ValidateRange(0, 10000)]
        [double]$StrokeWidth = 1,

        [ValidateRange(0.01, 10000)]
        [double[]]$Dash,

        [ValidateSet('Butt', 'Round', 'Square')]
        [string]$LineCap,

        [ValidateSet('Miter', 'Round', 'Bevel')]
        [string]$LineJoin,

        [ValidateRange(1, 100)]
        [double]$MiterLimit,

        [ValidateRange(0, 1)]
        [double]$Opacity,

        [ValidateRange(0, 1)]
        [double]$StrokeOpacity,

        [ValidateNotNullOrEmpty()]
        [string]$AltText
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfPath'
            $bound = $PSBoundParameters
            $hasIcc = $bound.ContainsKey('FillIcc') -or $bound.ContainsKey('StrokeIcc')
            if ($hasIcc -ne $bound.ContainsKey('IccProfilePath')) {
                throw 'Add-VellumPdfPath: -IccProfilePath and -FillIcc/-StrokeIcc go together; give both.'
            }
            if (($bound.ContainsKey('FillIcc') -and ($bound.ContainsKey('FillColor') -or $bound.ContainsKey('FillCmyk'))) -or
                ($bound.ContainsKey('StrokeIcc') -and ($bound.ContainsKey('StrokeColor') -or $bound.ContainsKey('StrokeCmyk'))) -or
                ($bound.ContainsKey('FillColor') -and $bound.ContainsKey('FillCmyk')) -or
                ($bound.ContainsKey('StrokeColor') -and $bound.ContainsKey('StrokeCmyk'))) {
                throw 'Add-VellumPdfPath: give a colour as RGB/hex/name, CMYK, or ICC components, not several.'
            }
            if ($PSCmdlet.ParameterSetName -eq 'Point') {
                $ops = ConvertTo-VellumPdfPathOps -Point $Point -Close:$Close -CommandName 'Add-VellumPdfPath'
            }
            else {
                $ops = ConvertTo-VellumPdfPathOps -Data $Data -CommandName 'Add-VellumPdfPath'
            }
            if (($bound.ContainsKey('FillCmyk') -or $bound.ContainsKey('StrokeCmyk')) -and
                $Document.Conformance -ne [VellumPdf.Document.PdfConformance]::None -and
                -not $Document.PSObject.Properties['PSVellumCmykIntent']) {
                Write-Warning ('Add-VellumPdfPath: PDF/A allows CMYK colour only with a CMYK output intent. Call ' +
                    'Set-VellumPdfOutputIntent -Cmyk on this document, or use RGB colours.')
            }
            $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfPath'
            $iccName = $null
            if ($hasIcc) {
                $icc = Register-VellumPdfIccSpace -Document $Document -Page $Page -IccProfilePath $IccProfilePath -CommandName 'Add-VellumPdfPath'
                $iccName = $icc.Name
                foreach ($pair in @(@('FillIcc', $FillIcc), @('StrokeIcc', $StrokeIcc))) {
                    if ($bound.ContainsKey($pair[0]) -and @($pair[1]).Count -ne $icc.Count) {
                        throw "Add-VellumPdfPath: -$($pair[0]) needs $($icc.Count) value(s) for this profile; got $(@($pair[1]).Count)."
                    }
                }
            }
            $hasFill = $bound.ContainsKey('FillColor') -or $bound.ContainsKey('FillCmyk') -or $bound.ContainsKey('FillIcc')
            $strokeRequested = $bound.ContainsKey('LineCap') -or $bound.ContainsKey('LineJoin') -or $bound.ContainsKey('MiterLimit') -or
                $bound.ContainsKey('StrokeColor') -or $bound.ContainsKey('StrokeCmyk') -or $bound.ContainsKey('StrokeIcc') -or
                $bound.ContainsKey('StrokeWidth') -or $bound.ContainsKey('Dash') -or $bound.ContainsKey('StrokeOpacity')
            $hasStroke = $strokeRequested -or -not $hasFill

            [void]$canvas.SaveState()
            try {
                $tagKind = if ($AltText) { 'Structure' } else { 'Artifact' }
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $Document.Pages[$Page - 1] -Kind $tagKind -StructType Figure -AltText $AltText -Draw {
                    if ($bound.ContainsKey('FillColor')) { $c = ConvertTo-VellumColor $FillColor; [void]$canvas.SetFillColorRgb($c[0], $c[1], $c[2]) }
                    if ($bound.ContainsKey('FillCmyk')) { [void]$canvas.SetFillColorCmyk($FillCmyk[0], $FillCmyk[1], $FillCmyk[2], $FillCmyk[3]) }
                    if ($bound.ContainsKey('StrokeColor')) { $c = ConvertTo-VellumColor $StrokeColor; [void]$canvas.SetStrokeColorRgb($c[0], $c[1], $c[2]) }
                    if ($bound.ContainsKey('StrokeCmyk')) { [void]$canvas.SetStrokeColorCmyk($StrokeCmyk[0], $StrokeCmyk[1], $StrokeCmyk[2], $StrokeCmyk[3]) }
                    if ($bound.ContainsKey('FillIcc')) {
                        [void]$canvas.SetFillColorSpace($iccName)
                        [void][PSVellumPDF.Interop.CanvasHelpers]::SetFillColor($canvas, $FillIcc)
                    }
                    if ($bound.ContainsKey('StrokeIcc')) {
                        [void]$canvas.SetStrokeColorSpace($iccName)
                        [void][PSVellumPDF.Interop.CanvasHelpers]::SetStrokeColor($canvas, $StrokeIcc)
                    }
                    if ($bound.ContainsKey('Opacity')) { [void]$canvas.SetFillAlpha($Opacity) }
                    if ($bound.ContainsKey('StrokeOpacity')) { [void]$canvas.SetStrokeAlpha($StrokeOpacity) }
                    if ($hasStroke) {
                        [void]$canvas.SetLineWidth($StrokeWidth)
                        if ($bound.ContainsKey('LineCap')) { [void]$canvas.SetLineCap(@{ Butt = 0; Round = 1; Square = 2 }[$LineCap]) }
                        if ($bound.ContainsKey('LineJoin')) { [void]$canvas.SetLineJoin(@{ Miter = 0; Round = 1; Bevel = 2 }[$LineJoin]) }
                        if ($bound.ContainsKey('MiterLimit')) { [void]$canvas.SetMiterLimit($MiterLimit) }
                        if ($Dash) { [void][PSVellumPDF.Interop.CanvasHelpers]::SetLineDash($canvas, $Dash, 0) }
                    }

                    Write-VellumPdfPathOps -Canvas $canvas -Ops $ops
                    if ($hasFill -and $hasStroke) {
                        if ($FillRule -eq 'EvenOdd') {
                            # No fill-even-odd-and-stroke operator: paint the fill, then the same outline again as a stroke.
                            [void]$canvas.FillEvenOdd()
                            Write-VellumPdfPathOps -Canvas $canvas -Ops $ops
                            [void]$canvas.Stroke()
                        }
                        else { [void]$canvas.FillAndStroke() }
                    }
                    elseif ($hasFill) {
                        if ($FillRule -eq 'EvenOdd') { [void]$canvas.FillEvenOdd() } else { [void]$canvas.Fill() }
                    }
                    else { [void]$canvas.Stroke() }
                }
            }
            finally { [void]$canvas.RestoreState() }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
