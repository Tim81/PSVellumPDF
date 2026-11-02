function Add-VellumPdfShape {
    <#
    .SYNOPSIS
        Draws a rectangle, ellipse or line on a page of a page-based document.
    .DESCRIPTION
        Coordinates are PDF points from the page's bottom-left corner (72 pt = 1
        inch). Rectangle and Ellipse take the lower-left corner (-X, -Y) and the
        size (-Width, -Height); an ellipse is inscribed in that box. A Line runs
        from (-X, -Y) to (-X2, -Y2).

        Colours are RGB triples in 0..1, hex ('#3366cc') or names; for CMYK use
        -FillCmyk / -StrokeCmyk with four values in 0..1. A shape with neither a
        fill nor a stroke is stroked in black; a line is always stroked. Opacity is
        0 (transparent) to 1 (opaque).
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER Shape
        Rectangle, Ellipse or Line.
    .PARAMETER X
        Left edge (Rectangle/Ellipse) or start x (Line), in points.
    .PARAMETER Y
        Bottom edge (Rectangle/Ellipse) or start y (Line), in points.
    .PARAMETER Width
        Width of a Rectangle or Ellipse.
    .PARAMETER Height
        Height of a Rectangle or Ellipse.
    .PARAMETER X2
        End x of a Line.
    .PARAMETER Y2
        End y of a Line.
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
        [ValidateSet('Rectangle', 'Ellipse', 'Line')]
        [string]$Shape,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,
        [double]$Width,
        [double]$Height,
        [double]$X2,
        [double]$Y2,

        [object]$FillColor,
        [ValidateCount(4, 4)] [ValidateRange(0, 1)] [double[]]$FillCmyk,
        [object]$StrokeColor,
        [ValidateCount(4, 4)] [ValidateRange(0, 1)] [double[]]$StrokeCmyk,

        [ValidateRange(0, 10000)]
        [double]$StrokeWidth = 1,

        [ValidateRange(0.01, 10000)]
        [double[]]$Dash,

        [ValidateRange(0, 1)]
        [double]$Opacity,

        [ValidateRange(0, 1)]
        [double]$StrokeOpacity
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfShape'
        $bound = $PSBoundParameters
        foreach ($v in $X, $Y, $Width, $Height, $X2, $Y2) {
            if (-not [double]::IsFinite($v)) { throw 'Add-VellumPdfShape: coordinates and sizes must be finite numbers.' }
        }
        if ($Shape -eq 'Line') {
            if (-not $bound.ContainsKey('X2') -or -not $bound.ContainsKey('Y2')) {
                throw 'Add-VellumPdfShape: a Line needs -X2 and -Y2.'
            }
            if ($bound.ContainsKey('FillColor') -or $bound.ContainsKey('FillCmyk') -or $bound.ContainsKey('Opacity')) {
                throw 'Add-VellumPdfShape: a Line has no fill; use -StrokeColor/-StrokeCmyk/-StrokeOpacity.'
            }
        }
        else {
            if ($Width -le 0 -or $Height -le 0 -or -not $bound.ContainsKey('Width') -or -not $bound.ContainsKey('Height')) {
                throw "Add-VellumPdfShape: a $Shape needs a positive -Width and -Height."
            }
            if ($bound.ContainsKey('X2') -or $bound.ContainsKey('Y2')) { throw "Add-VellumPdfShape: -X2/-Y2 apply to a Line only." }
        }
        if (($bound.ContainsKey('FillColor') -and $bound.ContainsKey('FillCmyk')) -or
            ($bound.ContainsKey('StrokeColor') -and $bound.ContainsKey('StrokeCmyk'))) {
            throw 'Add-VellumPdfShape: give a colour as RGB/hex/name or as CMYK, not both.'
        }

        if (($bound.ContainsKey('FillCmyk') -or $bound.ContainsKey('StrokeCmyk')) -and
            $Document.Conformance -ne [VellumPdf.Document.PdfConformance]::None -and
            -not $Document.PSObject.Properties['PSVellumCmykIntent']) {
            Write-Warning ('Add-VellumPdfShape: PDF/A allows CMYK colour only with a CMYK output intent. Call ' +
                'Set-VellumPdfOutputIntent -Cmyk on this document, or use RGB colours.')
        }
        $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfShape'
        $hasFill = $bound.ContainsKey('FillColor') -or $bound.ContainsKey('FillCmyk')
        $hasStroke = $bound.ContainsKey('StrokeColor') -or $bound.ContainsKey('StrokeCmyk') -or $Shape -eq 'Line' -or -not $hasFill

        [void]$canvas.SaveState()
        try {
            if ($bound.ContainsKey('FillColor')) { $c = ConvertTo-VellumColor $FillColor; [void]$canvas.SetFillColorRgb($c[0], $c[1], $c[2]) }
            if ($bound.ContainsKey('FillCmyk')) { [void]$canvas.SetFillColorCmyk($FillCmyk[0], $FillCmyk[1], $FillCmyk[2], $FillCmyk[3]) }
            if ($bound.ContainsKey('StrokeColor')) { $c = ConvertTo-VellumColor $StrokeColor; [void]$canvas.SetStrokeColorRgb($c[0], $c[1], $c[2]) }
            if ($bound.ContainsKey('StrokeCmyk')) { [void]$canvas.SetStrokeColorCmyk($StrokeCmyk[0], $StrokeCmyk[1], $StrokeCmyk[2], $StrokeCmyk[3]) }
            if ($bound.ContainsKey('Opacity')) { [void]$canvas.SetFillAlpha($Opacity) }
            if ($bound.ContainsKey('StrokeOpacity')) { [void]$canvas.SetStrokeAlpha($StrokeOpacity) }
            if ($hasStroke) {
                [void]$canvas.SetLineWidth($StrokeWidth)
                if ($Dash) { [void][PSVellumPDF.Interop.CanvasHelpers]::SetLineDash($canvas, $Dash, 0) }
            }

            switch ($Shape) {
                'Rectangle' { [void]$canvas.Rectangle($X, $Y, $Width, $Height) }
                'Line' { [void]$canvas.MoveTo($X, $Y).LineTo($X2, $Y2) }
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
            elseif ($hasFill -and $hasStroke -and ($bound.ContainsKey('StrokeColor') -or $bound.ContainsKey('StrokeCmyk'))) { [void]$canvas.FillAndStroke() }
            elseif ($hasFill) { [void]$canvas.Fill() }
            else { [void]$canvas.Stroke() }
        }
        finally { [void]$canvas.RestoreState() }
        $Document
    }
}
