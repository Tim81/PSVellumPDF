function Write-VellumPdfPageBands {
    <#
    .SYNOPSIS
        Stamps the repeated headers and footers (Set-VellumPdfPageBand) on every page.
    .DESCRIPTION
        Runs once while a page document is being finished, when the page count is final.
        Each band is drawn as an artifact. The stored bands are cleared afterwards so a
        second pass cannot stamp them twice.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [VellumPdf.Document.PdfDocument]$Document)

    $prop = $Document.PSObject.Properties['PSVellumPageBands']
    if (-not $prop -or $prop.Value.Count -eq 0) { return }
    $bands = @($prop.Value.Values)
    $prop.Value.Clear()
    $count = $Document.Pages.Count
    $rotatedWarned = $false
    for ($i = 1; $i -le $count; $i++) {
        $pdfPage = $Document.Pages[$i - 1]
        if ($pdfPage.Rotate -ne 0 -and -not $rotatedWarned) {
            Write-Warning 'Set-VellumPdfPageBand: a rotated page gets its bands relative to the unrotated page, not the displayed top and bottom.'
            $rotatedWarned = $true
        }
        $canvas = Get-VellumPdfPageCanvas -Document $Document -Page $i -CommandName 'Set-VellumPdfPageBand'
        foreach ($band in $bands) {
            if ($band.SkipFirstPage -and $i -eq 1) { continue }
            $text = $band.Template.Replace('{pages}', [string]($count + $band.StartNumber - 1)).Replace('{page}', [string]($i + $band.StartNumber - 1))
            $width = $pdfPage.MediaBox.Width
            $height = $pdfPage.MediaBox.Height
            $y = if ($band.Position -eq 'Header') { $pdfPage.MediaBox.LlY + $height - $band.Offset } else { $pdfPage.MediaBox.LlY + $band.Offset }
            $left = $pdfPage.MediaBox.LlX
            switch ($band.Align) {
                'Left' { $x = $left + $band.Inset; $alignment = [VellumPdf.Canvas.TextAlignment]::Left }
                'Right' { $x = $left + $width - $band.Inset; $alignment = [VellumPdf.Canvas.TextAlignment]::Right }
                default { $x = $left + $width / 2; $alignment = [VellumPdf.Canvas.TextAlignment]::Center }
            }
            $resolved = $band.Resolved
            [void]$canvas.SaveState()
            try {
                if ($band.Rgb) { [void]$canvas.SetFillColorRgb($band.Rgb[0], $band.Rgb[1], $band.Rgb[2]) }
                Invoke-VellumPdfTagged -Document $Document -Canvas $canvas -PdfPage $pdfPage -Kind Artifact -Draw {
                    [void]$canvas.BeginText()
                    if ($resolved.Handle) {
                        $Document.RegisterEmbeddedFontUsage($pdfPage, $resolved.Handle)
                        [void]$canvas.SetFontByName($resolved.Handle.ResourceName, $band.FontSize)
                        [void][PSVellumPDF.Interop.CanvasHelpers]::ShowEmbeddedText($canvas, $resolved.Handle, $text, $band.FontSize, $x, $y, $alignment)
                    }
                    else {
                        [void]$canvas.SetFont($resolved.Resource, $band.FontSize)
                        [void]$canvas.ShowTextAligned($text, $x, $y, $alignment)
                    }
                    [void]$canvas.EndText()
                }
            }
            finally { [void]$canvas.RestoreState() }
        }
    }
}
