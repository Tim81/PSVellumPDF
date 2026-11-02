function New-VellumPdfErrorRecord {
    <#
    .SYNOPSIS
        Builds an error record with one of the module's stable error ids, the matching exception type and category.
    .DESCRIPTION
        Every error that PSVellumPDF raises for a known cause carries an id that callers can filter on
        (FullyQualifiedErrorId starts with it; PowerShell appends ',<function name>' for advanced functions,
        so compare with -like 'PSVellumPDF.FileNotFound*') and an exception type they can catch:

          Id                          Exception                                  Category
          PSVellumPDF.FileNotFound    System.Management.Automation.ItemNotFoundException   ObjectNotFound
          PSVellumPDF.InvalidArgument System.ArgumentException                  InvalidArgument
          PSVellumPDF.PasswordRequired System.UnauthorizedAccessException       SecurityError
          PSVellumPDF.InvalidPdf      System.IO.InvalidDataException            InvalidData
          PSVellumPDF.NotConformant   System.InvalidOperationException          InvalidResult
          PSVellumPDF.FileReadError   System.IO.IOException                     ReadError
          PSVellumPDF.InputError      System.InvalidOperationException          InvalidData
          PSVellumPDF.<Cmdlet>        System.InvalidOperationException          InvalidOperation

        The last row is the fallback for every other `throw 'Cmdlet: message'`
        (see Resolve-VellumPdfErrorRecord); -Id Command with -CommandName builds it. The message is never
        changed. Throw the result with `throw (New-VellumPdfErrorRecord ...)`.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates an in-memory error record only.')]
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('FileNotFound', 'InvalidArgument', 'PasswordRequired', 'InvalidPdf', 'NotConformant', 'FileReadError', 'InputError', 'Command')]
        [string]$Id,

        [Parameter(Mandatory, Position = 1)]
        [string]$Message,

        [AllowNull()] $Target,

        [System.Exception]$InnerException,

        # The cmdlet name for -Id Command: the id becomes PSVellumPDF.<CommandName>.
        [string]$CommandName
    )

    $category = [System.Management.Automation.ErrorCategory]
    $exception = switch ($Id) {
        'FileNotFound' { $kind = $category::ObjectNotFound; [System.Management.Automation.ItemNotFoundException]::new($Message, $InnerException) }
        'InvalidArgument' { $kind = $category::InvalidArgument; [System.ArgumentException]::new($Message, $InnerException) }
        'PasswordRequired' { $kind = $category::SecurityError; [System.UnauthorizedAccessException]::new($Message, $InnerException) }
        'InvalidPdf' { $kind = $category::InvalidData; [System.IO.InvalidDataException]::new($Message, $InnerException) }
        'NotConformant' { $kind = $category::InvalidResult; [System.InvalidOperationException]::new($Message, $InnerException) }
        'FileReadError' { $kind = $category::ReadError; [System.IO.IOException]::new($Message, $InnerException) }
        'InputError' { $kind = $category::InvalidData; [System.InvalidOperationException]::new($Message, $InnerException) }
        default { $kind = $category::InvalidOperation; [System.InvalidOperationException]::new($Message, $InnerException) }
    }
    $errorId = if ($Id -eq 'Command') { "PSVellumPDF.$CommandName" } else { "PSVellumPDF.$Id" }
    [System.Management.Automation.ErrorRecord]::new($exception, $errorId, $kind, $Target)
}
