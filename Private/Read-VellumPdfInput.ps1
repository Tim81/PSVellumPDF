function Read-VellumPdfInput {
    <#
    .SYNOPSIS
        Reads the bytes of one input item returned by Get-VellumPdfInput.
    .DESCRIPTION
        Fills the item's Data property (a -Bytes item already has it) and throws a clear
        error when the item could not be resolved, the file is missing, unreadable or empty.
        Callers catch that error per item and report it with ConvertTo-VellumPdfFileError, so one bad
        file does not stop the others. A missing file raises FileNotFoundException.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Source
    )

    $command = $Source.Command
    if ($Source.Error) {
        if ($Source.Name -eq '<bytes>') { throw $Source.Error }
        throw [System.IO.FileNotFoundException]::new($Source.Error, $Source.Name)
    }
    if ($null -ne $Source.Data) { return }
    $file = $Source.Name
    if (-not [System.IO.File]::Exists($file)) {
        throw [System.IO.FileNotFoundException]::new("${command}: file not found: '$file'.", $file)
    }
    try { $data = [System.IO.File]::ReadAllBytes($file) }
    catch { throw [System.IO.IOException]::new("${command}: could not read '$file': $($_.Exception.Message)", $_.Exception) }
    if ($data.Length -eq 0) { throw "${command}: '$file' is empty, so it is not a PDF." }
    $Source.Data = $data
}
