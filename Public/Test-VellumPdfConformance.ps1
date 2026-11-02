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
    .PARAMETER Path
        The PDF file(s). Accepts wildcards, and pipeline input by property name, so
        the file returned by Save-VellumPdfDocument can be piped straight in.
    .PARAMETER LiteralPath
        The PDF file(s), taken literally (no wildcards).
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
    [OutputType([bool], ParameterSetName = 'Quiet')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [Alias('FullName')]
        [string[]]$Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [string[]]$LiteralPath,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$Bytes,

        [ValidateSet('PdfA2b', 'PdfA2u', 'PdfA2a', 'PdfUA1')]
        [string[]]$Profile,

        [securestring]$Password,

        [switch]$Quiet
    )

    begin {
        $plain = if ($Password) { [System.Net.NetworkCredential]::new('', $Password).Password }
        $allOk = $true
    }

    process {
        $sources = @(Get-VellumPdfInput -Path $Path -LiteralPath $LiteralPath -Bytes $Bytes -CommandName 'Test-VellumPdfConformance')

        foreach ($source in $sources) {
            $name = $source.Name
            $data = [byte[]]$source.Data

            $profiles = $Profile
            if (-not $profiles) {
                try {
                    $claimed = [VellumPdf.Conformance.PdfPreflight]::DetectClaimedProfiles($data, $plain)
                }
                catch [VellumPdf.Reader.PdfPasswordException] {
                    throw "Test-VellumPdfConformance: '$name' is encrypted and needs a password. Pass -Password."
                }
                catch [System.IO.InvalidDataException] {
                    throw "Test-VellumPdfConformance: '$name' is not a well-formed PDF: $($_.Exception.Message)"
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
                $result = Invoke-VellumPdfPreflight -Bytes $data -Profile $p -Password $plain -Source $name
                if (-not $result.IsCompliant) { $allOk = $false }
                if (-not $Quiet) { $result }
            }
        }
    }

    end {
        if ($Quiet) { $allOk }
    }
}
