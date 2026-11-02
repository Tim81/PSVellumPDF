function Write-VellumPdfTextLines {
    <#
    .SYNOPSIS
        Draws lines from Split-VellumPdfTextLine, one text object per line.
    .DESCRIPTION
        The first baseline sits one font size below -Top and the others follow at -Leading. Left, Center
        and Right align about the column; Justify stretches every line except the last of a paragraph to
        the full width, drawing it word by word with an invisible trailing space on every word but the
        last so that text extraction keeps its spaces. Call it inside the marked content of the element
        that owns the text.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [VellumPdf.Canvas.PdfCanvas]$Canvas,
        [Parameter(Mandatory)] $Resolved,
        [Parameter(Mandatory)] [double]$FontSize,
        [Parameter(Mandatory)] [object[]]$Lines,
        [Parameter(Mandatory)] [double]$X,
        [Parameter(Mandatory)] [double]$Top,
        [Parameter(Mandatory)] [double]$Width,
        [Parameter(Mandatory)] [double]$Leading,
        [ValidateSet('Left', 'Center', 'Right', 'Justify')] [string]$Align = 'Left'
    )
    $left = [VellumPdf.Canvas.TextAlignment]::Left
    $show = {
        param([string]$s, [double]$x, [double]$y, $alignment)
        if ($Resolved.Handle) {
            [void][PSVellumPDF.Interop.CanvasHelpers]::ShowEmbeddedText($Canvas, $Resolved.Handle, $s, $FontSize, $x, $y, $alignment)
        }
        else { [void]$Canvas.ShowTextAligned($s, $x, $y, $alignment) }
    }
    $row = 0
    foreach ($line in $Lines) {
        $baseline = $Top - $FontSize - $row * $Leading
        $row++
        if ($line.Words.Count -eq 0) { continue }
        [void]$Canvas.BeginText()
        if ($Resolved.Handle) { [void]$Canvas.SetFontByName($Resolved.Handle.ResourceName, $FontSize) }
        else { [void]$Canvas.SetFont($Resolved.Resource, $FontSize) }
        $textLine = $line.Words -join ' '
        if ($Align -eq 'Justify' -and -not $line.Last -and $line.Words.Count -gt 1) {
            $wordsWidth = 0.0
            foreach ($w in $line.Words) { $wordsWidth += (Measure-VellumPdfTextWidth -Resolved $Resolved -Text $w -FontSize $FontSize) }
            $gap = ($Width - $wordsWidth) / ($line.Words.Count - 1)
            $cursor = $X
            for ($n = 0; $n -lt $line.Words.Count; $n++) {
                $w = $line.Words[$n]
                $shown = if ($n -lt $line.Words.Count - 1) { $w + ' ' } else { $w }
                & $show $shown $cursor $baseline $left
                $cursor += (Measure-VellumPdfTextWidth -Resolved $Resolved -Text $w -FontSize $FontSize) + $gap
            }
        }
        elseif ($Align -eq 'Center') { & $show $textLine ($X + $Width / 2) $baseline ([VellumPdf.Canvas.TextAlignment]::Center) }
        elseif ($Align -eq 'Right') { & $show $textLine ($X + $Width) $baseline ([VellumPdf.Canvas.TextAlignment]::Right) }
        else { & $show $textLine $X $baseline $left }
        [void]$Canvas.EndText()
    }
}
