function ConvertTo-VellumPdfFileError {
    <#
    .SYNOPSIS
        Builds the non-terminating error record for a failure on one input file.
    .DESCRIPTION
        The reader cmdlets report a failure for one file with $PSCmdlet.WriteError(...) and go on
        with the next file. The record keeps the original message (adding the cmdlet and file name
        when the exception does not already start with the cmdlet name) and has the file as its
        TargetObject.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $exception = $ErrorRecord.Exception
    $original = $exception
    if (-not $exception.Message.StartsWith("${CommandName}:", [System.StringComparison]::Ordinal)) {
        $exception = [System.InvalidOperationException]::new("${CommandName}: '$Target': $($exception.Message)", $exception)
    }
    if ($original -is [System.IO.FileNotFoundException]) { $id = 'PdfFileNotFound'; $category = [System.Management.Automation.ErrorCategory]::ObjectNotFound }
    elseif ($original -is [System.IO.IOException] -or $original -is [System.UnauthorizedAccessException]) { $id = 'PdfFileReadError'; $category = [System.Management.Automation.ErrorCategory]::ReadError }
    else { $id = 'PdfInputError'; $category = [System.Management.Automation.ErrorCategory]::InvalidData }
    [System.Management.Automation.ErrorRecord]::new($exception, $id, $category, $Target)
}
