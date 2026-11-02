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

    Write-VellumPdfPageBands -Document $Document
    $prop = $Document.PSObject.Properties['PSVellumCanvases']
    if (-not $prop) { return }
    $warnings = [System.Collections.Generic.List[object]]::new()
    $rawCanvas = [bool]$Document.PSObject.Properties['PSVellumRawCanvas']
    $unbalanced = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in @($prop.Value.GetEnumerator())) {
        $canvas = $entry.Value
        $canvas.Finish()
        foreach ($w in $canvas.TextEncodingWarnings) { $warnings.Add($w) }
        if ($rawCanvas) {
            # Invoke-VellumPdfCanvas hands out the raw canvas; a script that saves more often than it restores
            # (or the reverse) would corrupt the state of everything drawn after it, so check the finished page.
            $balance = [PSVellumPDF.Interop.ContentStreamBalance]::Scan($entry.Key.ContentBytes)
            if ($balance.MinDepth -lt 0 -or $balance.FinalDepth -ne 0) {
                $pageNumber = $Document.Pages.IndexOf($entry.Key) + 1
                $unbalanced.Add("page $pageNumber (lowest depth $($balance.MinDepth), final depth $($balance.FinalDepth))")
            }
        }
    }
    if ($unbalanced.Count -gt 0) {
        $prop.Value.Clear()
        throw ('Invoke-VellumPdfCanvas: the script block saved and restored the graphics state unevenly on ' +
            ($unbalanced -join '; ') + '. Every SaveState needs a RestoreState inside the same block.')
    }
    $prop.Value.Clear()
    if ($Document.PSObject.Properties['PSVellumTextWarnings']) { $Document.PSVellumTextWarnings = $warnings }
    else { $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumTextWarnings', $warnings)) }
}
