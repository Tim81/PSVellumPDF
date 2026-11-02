function Add-VellumPdfShape {
    <#
    .SYNOPSIS
        Draws a rectangle, ellipse, arc or line on a page of a page-based document.
    .DESCRIPTION
        Coordinates are PDF points from the page's bottom-left corner (72 pt = 1
        inch). Rectangle and Ellipse take the lower-left corner (-X, -Y) and the
        size (-Width, -Height); an ellipse is inscribed in that box. A Line runs
        from (-X, -Y) to (-X2, -Y2). An Arc is part of a circle: (-X, -Y) is the centre,
        -Radius its size, and -StartAngle/-EndAngle (degrees, counter-clockwise from 3
        o'clock) the span; it is stroked, and a fill paints the segment between the arc
        and its chord.

        Colours are RGB triples in 0..1, hex ('#3366cc') or names; for CMYK use
        -FillCmyk / -StrokeCmyk with four values in 0..1. For colour-managed output give an
        ICC profile with -IccProfilePath and the colour in that profile's components with
        -FillIcc / -StrokeIcc (1, 3 or 4 values in 0..1 for a Gray, RGB/Lab or CMYK profile). A shape with neither a
        fill nor a stroke is stroked in black; a line is always stroked. Opacity is
        0 (transparent) to 1 (opaque).
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER Shape
        Rectangle, Ellipse, Arc or Line.
    .PARAMETER X
        Left edge (Rectangle/Ellipse) or start x (Line), in points.
    .PARAMETER Y
        Bottom edge (Rectangle/Ellipse) or start y (Line), in points.
    .PARAMETER Width
        Width of a Rectangle or Ellipse.
    .PARAMETER Height
        Height of a Rectangle or Ellipse.
    .PARAMETER Radius
        Arc: the radius in points.
    .PARAMETER StartAngle
        Arc: start angle in degrees, counter-clockwise from 3 o'clock.
    .PARAMETER EndAngle
        Arc: end angle in degrees (greater than -StartAngle for a counter-clockwise sweep).
    .PARAMETER IccProfilePath
        An ICC profile (.icc/.icm) that -FillIcc / -StrokeIcc colours are expressed in. The
        profile is embedded once per page and shared by all shapes that use it.
    .PARAMETER FillIcc
        Fill colour as components of the ICC profile (1, 3 or 4 values in 0..1).
    .PARAMETER StrokeIcc
        Outline colour as components of the ICC profile.
    .PARAMETER X2
        End x of a Line.
    .PARAMETER Y2
        End y of a Line.
    .PARAMETER FillColor
        Fill colour (RGB triple, hex or name).
    .PARAMETER FillGray
        Fill colour as a grey level, 0 (black) to 1 (white), written as DeviceGray.
    .PARAMETER StrokeGray
        Outline colour as a grey level, 0 (black) to 1 (white).
    .PARAMETER FillCmyk
        Fill colour as C,M,Y,K in 0..1.
    .PARAMETER StrokeColor
        Outline colour (RGB triple, hex or name).
    .PARAMETER StrokeCmyk
        Outline colour as C,M,Y,K in 0..1.
    .PARAMETER StrokeWidth
        Outline width in points (default 1).
    .PARAMETER LineCap
        How open line ends look: Butt (default), Round or Square.
    .PARAMETER LineJoin
        How corners look: Miter (default), Round or Bevel.
    .PARAMETER MiterLimit
        Longest miter, as a multiple of the line width, before a Miter join is bevelled.
    .PARAMETER AltText
        Alternate text. In a tagged page document the shape is then a Figure with this
        text; without it the shape is an artifact that assistive technology skips.
    .PARAMETER Dash
        Dash pattern in points, e.g. 4,2 (4 on, 2 off).
    .PARAMETER Opacity
        Fill opacity 0..1.
    .PARAMETER StrokeOpacity
        Outline opacity 0..1.
    .EXAMPLE
        $doc | Add-VellumPdfShape Rectangle -X 72 -Y 600 -Width 200 -Height 80 -FillColor '#e8f0fe' -StrokeColor navy
    .EXAMPLE
        $doc | Add-VellumPdfShape Line -X 72 -Y 590 -X2 523 -Y2 590 -StrokeWidth 2 -Dash 6,3
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Rectangle', 'Ellipse', 'Arc', 'Line')]
        [string]$Shape,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,
        [double]$Width,
        [double]$Height,
        [double]$X2,
        [double]$Y2,
        [ValidateRange(0.01, 1000000.0)] [double]$Radius,
        [double]$StartAngle,
        [double]$EndAngle,

        [string]$IccProfilePath,
        [ValidateRange(0.0, 1.0)] [double[]]$FillIcc,
        [ValidateRange(0.0, 1.0)] [double[]]$StrokeIcc,

        [object]$FillColor,
        [ValidateCount(4, 4)] [ValidateRange(0.0, 1.0)] [double[]]$FillCmyk,
        [ValidateRange(0.0, 1.0)] [double]$FillGray,
        [object]$StrokeColor,
        [ValidateCount(4, 4)] [ValidateRange(0.0, 1.0)] [double[]]$StrokeCmyk,
        [ValidateRange(0.0, 1.0)] [double]$StrokeGray,

        [ValidateRange(0.0, 10000.0)]
        [double]$StrokeWidth = 1,

        [ValidateRange(0.01, 10000.0)]
        [double[]]$Dash,

        [ValidateRange(0.0, 1.0)]
        [double]$Opacity,

        [ValidateRange(0.0, 1.0)]
        [double]$StrokeOpacity,

        [ValidateSet('Butt', 'Round', 'Square')]
        [string]$LineCap,

        [ValidateSet('Miter', 'Round', 'Bevel')]
        [string]$LineJoin,

        [ValidateRange(1.0, 100.0)]
        [double]$MiterLimit,

        # Alternate text: in a tagged document the shape becomes a Figure instead of an artifact.
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) }, ErrorMessage = '-AltText must not be empty or whitespace.')]
        [string]$AltText
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfShape'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $Page -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Add-VellumPdfShape'
            $bound = $PSBoundParameters
            foreach ($pair in @('X', $X), @('Y', $Y), @('Width', $Width), @('Height', $Height), @('X2', $X2), @('Y2', $Y2), @('Radius', $Radius)) {
                Assert-VellumPdfCoordinate $pair[1] $pair[0] 'Add-VellumPdfShape'
            }
            foreach ($angle in $StartAngle, $EndAngle) {
                if (-not [double]::IsFinite($angle)) { throw 'Add-VellumPdfShape: angles must be finite numbers.' }
            }
            if ($Shape -eq 'Line') {
                if (-not $bound.ContainsKey('X2') -or -not $bound.ContainsKey('Y2')) {
                    throw 'Add-VellumPdfShape: a Line needs -X2 and -Y2.'
                }
                if ($bound.ContainsKey('FillColor') -or $bound.ContainsKey('FillCmyk') -or $bound.ContainsKey('FillGray') -or $bound.ContainsKey('Opacity')) {
                    throw 'Add-VellumPdfShape: a Line has no fill; use -StrokeColor/-StrokeCmyk/-StrokeGray/-StrokeOpacity.'
                }
            }
            elseif ($Shape -eq 'Arc') {
                foreach ($req in 'Radius', 'StartAngle', 'EndAngle') {
                    if (-not $bound.ContainsKey($req)) { throw "Add-VellumPdfShape: an Arc needs -$req." }
                }
                foreach ($no in 'Width', 'Height', 'X2', 'Y2') {
                    if ($bound.ContainsKey($no)) { throw "Add-VellumPdfShape: -$no does not apply to an Arc; its size is -Radius." }
                }
            }
            else {
                if ($Width -le 0 -or $Height -le 0 -or -not $bound.ContainsKey('Width') -or -not $bound.ContainsKey('Height')) {
                    throw "Add-VellumPdfShape: a $Shape needs a positive -Width and -Height."
                }
                if ($bound.ContainsKey('X2') -or $bound.ContainsKey('Y2')) { throw "Add-VellumPdfShape: -X2/-Y2 apply to a Line only." }
            }
            if ($Shape -ne 'Arc') {
                foreach ($no in 'Radius', 'StartAngle', 'EndAngle') {
                    if ($bound.ContainsKey($no)) { throw "Add-VellumPdfShape: -$no applies to an Arc only." }
                }
            }
            foreach ($side in 'Fill', 'Stroke') {
                $models = @(@("${side}Color", "${side}Cmyk", "${side}Icc", "${side}Gray") | Where-Object { $bound.ContainsKey($_) })
                if ($models.Count -gt 1) { throw "Add-VellumPdfShape: give the $($side.ToLower()) colour as RGB/hex/name, CMYK, grey or ICC components, not several." }
            }
            $hasIcc = $bound.ContainsKey('FillIcc') -or $bound.ContainsKey('StrokeIcc')
            if ($hasIcc -ne $bound.ContainsKey('IccProfilePath')) {
                throw 'Add-VellumPdfShape: -IccProfilePath and -FillIcc/-StrokeIcc go together; give both.'
            }
            if ($Shape -eq 'Line' -and $bound.ContainsKey('FillIcc')) { throw 'Add-VellumPdfShape: a Line has no fill; use -StrokeIcc.' }
            if (($bound.ContainsKey('FillIcc') -and ($bound.ContainsKey('FillColor') -or $bound.ContainsKey('FillCmyk'))) -or
                ($bound.ContainsKey('StrokeIcc') -and ($bound.ContainsKey('StrokeColor') -or $bound.ContainsKey('StrokeCmyk')))) {
                throw 'Add-VellumPdfShape: give a colour as RGB/hex/name, CMYK, or ICC components, not several.'
            }
            if (($bound.ContainsKey('FillColor') -and $bound.ContainsKey('FillCmyk')) -or
                ($bound.ContainsKey('StrokeColor') -and $bound.ContainsKey('StrokeCmyk'))) {
                throw 'Add-VellumPdfShape: give a colour as RGB/hex/name or as CMYK, not both.'
            }

            if (($bound.ContainsKey('FillCmyk') -or $bound.ContainsKey('StrokeCmyk')) -and
                (Get-VellumPdfConformanceRequirement -Document $Document).IsPdfA -and
                -not $Document.PSObject.Properties['PSVellumCmykIntent']) {
                Write-Warning ('Add-VellumPdfShape: PDF/A allows CMYK colour only with a CMYK output intent. Call ' +
                    'Set-VellumPdfOutputIntent -Cmyk on this document, or use RGB colours.')
            }
            $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfShape'
            $iccName = $null
            if ($hasIcc) {
                $icc = Register-VellumPdfIccSpace -Document $Document -Page $Page -IccProfilePath $IccProfilePath -CommandName 'Add-VellumPdfShape'
                $iccCount = $icc.Count
                $iccName = $icc.Name
                foreach ($pair in @(@('FillIcc', $FillIcc), @('StrokeIcc', $StrokeIcc))) {
                    if ($bound.ContainsKey($pair[0]) -and @($pair[1]).Count -ne $iccCount) {
                        throw "Add-VellumPdfShape: -$($pair[0]) needs $iccCount value(s) for this profile; got $(@($pair[1]).Count)."
                    }
                }
            }
            $hasFill = $bound.ContainsKey('FillColor') -or $bound.ContainsKey('FillCmyk') -or $bound.ContainsKey('FillIcc') -or $bound.ContainsKey('FillGray')
            # Any stroke option asks for an outline (black unless a colour is given), even beside a fill.
            $strokeRequested = $bound.ContainsKey('LineCap') -or $bound.ContainsKey('LineJoin') -or $bound.ContainsKey('MiterLimit') -or $bound.ContainsKey('StrokeColor') -or $bound.ContainsKey('StrokeCmyk') -or $bound.ContainsKey('StrokeIcc') -or $bound.ContainsKey('StrokeGray') -or $bound.ContainsKey('StrokeWidth') -or
                $bound.ContainsKey('Dash') -or $bound.ContainsKey('StrokeOpacity')
            $hasStroke = $strokeRequested -or $Shape -eq 'Line' -or -not $hasFill

            [void]$canvas.SaveState()
            try {
                # Tagged documents: decorative graphics are artifacts; -AltText makes the shape a Figure.
                $tagKind = if ($AltText) { 'Structure' } else { 'Artifact' }
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $Document.Pages[$Page - 1] -Kind $tagKind -StructType Figure -AltText $AltText -Draw {
                if ($bound.ContainsKey('FillColor')) { $c = ConvertTo-VellumColor $FillColor; [void]$canvas.SetFillColorRgb($c[0], $c[1], $c[2]) }
                if ($bound.ContainsKey('FillGray')) { [void]$canvas.SetFillColorGray($FillGray) }
                if ($bound.ContainsKey('FillCmyk')) { [void]$canvas.SetFillColorCmyk($FillCmyk[0], $FillCmyk[1], $FillCmyk[2], $FillCmyk[3]) }
                if ($bound.ContainsKey('StrokeColor')) { $c = ConvertTo-VellumColor $StrokeColor; [void]$canvas.SetStrokeColorRgb($c[0], $c[1], $c[2]) }
                if ($bound.ContainsKey('StrokeGray')) { [void]$canvas.SetStrokeColorGray($StrokeGray) }
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

                switch ($Shape) {
                    'Rectangle' { [void]$canvas.Rectangle($X, $Y, $Width, $Height) }
                    'Line' { [void]$canvas.MoveTo($X, $Y).LineTo($X2, $Y2) }
                    'Arc' {
                        $toRadians = [math]::PI / 180
                        $from = $StartAngle * $toRadians
                        # AppendArc extends the current path, so start it at the arc's first point.
                        [void]$canvas.MoveTo($X + $Radius * [math]::Cos($from), $Y + $Radius * [math]::Sin($from))
                        [void]$canvas.AppendArc($X, $Y, $Radius, $from, $EndAngle * $toRadians)
                    }
                    'Ellipse' {
                        # Four cubic Beziers; k is the standard circle-approximation constant.
                        $k = 0.5522847498
                        $rx = $Width / 2; $ry = $Height / 2
                        $cx = $X + $rx; $cy = $Y + $ry
                        [void]$canvas.MoveTo($cx + $rx, $cy)
                        [void]$canvas.CurveTo($cx + $rx, $cy + $k * $ry, $cx + $k * $rx, $cy + $ry, $cx, $cy + $ry)
                        [void]$canvas.CurveTo($cx - $k * $rx, $cy + $ry, $cx - $rx, $cy + $k * $ry, $cx - $rx, $cy)
                        [void]$canvas.CurveTo($cx - $rx, $cy - $k * $ry, $cx - $k * $rx, $cy - $ry, $cx, $cy - $ry)
                        [void]$canvas.CurveTo($cx + $k * $rx, $cy - $ry, $cx + $rx, $cy - $k * $ry, $cx + $rx, $cy)
                        [void]$canvas.ClosePath()
                    }
                }
                if ($Shape -eq 'Line') { [void]$canvas.Stroke() }
                elseif ($hasFill -and $strokeRequested) { [void]$canvas.FillAndStroke() }
                elseif ($hasFill) { [void]$canvas.Fill() }
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
