function Use-VellumPdfTransform {
    <#
    .SYNOPSIS
        Runs a script block whose page drawing is rotated, scaled and/or moved.
    .DESCRIPTION
        Everything drawn on the page by the script block (Add-VellumPdfShape, -Path, -Text, -TextBox,
        -PageImage, -PageBarcode, -Gradient, Invoke-VellumPdfCanvas ...) is transformed; the
        transformation ends with the block, even if it throws. Scopes can be nested.

        The transformation is applied in this order: scale about the origin, rotate about the origin,
        then move. The origin is -OriginX/-OriginY (default the page's bottom-left corner), so to
        rotate a stamp about its own centre give that centre as the origin. Rotation is in degrees,
        counter-clockwise.

        Coordinates inside the block are the ones you would have used without the transform; only
        the result moves. A block that draws on another page than -Page is not transformed there
        (a warning says so).

        Links and form fields (Add-VellumPdfLink, Add-VellumPdfFormField) are annotations placed in page
        coordinates and are not transformed, nor clipped by Use-VellumPdfClip.

        The block runs in the caller's scope with the document as $_. Its own output is discarded;
        the cmdlet writes the document to the pipeline, so the call chains.
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER ScriptBlock
        The drawing to transform.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER Rotate
        Rotation in degrees, counter-clockwise (negative is clockwise).
    .PARAMETER Scale
        One factor for both directions, or two (horizontal, vertical). Negative values mirror. The size of
        a factor is limited to 0.000001 ... 1,000,000.
    .PARAMETER OriginX
        x of the point the scale and rotation are about, in points (default 0).
    .PARAMETER OriginY
        y of the point the scale and rotation are about, in points (default 0).
    .PARAMETER TranslateX
        Horizontal move applied last, in points.
    .PARAMETER TranslateY
        Vertical move applied last, in points.
    .EXAMPLE
        # A diagonal "DRAFT" stamp, rotated 45 degrees about the page centre.
        $doc | Use-VellumPdfTransform -Rotate 45 -OriginX 297 -OriginY 421 -ScriptBlock {
            $_ | Add-VellumPdfText 'DRAFT' -X 297 -Y 421 -FontSize 80 -Font HelveticaBold -Align Center -Color '#cccccc'
        }
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [double]$Rotate = 0,

        [ValidateCount(1, 2)]
        [double[]]$Scale = @(1.0),

        [double]$OriginX = 0,
        [double]$OriginY = 0,
        [double]$TranslateX = 0,
        [double]$TranslateY = 0
    )

    process {
        try {
            Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Use-VellumPdfTransform'
            $Page = Resolve-VellumPdfPageNumber -Document $Document -Page $(if ($PSBoundParameters.ContainsKey('Page')) { $PSBoundParameters['Page'] } else { 1 }) -Bound $PSBoundParameters.ContainsKey('Page') -CommandName 'Use-VellumPdfTransform'
            if (-not [double]::IsFinite($Rotate)) { throw 'Use-VellumPdfTransform: -Rotate must be a finite number of degrees.' }
            foreach ($factor in $Scale) {
                if (-not [double]::IsFinite($factor) -or $factor -eq 0 -or [Math]::Abs($factor) -lt 1e-6 -or [Math]::Abs($factor) -gt 1e6) {
                    throw 'Use-VellumPdfTransform: -Scale must be finite, not zero, and between 0.000001 and 1,000,000 in size (a smaller factor collapses the drawing; a larger one overflows the numbers PDF allows).'
                }
            }
            foreach ($pair in @('OriginX', $OriginX), @('OriginY', $OriginY), @('TranslateX', $TranslateX), @('TranslateY', $TranslateY)) {
                Assert-VellumPdfCoordinate $pair[1] $pair[0] 'Use-VellumPdfTransform'
            }
            $sx = $Scale[0]
            $sy = if ($Scale.Count -gt 1) { $Scale[1] } else { $Scale[0] }
            $radians = $Rotate * [math]::PI / 180
            $cos = [math]::Cos($radians)
            $sin = [math]::Sin($radians)
            # p' = O + R * S * (p - O) + T, written as the PDF matrix [a b c d e f].
            $a = $sx * $cos; $b = $sx * $sin; $c = -$sy * $sin; $d = $sy * $cos
            $e = $OriginX - ($a * $OriginX + $c * $OriginY) + $TranslateX
            $f = $OriginY - ($b * $OriginX + $d * $OriginY) + $TranslateY
            # Rounding (and + 0.0) keeps floating-point dust and "-0" out of the content stream.
            $a, $b, $c, $d, $e, $f = $a, $b, $c, $d, $e, $f | ForEach-Object { [math]::Round($_, 8) + 0.0 }
            if (($a, $b, $c, $d | Where-Object { $_ -ne 0 }).Count -eq 0) { throw 'Use-VellumPdfTransform: the transformation collapses everything to a point.' }
            $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Use-VellumPdfTransform'
            [void]$canvas.SaveState()
            Push-VellumPdfScopePage -Document $Document -Page $Page
            try {
                [void]$canvas.Concat($a, $b, $c, $d, $e, $f)
                $null = $Document | ForEach-Object -Process $ScriptBlock
            }
            finally { Pop-VellumPdfScopePage -Document $Document; [void]$canvas.RestoreState() }
            $Document
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Use-VellumPdfTransform'))
        }
    }
}
