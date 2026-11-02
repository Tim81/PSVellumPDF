function Write-VellumPdfPathOps {
    <#
    .SYNOPSIS
        Emits parsed path operations (from ConvertTo-VellumPdfPathOps) as canvas path construction.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [VellumPdf.Canvas.PdfCanvas]$Canvas,
        [Parameter(Mandatory)] [object[]]$Ops
    )
    foreach ($o in $Ops) {
        $a = $o.Args
        switch ($o.Op) {
            'M' { [void]$Canvas.MoveTo($a[0], $a[1]) }
            'L' { [void]$Canvas.LineTo($a[0], $a[1]) }
            'C' { [void]$Canvas.CurveTo($a[0], $a[1], $a[2], $a[3], $a[4], $a[5]) }
            'Z' { [void]$Canvas.ClosePath() }
        }
    }
}
