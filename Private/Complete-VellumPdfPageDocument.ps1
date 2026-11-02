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

    $prop = $Document.PSObject.Properties['PSVellumCanvases']
    if (-not $prop) { return }
    $warnings = [System.Collections.Generic.List[object]]::new()
    foreach ($canvas in $prop.Value.Values) {
        $canvas.Finish()
        foreach ($w in $canvas.TextEncodingWarnings) { $warnings.Add($w) }
    }
    $prop.Value.Clear()
    if ($Document.PSObject.Properties['PSVellumTextWarnings']) { $Document.PSVellumTextWarnings = $warnings }
    else { $Document.PSObject.Properties.Add([psnoteproperty]::new('PSVellumTextWarnings', $warnings)) }
}
