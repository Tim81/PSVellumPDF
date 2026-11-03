function Test-VellumPdfConformance {
    <#
    .SYNOPSIS
        Validates a PDF against PDF/A-2 (b/u/a) or PDF/UA-1, in-process.
    .DESCRIPTION
        Runs VellumPdf's built-in preflight (VellumPdf.Conformance) on an existing
        PDF file or byte array - it does not need veraPDF or any external tool and
        works on any PDF, not just ones this module wrote. It returns one result
        object per profile with the verdict and every finding (rule id, ISO clause,
        severity, message, object).

        Without -Profile the PDF's own claim is read (its XMP PDF/A and PDF/UA
        identification) and every claimed profile is validated. A PDF that claims
        nothing needs an explicit -Profile.

        The preflight covers the checks that can be decided in-process; it is a
        fast regression gate, not a replacement for a certified validator when a
        formal compliance statement is required. Known gap: it does not examine
        fonts that are used only by form fields or other annotation appearances.

        Several files can be given (or piped); they are opened one at a time. A failure for
        one file (not found, unreadable, malformed, wrong password, ...) is a non-terminating
        error with that file as TargetObject and the next file is still processed; use
        -ErrorAction Stop to stop at the first one. Invalid parameters terminate. With -Quiet a file that could
        not be checked makes the result $false.
    .PARAMETER Path
        The PDF file(s). Accepts wildcards. Piped strings bind here, and so do piped objects with a Path property;
        the file returned by Save-VellumPdfDocument (a FileInfo) binds to -LiteralPath, so it can be piped
        straight in and names containing [ ] work.
    .PARAMETER LiteralPath
        The PDF file(s), taken literally (no wildcards). Aliases PSPath and FullName, so objects with either
        property (FileInfo, Select-Object FullName) bind by name.
    .PARAMETER Bytes
        The PDF as a byte array.
    .PARAMETER Profile
        PdfA2b, PdfA2u, PdfA2a or PdfUA1. Default: the profiles the PDF claims.
    .PARAMETER Password
        Password of an encrypted PDF (a SecureString). An empty user password is
        tried automatically.
    .PARAMETER Quiet
        Return only [bool]: $true when every validated profile passes.
    .EXAMPLE
        New-VellumPdfDocument -Conformance PdfA2b | Add-VellumPdfParagraph -Text 'x' |
            Save-VellumPdfDocument -Path ./a.pdf | Test-VellumPdfConformance
    .EXAMPLE
        Test-VellumPdfConformance ./report.pdf -Profile PdfUA1 |
            ForEach-Object Assertions | Where-Object Severity -eq Error
    .OUTPUTS
        PSVellumPDF.PreflightResult (Path, Profile, IsCompliant, ErrorCount,
        WarningCount, Assertions), or System.Boolean with -Quiet.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType('PSVellumPDF.PreflightResult')]
    [OutputType([bool])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', '',
        Justification = '-Profile names the PDF conformance profile (documented API); inside this function it only shadows the host-profile variable.')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath', 'FullName')]
        [string[]]$LiteralPath,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [AllowEmptyCollection()]
        [byte[]]$Bytes,

        [ValidateSet('PdfA2b', 'PdfA2u', 'PdfA2a', 'PdfUA1')]
        [string[]]$Profile,

        [securestring]$Password,

        [switch]$Quiet
    )

    begin {
        try {
            $plain = if ($Password) { [System.Net.NetworkCredential]::new('', $Password).Password }
            $allOk = $true
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Test-VellumPdfConformance'))
        }
    }

    process {
        try {
            foreach ($source in Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -Bytes $Bytes -CommandName 'Test-VellumPdfConformance') {
                try {
                    Read-VellumPdfInput -Source $source
                    $name = $source.Name
                    $data = [byte[]]$source.Data

                    $profiles = $Profile
                    if (-not $profiles) {
                        try {
                            $claimed = [VellumPdf.Conformance.PdfPreflight]::DetectClaimedProfiles($data, $plain)
                        }
                        catch [VellumPdf.Reader.PdfPasswordException] {
                            throw (New-VellumPdfErrorRecord PasswordRequired "Test-VellumPdfConformance: '$name' is encrypted and needs a password. Pass -Password." -Target $name -InnerException $_.Exception)
                        }
                        catch [System.IO.InvalidDataException] {
                            throw (New-VellumPdfErrorRecord InvalidPdf "Test-VellumPdfConformance: '$name' is not a well-formed PDF: $($_.Exception.Message)" -Target $name -InnerException $_.Exception)
                        }
                        $profiles = @(foreach ($c in $claimed) {
                                switch ($c) {
                                    ([VellumPdf.Conformance.PdfConformance]::PdfA2B) { 'PdfA2b' }
                                    ([VellumPdf.Conformance.PdfConformance]::PdfA2U) { 'PdfA2u' }
                                    ([VellumPdf.Conformance.PdfConformance]::PdfA2A) { 'PdfA2a' }
                                    ([VellumPdf.Conformance.PdfConformance]::PdfUA1) { 'PdfUA1' }
                                }
                            })
                        if (-not $profiles) {
                            throw ("Test-VellumPdfConformance: '$name' does not claim PDF/A-2 or PDF/UA-1 conformance. " +
                                'Pass -Profile to validate it against a profile anyway.')
                        }
                    }

                    foreach ($p in $profiles) {
                        $result = Invoke-VellumPdfPreflight -Bytes $data -Level $p -Password $plain -Source $name
                        if (-not $result.IsCompliant) { $allOk = $false }
                        if (-not $Quiet) { $result }
                    }
                }
                catch {
                    $allOk = $false   # a file that could not be checked is not known to conform
                    Write-VellumPdfFileError -Cmdlet $PSCmdlet -ErrorRecord (ConvertTo-VellumPdfFileError -ErrorRecord $_ -Target $source.Name -CommandName 'Test-VellumPdfConformance') -ErrorActionPreferenceValue $ErrorActionPreference
                }
                finally { $source.Data = $null; $data = $null }   # one file in memory at a time
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Test-VellumPdfConformance'))
        }
    }

    end {
        try {
            if ($Quiet) { $allOk }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError((Resolve-VellumPdfErrorRecord -ErrorRecord $_ -CommandName 'Test-VellumPdfConformance'))
        }
    }
}
