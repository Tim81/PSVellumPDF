function Complete-VellumPdfPageDocument {
    <#
    .SYNOPSIS
        Finishes every page canvas of a page-based document before it is saved.
    .DESCRIPTION
        Writes each canvas's operators into its page and collects the canvases'
        text-encoding warnings (characters the base-14 fonts could not encode) for
        Save-VellumPdfDocument to report.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [VellumPdf.Document.PdfDocument]$Document)

    Write-VellumPdfPageBand -Document $Document
    $prop = $Document.PSObject.Properties['PSVellumCanvases']
    if (-not $prop) { return }
    $warnings = [System.Collections.Generic.List[object]]::new()
    $rawCanvas = [bool]$Document.PSObject.Properties['PSVellumRawCanvas']
    $unbalanced = [System.Collections.Generic.List[string]]::new()
    $graphicsStateProblem = $false
    foreach ($entry in @($prop.Value.GetEnumerator())) {
        $canvas = $entry.Value
        $canvas.Finish()
        foreach ($w in $canvas.TextEncodingWarnings) { $warnings.Add($w) }
        if ($rawCanvas) {
            # Invoke-VellumPdfCanvas hands out the raw canvas; a script that saves more often than it restores
            # (or the reverse), or leaves a text object or marked-content sequence open or closes one it did not open,
            # would corrupt everything drawn after it (and structure in a tagged document), so check the finished page.
            $balance = [PSVellumPDF.Interop.ContentStreamBalance]::Scan($entry.Key.ContentBytes)
            if (-not $balance.IsBalanced) {
                $pageNumber = $Document.Pages.IndexOf($entry.Key) + 1
                $unbalanced.Add("page $pageNumber`: $($balance.Describe())")
                if ($balance.MinDepth -lt 0 -or $balance.FinalDepth -ne 0) { $graphicsStateProblem = $true }
            }
        }
    }
    if ($unbalanced.Count -gt 0) {
        $prop.Value.Clear()
        $what = if ($graphicsStateProblem) { 'saved and restored the graphics state unevenly' } else { 'left paired content operators unbalanced' }
        throw ("Invoke-VellumPdfCanvas: the script block $what on " +
            ($unbalanced -join ' | ') + '. Every SaveState needs a RestoreState, every BeginText an EndText and every ' +
            'BeginMarkedContent an EndMarkedContent, inside the same block (and never close more than the block opened).')
    }
    $prop.Value.Clear()
    if ($Document.PSObject.Properties['PSVellumTextWarnings']) { $Document.PSVellumTextWarnings = $warnings }
    else { $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumTextWarnings', $warnings)) }
}
