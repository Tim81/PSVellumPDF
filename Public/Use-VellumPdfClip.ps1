function Use-VellumPdfClip {
    <#
    .SYNOPSIS
        Runs a script block whose page drawing is clipped to a region.
    .DESCRIPTION
        Everything drawn on the page by the script block (Add-VellumPdfShape, -Path,
        -Text, -Gradient, -PageImage, Invoke-VellumPdfCanvas ...) is visible only inside the
        clip region; the clip is lifted again when the block ends, even if it throws. Clip
        scopes can be nested, which intersects the regions.

        Give the region as -Data/-Point (see Add-VellumPdfPath), as a rectangle with
        -X/-Y/-Width/-Height, or as an ellipse with -Ellipse. The default -FillRule NonZero
        or EvenOdd decides what is inside when sub-paths overlap.

        Links and form fields (Add-VellumPdfLink, Add-VellumPdfFormField) are annotations in page coordinates
        and are not affected by the clip.

        The block runs in the caller's scope with the document as $_. Its own output is
        discarded; the cmdlet writes the document to the pipeline, so the call chains.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER ScriptBlock
        The drawing to clip.
    .PARAMETER Data
        Path data for the region, e.g. 'M 100 100 L 300 100 L 200 250 Z'.
    .PARAMETER Point
        Polygon vertices as x,y pairs.
    .PARAMETER X
        Rectangle/ellipse left edge.
    .PARAMETER Y
        Rectangle/ellipse bottom edge.
    .PARAMETER Width
        Rectangle/ellipse width.
    .PARAMETER Height
        Rectangle/ellipse height.
    .PARAMETER Ellipse
        Make the box an ellipse instead of a rectangle.
    .PARAMETER FillRule
        NonZero (default) or EvenOdd.
    .EXAMPLE
        $doc | Use-VellumPdfClip -X 72 -Y 500 -Width 200 -Height 100 -Ellipse -ScriptBlock {
            $_ | Add-VellumPdfGradient -Direction LeftToRight -X 72 -Y 500 -Width 200 -Height 100 -StartColor red -EndColor blue
        }
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Box')]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory, ParameterSetName = 'Data')]
        [ValidateNotNullOrEmpty()]
        [string]$Data,

        [Parameter(Mandatory, ParameterSetName = 'Point')]
        [ValidateNotNull()]
        [object[]]$Point,

        [Parameter(Mandatory, ParameterSetName = 'Box')] [double]$X,
        [Parameter(Mandatory, ParameterSetName = 'Box')] [double]$Y,
        [Parameter(Mandatory, ParameterSetName = 'Box')] [ValidateRange(0.01, 1000000.0)] [double]$Width,
        [Parameter(Mandatory, ParameterSetName = 'Box')] [ValidateRange(0.01, 1000000.0)] [double]$Height,
        [Parameter(ParameterSetName = 'Box')] [switch]$Ellipse,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [ValidateSet('NonZero', 'EvenOdd')]
        [string]$FillRule = 'NonZero'
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Use-VellumPdfClip'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $(if ($PSBoundParameters.ContainsKey('Page')) { $PSBoundParameters['Page'] } else { 1 }) -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Use-VellumPdfClip'
            switch ($PSCmdlet.ParameterSetName) {
                'Data' { $ops = ConvertTo-VellumPdfPathOp -Data $Data -CommandName 'Use-VellumPdfClip' }
                'Point' { $ops = ConvertTo-VellumPdfPathOp -Point $Point -Close -CommandName 'Use-VellumPdfClip' }
                default {
                    foreach ($pair in @('X', $X), @('Y', $Y), @('Width', $Width), @('Height', $Height)) {
                        Assert-VellumPdfCoordinate $pair[1] $pair[0] 'Use-VellumPdfClip'
                    }
                    if ($Ellipse) {
                        $k = 0.5522847498
                        $rx = $Width / 2; $ry = $Height / 2
                        $cx = $X + $rx; $cy = $Y + $ry
                        $kx = $k * $rx; $ky = $k * $ry
                        $ops = @(
                            [pscustomobject]@{ Op = 'M'; Args = [double[]]@(($cx + $rx), $cy) }
                            [pscustomobject]@{ Op = 'C'; Args = [double[]]@(($cx + $rx), ($cy + $ky), ($cx + $kx), ($cy + $ry), $cx, ($cy + $ry)) }
                            [pscustomobject]@{ Op = 'C'; Args = [double[]]@(($cx - $kx), ($cy + $ry), ($cx - $rx), ($cy + $ky), ($cx - $rx), $cy) }
                            [pscustomobject]@{ Op = 'C'; Args = [double[]]@(($cx - $rx), ($cy - $ky), ($cx - $kx), ($cy - $ry), $cx, ($cy - $ry)) }
                            [pscustomobject]@{ Op = 'C'; Args = [double[]]@(($cx + $kx), ($cy - $ry), ($cx + $rx), ($cy - $ky), ($cx + $rx), $cy) }
                            [pscustomobject]@{ Op = 'Z'; Args = [double[]]@() }
                        )
                    }
                    else {
                        $ops = @(
                            [pscustomobject]@{ Op = 'M'; Args = [double[]]@($X, $Y) }
                            [pscustomobject]@{ Op = 'L'; Args = [double[]]@(($X + $Width), $Y) }
                            [pscustomobject]@{ Op = 'L'; Args = [double[]]@(($X + $Width), ($Y + $Height)) }
                            [pscustomobject]@{ Op = 'L'; Args = [double[]]@($X, ($Y + $Height)) }
                            [pscustomobject]@{ Op = 'Z'; Args = [double[]]@() }
                        )
                    }
                }
            }
            $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Use-VellumPdfClip'
            [void]$canvas.SaveState()
            Push-VellumPdfScopePage -Document $Document -Page $Page
            try {
                Write-VellumPdfPathOp -Canvas $canvas -Ops $ops
                if ($FillRule -eq 'EvenOdd') { [void]$canvas.ClipEvenOdd() } else { [void]$canvas.Clip() }
                [void]$canvas.EndPath()
                # Run in the caller's scope with the document as $_; the block's own output is dropped.
                $null = $Document | ForEach-Object -Process $ScriptBlock
            }
            finally { Pop-VellumPdfScopePage -Document $Document; [void]$canvas.RestoreState() }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
