function Get-VellumPdfConformanceCoverage {
    <#
    .SYNOPSIS
        Lists which PDF/A and PDF/UA checks the in-process preflight performs.
    .DESCRIPTION
        Test-VellumPdfConformance covers the checks that can be decided in-process, and
        the engine publishes exactly which: for every clause of PDF/A-2 and PDF/UA-1 a
        status of Implemented, Partial, Deferred or OutOfScope. This cmdlet returns that
        catalog, so you can see what a passing result does - and does not - tell you
        before relying on it, or decide when a certified validator (veraPDF) is still
        needed. With -Summary it returns the counts and percentage instead.
    .PARAMETER Profile
        Limit to one profile: PdfA2b, PdfA2u, PdfA2a or PdfUA1. Default: all checks.
    .PARAMETER Status
        Limit to checks with this status.
    .PARAMETER Summary
        Return one summary object per profile (counts and percentage implemented).
    .EXAMPLE
        Get-VellumPdfConformanceCoverage -Summary
    .EXAMPLE
        Get-VellumPdfConformanceCoverage -Profile PdfUA1 -Status Deferred, Partial | Format-Table Clause, Status, Note
    .OUTPUTS
        PSVellumPDF.ConformanceCheck (TestId, Profiles, Clause, Status, Note), or
        PSVellumPDF.ConformanceCoverage with -Summary.
    #>
    [CmdletBinding()]
    [OutputType('PSVellumPDF.ConformanceCheck')]
    [OutputType('PSVellumPDF.ConformanceCoverage')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', '',
        Justification = '-Profile names the PDF conformance profile (documented API); inside this function it only shadows the host-profile variable.')]
    param(
        [ValidateSet('PdfA2b', 'PdfA2u', 'PdfA2a', 'PdfUA1')]
        [string[]]$Profile,

        [ValidateSet('Implemented', 'Partial', 'Deferred', 'OutOfScope')]
        [string[]]$Status,

        [switch]$Summary
    )

    try {
        $names = @{
            PdfA2b = [VellumPdf.Conformance.PdfConformance]::PdfA2B
            PdfA2u = [VellumPdf.Conformance.PdfConformance]::PdfA2U
            PdfA2a = [VellumPdf.Conformance.PdfConformance]::PdfA2A
            PdfUA1 = [VellumPdf.Conformance.PdfConformance]::PdfUA1
        }
        $friendly = @{ PdfA2B = 'PdfA2b'; PdfA2U = 'PdfA2u'; PdfA2A = 'PdfA2a'; PdfUA1 = 'PdfUA1' }
        $selected = if ($Profile) { $Profile } else { @('PdfA2b', 'PdfA2u', 'PdfA2a', 'PdfUA1') }

        if ($Summary) {
            foreach ($p in $selected) {
                $c = [VellumPdf.Conformance.Coverage.ConformanceCatalog]::Coverage($names[$p])
                [pscustomobject]@{
                    PSTypeName         = 'PSVellumPDF.ConformanceCoverage'
                    Profile            = $p
                    Total              = $c.Total
                    Implemented        = $c.Implemented
                    Partial            = $c.Partial
                    Deferred           = $c.Deferred
                    OutOfScope         = $c.OutOfScope
                    PercentImplemented = [math]::Round($c.Percent, 1)
                }
            }
            return
        }

        $seen = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($p in $selected) {
            foreach ($check in [VellumPdf.Conformance.Coverage.ConformanceCatalog]::For($names[$p])) {
                if ($Status -and ([string]$check.Status) -notin $Status) { continue }
                if (-not $seen.Add($check.TestId)) { continue }   # a check shared by several profiles is listed once
                [pscustomobject]@{
                    PSTypeName = 'PSVellumPDF.ConformanceCheck'
                    TestId     = $check.TestId
                    Profiles   = @($check.Profiles | ForEach-Object { $friendly[[string]$_] })
                    Clause     = $check.Clause
                    Status     = [string]$check.Status
                    Note       = $check.Note
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
