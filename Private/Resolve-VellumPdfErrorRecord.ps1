function Resolve-VellumPdfErrorRecord {
    <#
    .SYNOPSIS
        Gives an error a stable id: used in the catch block of every public cmdlet before ThrowTerminatingError.
    .DESCRIPTION
        The module raises most errors with `throw 'Cmdlet: message'`, which PowerShell reports as a
        RuntimeException whose FullyQualifiedErrorId is the whole message text and whose category is
        OperationStopped: nothing a caller can filter or catch by type. This turns exactly such a
        message-only error into an InvalidOperation error with the id PSVellumPDF.<CommandName> (the
        exception is an InvalidOperationException with the original message and the original exception
        inside it). The message text is never changed.

        Everything else passes through unchanged: a record the module already built with a specific id
        (New-VellumPdfErrorRecord: PSVellumPDF.FileNotFound, .InvalidArgument, .PasswordRequired,
        .InvalidPdf, .NotConformant, ...), parameter-binding and validation errors, and engine exceptions.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    $exception = $ErrorRecord.Exception
    $messageOnly = $exception.GetType() -eq [System.Management.Automation.RuntimeException] -and
        $ErrorRecord.FullyQualifiedErrorId -ceq $exception.Message
    if (-not $messageOnly) { return $ErrorRecord }
    New-VellumPdfErrorRecord -Id Command -Message $exception.Message -Target $ErrorRecord.TargetObject -InnerException $exception -CommandName $CommandName
}
