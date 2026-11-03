function Invoke-VellumPdfPreflight {
    <#
    .SYNOPSIS
        Validates PDF bytes against one conformance profile and returns a result object.
    .DESCRIPTION
        Shared by Test-VellumPdfConformance and Save-VellumPdfDocument -Validate.
        Maps the friendly profile names (PdfA2b, PdfA2u, PdfA2a, PdfUA1) to
        VellumPdf.Conformance.PdfConformance and flattens the engine's result into
        a PSVellumPDF.PreflightResult object.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password',
        Justification = 'Internal helper: the public cmdlets take SecureString and convert at the boundary; the engine API needs the plain string.')]
    param(
        [Parameter(Mandatory)] [byte[]]$Bytes,
        [Parameter(Mandatory)] [ValidateSet('PdfA2b', 'PdfA2u', 'PdfA2a', 'PdfUA1')] [string]$Level,
        [string]$Password,
        [string]$Source = '<bytes>'
    )

    $engineProfile = switch ($Level) {
        'PdfA2b' { [VellumPdf.Conformance.PdfConformance]::PdfA2B }
        'PdfA2u' { [VellumPdf.Conformance.PdfConformance]::PdfA2U }
        'PdfA2a' { [VellumPdf.Conformance.PdfConformance]::PdfA2A }
        'PdfUA1' { [VellumPdf.Conformance.PdfConformance]::PdfUA1 }
    }

    try {
        $result = [VellumPdf.Conformance.PdfPreflight]::Validate($Bytes, $engineProfile, $Password)
    }
    catch [VellumPdf.Reader.PdfPasswordException] {
        throw (New-VellumPdfErrorRecord PasswordRequired ("Test-VellumPdfConformance: '$Source' is encrypted and needs a password. " +
                'Pass -Password (an empty user password is tried automatically).') -Target $Source -InnerException $_.Exception)
    }
    catch [System.IO.InvalidDataException] {
        throw (New-VellumPdfErrorRecord InvalidPdf "Test-VellumPdfConformance: '$Source' is not a well-formed PDF: $($_.Exception.Message)" -Target $Source -InnerException $_.Exception)
    }
    catch [VellumPdf.Reader.UnsupportedPdfFeatureException] {
        throw (New-VellumPdfErrorRecord InputError "Test-VellumPdfConformance: '$Source' uses a feature the preflight reader does not support yet: $($_.Exception.Message)" -Target $Source -InnerException $_.Exception)
    }

    $assertions = @(foreach ($a in $result.Assertions) {
            [pscustomobject]@{
                PSTypeName = 'PSVellumPDF.PreflightAssertion'
                RuleId     = $a.RuleId
                Severity   = [string]$a.Severity
                Clause     = $a.Clause
                Message    = $a.Message
                ObjectRef  = $a.ObjectRef
            }
        })
    [pscustomobject]@{
        PSTypeName   = 'PSVellumPDF.PreflightResult'
        Path         = $Source
        Profile      = $Level
        IsCompliant  = $result.IsCompliant
        ErrorCount   = @($assertions | Where-Object Severity -EQ 'Error').Count
        WarningCount = @($assertions | Where-Object Severity -EQ 'Warning').Count
        Assertions   = $assertions
    }
}
