function ConvertTo-VellumPdfFileError {
    <#
    .SYNOPSIS
        Builds the non-terminating error record for a failure on one input file.
    .DESCRIPTION
        The reader cmdlets report a failure for one file with $PSCmdlet.WriteError(...) and go on
        with the next file. The record keeps the original message (adding the cmdlet and file name
        when the exception does not already start with the cmdlet name) and has the file as its
        TargetObject. Its id and exception type follow the module's scheme (New-VellumPdfErrorRecord):
        PSVellumPDF.FileNotFound (ItemNotFoundException, ObjectNotFound), PSVellumPDF.PasswordRequired
        (UnauthorizedAccessException, SecurityError), PSVellumPDF.InvalidPdf (InvalidDataException,
        InvalidData), PSVellumPDF.FileReadError (IOException, ReadError), otherwise PSVellumPDF.InputError.
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
    $message = $exception.Message
    if (-not $message.StartsWith("${CommandName}:", [System.StringComparison]::Ordinal)) {
        $message = "${CommandName}: '$Target': $message"
    }
    # A cause the module already named (PSVellumPDF.PasswordRequired, .InvalidPdf, ...) keeps its id; otherwise the
    # exception type decides: a missing file, a file that could not be read, or any other failure for this input.
    $known = 'FileNotFound', 'PasswordRequired', 'InvalidPdf', 'FileReadError', 'InputError'
    $named = if ($ErrorRecord.FullyQualifiedErrorId -match '^PSVellumPDF\.([A-Za-z]+)') { $Matches[1] }
    $id = if ($named -in $known) { $named }
    elseif ($exception -is [System.IO.FileNotFoundException] -or $exception -is [System.IO.DirectoryNotFoundException] -or $exception -is [System.Management.Automation.ItemNotFoundException]) { 'FileNotFound' }
    elseif ($exception -is [VellumPdf.Reader.PdfPasswordException]) { 'PasswordRequired' }
    elseif ($exception -is [System.IO.InvalidDataException]) { 'InvalidPdf' }
    elseif ($exception -is [System.IO.IOException] -or $exception -is [System.UnauthorizedAccessException]) { 'FileReadError' }
    else { 'InputError' }
    New-VellumPdfErrorRecord -Id $id -Message $message -Target $Target -InnerException $exception
}
