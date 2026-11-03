function Read-VellumPdfInput {
    <#
    .SYNOPSIS
        Reads the bytes of one input item returned by Get-VellumPdfInput.
    .DESCRIPTION
        Fills the item's Data property (a -Bytes item already has it) and throws a clear
        error when the item could not be resolved, the file is missing, unreadable or empty.
        Callers catch that error per item and report it with ConvertTo-VellumPdfFileError, so one bad
        file does not stop the others. A missing file raises PSVellumPDF.FileNotFound, an unreadable one
        PSVellumPDF.FileReadError, an empty one PSVellumPDF.InvalidPdf (see New-VellumPdfErrorRecord).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Source
    )

    $command = $Source.Command
    if ($Source.Error) {
        if ($Source.Name -eq '<bytes>') { throw (New-VellumPdfErrorRecord InvalidPdf $Source.Error -Target $Source.Name) }
        throw (New-VellumPdfErrorRecord FileNotFound $Source.Error -Target $Source.Name)
    }
    if ($null -ne $Source.Data) { return }
    $file = $Source.Name
    if (-not [System.IO.File]::Exists($file)) {
        throw (New-VellumPdfErrorRecord FileNotFound "${command}: file not found: '$file'." -Target $file)
    }
    try { $data = [System.IO.File]::ReadAllBytes($file) }
    catch { throw (New-VellumPdfErrorRecord FileReadError "${command}: could not read '$file': $($_.Exception.Message)" -Target $file -InnerException $_.Exception) }
    if ($data.Length -eq 0) { throw (New-VellumPdfErrorRecord InvalidPdf "${command}: '$file' is empty, so it is not a PDF." -Target $file) }
    $Source.Data = $data
}
