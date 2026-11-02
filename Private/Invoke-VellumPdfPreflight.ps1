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
    param(
        [Parameter(Mandatory)] [byte[]]$Bytes,
        [Parameter(Mandatory)] [ValidateSet('PdfA2b', 'PdfA2u', 'PdfA2a', 'PdfUA1')] [string]$Profile,
        [string]$Password,
        [string]$Source = '<bytes>'
    )

    $engineProfile = switch ($Profile) {
        'PdfA2b' { [VellumPdf.Conformance.PdfConformance]::PdfA2B }
        'PdfA2u' { [VellumPdf.Conformance.PdfConformance]::PdfA2U }
        'PdfA2a' { [VellumPdf.Conformance.PdfConformance]::PdfA2A }
        'PdfUA1' { [VellumPdf.Conformance.PdfConformance]::PdfUA1 }
    }

    try {
        $result = [VellumPdf.Conformance.PdfPreflight]::Validate($Bytes, $engineProfile, $Password)
    }
    catch [VellumPdf.Reader.PdfPasswordException] {
        throw ("Test-VellumPdfConformance: '$Source' is encrypted and needs a password. " +
            'Pass -Password (an empty user password is tried automatically).')
    }
    catch [System.IO.InvalidDataException] {
        throw "Test-VellumPdfConformance: '$Source' is not a well-formed PDF: $($_.Exception.Message)"
    }
    catch [VellumPdf.Reader.UnsupportedPdfFeatureException] {
        throw "Test-VellumPdfConformance: '$Source' uses a feature the preflight reader does not support yet: $($_.Exception.Message)"
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
        Profile      = $Profile
        IsCompliant  = $result.IsCompliant
        ErrorCount   = @($assertions | Where-Object Severity -EQ 'Error').Count
        WarningCount = @($assertions | Where-Object Severity -EQ 'Warning').Count
        Assertions   = $assertions
    }
}
