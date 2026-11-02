function Add-VellumPdfGradient {
    <#
    .SYNOPSIS
        Fills a rectangle on a page with a two-colour gradient.
    .DESCRIPTION
        Paints an axial (linear) or radial gradient clipped to the rectangle at
        (-X, -Y) of size -Width x -Height, in points from the page's bottom-left.
        -Direction chooses how a linear gradient runs: LeftToRight (default),
        BottomToTop, or Diagonal (bottom-left to top-right). A radial gradient runs
        from the centre (-StartColor) to the corners (-EndColor).
    .PARAMETER Document
        A document from New-VellumPdfPageDocument.
    .PARAMETER Page
        The 1-based page number. Default 1.
    .PARAMETER X
        Left edge in points.
    .PARAMETER Y
        Bottom edge in points.
    .PARAMETER Width
        Width in points.
    .PARAMETER Height
        Height in points.
    .PARAMETER StartColor
        First colour: RGB triple in 0..1, hex or name.
    .PARAMETER EndColor
        Second colour.
    .PARAMETER Type
        Axial (default) or Radial.
    .PARAMETER AltText
        Alternate text. In a tagged page document the gradient is then a Figure; without it
        it is an artifact that assistive technology skips.
    .PARAMETER Direction
        Axial only: LeftToRight, BottomToTop or Diagonal.
    .EXAMPLE
        $doc | Add-VellumPdfGradient -X 72 -Y 600 -Width 300 -Height 100 -StartColor navy -EndColor '#99ccff'
    .OUTPUTS
        VellumPdf.Document.PdfDocument (the same instance, for chaining)
    #>
    [CmdletBinding()]
    [OutputType([VellumPdf.Document.PdfDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VellumPdf.Document.PdfDocument]$Document,

        [ValidateRange(1, 1000000)]
        [int]$Page = 1,

        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Y,
        [Parameter(Mandatory)] [ValidateRange(0.01, 1000000)] [double]$Width,
        [Parameter(Mandatory)] [ValidateRange(0.01, 1000000)] [double]$Height,
        [Parameter(Mandatory)] [object]$StartColor,
        [Parameter(Mandatory)] [object]$EndColor,

        [ValidateSet('Axial', 'Radial')]
        [string]$Type = 'Axial',

        [ValidateSet('LeftToRight', 'BottomToTop', 'Diagonal')]
        [string]$Direction = 'LeftToRight',

        [ValidateNotNullOrEmpty()]
        [string]$AltText
    )

    process {
        Assert-VellumPdfDocumentOpen -Document $Document -CommandName 'Add-VellumPdfGradient'
        if (-not [double]::IsFinite($X) -or -not [double]::IsFinite($Y)) { throw 'Add-VellumPdfGradient: -X and -Y must be finite.' }
        if ($Type -eq 'Radial' -and $PSBoundParameters.ContainsKey('Direction')) {
            throw 'Add-VellumPdfGradient: -Direction applies to an Axial gradient only.'
        }
        $a = ConvertTo-VellumColor $StartColor
        $b = ConvertTo-VellumColor $EndColor
        $c0 = [VellumPdf.Graphics.KernelColor]::new($a[0], $a[1], $a[2])
        $c1 = [VellumPdf.Graphics.KernelColor]::new($b[0], $b[1], $b[2])
        $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $Page -CommandName 'Add-VellumPdfGradient'

        [void]$canvas.SaveState()
        try {
            $tagKind = if ($AltText) { 'Structure' } else { 'Artifact' }
            Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $Document.Pages[$Page - 1] -Kind $tagKind -StructType Figure -AltText $AltText -Draw {
            [void]$canvas.Rectangle($X, $Y, $Width, $Height).Clip().EndPath()
            if ($Type -eq 'Radial') {
                $cx = $X + $Width / 2; $cy = $Y + $Height / 2
                $radius = [math]::Sqrt($Width * $Width + $Height * $Height) / 2
                [void]$canvas.PaintRadialGradient($cx, $cy, 0, $cx, $cy, $radius, $c0, $c1)
            }
            else {
                switch ($Direction) {
                    'LeftToRight' { $pts = @($X, ($Y + $Height / 2), ($X + $Width), ($Y + $Height / 2)) }
                    'BottomToTop' { $pts = @(($X + $Width / 2), $Y, ($X + $Width / 2), ($Y + $Height)) }
                    'Diagonal' { $pts = @($X, $Y, ($X + $Width), ($Y + $Height)) }
                }
                [void]$canvas.PaintAxialGradient($pts[0], $pts[1], $pts[2], $pts[3], $c0, $c1)
            }
            }
        }
        finally { [void]$canvas.RestoreState() }
        $Document
    }
}
