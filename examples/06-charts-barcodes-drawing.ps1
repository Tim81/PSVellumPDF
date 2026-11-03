<#
    Charts, barcodes and free-form drawing in a flowing document: a pie chart
    built from pipeline data, a QR code and a retail barcode, and a vector
    drawing (gradient-like bars, transparency, a dashed line and text) made with
    the VellumPdf canvas inside a script block.

    Run from the repo root after ./build.ps1 Restore:
        ./examples/06-charts-barcodes-drawing.ps1
#>
#requires -Version 7.6
Import-Module (Join-Path $PSScriptRoot '..' 'PSVellumPDF.psd1') -Force

$out = Join-Path $PSScriptRoot 'charts-barcodes-drawing.pdf'

$files = Get-ChildItem $PSScriptRoot -File | Group-Object Extension | Sort-Object Count -Descending | Select-Object -First 5

$doc = New-VellumPdfDocument -Margin 50 |
    Add-VellumPdfHeading -Text 'Charts, codes and drawings' -Color '#1f3a93'

# Pipeline data: the chart takes the document by parameter and the objects from the pipeline.
$files | Add-VellumPdfPieChart -Document $doc -ValueProperty Count -LabelProperty Name -Legend -Diameter 160 | Out-Null

$doc |
    Add-VellumPdfBarcode -Type QrCode -Content 'https://github.com/Tim81/PSVellumPDF' -TargetWidth 80 -MarginTop 12 |
    Add-VellumPdfBarcode -Type Ean13 -Content '5901234123457' -BarHeight 45 -MarginTop 12 |
    Add-VellumPdfDrawing -Height 90 -MarginTop 12 -AltText 'Three translucent bars and a dashed baseline' -ScriptBlock {
        param($canvas, $box, $ctx)
        # $box is the reserved area in PDF points (origin bottom-left).
        $font = $ctx.GetFont([VellumPdf.Fonts.Standard14]::Helvetica)
        foreach ($i in 0..2) {
            [void]$canvas.SetFillAlpha(0.35 + 0.25 * $i).SetFillColorCmyk(1 - 0.3 * $i, 0.4, 0, 0.1)
            [void]$canvas.Rectangle($box.X + 10 + 70 * $i, $box.Y + 14, 55, 30 + 18 * $i).Fill()
        }
        [void]$canvas.SetFillAlpha(1).SetStrokeColorGray(0.3).SetLineWidth(1)
        [void][PSVellumPDF.Interop.CanvasHelpers]::SetLineDash($canvas, [double[]](5, 3), 0)
        [void]$canvas.MoveTo($box.X + 5, $box.Y + 12).LineTo($box.X + 230, $box.Y + 12).Stroke()
        [void]$canvas.SetFillColorGray(0).BeginText().SetFont($font, 9).MoveTextPosition($box.X + 10, $box.Y + 2).ShowText('bars: 3 samples').EndText()
    } |
    Save-VellumPdfDocument -Path $out

"Wrote $out"
